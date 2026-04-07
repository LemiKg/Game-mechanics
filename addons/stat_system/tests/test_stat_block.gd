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
