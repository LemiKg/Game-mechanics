# Stat System UI Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add reusable UI widgets (`StatBarUI`, `BuffBarUI`) to the stat_system addon plus a manual test scene that wires them up to a player with bound input keys, so consumers can build a working game HUD without writing custom UI code.

**Architecture:** Two `Control`-derived widgets in `addons/stat_system/ui/`. Each widget owns a `.tscn` scene file (its visual hierarchy) and a `.gd` script (its behavior). Both depend on `StatReader` (the existing read-only ISP view) — `StatReader` is extended with two new signals (`modifier_added`, `modifier_removed`) to support the buff bar. A standalone manual test scene exercises both widgets in 3D with hardcoded keybindings.

**Tech Stack:** Godot 4.x, GDScript, `@tool` editor types (NOT used here — widgets are runtime-only), headless test scripts run via `godot --headless --quit --script <path>`.

**Spec:** `docs/superpowers/specs/2026-04-07-stat-system-ui-design.md`

**Builds on:** Existing stat_system addon at `addons/stat_system/` (60 tests passing, HEAD `fd743d2` or later).

---

## File Structure

**Created:**

```
addons/stat_system/ui/
├── stat_bar_ui.gd
├── stat_bar_ui.tscn
├── buff_bar_ui.gd
└── buff_bar_ui.tscn
addons/stat_system/tests/
├── test_stat_reader_modifier_signals.gd
├── test_stat_bar_ui.gd
└── test_buff_bar_ui.gd
scenes/
├── stat_system_test_scene.tscn
└── stat_system_test_player.gd
```

**Modified:**

- `addons/stat_system/core/stat_reader.gd` — adds 2 signals + 2 forwarders
- `addons/stat_system/stat_system_plugin.gd` — registers `StatBarUI` and `BuffBarUI` as custom types
- `addons/stat_system/README.md` — documents the new widgets

---

## Conventions used in this plan

- All file paths are repo-relative.
- "Run" commands assume the working directory is the repo root.
- Headless test runs use:
  ```bash
  "D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
  ```
- Before any test that depends on a freshly-created `class_name`, the implementer MUST first refresh the script class cache with:
  ```bash
  "D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
  ```
- Each task ends with a commit step. Never skip a commit.
- All new GDScript files use TAB indentation (Godot convention).
- Currently 60 tests pass. After this plan, 74 will pass.

---

### Task 1: Extend StatReader with modifier signals (TDD)

**Files:**
- Create: `addons/stat_system/tests/test_stat_reader_modifier_signals.gd`
- Modify: `addons/stat_system/core/stat_reader.gd` (add 2 signals + 2 forwarders + 2 connect lines in `_init`)

**Why first:** `BuffBarUI` (Task 4) depends on `StatReader` exposing `modifier_added` and `modifier_removed`. Building this extension first unblocks the buff widget cleanly and gives us a small TDD warm-up.

- [ ] **Step 1: Write the failing test `addons/stat_system/tests/test_stat_reader_modifier_signals.gd`**

```gdscript
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
```

