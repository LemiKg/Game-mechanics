extends RefCounted
## Tests for StatBlock. Built up across plan tasks 6–10.

func _make_def(id: StringName, base: float, is_resource: bool = false, max_v: float = 0.0) -> StatDefinition:
	var d := StatDefinition.new()
	d.id = id
	d.display_name = String(id).capitalize()
	d.base_value = base
	d.max_value = max_v
	d.is_resource = is_resource
	return d

func _make_block(defs: Array[StatDefinition]) -> StatBlock:
	var b := StatBlock.new()
	b.definitions = defs
	# Safety net: a StatBlock loaded from a .tres with formula=null would have
	# its _init default overwritten by the loader. Harmless in tests but
	# documents the real edge case the guard exists for.
	if b.formula == null:
		b.formula = AdditivePercentFormula.new()
	return b

# --- Part A: definitions + value reads ---

func test_get_value_for_flat_stat() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	assert(b.get_value(&"attack") == 5.0)
	return true

func test_get_value_unknown_returns_zero_and_warns() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	# Just check the return value; the warning is observational only.
	assert(b.get_value(&"nope") == 0.0)
	return true

func test_get_max_equals_get_value_for_flat_stat() -> bool:
	var b := _make_block([_make_def(&"attack", 7.0)])
	assert(b.get_max(&"attack") == 7.0)
	return true

func test_get_max_for_resource_stat_uses_base() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	assert(b.get_max(&"health") == 100.0)
	return true

func test_get_current_flat_equals_value() -> bool:
	var b := _make_block([_make_def(&"attack", 7.0)])
	assert(b.get_current(&"attack") == 7.0)
	return true

func test_default_formula_is_additive_percent() -> bool:
	var b := StatBlock.new()
	assert(b.formula != null)
	assert(b.formula is AdditivePercentFormula)
	return true

# --- Part B: modifier mgmt ---

func _make_mod(stat_id: StringName, op: int, value: float, source: StringName = &"") -> StatModifier:
	var m := StatModifier.new()
	m.stat_id = stat_id
	m.op = op
	m.value = value
	m.source_id = source
	return m

func test_add_modifier_changes_value() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	b.add_modifier(_make_mod(&"attack", StatModifier.Op.FLAT, 3.0))
	assert(b.get_value(&"attack") == 8.0)
	return true

func test_remove_modifier_restores_value() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var m := _make_mod(&"attack", StatModifier.Op.FLAT, 3.0)
	b.add_modifier(m)
	b.remove_modifier(m)
	assert(b.get_value(&"attack") == 5.0)
	return true

func test_remove_modifiers_by_source_removes_all_from_one_source() -> bool:
	var b := _make_block([_make_def(&"attack", 0.0), _make_def(&"defense", 0.0)])
	b.add_modifier(_make_mod(&"attack", StatModifier.Op.FLAT, 5.0, &"helmet"))
	b.add_modifier(_make_mod(&"defense", StatModifier.Op.FLAT, 3.0, &"helmet"))
	b.add_modifier(_make_mod(&"attack", StatModifier.Op.FLAT, 2.0, &"sword"))
	assert(b.get_value(&"attack") == 7.0)
	assert(b.get_value(&"defense") == 3.0)
	b.remove_modifiers_by_source(&"helmet")
	assert(b.get_value(&"attack") == 2.0)
	assert(b.get_value(&"defense") == 0.0)
	return true

func test_add_null_modifier_is_noop() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	b.add_modifier(null)
	assert(b.get_value(&"attack") == 5.0)
	return true

func test_add_modifier_with_unknown_stat_is_noop() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	b.add_modifier(_make_mod(&"nope", StatModifier.Op.FLAT, 100.0))
	assert(b.get_value(&"attack") == 5.0)
	return true

func test_stat_changed_signal_fires_on_add() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var captured := []
	b.stat_changed.connect(func(id, old, new): captured.append([id, old, new]))
	b.add_modifier(_make_mod(&"attack", StatModifier.Op.FLAT, 3.0))
	assert(captured.size() == 1, "expected 1 emit, got %d" % captured.size())
	assert(captured[0][0] == &"attack")
	assert(captured[0][1] == 5.0)
	assert(captured[0][2] == 8.0)
	return true

func test_stat_changed_does_not_fire_when_value_unchanged() -> bool:
	# Adding a 0-value modifier should not emit because computed value is unchanged.
	var b := _make_block([_make_def(&"attack", 5.0)])
	var emit_count := [0]
	b.stat_changed.connect(func(_id, _old, _new): emit_count[0] += 1)
	b.add_modifier(_make_mod(&"attack", StatModifier.Op.FLAT, 0.0))
	assert(emit_count[0] == 0, "expected 0 emits, got %d" % emit_count[0])
	return true

func test_modifier_added_signal_fires() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var captured := []
	b.modifier_added.connect(func(m): captured.append(m))
	var mod := _make_mod(&"attack", StatModifier.Op.FLAT, 3.0)
	b.add_modifier(mod)
	assert(captured.size() == 1)
	assert(captured[0] == mod)
	return true

func test_modifier_removed_signal_carries_reason() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var captured := []
	b.modifier_removed.connect(func(m, reason): captured.append([m, reason]))
	var mod := _make_mod(&"attack", StatModifier.Op.FLAT, 3.0, &"helmet")
	b.add_modifier(mod)
	b.remove_modifiers_by_source(&"helmet")
	assert(captured.size() == 1)
	assert(captured[0][0] == mod)
	assert(captured[0][1] == StatModifier.RemoveReason.SOURCE_REMOVED)
	return true
