extends RefCounted
## Tests for StatBarUI. Constructed outside SceneTree; _ready never fires.
## Tests inject _bar and _label directly and call _bind() manually.

func _make_def(id: StringName, base: float, is_resource: bool = true) -> StatDefinition:
	var d := StatDefinition.new()
	d.id = id
	d.display_name = String(id).capitalize()
	d.base_value = base
	d.is_resource = is_resource
	d.color = Color.RED
	return d

func _make_component(defs: Array[StatDefinition]) -> StatComponent:
	var c := StatComponent.new()
	var b := StatBlock.new()
	b.definitions = defs
	if b.formula == null:
		b.formula = AdditivePercentFormula.new()
	c.stat_block = b
	return c

func _make_widget(c: StatComponent, stat_id: StringName) -> StatBarUI:
	var w := StatBarUI.new()
	w.stat_component = c
	w.stat_id = stat_id
	w._bar = ProgressBar.new()
	w._label = Label.new()
	w._bind()
	return w

func test_bar_renders_full_when_resource_uninitialized() -> bool:
	var c := _make_component([_make_def(&"health", 100.0)])
	var w := _make_widget(c, &"health")
	assert(w._bar.value == 1.0, "expected full bar, got %f" % w._bar.value)
	return true

func test_bar_label_uses_format_string() -> bool:
	var c := _make_component([_make_def(&"health", 100.0)])
	var w := _make_widget(c, &"health")
	assert(w._label.text == "100 / 100", "expected '100 / 100', got '%s'" % w._label.text)
	return true

func test_bar_reflects_modify_resource() -> bool:
	var c := _make_component([_make_def(&"health", 100.0)])
	var w := _make_widget(c, &"health")
	c.modify_resource(&"health", -25.0)
	assert(w._bar.value == 0.75, "expected 0.75, got %f" % w._bar.value)
	assert(w._label.text == "75 / 100")
	return true

func test_bar_reflects_modifier_max_change() -> bool:
	# Use base=200 so set_current(100) is not a no-op (uninitialized fallback=200).
	var c := _make_component([_make_def(&"health", 200.0)])
	var w := _make_widget(c, &"health")
	# set_current to 100 — old_current=200, new_current=100, so current_resources is set.
	c.set_current(&"health", 100.0)
	# Add a +50 flat modifier — max becomes 250, current stays at 100.
	# After: bar = 100/250 = 0.4
	var m := StatModifier.new()
	m.stat_id = &"health"
	m.op = StatModifier.Op.FLAT
	m.value = 50.0
	c.add_modifier(m)
	assert(abs(w._bar.value - (100.0 / 250.0)) < 0.001, "expected ~0.4, got %f" % w._bar.value)
	return true

func test_bar_with_null_component_renders_empty() -> bool:
	var w := StatBarUI.new()
	w.stat_component = null
	w.stat_id = &"health"
	w._bar = ProgressBar.new()
	w._label = Label.new()
	w._bind()
	# _bind early-returns on null component, so bar stays at default 0
	assert(w._bar.value == 0.0)
	return true

func test_bar_with_flat_stat_warns_and_renders_empty() -> bool:
	# Flat stats are not appropriate for a resource bar. The widget should
	# warn once and render an empty bar.
	var c := _make_component([_make_def(&"attack", 10.0, false)])
	var w := _make_widget(c, &"attack")
	# We don't capture the warning (no easy mechanism in headless tests),
	# but verify the bar reads 0.
	assert(w._bar.value == 0.0, "expected 0 for flat stat, got %f" % w._bar.value)
	return true

func test_bar_with_unknown_stat_renders_empty() -> bool:
	var c := _make_component([_make_def(&"health", 100.0)])
	var w := _make_widget(c, &"nope")
	assert(w._bar.value == 0.0)
	return true

func test_rebind_disconnects_old_component() -> bool:
	# After rebinding to a new component, changes to the OLD component must
	# not update the bar. This pins the disconnect path in _bind().
	var c1 := _make_component([_make_def(&"health", 200.0)])
	var c2 := _make_component([_make_def(&"health", 80.0)])
	var w := _make_widget(c1, &"health")
	# Pin c1's current to 100/200 so the bar starts at 0.5
	c1.set_current(&"health", 100.0)
	assert(w._bar.value == 0.5, "expected 0.5 from c1, got %f" % w._bar.value)

	# Rebind to c2 (full bar at 80/80 = 1.0)
	w.stat_component = c2
	w._bind()
	assert(w._bar.value == 1.0, "expected 1.0 from c2 after rebind, got %f" % w._bar.value)

	# Mutate the OLD component — the bar must NOT change
	c1.modify_resource(&"health", -50.0)
	assert(w._bar.value == 1.0, "old component should not drive bar after rebind, got %f" % w._bar.value)

	# Mutate the NEW component — the bar SHOULD change
	c2.modify_resource(&"health", -40.0)
	assert(w._bar.value == 0.5, "new component should drive bar, got %f" % w._bar.value)
	return true
