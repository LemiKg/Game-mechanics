extends RefCounted
## Tests for StatReader's forwarding of modifier_added and modifier_removed signals.

func _make_def(id: StringName, base: float) -> StatDefinition:
	var d := StatDefinition.new()
	d.id = id
	d.base_value = base
	return d

func _make_block(defs: Array[StatDefinition]) -> StatBlock:
	var b := StatBlock.new()
	b.definitions = defs
	if b.formula == null:
		b.formula = AdditivePercentFormula.new()
	return b

func test_reader_forwards_modifier_added() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var r := StatReader.new(b)
	var captured := []
	r.modifier_added.connect(func(m): captured.append(m))
	var input := StatModifier.new()
	input.stat_id = &"attack"
	input.op = StatModifier.Op.FLAT
	input.value = 3.0
	b.add_modifier(input)
	assert(captured.size() == 1, "expected 1 modifier_added emit, got %d" % captured.size())
	# StatBlock.add_modifier duplicates the input, so the captured instance is
	# the owned copy — assert by field, not identity.
	assert(captured[0].stat_id == &"attack")
	assert(captured[0].op == StatModifier.Op.FLAT)
	assert(captured[0].value == 3.0)
	return true

func test_reader_forwards_modifier_removed_with_reason() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var r := StatReader.new(b)
	var captured := []
	r.modifier_removed.connect(func(m, reason): captured.append([m, reason]))
	var input := StatModifier.new()
	input.stat_id = &"attack"
	input.op = StatModifier.Op.FLAT
	input.value = 3.0
	input.source_id = &"helmet"
	b.add_modifier(input)
	b.remove_modifiers_by_source(&"helmet")
	assert(captured.size() == 1)
	assert(captured[0][0].source_id == &"helmet")
	assert(captured[0][1] == StatModifier.RemoveReason.SOURCE_REMOVED)
	return true

func test_reader_with_null_block_does_not_crash() -> bool:
	# The _init guard must hold even after the signal additions —
	# StatReader.new(null) must construct safely with no connections.
	var r := StatReader.new(null)
	assert(r != null)
	# Reads should also fall through to safe defaults.
	assert(r.get_value(&"anything") == 0.0)
	assert(r.get_active_modifiers().is_empty())
	return true
