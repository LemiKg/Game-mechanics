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
	var captured: Array[StatModifier] = []
	b.modifier_added.connect(func(m): captured.append(m))
	b.add_modifier(_make_mod(&"attack", StatModifier.Op.FLAT, 3.0))
	b.remove_modifier(captured[0])
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
	b.stat_changed.connect(func(id, old, new_val): captured.append([id, old, new_val]))
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
	assert(captured[0].stat_id == mod.stat_id)
	assert(captured[0].op == mod.op)
	assert(captured[0].value == mod.value)
	return true

func test_modifier_removed_signal_carries_reason() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var captured := []
	b.modifier_removed.connect(func(m, reason): captured.append([m, reason]))
	var mod := _make_mod(&"attack", StatModifier.Op.FLAT, 3.0, &"helmet")
	b.add_modifier(mod)
	b.remove_modifiers_by_source(&"helmet")
	assert(captured.size() == 1)
	assert(captured[0][0].source_id == &"helmet")
	assert(captured[0][1] == StatModifier.RemoveReason.SOURCE_REMOVED)
	return true

func test_stat_changed_does_not_fire_when_remove_leaves_value_unchanged() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var added: Array[StatModifier] = []
	b.modifier_added.connect(func(m): added.append(m))
	b.add_modifier(_make_mod(&"attack", StatModifier.Op.FLAT, 0.0))
	var emit_count := [0]
	b.stat_changed.connect(func(_id, _old, _new): emit_count[0] += 1)
	b.remove_modifier(added[0])
	assert(emit_count[0] == 0, "expected 0 emits on remove of no-op modifier, got %d" % emit_count[0])
	return true

# --- Part C: resource current pool ---

func test_get_current_for_resource_returns_full_when_uninitialized() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	assert(b.get_current(&"health") == 100.0)
	return true

func test_modify_resource_subtracts() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	b.modify_resource(&"health", -30.0)
	assert(b.get_current(&"health") == 70.0)
	return true

func test_modify_resource_clamps_at_zero() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	b.modify_resource(&"health", -150.0)
	assert(b.get_current(&"health") == 0.0)
	return true

func test_modify_resource_clamps_at_max() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	b.modify_resource(&"health", -30.0)
	assert(b.get_current(&"health") == 70.0)
	b.modify_resource(&"health", 999.0)
	assert(b.get_current(&"health") == 100.0)
	return true

func test_modify_resource_on_flat_stat_warns_and_noops() -> bool:
	var b := _make_block([_make_def(&"attack", 10.0, false)])
	b.modify_resource(&"attack", -5.0)
	assert(b.get_value(&"attack") == 10.0)
	return true

func test_modify_resource_emits_stat_changed() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	var captured := []
	b.stat_changed.connect(func(id, old, new_val): captured.append([id, old, new_val]))
	b.modify_resource(&"health", -30.0)
	assert(captured.size() == 1)
	assert(captured[0][0] == &"health")
	assert(captured[0][1] == 100.0)
	assert(captured[0][2] == 70.0)
	return true

func test_resource_depleted_signal_fires_at_zero() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	var depleted := []
	b.resource_depleted.connect(func(id): depleted.append(id))
	b.modify_resource(&"health", -100.0)
	assert(depleted.size() == 1)
	assert(depleted[0] == &"health")
	return true

func test_resource_filled_signal_fires_when_back_to_max() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	var filled := []
	b.resource_filled.connect(func(id): filled.append(id))
	b.modify_resource(&"health", -30.0)
	# Not yet at max — no emit.
	assert(filled.size() == 0)
	b.modify_resource(&"health", 30.0)
	# Now back to max — emit.
	assert(filled.size() == 1)
	assert(filled[0] == &"health")
	return true

func test_set_current_clamps() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	b.set_current(&"health", 50.0)
	assert(b.get_current(&"health") == 50.0)
	b.set_current(&"health", -10.0)
	assert(b.get_current(&"health") == 0.0)
	b.set_current(&"health", 9999.0)
	assert(b.get_current(&"health") == 100.0)
	return true

