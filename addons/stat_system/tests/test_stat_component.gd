extends RefCounted
## Tests for StatComponent. Avoids real _process — calls tick() directly
## via stat_block to keep these deterministic.

func _make_def(id: StringName, base: float, is_resource: bool = false) -> StatDefinition:
	var d := StatDefinition.new()
	d.id = id
	d.base_value = base
	d.is_resource = is_resource
	return d

func _make_component() -> StatComponent:
	var c := StatComponent.new()
	var b := StatBlock.new()
	b.definitions = [_make_def(&"health", 100.0, true), _make_def(&"attack", 10.0)]
	if b.formula == null:
		b.formula = AdditivePercentFormula.new()
	c.stat_block = b
	return c

func test_component_forwards_get_value() -> bool:
	var c := _make_component()
	assert(c.get_value(&"attack") == 10.0)
	return true

func test_component_forwards_get_max_and_get_current() -> bool:
	var c := _make_component()
	assert(c.get_max(&"health") == 100.0)
	assert(c.get_current(&"health") == 100.0)
	return true

func test_component_modify_resource_proxies_block() -> bool:
	var c := _make_component()
	c.modify_resource(&"health", -25.0)
	assert(c.get_current(&"health") == 75.0)
	return true

func test_component_add_modifier_proxies_block() -> bool:
	var c := _make_component()
	var m := StatModifier.new()
	m.stat_id = &"attack"
	m.op = StatModifier.Op.FLAT
	m.value = 5.0
	c.add_modifier(m)
	assert(c.get_value(&"attack") == 15.0)
	return true

func test_component_remove_modifiers_by_source() -> bool:
	var c := _make_component()
	var m := StatModifier.new()
	m.stat_id = &"attack"
	m.op = StatModifier.Op.FLAT
	m.value = 5.0
	m.source_id = &"helmet"
	c.add_modifier(m)
	c.remove_modifiers_by_source(&"helmet")
	assert(c.get_value(&"attack") == 10.0)
	return true

func test_component_get_reader_returns_stat_reader() -> bool:
	var c := _make_component()
	var r := c.get_reader()
	assert(r != null)
	assert(r is StatReader)
	assert(r.get_value(&"attack") == 10.0)
	return true

func test_component_serialize_round_trip() -> bool:
	var c := _make_component()
	c.modify_resource(&"health", -40.0)
	var data := c.serialize()
	var c2 := _make_component()
	c2.deserialize(data)
	assert(c2.get_current(&"health") == 60.0)
	return true
