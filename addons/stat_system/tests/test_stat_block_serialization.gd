extends RefCounted
## Tests for StatBlock.serialize() / deserialize().

func _make_def(id: StringName, base: float, is_resource: bool = false) -> StatDefinition:
	var d := StatDefinition.new()
	d.id = id
	d.base_value = base
	d.is_resource = is_resource
	return d

func _make_block() -> StatBlock:
	var b := StatBlock.new()
	b.definitions = [
		_make_def(&"health", 100.0, true),
		_make_def(&"mana", 50.0, true),
		_make_def(&"attack", 10.0, false),
	]
	if b.formula == null:
		b.formula = AdditivePercentFormula.new()
	return b

func test_serialize_returns_dict_with_current_resources() -> bool:
	var b := _make_block()
	b.modify_resource(&"health", -30.0)  # current = 70
	var data := b.serialize()
	assert(data.has("current_resources"))
	var cr: Dictionary = data["current_resources"]
	assert(cr.has(&"health") or cr.has("health"))  # tolerate StringName/String round-trip
	var hp_value = cr.get(&"health", cr.get("health", null))
	assert(hp_value == 70.0)
	return true

func test_serialize_omits_modifiers() -> bool:
	var b := _make_block()
	var m := StatModifier.new()
	m.stat_id = &"attack"
	m.op = StatModifier.Op.FLAT
	m.value = 5.0
	b.add_modifier(m)
	var data := b.serialize()
	# Modifiers must NOT be persisted — equipment re-pushes them on load.
	# Stronger check: the only top-level key must be "current_resources".
	assert(data.keys() == ["current_resources"])
	return true

func test_deserialize_restores_current_resources() -> bool:
	var b := _make_block()
	var data := {
		"current_resources": {&"health": 42.0, &"mana": 13.0},
	}
	b.deserialize(data)
	assert(b.get_current(&"health") == 42.0)
	assert(b.get_current(&"mana") == 13.0)
	return true

func test_deserialize_clamps_to_current_max() -> bool:
	# A save with current > max (e.g. after a balance change) clamps cleanly.
	var b := _make_block()
	var data := {
		"current_resources": {&"health": 9999.0},
	}
	b.deserialize(data)
	assert(b.get_current(&"health") == 100.0)
	return true

func test_round_trip_preserves_state() -> bool:
	var b1 := _make_block()
	b1.modify_resource(&"health", -25.0)
	b1.modify_resource(&"mana", -10.0)
	var data := b1.serialize()

	var b2 := _make_block()
	b2.deserialize(data)
	assert(b2.get_current(&"health") == 75.0)
	assert(b2.get_current(&"mana") == 40.0)
	assert(b2.get_value(&"attack") == 10.0)
	return true

func test_round_trip_clamps_when_loaded_max_is_lower() -> bool:
	# Save with an inflated max (via modifier), load on a fresh block where
	# the modifier is gone — saved current must clamp down to the base max.
	var b1 := _make_block()
	var m := StatModifier.new()
	m.stat_id = &"health"
	m.op = StatModifier.Op.FLAT
	m.value = 100.0  # inflates max from 100 to 200
	b1.add_modifier(m)
	b1.set_current(&"health", 150.0)
	assert(b1.get_current(&"health") == 150.0)
	var data := b1.serialize()

	# Fresh block — no modifier, max is back to 100.
	var b2 := _make_block()
	b2.deserialize(data)
	assert(b2.get_current(&"health") == 100.0, "expected clamp to 100, got %f" % b2.get_current(&"health"))
	return true