- [ ] **Step 2: Refresh script class cache and run tests, expect failures**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: 60 existing tests still pass, 2 new tests FAIL with `Invalid call. Nonexistent function 'connect' in base 'StatReader' for signal 'modifier_added'` (or similar — the signals don't exist yet on `StatReader`). Total: `=== 60 passed, 2 failed ===` (or similar — exact failure count depends on whether parse failures abort).

- [ ] **Step 3: Read the current `addons/stat_system/core/stat_reader.gd`**

Use the Read tool to see the current content. The file currently has 3 signals (`stat_changed`, `resource_depleted`, `resource_filled`) and 3 forwarders. We need to add 2 more of each.

- [ ] **Step 4: Modify `addons/stat_system/core/stat_reader.gd`**

Replace the entire file with this content:

```gdscript
extends RefCounted
class_name StatReader
## Read-only view of a StatBlock for UI consumers.
## Exposes only reads + signal forwarding. UI bars and buff lists should
## depend on this, not on StatComponent or StatBlock directly.
##
## Construct via StatComponent.get_reader().

signal stat_changed(id: StringName, old_value: float, new_value: float)
signal resource_depleted(id: StringName)
signal resource_filled(id: StringName)
signal modifier_added(modifier: StatModifier)
signal modifier_removed(modifier: StatModifier, reason: int)

var _block: StatBlock

func _init(block: StatBlock) -> void:
	_block = block
	if _block:
		_block.stat_changed.connect(_forward_stat_changed)
		_block.resource_depleted.connect(_forward_depleted)
		_block.resource_filled.connect(_forward_filled)
		_block.modifier_added.connect(_forward_modifier_added)
		_block.modifier_removed.connect(_forward_modifier_removed)

func get_value(id: StringName) -> float:
	return _block.get_value(id) if _block else 0.0

func get_max(id: StringName) -> float:
	return _block.get_max(id) if _block else 0.0

func get_current(id: StringName) -> float:
	return _block.get_current(id) if _block else 0.0

func get_active_modifiers() -> Array[StatModifier]:
	return _block.get_active_modifiers() if _block else []

func _forward_stat_changed(id: StringName, old_value: float, new_value: float) -> void:
	stat_changed.emit(id, old_value, new_value)

func _forward_depleted(id: StringName) -> void:
	resource_depleted.emit(id)

func _forward_filled(id: StringName) -> void:
	resource_filled.emit(id)

func _forward_modifier_added(modifier: StatModifier) -> void:
	modifier_added.emit(modifier)

func _forward_modifier_removed(modifier: StatModifier, reason: int) -> void:
	modifier_removed.emit(modifier, reason)
```

- [ ] **Step 5: Refresh cache and run tests — expect 62 passing**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: `=== 62 passed, 0 failed ===` (60 previous + 2 new). Exit code 0.

- [ ] **Step 6: Commit**

```bash
git add addons/stat_system/core/stat_reader.gd addons/stat_system/tests/test_stat_reader_modifier_signals.gd
git commit -m "feat(stat-system): extend StatReader with modifier signal forwarding"
```

---

### Task 2: StatBarUI script (TDD)

**Files:**
- Create: `addons/stat_system/tests/test_stat_bar_ui.gd`
- Create: `addons/stat_system/ui/stat_bar_ui.gd`

**Note on testing strategy:** The tests instantiate `StatBarUI` via `.new()` outside the SceneTree, so `_ready` never fires. The widget's normal lifecycle is `_ready → _bind`, but we can call `_bind()` directly after manually setting up `_bar` and `_label`. Since `@onready` references won't resolve outside the tree either, the test must inject its own ProgressBar and Label as private members. The widget's `_bind()` method must therefore tolerate `_bar`/`_label` being already set, OR the tests must bypass `_ready` and call internal methods directly.

The cleanest approach: the script holds `_bar` and `_label` as plain `var`s (not `@onready`), and `_ready` does the lookup. Tests can then construct the widget, manually assign `_bar` and `_label` to fresh instances, and call `_bind()` without ever being in a tree.

- [ ] **Step 1: Write the failing test `addons/stat_system/tests/test_stat_bar_ui.gd`**

```gdscript
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
	var c := _make_component([_make_def(&"health", 100.0)])
	var w := _make_widget(c, &"health")
	# Add a +50 health modifier — max becomes 150, current stays 100 (uninitialized fallback).
	# Actually current is fallback-from-max so it's 100 before, and max is now 150.
	# After: bar = 100/150 = 0.666...
	var m := StatModifier.new()
	m.stat_id = &"health"
	m.op = StatModifier.Op.FLAT
	m.value = 50.0
	c.add_modifier(m)
	# The bar refresh happens via stat_changed. Verify the new ratio.
	assert(abs(w._bar.value - (100.0 / 150.0)) < 0.001, "expected ~0.666, got %f" % w._bar.value)
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
```

- [ ] **Step 2: Refresh cache and run tests, expect failures**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: 62 still pass, 7 new tests fail with `Identifier "StatBarUI" not declared`.

- [ ] **Step 3: Create `addons/stat_system/ui/stat_bar_ui.gd`**

```gdscript
extends Control
class_name StatBarUI
## Displays one resource stat as a filled bar with optional overlay text.
## Binds to a StatComponent + stat_id; refreshes via the StatReader's
## stat_changed signal.
##
## The scene file `stat_bar_ui.tscn` provides a default ProgressBar + Label
## hierarchy. Authors can replace either child node in their own scene
## without touching this script — only the @export node references matter.

@export var stat_component: StatComponent
@export var stat_id: StringName = &"health"
@export var show_label: bool = true
@export var label_format: String = "%d / %d"

# These are looked up in _ready. Tests can inject them directly.
var _bar: ProgressBar
var _label: Label

var _reader: StatReader

func _ready() -> void:
	_bar = $ProgressBar
	_label = $Label
	_label.visible = show_label
	_bind()

## Public setter so consumers can swap the data source at runtime.
func set_stat_component(c: StatComponent) -> void:
	stat_component = c
	if is_inside_tree():
		_bind()

func _bind() -> void:
	if not stat_component:
		return
	# Disconnect from any previous reader.
	if _reader and _reader.stat_changed.is_connected(_on_stat_changed):
		_reader.stat_changed.disconnect(_on_stat_changed)
	_reader = stat_component.get_reader()
	_reader.stat_changed.connect(_on_stat_changed)

	# Validate that the bound stat is a resource. Flat stats render as empty
	# and emit a warning so authoring mistakes surface immediately.
	var def := _find_definition()
	if def == null:
		push_warning("StatBarUI: stat_id '%s' not found in stat block" % stat_id)
	elif not def.is_resource:
		push_warning("StatBarUI: stat_id '%s' is a flat stat, not a resource — bar will read 0" % stat_id)
	elif def.color != Color.WHITE:
		_bar.modulate = def.color

	_refresh()

func _find_definition() -> StatDefinition:
	if not stat_component or not stat_component.stat_block:
		return null
	for d in stat_component.stat_block.definitions:
		if d != null and d.id == stat_id:
			return d
	return null

func _on_stat_changed(id: StringName, _old: float, _new: float) -> void:
	if id == stat_id:
		_refresh()

func _refresh() -> void:
	if not _reader:
		return
	var def := _find_definition()
	# Flat stat or unknown stat — render empty.
	if def == null or not def.is_resource:
		_bar.value = 0.0
		if show_label:
			_label.text = label_format % [0, 0]
		return

	var current := _reader.get_current(stat_id)
	var max_v := _reader.get_max(stat_id)
	if max_v <= 0.0:
		_bar.value = 0.0
	else:
		_bar.value = current / max_v
	if show_label:
		_label.text = label_format % [int(current), int(max_v)]
```

- [ ] **Step 4: Refresh cache and run tests — expect 69 passing**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: `=== 69 passed, 0 failed ===` (62 previous + 7 new).

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/ui/stat_bar_ui.gd addons/stat_system/tests/test_stat_bar_ui.gd
git commit -m "feat(stat-system): add StatBarUI widget script with TDD coverage"
```

---

### Task 3: StatBarUI scene file

**Files:**
- Create: `addons/stat_system/ui/stat_bar_ui.tscn`

This task creates the scene file that pairs with the script from Task 2. Authors can instance this scene directly, or instance the script as a custom type and add their own children.

- [ ] **Step 1: Create `addons/stat_system/ui/stat_bar_ui.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/stat_system/ui/stat_bar_ui.gd" id="1_script"]

[node name="StatBarUI" type="Control"]
custom_minimum_size = Vector2(150, 24)
anchors_preset = 0
script = ExtResource("1_script")

[node name="ProgressBar" type="ProgressBar" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
max_value = 1.0
step = 0.001
value = 1.0
show_percentage = false

[node name="Label" type="Label" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
horizontal_alignment = 1
vertical_alignment = 1
text = "0 / 0"
```

- [ ] **Step 2: Sanity-load and run tests**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: no script errors, `=== 69 passed, 0 failed ===`.

- [ ] **Step 3: Commit**

```bash
git add addons/stat_system/ui/stat_bar_ui.tscn
git commit -m "feat(stat-system): add StatBarUI scene file with default ProgressBar + Label"
```

---

### Task 4: BuffBarUI script (TDD)

**Files:**
- Create: `addons/stat_system/tests/test_buff_bar_ui.gd`
- Create: `addons/stat_system/ui/buff_bar_ui.gd`

**Testing approach:** Same as `StatBarUI` — construct outside SceneTree, inject the `HBoxContainer` directly, call `_bind()` manually. The tests verify slot count and filtering behavior, not visual rendering.

- [ ] **Step 1: Write the failing test `addons/stat_system/tests/test_buff_bar_ui.gd`**

```gdscript
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
	# Remove all modifiers via source — but we set no source. Use the
	# captured owned instance from the running list instead.
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
```

- [ ] **Step 2: Refresh cache and run tests, expect failures**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: 69 still pass, 5 new tests fail with `Identifier "BuffBarUI" not declared`.

- [ ] **Step 3: Create `addons/stat_system/ui/buff_bar_ui.gd`**

```gdscript
extends Control
class_name BuffBarUI
## Displays the active timed modifiers as a horizontal row of icon + countdown.
## Permanent modifiers (duration < 0) are filtered out — equipment bonuses
## don't belong in a buff bar.
##
## Bind by setting `stat_component`. The widget connects to the StatReader's
## modifier_added / modifier_removed signals.

@export var stat_component: StatComponent
@export var icon_size: int = 32
@export var spacing: int = 4
@export var show_countdown_label: bool = true

# Looked up in _ready. Tests can inject directly.
var _row: HBoxContainer

var _reader: StatReader
var _slots: Dictionary = {}              # StatModifier -> child PanelContainer
var _running: Array[StatModifier] = []   # mirrors _slots keys for tick

func _ready() -> void:
	_row = $HBoxContainer
	_row.add_theme_constant_override("separation", spacing)
	_bind()

## Public setter so consumers can swap the data source at runtime.
func set_stat_component(c: StatComponent) -> void:
	stat_component = c
	if is_inside_tree():
		_bind()

func _bind() -> void:
	if not stat_component:
		return
	# Disconnect old reader if any.
	if _reader:
		if _reader.modifier_added.is_connected(_on_modifier_added):
			_reader.modifier_added.disconnect(_on_modifier_added)
		if _reader.modifier_removed.is_connected(_on_modifier_removed):
			_reader.modifier_removed.disconnect(_on_modifier_removed)
	_reader = stat_component.get_reader()
	_reader.modifier_added.connect(_on_modifier_added)
	_reader.modifier_removed.connect(_on_modifier_removed)
	_refresh_all()

func _refresh_all() -> void:
	for child in _row.get_children():
		child.queue_free()
	_slots.clear()
	_running.clear()
	for m in _reader.get_active_modifiers():
		if m == null or m.duration < 0.0:
			continue
		_add_slot(m)

func _on_modifier_added(m: StatModifier) -> void:
	if m == null or m.duration < 0.0:
		return
	_add_slot(m)

func _on_modifier_removed(m: StatModifier, _reason: int) -> void:
	if m == null:
		return
	var node = _slots.get(m)
	if node:
		node.queue_free()
		_slots.erase(m)
		_running.erase(m)

func _process(_delta: float) -> void:
	if not show_countdown_label:
		return
	# Cheap re-render of countdown labels. We do not need a per-frame signal —
	# remaining is updated by StatBlock.tick() and we just read it.
	for m in _running:
		var node = _slots.get(m)
		if node:
			var label: Label = node.get_node_or_null("Label")
			if label:
				label.text = "%ds" % int(ceil(m.remaining))

func _add_slot(m: StatModifier) -> void:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(icon_size, icon_size)
	var icon := TextureRect.new()
	icon.texture = m.icon
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)
	if show_countdown_label:
		var label := Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		label.text = "%ds" % int(ceil(m.duration))
		slot.add_child(label)
	_row.add_child(slot)
	_slots[m] = slot
	_running.append(m)
```

- [ ] **Step 4: Refresh cache and run tests — expect 74 passing**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: `=== 74 passed, 0 failed ===` (69 previous + 5 new).

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/ui/buff_bar_ui.gd addons/stat_system/tests/test_buff_bar_ui.gd
git commit -m "feat(stat-system): add BuffBarUI widget script with TDD coverage"
```

---

### Task 5: BuffBarUI scene file

**Files:**
- Create: `addons/stat_system/ui/buff_bar_ui.tscn`

- [ ] **Step 1: Create `addons/stat_system/ui/buff_bar_ui.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/stat_system/ui/buff_bar_ui.gd" id="1_script"]

[node name="BuffBarUI" type="Control"]
custom_minimum_size = Vector2(200, 36)
anchors_preset = 0
script = ExtResource("1_script")

[node name="HBoxContainer" type="HBoxContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
alignment = 0
```

- [ ] **Step 2: Sanity-load and run tests**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: no script errors, `=== 74 passed, 0 failed ===`.

- [ ] **Step 3: Commit**

```bash
git add addons/stat_system/ui/buff_bar_ui.tscn
git commit -m "feat(stat-system): add BuffBarUI scene file with HBoxContainer"
```

---

### Task 6: Register UI widgets in plugin

**Files:**
- Modify: `addons/stat_system/stat_system_plugin.gd`

Add `add_custom_type` calls for the two new widgets so they appear in the editor's "Add Node" dialog.

- [ ] **Step 1: Read the current `addons/stat_system/stat_system_plugin.gd`**

Use Read to verify the current structure. The file currently has 7 `add_custom_type` calls in `_enter_tree` (6 Resources + 1 StatComponent Node) and matching `remove_custom_type` calls in `_exit_tree`, plus the gated effect helpers.

- [ ] **Step 2: Add 2 new registrations in `_enter_tree`**

Find this block:

```gdscript
	# Runtime node.
	add_custom_type("StatComponent", "Node", preload("core/stat_component.gd"), null)

	# Conditional effect registration: gated by Task 14.
	_register_effects_if_inventory_enabled()
```

Replace with:

```gdscript
	# Runtime node.
	add_custom_type("StatComponent", "Node", preload("core/stat_component.gd"), null)

	# UI widgets.
	add_custom_type("StatBarUI", "Control", preload("ui/stat_bar_ui.gd"), null)
	add_custom_type("BuffBarUI", "Control", preload("ui/buff_bar_ui.gd"), null)

	# Conditional effect registration: gated by Task 14.
	_register_effects_if_inventory_enabled()
```

- [ ] **Step 3: Add 2 new unregistrations in `_exit_tree`**

Find this block:

```gdscript
	remove_custom_type("StatComponent")
	_unregister_effects_if_inventory_enabled()
```

Replace with:

```gdscript
	remove_custom_type("StatComponent")
	remove_custom_type("StatBarUI")
	remove_custom_type("BuffBarUI")
	_unregister_effects_if_inventory_enabled()
```

- [ ] **Step 4: Sanity-load and run tests**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: no script errors, `=== 74 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/stat_system_plugin.gd
git commit -m "feat(stat-system): register StatBarUI and BuffBarUI as editor custom types"
```

---

### Task 7: Test player script

**Files:**
- Create: `scenes/stat_system_test_player.gd`

A minimal Node3D script with hardcoded keybindings. No tests — this is a manual test scaffold.

- [ ] **Step 1: Create `scenes/stat_system_test_player.gd`**

```gdscript
extends Node3D
## Manual test player for the stat system. Bound keys:
##   1 = damage 10 health
##   2 = spend 15 mana
##   3 = spend 25 stamina
##   4 = apply 5-second +5 attack buff
##   5 = apply 10-second -3 defense debuff
##   R = reset all resources to full
##
## Uses raw KEY_* checks via _input — no project input map setup required.

@export var stat_component: StatComponent

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not stat_component:
		return

	match event.keycode:
		KEY_1:
			stat_component.modify_resource(&"health", -10.0)
		KEY_2:
			stat_component.modify_resource(&"mana", -15.0)
		KEY_3:
			stat_component.modify_resource(&"stamina", -25.0)
		KEY_4:
			_apply_buff(&"attack", 5.0, 5.0)
		KEY_5:
			_apply_buff(&"defense", -3.0, 10.0)
		KEY_R:
			_reset_all()

func _apply_buff(stat_id: StringName, value: float, duration: float) -> void:
	var m := StatModifier.new()
	m.stat_id = stat_id
	m.op = StatModifier.Op.FLAT
	m.value = value
	m.duration = duration
	m.source_id = StringName("test_buff_%d" % Time.get_ticks_msec())
	stat_component.add_modifier(m)

func _reset_all() -> void:
	for def in stat_component.stat_block.definitions:
		if def != null and def.is_resource:
			stat_component.set_current(def.id, stat_component.get_max(def.id))
```

- [ ] **Step 2: Sanity-load**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
```

Expected: no script errors mentioning `stat_system_test_player.gd`.

- [ ] **Step 3: Commit**

```bash
git add scenes/stat_system_test_player.gd
git commit -m "feat(stat-system): add manual test player script with bound keybindings"
```

---

### Task 8: Test scene

**Files:**
- Create: `scenes/stat_system_test_scene.tscn`

A standalone Node3D scene with player + camera + floor + HUD wiring everything together. The `StatBlock` is an inline `SubResource` referencing the example stat definitions.

- [ ] **Step 1: Create `scenes/stat_system_test_scene.tscn`**

```
[gd_scene load_steps=15 format=3]

[ext_resource type="Script" path="res://scenes/stat_system_test_player.gd" id="1_player"]
[ext_resource type="Script" path="res://addons/stat_system/core/stat_component.gd" id="2_stat_component"]
[ext_resource type="Script" path="res://addons/stat_system/core/stat_block.gd" id="3_stat_block"]
[ext_resource type="Script" path="res://addons/stat_system/core/additive_percent_formula.gd" id="4_formula"]
[ext_resource type="Resource" path="res://addons/stat_system/examples/stats/health.tres" id="5_health"]
[ext_resource type="Resource" path="res://addons/stat_system/examples/stats/mana.tres" id="6_mana"]
[ext_resource type="Resource" path="res://addons/stat_system/examples/stats/stamina.tres" id="7_stamina"]
[ext_resource type="Resource" path="res://addons/stat_system/examples/stats/attack.tres" id="8_attack"]
[ext_resource type="Resource" path="res://addons/stat_system/examples/stats/defense.tres" id="9_defense"]
[ext_resource type="PackedScene" path="res://addons/stat_system/ui/stat_bar_ui.tscn" id="10_bar"]
[ext_resource type="PackedScene" path="res://addons/stat_system/ui/buff_bar_ui.tscn" id="11_buff_bar"]

[sub_resource type="Resource" id="formula"]
script = ExtResource("4_formula")

[sub_resource type="Resource" id="block"]
script = ExtResource("3_stat_block")
definitions = [ExtResource("5_health"), ExtResource("6_mana"), ExtResource("7_stamina"), ExtResource("8_attack"), ExtResource("9_defense")]
formula = SubResource("formula")
current_resources = {}

[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.4, 0.45, 0.5, 1)
ambient_light_source = 2
ambient_light_color = Color(0.7, 0.7, 0.7, 1)

[node name="StatSystemTestScene" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.7, -0.5, 0.5, 0, 0.707, 0.707, -0.7, -0.5, 0.5, 0, 5, 0)

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.866, 0.5, 0, -0.5, 0.866, 0, 4, 6)

[node name="Floor" type="CSGBox3D" parent="."]
size = Vector3(20, 1, 20)
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)