func test_set_current_emits_depleted_when_crossing_zero() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	var depleted := []
	b.resource_depleted.connect(func(id): depleted.append(id))
	b.set_current(&"health", 0.0)
	assert(depleted.size() == 1)
	assert(depleted[0] == &"health")
	return true

func test_set_current_emits_filled_when_restoring_to_max() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	b.set_current(&"health", 50.0)
	var filled := []
	b.resource_filled.connect(func(id): filled.append(id))
	b.set_current(&"health", 100.0)
	assert(filled.size() == 1)
	assert(filled[0] == &"health")
	return true

func test_modify_resource_already_at_zero_does_not_double_fire_depleted() -> bool:
	var b := _make_block([_make_def(&"health", 100.0, true)])
	b.modify_resource(&"health", -100.0)  # depletes
	var depleted_count := [0]
	b.resource_depleted.connect(func(_id): depleted_count[0] += 1)
	b.modify_resource(&"health", -50.0)  # already at zero, no-op
	assert(depleted_count[0] == 0, "expected 0 emits, got %d" % depleted_count[0])
	return true

# --- Part D: tick (regen + timed modifier countdown) ---

func test_tick_applies_regen_to_resource() -> bool:
	var def := _make_def(&"health", 100.0, true)
	def.regen_per_second = 10.0
	var b := _make_block([def])
	b.modify_resource(&"health", -50.0)
	assert(b.get_current(&"health") == 50.0)
	b.tick(1.0)
	assert(b.get_current(&"health") == 60.0)
	b.tick(0.5)
	assert(b.get_current(&"health") == 65.0)
	return true

func test_tick_regen_does_not_overshoot_max() -> bool:
	var def := _make_def(&"health", 100.0, true)
	def.regen_per_second = 50.0
	var b := _make_block([def])
	b.modify_resource(&"health", -10.0)
	b.tick(10.0)  # would add 500
	assert(b.get_current(&"health") == 100.0)
	return true

func test_tick_no_regen_for_flat_stats() -> bool:
	# Flat stats have no current pool, so tick shouldn't touch them.
	var def := _make_def(&"attack", 5.0, false)
	def.regen_per_second = 99.0  # nonsense, but should be ignored
	var b := _make_block([def])
	b.tick(1.0)
	assert(b.get_value(&"attack") == 5.0)
	return true

func test_tick_decrements_timed_modifier_remaining() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var captured: Array[StatModifier] = []
	b.modifier_added.connect(func(m): captured.append(m))
	var input := _make_mod(&"attack", StatModifier.Op.FLAT, 10.0)
	input.duration = 2.0
	b.add_modifier(input)
	var owned := captured[0]
	assert(owned.remaining == 2.0)
	b.tick(0.5)
	assert(owned.remaining == 1.5)
	assert(b.get_value(&"attack") == 15.0)
	return true

func test_tick_expires_timed_modifier_at_zero() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var added: Array[StatModifier] = []
	b.modifier_added.connect(func(m): added.append(m))
	var input := _make_mod(&"attack", StatModifier.Op.FLAT, 10.0)
	input.duration = 1.0
	b.add_modifier(input)
	assert(b.get_value(&"attack") == 15.0)
	var captured := []
	b.modifier_removed.connect(func(mod, reason): captured.append([mod, reason]))
	b.tick(1.5)
	assert(b.get_value(&"attack") == 5.0)
	assert(captured.size() == 1)
	assert(captured[0][0] == added[0])  # owned instance, not the input
	assert(captured[0][1] == StatModifier.RemoveReason.EXPIRED)
	return true

func test_tick_does_not_expire_permanent_modifier() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var m := _make_mod(&"attack", StatModifier.Op.FLAT, 10.0)
	# duration = -1 is permanent
	b.add_modifier(m)
	b.tick(9999.0)
	assert(b.get_value(&"attack") == 15.0)
	return true
