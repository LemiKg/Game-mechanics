extends RefCounted
## Tests for AdditivePercentFormula.
## Formula: final = (base + sum_flat) * (1 + sum_percent / 100), clamped.

func _make_def(base: float, min_v: float = 0.0, max_v: float = 0.0) -> StatDefinition:
	var d := StatDefinition.new()
	d.id = &"test"
	d.base_value = base
	d.min_value = min_v
	d.max_value = max_v
	return d

func _make_mod(op: int, value: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat_id = &"test"
	m.op = op
	m.value = value
	return m

func test_empty_modifiers_returns_base() -> bool:
	var f := AdditivePercentFormula.new()
	var d := _make_def(10.0)
	var result := f.compute(d, [])
	assert(result == 10.0, "expected 10.0, got %f" % result)
	return true

func test_single_flat_modifier_adds() -> bool:
	var f := AdditivePercentFormula.new()
	var d := _make_def(10.0)
	var mods: Array[StatModifier] = [_make_mod(StatModifier.Op.FLAT, 5.0)]
	var result := f.compute(d, mods)
	assert(result == 15.0, "expected 15.0, got %f" % result)
	return true

func test_single_percent_modifier_multiplies() -> bool:
	var f := AdditivePercentFormula.new()
	var d := _make_def(100.0)
	var mods: Array[StatModifier] = [_make_mod(StatModifier.Op.PERCENT, 10.0)]
	var result := f.compute(d, mods)
	assert(result == 110.0, "expected 110.0, got %f" % result)
	return true

func test_mixed_flat_and_percent() -> bool:
	# (100 + 20) * (1 + 50/100) = 120 * 1.5 = 180
	var f := AdditivePercentFormula.new()
	var d := _make_def(100.0)
	var mods: Array[StatModifier] = [
		_make_mod(StatModifier.Op.FLAT, 20.0),
		_make_mod(StatModifier.Op.PERCENT, 50.0),
	]
	var result := f.compute(d, mods)
	assert(result == 180.0, "expected 180.0, got %f" % result)
	return true

func test_multiple_flats_sum() -> bool:
	var f := AdditivePercentFormula.new()
	var d := _make_def(0.0)
	var mods: Array[StatModifier] = [
		_make_mod(StatModifier.Op.FLAT, 5.0),
		_make_mod(StatModifier.Op.FLAT, 3.0),
		_make_mod(StatModifier.Op.FLAT, 2.0),
	]
	var result := f.compute(d, mods)
	assert(result == 10.0, "expected 10.0, got %f" % result)
	return true

func test_multiple_percents_sum_additively() -> bool:
	# 100 * (1 + (10 + 20 + 30)/100) = 100 * 1.6 = 160
	var f := AdditivePercentFormula.new()
	var d := _make_def(100.0)
	var mods: Array[StatModifier] = [
		_make_mod(StatModifier.Op.PERCENT, 10.0),
		_make_mod(StatModifier.Op.PERCENT, 20.0),
		_make_mod(StatModifier.Op.PERCENT, 30.0),
	]
	var result := f.compute(d, mods)
	assert(result == 160.0, "expected 160.0, got %f" % result)
	return true

func test_negative_percent_caps_at_zero() -> bool:
	# 100 * (1 + (-100)/100) = 100 * 0 = 0
	var f := AdditivePercentFormula.new()
	var d := _make_def(100.0)
	var mods: Array[StatModifier] = [_make_mod(StatModifier.Op.PERCENT, -100.0)]
	var result := f.compute(d, mods)
	assert(result == 0.0, "expected 0.0, got %f" % result)
	return true

func test_max_value_clamps() -> bool:
	var f := AdditivePercentFormula.new()
	var d := _make_def(100.0, 0.0, 150.0)  # max 150
	var mods: Array[StatModifier] = [_make_mod(StatModifier.Op.FLAT, 200.0)]
	var result := f.compute(d, mods)
	assert(result == 150.0, "expected 150.0, got %f" % result)
	return true

func test_min_value_clamps() -> bool:
	var f := AdditivePercentFormula.new()
	var d := _make_def(50.0, 10.0, 0.0)  # min 10
	var mods: Array[StatModifier] = [_make_mod(StatModifier.Op.FLAT, -100.0)]
	var result := f.compute(d, mods)
	assert(result == 10.0, "expected 10.0, got %f" % result)
	return true

func test_max_value_zero_means_unbounded() -> bool:
	var f := AdditivePercentFormula.new()
	var d := _make_def(100.0, 0.0, 0.0)  # 0 = unbounded
	var mods: Array[StatModifier] = [_make_mod(StatModifier.Op.FLAT, 999999.0)]
	var result := f.compute(d, mods)
	assert(result == 1000099.0, "expected 1000099.0, got %f" % result)
	return true