[node name="TestPlayer" type="Node3D" parent="."]
script = ExtResource("1_player")

[node name="Mesh" type="CSGCylinder3D" parent="TestPlayer"]
radius = 0.4
height = 1.8
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)

[node name="StatComponent" type="Node" parent="TestPlayer"]
script = ExtResource("2_stat_component")
stat_block = SubResource("block")

[node name="HUD" type="CanvasLayer" parent="."]

[node name="BarStack" type="VBoxContainer" parent="HUD"]
anchors_preset = 1
anchor_left = 0.0
anchor_right = 0.0
offset_left = 16.0
offset_top = 16.0
offset_right = 216.0
offset_bottom = 100.0

[node name="HealthBar" parent="HUD/BarStack" instance=ExtResource("10_bar")]
stat_id = &"health"

[node name="ManaBar" parent="HUD/BarStack" instance=ExtResource("10_bar")]
stat_id = &"mana"

[node name="StaminaBar" parent="HUD/BarStack" instance=ExtResource("10_bar")]
stat_id = &"stamina"

[node name="BuffBar" parent="HUD" instance=ExtResource("11_buff_bar")]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -216.0
offset_top = 16.0
offset_right = -16.0
offset_bottom = 52.0
```

**Note about node references:** The `TestPlayer` script has an `@export var stat_component: StatComponent`. The scene above does NOT pre-wire that export, which means the script will see `null` until the user assigns it manually. To fix this without manual editor work, we add a small `_ready` lookup to the test player script. Update Task 7's player script in this task too.

- [ ] **Step 2: Add the auto-lookup to `scenes/stat_system_test_player.gd`**

Open the file and add this `_ready` method **before** `_input`:

```gdscript
func _ready() -> void:
	# Auto-bind to a child StatComponent if not explicitly set in the editor.
	if stat_component == null:
		stat_component = get_node_or_null("StatComponent") as StatComponent
	# Auto-bind every StatBarUI/BuffBarUI in the scene's HUD to this component.
	# Walks the root scene's CanvasLayer children for any widget that needs a binding.
	var root := get_tree().current_scene
	if root:
		_auto_bind_widgets(root)

