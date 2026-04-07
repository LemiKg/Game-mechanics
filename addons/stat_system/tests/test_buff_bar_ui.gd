extends RefCounted
## Tests for BuffBarUI. Constructed outside SceneTree; _ready never fires.

func _make_block() -> StatBlock:
	var b := StatBlock.new()
	var d := StatDefinition.new()
	d.id = &"attack"
	d.base_value = 5.0
	b.definitions = [d]
	if b.formula == null:
		b.formula = AdditivePercentFormula.new()
	return b

func _make_component() -> StatComponent:
	var c := StatComponent.new()
	c.stat_block = _make_block()
	return c

func _make_widget(c: StatComponent) -> BuffBarUI:
	var w := BuffBarUI.new()
	w.stat_component = c
	w._row = HBoxContainer.new()
	w._bind()
	return w

func _make_timed_mod(value: float, duration: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat_id = &"attack"
	m.op = StatModifier.Op.FLAT
	m.value = value
	m.duration = duration
	return m

func _make_permanent_mod(value: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat_id = &"attack"
	m.op = StatModifier.Op.FLAT
	m.value = value
	# duration defaults to -1 (permanent)
	return m

func test_widget_with_null_component_does_nothing() -> bool:
	var w := BuffBarUI.new()
	w.stat_component = null
	w._row = HBoxContainer.new()
	w._bind()
	assert(w._slots.size() == 0)
	return true

func test_timed_modifier_added_creates_slot() -> bool:
	var c := _make_component()
	var w := _make_widget(c)
	c.add_modifier(_make_timed_mod(5.0, 10.0))
	assert(w._slots.size() == 1, "expected 1 slot, got %d" % w._slots.size())
	return true

func test_timed_modifier_removed_destroys_slot() -> bool:
	var c := _make_component()
	var w := _make_widget(c)
	c.add_modifier(_make_timed_mod(5.0, 10.0))
	assert(w._slots.size() == 1)
	# Remove via the captured owned instance from the running list
	var owned: StatModifier = w._running[0]
	c.remove_modifier(owned)
	assert(w._slots.size() == 0, "expected 0 slots after remove, got %d" % w._slots.size())
	return true

func test_permanent_modifier_filtered() -> bool:
	var c := _make_component()
	var w := _make_widget(c)
	c.add_modifier(_make_permanent_mod(3.0))
	assert(w._slots.size() == 0, "expected permanent modifier filtered, got %d slots" % w._slots.size())
	return true

func test_two_timed_modifiers_create_two_slots() -> bool:
	var c := _make_component()
	var w := _make_widget(c)
	c.add_modifier(_make_timed_mod(5.0, 10.0))
	c.add_modifier(_make_timed_mod(3.0, 5.0))
	assert(w._slots.size() == 2, "expected 2 slots, got %d" % w._slots.size())
	return true