func _auto_bind_widgets(node: Node) -> void:
	if node is StatBarUI and (node as StatBarUI).stat_component == null:
		(node as StatBarUI).set_stat_component(stat_component)
	elif node is BuffBarUI and (node as BuffBarUI).stat_component == null:
		(node as BuffBarUI).set_stat_component(stat_component)
	for child in node.get_children():
		_auto_bind_widgets(child)
```

This makes the scene self-wiring: the player auto-finds its `StatComponent` child and walks the scene to bind any widget that doesn't have a `stat_component` set.

- [ ] **Step 3: Sanity-load**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
```

Expected: no script errors mentioning `stat_system_test_scene.tscn` or `stat_system_test_player.gd`.

Then run the tests to confirm nothing else broke:

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: `=== 74 passed, 0 failed ===`.

- [ ] **Step 4: Commit**

```bash
git add scenes/stat_system_test_scene.tscn scenes/stat_system_test_player.gd
git commit -m "feat(stat-system): add manual test scene wiring widgets to test player"
```

---

### Task 9: Update addon README to document new widgets

**Files:**
- Modify: `addons/stat_system/README.md`

Add a "UI widgets" section after the "Public API" section.

- [ ] **Step 1: Read the current `addons/stat_system/README.md`**

The file currently has these top-level sections (in order): title, intro, Quick start, Concepts, Public API, Inventory integration (optional), Tests. We're inserting a new section between Public API and Inventory integration.

- [ ] **Step 2: Insert the UI widgets section**

Find this line:

```markdown
## Inventory integration (optional)
```

Insert this section immediately before it (so the order becomes Public API → UI widgets → Inventory integration → Tests):

```markdown
## UI widgets

The addon ships two reusable `Control` widgets in `addons/stat_system/ui/`:

### `StatBarUI`

A resource bar (HP/MP/stamina) that binds to one stat by id. Built on
Godot's `ProgressBar` so it picks up your project's themes automatically.

Author either by instancing `stat_bar_ui.tscn` directly, or by adding the
`StatBarUI` custom type as a Control node.

| Export | Purpose |
|---|---|
| `stat_component: StatComponent` | The data source. Required at runtime. |
| `stat_id: StringName` | Which stat to bind to (must be `is_resource = true`). |
| `show_label: bool` | Toggle the "current / max" overlay. |
| `label_format: String` | printf-style format with two `%d` slots. Default: `"%d / %d"`. |

The widget reads `StatDefinition.color` and applies it as `modulate` on
the inner `ProgressBar`. The Label is a sibling so it isn't tinted.

Bound to a flat stat by mistake? The widget pushes a one-time warning
and renders an empty bar.

### `BuffBarUI`

A horizontal row of icons + countdown labels for the active timed
modifiers (`duration > 0`). Permanent modifiers (equipment bonuses) are
filtered out — they don't belong in a buff bar.

| Export | Purpose |
|---|---|
| `stat_component: StatComponent` | The data source. Required at runtime. |
| `icon_size: int` | Square slot size in pixels. Default 32. |
| `spacing: int` | Pixel gap between slots. Default 4. |
| `show_countdown_label: bool` | Toggle the "Ns" remaining-time overlay. |

The widget creates one `PanelContainer` per active timed modifier and
destroys them when modifiers expire or are removed. Countdown labels
update each frame via `_process` (no per-tick signal traffic).

### Test scene

`scenes/stat_system_test_scene.tscn` ships as a runnable demo: open it
in the editor and press F5. The bound keys are:

| Key | Action |
|---|---|
| `1` | Damage 10 health |
| `2` | Spend 15 mana |
| `3` | Spend 25 stamina |
| `4` | Apply 5-second +5 attack buff |
| `5` | Apply 10-second -3 defense debuff |
| `R` | Reset all resources to full |

```

- [ ] **Step 3: Sanity-load and run tests**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: `=== 74 passed, 0 failed ===`.

- [ ] **Step 4: Commit**

```bash
git add addons/stat_system/README.md
git commit -m "docs(stat-system): document StatBarUI, BuffBarUI, and test scene in addon README"
```

---

### Task 10: Final verification

**Files:** none — verification only.

- [ ] **Step 1: Run the full test suite**

```bash
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --import --quit
"D:/Godot Engine/Godot_v4.6.2-stable_win64_console.exe" --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Expected: `=== 74 passed, 0 failed ===`. Exit code 0.

- [ ] **Step 2: Verify the commit history is clean**

```bash
git log --oneline -12
```

Expected: 9 task commits + the spec commit, in order. No `WIP` or `fixup!` commits. The 9 task commits should look like:

```
... docs(stat-system): document StatBarUI, BuffBarUI, and test scene in addon README
... feat(stat-system): add manual test scene wiring widgets to test player
... feat(stat-system): add manual test player script with bound keybindings
... feat(stat-system): register StatBarUI and BuffBarUI as editor custom types
... feat(stat-system): add BuffBarUI scene file with HBoxContainer
... feat(stat-system): add BuffBarUI widget script with TDD coverage
... feat(stat-system): add StatBarUI scene file with default ProgressBar + Label
... feat(stat-system): add StatBarUI widget script with TDD coverage
... feat(stat-system): extend StatReader with modifier signal forwarding
```

(Plus the spec commit `2557fc9` and any earlier `.gd.uid` chore commits from cache regeneration.)

- [ ] **Step 3: (Optional) Manual smoke test in the editor**

If the editor is available, open `scenes/stat_system_test_scene.tscn` and press F5. Verify:
- Three bars appear in the top-left (red HP, blue mana, yellow stamina)
- Pressing `1` shrinks the HP bar by 10%
- Pressing `4` makes a buff icon appear in the top-right with a "5s" countdown
- The buff icon disappears after 5 seconds
- Pressing `R` refills all bars

This is a human-eye check; failures here mean either the scene wiring is wrong or one of the widgets has a runtime-only bug not covered by the headless tests.

- [ ] **Step 4: Done.** Hand the branch off to the user.

---

## Out of scope (intentional)

Per the spec's "Non-Goals" section:

- Stat sheet panel (Control listing all stats for a character menu)
- Damage numbers / floating text
- Scrolling buff overflow
- Animation / tween on bar fill
- Colored fill via `StyleBoxFlat`
- Editor preview (`@tool`)

These are deferred to future plans.
