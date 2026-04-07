# Stat System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a SOLID-compliant Stat System addon (`addons/stat_system/`) with resource stats (HP/MP/stamina), flat stats with flat+percent modifier stacks, source-tracked and timed buffs, and clean optional integration with the existing `inventory_system` addon.

**Architecture:** Three-layer addon following the project's `BaseInventory`/`Inventory`/`InventoryComponent` pattern. Pure-data Resources (`StatDefinition`, `StatModifier`, `StatBlock`) compute via an injected `StatFormula` strategy. A `StatComponent` Node hosts the runtime loop. Inventory integration is via an optional `@export var stat_component` on `EquipmentComponent`, with effects in `addons/stat_system/effects/` gated to load only when `inventory_system` is enabled.

**Tech Stack:** Godot 4.x, GDScript, `@tool` editor types, headless test scripts run via `godot --headless --quit --script <path>`.

**Spec:** `docs/superpowers/specs/2026-04-07-stat-system-design.md`

---

## File Structure

**Created:**

```
addons/stat_system/
├── plugin.cfg
├── stat_system_plugin.gd
├── README.md
├── core/
│   ├── stat_definition.gd
│   ├── stat_modifier.gd
│   ├── stat_formula.gd
│   ├── additive_percent_formula.gd
│   ├── base_stat_block.gd
│   ├── stat_block.gd
│   ├── stat_reader.gd
│   └── stat_component.gd
├── effects/
│   ├── resource_effect.gd
│   └── apply_modifier_effect.gd
├── examples/stats/
│   ├── health.tres
│   ├── mana.tres
│   ├── stamina.tres
│   ├── attack.tres
│   └── defense.tres
└── tests/
    ├── run_tests.gd
    ├── test_additive_percent_formula.gd
    ├── test_stat_block.gd
    ├── test_stat_block_serialization.gd
    └── test_stat_component.gd
scenes/
└── stat_system_test_scene.tscn
```

**Modified:**

- `project.godot` (enable plugin)
- `README.md` (move "Stat System" from Planned to Available)
- `addons/inventory_system/inventory_plugin.gd` (remove HealEffect/ManaEffect registration)
- `addons/inventory_system/core/equipment_item.gd` (remove `defense`/`damage`/`stats`, add `stat_modifiers` + `get_stat_modifiers`)
- `addons/inventory_system/core/equipment_component.gd` (add `@export var stat_component`, push/remove modifiers, remove `get_total_stat`/`get_all_stats`)
- `addons/inventory_system/README.md` (document optional integration)
- `items/iron_chestplate.tres` `items/iron_helmet.tres` `items/leather_boots.tres` `items/steel_sword.tres` (use `stat_modifiers`)
- `items/health_potion.tres` `items/mana_potion.tres` (use `ResourceEffect`)

**Deleted:**

- `addons/inventory_system/core/heal_effect.gd`
- `addons/inventory_system/core/mana_effect.gd`

---

## Conventions used in this plan

- All file paths are repo-relative.
- "Run" commands assume the working directory is the repo root.
- Headless test runs use:
  ```bash
  godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
  ```
- Each task ends with a commit step. Never skip a commit — they bound the blast radius if a later task fails.
- All new GDScript files start with `@tool` only when the class is intended to be used in the editor (Resources need `@tool` so the inspector recognises them).

---

### Task 1: Bootstrap the addon scaffolding

**Files:**
- Create: `addons/stat_system/plugin.cfg`
- Create: `addons/stat_system/stat_system_plugin.gd`
- Create: `addons/stat_system/README.md`
- Modify: `project.godot` (append to `enabled` PackedStringArray)

- [ ] **Step 1: Create `addons/stat_system/plugin.cfg`**

```ini
[plugin]

name="Stat System"
description="Resource stats (HP/MP/stamina), flat stats with flat+percent modifiers, and timed buffs. Optional inventory integration."
author="Game Systems Library"
version="0.1.0"
script="stat_system_plugin.gd"
```

- [ ] **Step 2: Create empty plugin script `addons/stat_system/stat_system_plugin.gd`**

```gdscript
@tool
extends EditorPlugin
## Stat System editor plugin. Registers core types in _enter_tree.
## Effects in addons/stat_system/effects/ are gated to load only when
## the inventory_system addon is enabled (they extend ItemEffect).

func _enter_tree() -> void:
	# Custom-type registration is filled in by Task 13 (core) and Task 14 (effects).
	pass

func _exit_tree() -> void:
	pass
```

- [ ] **Step 3: Create README stub `addons/stat_system/README.md`**

```markdown
# Stat System

Reusable Godot 4 addon for resource stats (HP/MP/stamina), flat stats with
flat+percent modifier stacks, and timed buffs/debuffs. SOLID architecture,
no hard dependencies.

See `docs/superpowers/specs/2026-04-07-stat-system-design.md` for the full
design. This README is filled in by Task 20.
```

- [ ] **Step 4: Enable the plugin in `project.godot`**

Open `project.godot`, find the `[editor_plugins]` section's `enabled` line, and append `"res://addons/stat_system/plugin.cfg"` to the PackedStringArray. Example, the line currently reads:

```
enabled=PackedStringArray("res://addons/inventory_system/plugin.cfg", "res://addons/player_control_3rd_person/plugin.cfg", "res://addons/player_control_core/plugin.cfg", "res://addons/player_control_fps/plugin.cfg", "res://addons/pose_warping/plugin.cfg", "res://addons/procedural_world/plugin.cfg")
```

It should become:

```
enabled=PackedStringArray("res://addons/inventory_system/plugin.cfg", "res://addons/player_control_3rd_person/plugin.cfg", "res://addons/player_control_core/plugin.cfg", "res://addons/player_control_fps/plugin.cfg", "res://addons/pose_warping/plugin.cfg", "res://addons/procedural_world/plugin.cfg", "res://addons/stat_system/plugin.cfg")
```

- [ ] **Step 5: Verify Godot loads the plugin without errors**

Run:
```bash
godot --headless --quit
```
Expected: exits cleanly with no `SCRIPT ERROR` lines mentioning `stat_system`. (Warnings are OK.)

- [ ] **Step 6: Commit**

```bash
git add addons/stat_system/plugin.cfg addons/stat_system/stat_system_plugin.gd addons/stat_system/README.md project.godot
git commit -m "feat(stat-system): bootstrap addon scaffolding"
```

---

### Task 2: Headless test runner

**Files:**
- Create: `addons/stat_system/tests/run_tests.gd`

The test runner is intentionally minimal: it loads each `test_*.gd` file in `addons/stat_system/tests/`, instantiates it, calls every method whose name starts with `test_`, prints PASS/FAIL per assertion, and exits with a non-zero code on failure. No external test framework dependency.

- [ ] **Step 1: Create `addons/stat_system/tests/run_tests.gd`**

```gdscript
extends SceneTree
## Headless test runner for the stat_system addon.
## Run with: godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"

const TESTS_DIR := "res://addons/stat_system/tests/"

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== stat_system test runner ===")
	var dir := DirAccess.open(TESTS_DIR)
	if not dir:
		push_error("Could not open tests directory: " + TESTS_DIR)
		quit(1)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var test_files: Array[String] = []
	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			test_files.append(TESTS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	test_files.sort()

	for path in test_files:
		_run_file(path)

	print("=== %d passed, %d failed ===" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)

func _run_file(path: String) -> void:
	print("--- " + path)
	var script: GDScript = load(path)
	if script == null:
		_failures += 1
		print("  FAIL: could not load script")
		return
	var instance = script.new()
	if instance == null:
		_failures += 1
		print("  FAIL: could not instantiate")
		return

	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		var ok := _run_test_method(instance, method_name)
		if ok:
			_passes += 1
			print("  PASS: " + method_name)
		else:
			_failures += 1
			print("  FAIL: " + method_name)

func _run_test_method(instance: Object, method_name: String) -> bool:
	# Tests use `assert()` which crashes on failure in debug builds. We catch
	# nothing — a failure aborts the runner. Tests should return true on
	# success and false on failure for soft-assertion paths, OR rely on
	# assert() to abort. We treat any return value other than `false` as pass.
	var result = instance.call(method_name)
	return result != false
```

- [ ] **Step 2: Run it (it will report 0 tests since no test files exist yet)**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected output contains:
```
=== stat_system test runner ===
=== 0 passed, 0 failed ===
```
Exit code 0.

- [ ] **Step 3: Commit**

```bash
git add addons/stat_system/tests/run_tests.gd
git commit -m "feat(stat-system): add headless test runner"
```

---

### Task 3: Data resources — StatDefinition, StatModifier, StatFormula (abstract)

**Files:**
- Create: `addons/stat_system/core/stat_definition.gd`
- Create: `addons/stat_system/core/stat_modifier.gd`
- Create: `addons/stat_system/core/stat_formula.gd`

These three files have no logic worth testing in isolation — they're pure data and one abstract method. The tests for them ride on top of `AdditivePercentFormula` (Task 4) and `StatBlock` (Task 6+).

- [ ] **Step 1: Create `addons/stat_system/core/stat_definition.gd`**

```gdscript
@tool
extends Resource
class_name StatDefinition
## Static schema for one stat type.
## Authored once per stat (e.g. health.tres, attack.tres) and referenced
## by every StatBlock that includes that stat.

## Unique identifier (e.g. "health", "attack"). StringName for fast lookup.
@export var id: StringName = &""

## Display name for UI (e.g. "Health").
@export var display_name: String = ""

## Base value before any modifiers are applied.
@export var base_value: float = 0.0

## Lower clamp on the final computed value.
@export var min_value: float = 0.0

## Upper clamp on the final computed value. 0 = unbounded.
@export var max_value: float = 0.0

## When true, this stat tracks a `current` value separately from its computed
## max (HP, MP, stamina). When false, it is a flat stat (attack, defense).
@export var is_resource: bool = false

## Per-second regen applied to `current` for resource stats. 0 = no regen.
@export var regen_per_second: float = 0.0

## Optional icon for UI bars/buff lists.
@export var icon: Texture2D

## Display color for UI bars.
@export var color: Color = Color.WHITE
```

- [ ] **Step 2: Create `addons/stat_system/core/stat_modifier.gd`**

```gdscript
@tool
extends Resource
class_name StatModifier
## One bonus applied to one stat from one source.
## Modifiers may be permanent (duration < 0) or timed (duration > 0).

enum Op { FLAT, PERCENT }

## Reason a modifier was removed. Forwarded with the modifier_removed signal.
enum RemoveReason { SOURCE_REMOVED, EXPIRED, MANUAL }

## Which stat this modifier targets (matches StatDefinition.id).
@export var stat_id: StringName = &""

## FLAT adds value directly. PERCENT contributes value to a percent sum
## that is multiplied in once by AdditivePercentFormula.
@export var op: Op = Op.FLAT

## Magnitude. For PERCENT, 10.0 means +10% of (base + flat_sum).
@export var value: float = 0.0

## Source identifier for clean removal (e.g. "iron_helmet", "haste_buff").
## remove_modifiers_by_source uses this to clear all modifiers from one source.
@export var source_id: StringName = &""

## Lifetime in seconds. -1 = permanent (default). >0 = ticks down each frame
## via StatBlock.tick().
@export var duration: float = -1.0

## Display name for buff bar UI.
@export var display_name: String = ""

## Optional icon for buff bar UI.
@export var icon: Texture2D

## Runtime: time remaining for timed modifiers. Initialized by add_modifier.
## Not exported — recomputed at runtime, not persisted.
var remaining: float = -1.0
```

- [ ] **Step 3: Create `addons/stat_system/core/stat_formula.gd`**

```gdscript
@tool
extends Resource
class_name StatFormula
## Strategy resource: computes the final value of one stat from its
## definition and the list of modifiers currently targeting it.
## Subclass and override compute() to add new math rules without
## modifying StatBlock (OCP).

## @virtual Compute the final value of `definition` given `modifiers`.
## Implementations should clamp to [definition.min_value, definition.max_value]
## (treating max_value == 0 as unbounded).
func compute(definition: StatDefinition, modifiers: Array[StatModifier]) -> float:
	push_error("StatFormula.compute() is abstract — override in subclass")
	return 0.0
```

- [ ] **Step 4: Quick sanity-load**

Run:
```bash
godot --headless --quit
```
Expected: no `SCRIPT ERROR` mentioning these new files.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/core/stat_definition.gd addons/stat_system/core/stat_modifier.gd addons/stat_system/core/stat_formula.gd
git commit -m "feat(stat-system): add StatDefinition, StatModifier, StatFormula resources"
```

---

### Task 4: AdditivePercentFormula (TDD)

**Files:**
- Create: `addons/stat_system/tests/test_additive_percent_formula.gd`
- Create: `addons/stat_system/core/additive_percent_formula.gd`

The default formula. This is pure math — perfect for TDD. Write the failing test first.

- [ ] **Step 1: Write the failing test `addons/stat_system/tests/test_additive_percent_formula.gd`**

```gdscript
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
```

- [ ] **Step 2: Run the test runner — expect failures**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: every `test_*` method FAILs with `SCRIPT ERROR: Identifier "AdditivePercentFormula" not declared`. Exit code 1.

- [ ] **Step 3: Implement `addons/stat_system/core/additive_percent_formula.gd`**

```gdscript
@tool
extends StatFormula
class_name AdditivePercentFormula
## Default StatFormula:  final = (base + sum_flat) * (1 + sum_percent / 100)
## Result is clamped to [definition.min_value, definition.max_value],
## treating max_value == 0 as unbounded.

func compute(definition: StatDefinition, modifiers: Array[StatModifier]) -> float:
	if definition == null:
		push_warning("AdditivePercentFormula: null definition")
		return 0.0

	var sum_flat: float = 0.0
	var sum_percent: float = 0.0
	for m in modifiers:
		if m == null or m.stat_id != definition.id:
			continue
		match m.op:
			StatModifier.Op.FLAT:
				sum_flat += m.value
			StatModifier.Op.PERCENT:
				sum_percent += m.value

	var result: float = (definition.base_value + sum_flat) * (1.0 + sum_percent / 100.0)

	if result < definition.min_value:
		result = definition.min_value
	if definition.max_value > 0.0 and result > definition.max_value:
		result = definition.max_value

	return result
```

- [ ] **Step 4: Run the test runner — expect all PASS**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected output contains:
```
PASS: test_empty_modifiers_returns_base
PASS: test_single_flat_modifier_adds
PASS: test_single_percent_modifier_multiplies
PASS: test_mixed_flat_and_percent
PASS: test_multiple_flats_sum
PASS: test_multiple_percents_sum_additively
PASS: test_negative_percent_caps_at_zero
PASS: test_max_value_clamps
PASS: test_min_value_clamps
PASS: test_max_value_zero_means_unbounded
=== 10 passed, 0 failed ===
```
Exit code 0.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/core/additive_percent_formula.gd addons/stat_system/tests/test_additive_percent_formula.gd
git commit -m "feat(stat-system): add AdditivePercentFormula with TDD coverage"
```

---

### Task 5: BaseStatBlock abstract container

**Files:**
- Create: `addons/stat_system/core/base_stat_block.gd`

Abstract base mirroring `BaseInventory`. Defines the contract; default impl lives in `StatBlock`.

- [ ] **Step 1: Create `addons/stat_system/core/base_stat_block.gd`**

```gdscript
@tool
extends Resource
class_name BaseStatBlock
## Abstract base class for stat containers.
## Mirrors BaseInventory's role in the inventory_system addon.
## Subclass to create variants (e.g. a future DerivedStatBlock).

## Emitted whenever the final computed value of a stat changes.
signal stat_changed(id: StringName, old_value: float, new_value: float)

## Emitted when a resource stat's `current` reaches 0.
signal resource_depleted(id: StringName)

## Emitted when a resource stat's `current` becomes equal to its computed max
## (and was previously below max).
signal resource_filled(id: StringName)

## Emitted after a modifier is added.
signal modifier_added(modifier: StatModifier)

## Emitted after a modifier is removed. `reason` is a StatModifier.RemoveReason.
signal modifier_removed(modifier: StatModifier, reason: int)

## @virtual Final computed value for a flat stat, or the computed max for
## a resource stat. Returns 0.0 and pushes a warning for unknown ids.
func get_value(_id: StringName) -> float:
	push_error("BaseStatBlock.get_value() is abstract")
	return 0.0

## @virtual Convenience: same as get_value(). Provided so call sites that
## want to read "the maximum" of a resource stat read better.
func get_max(_id: StringName) -> float:
	push_error("BaseStatBlock.get_max() is abstract")
	return 0.0

## @virtual For resource stats, returns the persisted current value.
## For flat stats, returns the same as get_value().
func get_current(_id: StringName) -> float:
	push_error("BaseStatBlock.get_current() is abstract")
	return 0.0

## @virtual Adjust a resource stat's current by `delta`. Clamps to [0, max].
## Emits stat_changed and resource_depleted/resource_filled as appropriate.
func modify_resource(_id: StringName, _delta: float) -> void:
	push_error("BaseStatBlock.modify_resource() is abstract")

## @virtual Set a resource stat's current directly. Clamps to [0, max].
func set_current(_id: StringName, _value: float) -> void:
	push_error("BaseStatBlock.set_current() is abstract")

## @virtual Add a modifier. Recomputes the affected stat and emits signals.
func add_modifier(_modifier: StatModifier) -> void:
	push_error("BaseStatBlock.add_modifier() is abstract")

## @virtual Remove one specific modifier instance.
func remove_modifier(_modifier: StatModifier) -> void:
	push_error("BaseStatBlock.remove_modifier() is abstract")

## @virtual Remove all modifiers tagged with the given source_id.
## Used by EquipmentComponent on unequip.
func remove_modifiers_by_source(_source_id: StringName) -> void:
	push_error("BaseStatBlock.remove_modifiers_by_source() is abstract")

## @virtual Read-only snapshot of all active modifiers.
func get_active_modifiers() -> Array[StatModifier]:
	push_error("BaseStatBlock.get_active_modifiers() is abstract")
	return []

## @virtual Apply per-frame updates: regen for resource stats, and countdown
## for timed modifiers (removing them with reason EXPIRED on hit zero).
## Called by StatComponent._process.
func tick(_delta: float) -> void:
	push_error("BaseStatBlock.tick() is abstract")

## @virtual Save the persistent parts of the block to a Dictionary.
func serialize() -> Dictionary:
	push_error("BaseStatBlock.serialize() is abstract")
	return {}

## @virtual Restore from a Dictionary produced by serialize().
func deserialize(_data: Dictionary) -> void:
	push_error("BaseStatBlock.deserialize() is abstract")
```

- [ ] **Step 2: Sanity-load**

Run:
```bash
godot --headless --quit
```
Expected: no script errors.

- [ ] **Step 3: Commit**

```bash
git add addons/stat_system/core/base_stat_block.gd
git commit -m "feat(stat-system): add BaseStatBlock abstract container"
```

---

### Task 6: StatBlock part A — definitions and value reads

**Files:**
- Create: `addons/stat_system/tests/test_stat_block.gd`
- Create: `addons/stat_system/core/stat_block.gd`

Build the StatBlock incrementally over Tasks 6–10. Part A only handles definitions, the formula default, and the read methods (`get_value`, `get_max`, `get_current` for flat stats with no modifiers yet).

- [ ] **Step 1: Write the failing tests**

Create `addons/stat_system/tests/test_stat_block.gd`:

```gdscript
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
	# StatBlock._init assigns AdditivePercentFormula by default; re-trigger
	# in case the array assignment happened after _init.
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
```

- [ ] **Step 2: Run tests, expect failure**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `test_stat_block.gd` tests FAIL with `Identifier "StatBlock" not declared`. The 10 `AdditivePercentFormula` tests still PASS.

- [ ] **Step 3: Implement StatBlock Part A in `addons/stat_system/core/stat_block.gd`**

```gdscript
@tool
extends BaseStatBlock
class_name StatBlock
## Default StatBlock implementation: holds definitions, modifiers,
## current resource values, and a swappable formula. Built up over
## plan tasks 6–10.

@export var definitions: Array[StatDefinition] = []
@export var formula: StatFormula  # set in _init if null
@export var current_resources: Dictionary = {}  # StringName -> float

# Runtime, not exported. Modifiers are recomputed at load time by the
# systems that own them (e.g. EquipmentComponent on equip).
var _modifiers: Array[StatModifier] = []

# Cache of computed values, invalidated when modifiers change.
var _value_cache: Dictionary = {}  # StringName -> float

func _init() -> void:
	if formula == null:
		formula = AdditivePercentFormula.new()

## Look up a StatDefinition by id. Returns null and warns if not found.
func _find_definition(id: StringName) -> StatDefinition:
	for d in definitions:
		if d != null and d.id == id:
			return d
	return null

func get_value(id: StringName) -> float:
	if _value_cache.has(id):
		return _value_cache[id]
	var def := _find_definition(id)
	if def == null:
		push_warning("StatBlock: unknown stat id '%s'" % id)
		return 0.0
	var value: float = formula.compute(def, _modifiers)
	_value_cache[id] = value
	return value

func get_max(id: StringName) -> float:
	# For both flat and resource stats, get_max returns the computed value.
	return get_value(id)

func get_current(id: StringName) -> float:
	var def := _find_definition(id)
	if def == null:
		push_warning("StatBlock: unknown stat id '%s'" % id)
		return 0.0
	if not def.is_resource:
		return get_value(id)
	# Resource stat: return persisted current. If never initialized, fall
	# back to the computed max so a freshly-authored block reads as full.
	if current_resources.has(id):
		return current_resources[id]
	return get_value(id)

# Stub implementations for the rest of the abstract surface — filled in
# by Tasks 7–10. Empty bodies are correct enough that the runtime doesn't
# crash if a consumer happens to call them mid-implementation.

func modify_resource(_id: StringName, _delta: float) -> void:
	pass

func set_current(_id: StringName, _value: float) -> void:
	pass

func add_modifier(_modifier: StatModifier) -> void:
	pass

func remove_modifier(_modifier: StatModifier) -> void:
	pass

func remove_modifiers_by_source(_source_id: StringName) -> void:
	pass

func get_active_modifiers() -> Array[StatModifier]:
	return _modifiers.duplicate()

func tick(_delta: float) -> void:
	pass

func serialize() -> Dictionary:
	return {}

func deserialize(_data: Dictionary) -> void:
	pass
```

- [ ] **Step 4: Run tests — Part A tests should PASS**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: the 6 Part A tests PASS, the 10 AdditivePercentFormula tests still PASS. `=== 16 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/core/stat_block.gd addons/stat_system/tests/test_stat_block.gd
git commit -m "feat(stat-system): StatBlock part A — definitions and value reads"
```

---

### Task 7: StatBlock part B — modifier add/remove + recompute + signals

**Files:**
- Modify: `addons/stat_system/tests/test_stat_block.gd` (append tests)
- Modify: `addons/stat_system/core/stat_block.gd` (replace stubs)

- [ ] **Step 1: Append the failing tests**

Append to `addons/stat_system/tests/test_stat_block.gd`:

```gdscript
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
```

- [ ] **Step 2: Run tests, expect failure**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: the 9 new Part B tests FAIL (the stub `add_modifier` is a no-op, so values never change).

- [ ] **Step 3: Replace the stubs in `stat_block.gd` with real implementations**

In `addons/stat_system/core/stat_block.gd`, replace these methods (everything from `func add_modifier` down through `func remove_modifiers_by_source`) with:

```gdscript
func add_modifier(modifier: StatModifier) -> void:
	if modifier == null:
		push_warning("StatBlock.add_modifier: null modifier")
		return
	var def := _find_definition(modifier.stat_id)
	if def == null:
		push_warning("StatBlock.add_modifier: unknown stat id '%s'" % modifier.stat_id)
		return

	var old_value := get_value(modifier.stat_id)
	_modifiers.append(modifier)
	# Initialize timed-modifier remaining counter.
	modifier.remaining = modifier.duration
	_invalidate(modifier.stat_id)
	modifier_added.emit(modifier)

	var new_value := get_value(modifier.stat_id)
	if new_value != old_value:
		stat_changed.emit(modifier.stat_id, old_value, new_value)

func remove_modifier(modifier: StatModifier) -> void:
	_remove_modifier_with_reason(modifier, StatModifier.RemoveReason.MANUAL)

func remove_modifiers_by_source(source_id: StringName) -> void:
	# Iterate over a copy because we're mutating the list.
	for m in _modifiers.duplicate():
		if m != null and m.source_id == source_id:
			_remove_modifier_with_reason(m, StatModifier.RemoveReason.SOURCE_REMOVED)

func _remove_modifier_with_reason(modifier: StatModifier, reason: int) -> void:
	if modifier == null:
		return
	var idx := _modifiers.find(modifier)
	if idx < 0:
		return
	var stat_id: StringName = modifier.stat_id
	var old_value := get_value(stat_id)
	_modifiers.remove_at(idx)
	_invalidate(stat_id)
	modifier_removed.emit(modifier, reason)

	var new_value := get_value(stat_id)
	if new_value != old_value:
		stat_changed.emit(stat_id, old_value, new_value)

## Invalidate the cached value for one stat, forcing recomputation on next read.
func _invalidate(id: StringName) -> void:
	_value_cache.erase(id)
```

- [ ] **Step 4: Run tests — Part A + Part B should PASS**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 25 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/core/stat_block.gd addons/stat_system/tests/test_stat_block.gd
git commit -m "feat(stat-system): StatBlock part B — modifier add/remove with signals"
```

---

### Task 8: StatBlock part C — resource current pool

**Files:**
- Modify: `addons/stat_system/tests/test_stat_block.gd` (append tests)
- Modify: `addons/stat_system/core/stat_block.gd` (replace stubs)

- [ ] **Step 1: Append the failing tests**

Append to `addons/stat_system/tests/test_stat_block.gd`:

```gdscript
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
	b.stat_changed.connect(func(id, old, new): captured.append([id, old, new]))
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
```

- [ ] **Step 2: Run tests, expect failure**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: the 9 new Part C tests FAIL.

- [ ] **Step 3: Implement Part C in `stat_block.gd`**

Replace the stub `func modify_resource` and `func set_current` methods with:

```gdscript
func modify_resource(id: StringName, delta: float) -> void:
	var def := _find_definition(id)
	if def == null:
		push_warning("StatBlock.modify_resource: unknown stat id '%s'" % id)
		return
	if not def.is_resource:
		push_warning("StatBlock.modify_resource: '%s' is not a resource stat" % id)
		return

	var max_v := get_max(id)
	var old_current := get_current(id)
	var new_current := clampf(old_current + delta, 0.0, max_v)

	if new_current == old_current:
		return

	current_resources[id] = new_current
	stat_changed.emit(id, old_current, new_current)
	if new_current <= 0.0 and old_current > 0.0:
		resource_depleted.emit(id)
	elif new_current >= max_v and old_current < max_v:
		resource_filled.emit(id)

func set_current(id: StringName, value: float) -> void:
	var def := _find_definition(id)
	if def == null:
		push_warning("StatBlock.set_current: unknown stat id '%s'" % id)
		return
	if not def.is_resource:
		push_warning("StatBlock.set_current: '%s' is not a resource stat" % id)
		return
	var max_v := get_max(id)
	var old_current := get_current(id)
	var new_current := clampf(value, 0.0, max_v)
	if new_current == old_current:
		return
	current_resources[id] = new_current
	stat_changed.emit(id, old_current, new_current)
	if new_current <= 0.0 and old_current > 0.0:
		resource_depleted.emit(id)
	elif new_current >= max_v and old_current < max_v:
		resource_filled.emit(id)
```

- [ ] **Step 4: Run tests — Parts A+B+C should PASS**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 34 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/core/stat_block.gd addons/stat_system/tests/test_stat_block.gd
git commit -m "feat(stat-system): StatBlock part C — resource current pool with depletion/fill signals"
```

---

### Task 9: StatBlock part D — tick (regen + buff timers)

**Files:**
- Modify: `addons/stat_system/tests/test_stat_block.gd` (append tests)
- Modify: `addons/stat_system/core/stat_block.gd` (replace stub)

- [ ] **Step 1: Append the failing tests**

Append to `addons/stat_system/tests/test_stat_block.gd`:

```gdscript
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
	var m := _make_mod(&"attack", StatModifier.Op.FLAT, 10.0)
	m.duration = 2.0
	b.add_modifier(m)
	assert(m.remaining == 2.0)
	b.tick(0.5)
	assert(m.remaining == 1.5)
	assert(b.get_value(&"attack") == 15.0)
	return true

func test_tick_expires_timed_modifier_at_zero() -> bool:
	var b := _make_block([_make_def(&"attack", 5.0)])
	var m := _make_mod(&"attack", StatModifier.Op.FLAT, 10.0)
	m.duration = 1.0
	b.add_modifier(m)
	assert(b.get_value(&"attack") == 15.0)
	var captured := []
	b.modifier_removed.connect(func(mod, reason): captured.append([mod, reason]))
	b.tick(1.5)
	assert(b.get_value(&"attack") == 5.0)
	assert(captured.size() == 1)
	assert(captured[0][0] == m)
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
```

- [ ] **Step 2: Run tests, expect failure**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: the 6 new Part D tests FAIL — `tick()` is still a stub.

- [ ] **Step 3: Replace the `tick` stub in `stat_block.gd`**

```gdscript
func tick(delta: float) -> void:
	if delta <= 0.0:
		return

	# 1. Regen for resource stats.
	for def in definitions:
		if def == null or not def.is_resource or def.regen_per_second == 0.0:
			continue
		var current := get_current(def.id)
		var max_v := get_max(def.id)
		if current >= max_v:
			continue
		modify_resource(def.id, def.regen_per_second * delta)

	# 2. Decrement timed modifiers; remove expired ones.
	# Snapshot the list because we're going to mutate it.
	var to_expire: Array[StatModifier] = []
	for m in _modifiers:
		if m == null or m.duration < 0.0:
			continue
		m.remaining -= delta
		if m.remaining <= 0.0:
			to_expire.append(m)

	for m in to_expire:
		_remove_modifier_with_reason(m, StatModifier.RemoveReason.EXPIRED)
```

- [ ] **Step 4: Run tests — Parts A+B+C+D should PASS**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 40 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/core/stat_block.gd addons/stat_system/tests/test_stat_block.gd
git commit -m "feat(stat-system): StatBlock part D — tick with regen and buff expiry"
```

---

### Task 10: StatBlock part E — serialize/deserialize

**Files:**
- Create: `addons/stat_system/tests/test_stat_block_serialization.gd`
- Modify: `addons/stat_system/core/stat_block.gd` (replace stubs)

`current_resources` is persisted; `_modifiers` are not. Equipment re-pushes its modifiers on load via `EquipmentComponent`, and timed buffs intentionally don't survive a save cycle.

- [ ] **Step 1: Write the failing test `addons/stat_system/tests/test_stat_block_serialization.gd`**

```gdscript
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
	assert(not data.has("modifiers"))
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
```

- [ ] **Step 2: Run tests, expect failure**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: the 5 new tests FAIL.

- [ ] **Step 3: Replace the serialize/deserialize stubs in `stat_block.gd`**

```gdscript
func serialize() -> Dictionary:
	# Convert StringName keys to String for save-file readability.
	var cr_out := {}
	for key in current_resources:
		cr_out[String(key)] = current_resources[key]
	return {
		"current_resources": cr_out,
	}

func deserialize(data: Dictionary) -> void:
	current_resources.clear()
	_value_cache.clear()
	var cr: Dictionary = data.get("current_resources", {})
	for key in cr:
		var id := StringName(key) if not (key is StringName) else key
		var def := _find_definition(id)
		if def == null or not def.is_resource:
			continue
		var max_v := get_max(id)
		current_resources[id] = clampf(cr[key], 0.0, max_v)
```

- [ ] **Step 4: Run tests — all serialization tests should PASS**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 45 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/core/stat_block.gd addons/stat_system/tests/test_stat_block_serialization.gd
git commit -m "feat(stat-system): StatBlock part E — serialize/deserialize current resources"
```

---

### Task 11: StatReader read-only view (ISP)

**Files:**
- Create: `addons/stat_system/core/stat_reader.gd`

A narrow read-only wrapper for UI consumers. Exposes only reads + signals; no `add_modifier`, no `modify_resource`. Convention-based ISP — UI cannot accidentally mutate.

- [ ] **Step 1: Create `addons/stat_system/core/stat_reader.gd`**

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

var _block: StatBlock

func _init(block: StatBlock) -> void:
	_block = block
	if _block:
		_block.stat_changed.connect(_forward_stat_changed)
		_block.resource_depleted.connect(_forward_depleted)
		_block.resource_filled.connect(_forward_filled)

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
```

- [ ] **Step 2: Sanity-load**

Run:
```bash
godot --headless --quit
```
Expected: no script errors. Tests still pass:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 45 passed, 0 failed ===`.

- [ ] **Step 3: Commit**

```bash
git add addons/stat_system/core/stat_reader.gd
git commit -m "feat(stat-system): add StatReader read-only view (ISP)"
```

---

### Task 12: StatComponent Node + integration test

**Files:**
- Create: `addons/stat_system/tests/test_stat_component.gd`
- Create: `addons/stat_system/core/stat_component.gd`

The Node wraps the Resource, drives `_process`, and forwards signals to the scene-tree consumers. Also exposes `get_reader()` and forwards public methods through to the block (so consumers usually don't need to reach into `stat_block` directly).

- [ ] **Step 1: Write the failing test `addons/stat_system/tests/test_stat_component.gd`**

The test does NOT enter the SceneTree (the headless runner is a SceneTree itself, but adding nodes is fragile in this context). Instead it constructs the Component, manually invokes `tick`, and checks signal forwarding via direct connection.

```gdscript
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
```

- [ ] **Step 2: Run tests, expect failure**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: 7 new tests FAIL with `Identifier "StatComponent" not declared`.

- [ ] **Step 3: Implement `addons/stat_system/core/stat_component.gd`**

```gdscript
@tool
extends Node
class_name StatComponent
## Runtime owner of a StatBlock. Hosts the per-frame tick (regen + buff
## countdown) and forwards public stat operations + signals to the block.
##
## Consumers should usually call methods on this Node rather than poking
## stat_block directly. UI consumers should call get_reader() instead.

@export var stat_block: StatBlock

# Re-emitted from the wrapped StatBlock so scene-tree consumers can connect
# without reaching into the resource.
signal stat_changed(id: StringName, old_value: float, new_value: float)
signal resource_depleted(id: StringName)
signal resource_filled(id: StringName)
signal modifier_added(modifier: StatModifier)
signal modifier_removed(modifier: StatModifier, reason: int)

func _ready() -> void:
	if stat_block == null:
		push_warning("StatComponent: no stat_block assigned to '%s'" % name)
		return
	stat_block.stat_changed.connect(_on_stat_changed)
	stat_block.resource_depleted.connect(_on_resource_depleted)
	stat_block.resource_filled.connect(_on_resource_filled)
	stat_block.modifier_added.connect(_on_modifier_added)
	stat_block.modifier_removed.connect(_on_modifier_removed)

func _process(delta: float) -> void:
	if stat_block:
		stat_block.tick(delta)

# --- Read API ---

func get_value(id: StringName) -> float:
	return stat_block.get_value(id) if stat_block else 0.0

func get_max(id: StringName) -> float:
	return stat_block.get_max(id) if stat_block else 0.0

func get_current(id: StringName) -> float:
	return stat_block.get_current(id) if stat_block else 0.0

func get_active_modifiers() -> Array[StatModifier]:
	return stat_block.get_active_modifiers() if stat_block else []

func get_reader() -> StatReader:
	return StatReader.new(stat_block)

# --- Mutation API ---

func modify_resource(id: StringName, delta: float) -> void:
	if stat_block:
		stat_block.modify_resource(id, delta)

func set_current(id: StringName, value: float) -> void:
	if stat_block:
		stat_block.set_current(id, value)

func add_modifier(modifier: StatModifier) -> void:
	if stat_block:
		stat_block.add_modifier(modifier)

func remove_modifier(modifier: StatModifier) -> void:
	if stat_block:
		stat_block.remove_modifier(modifier)

func remove_modifiers_by_source(source_id: StringName) -> void:
	if stat_block:
		stat_block.remove_modifiers_by_source(source_id)

# --- Save/load ---

func serialize() -> Dictionary:
	return stat_block.serialize() if stat_block else {}

func deserialize(data: Dictionary) -> void:
	if stat_block:
		stat_block.deserialize(data)

# --- Signal forwarders ---

func _on_stat_changed(id: StringName, old_value: float, new_value: float) -> void:
	stat_changed.emit(id, old_value, new_value)

func _on_resource_depleted(id: StringName) -> void:
	resource_depleted.emit(id)

func _on_resource_filled(id: StringName) -> void:
	resource_filled.emit(id)

func _on_modifier_added(modifier: StatModifier) -> void:
	modifier_added.emit(modifier)

func _on_modifier_removed(modifier: StatModifier, reason: int) -> void:
	modifier_removed.emit(modifier, reason)
```

- [ ] **Step 4: Run tests — all should PASS**

Run:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 52 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/core/stat_component.gd addons/stat_system/tests/test_stat_component.gd
git commit -m "feat(stat-system): add StatComponent runtime Node"
```

---

### Task 13: Plugin registration of core types

**Files:**
- Modify: `addons/stat_system/stat_system_plugin.gd`

Wire all core types into the editor so they appear under "Create New Node/Resource".

- [ ] **Step 1: Replace `addons/stat_system/stat_system_plugin.gd` with the full registration**

```gdscript
@tool
extends EditorPlugin
## Stat System editor plugin. Registers core types, then conditionally
## registers effects (which extend ItemEffect from inventory_system) only
## when the inventory_system addon is enabled.

func _enter_tree() -> void:
	# Core data resources.
	add_custom_type("StatDefinition", "Resource", preload("core/stat_definition.gd"), null)
	add_custom_type("StatModifier", "Resource", preload("core/stat_modifier.gd"), null)
	add_custom_type("StatFormula", "Resource", preload("core/stat_formula.gd"), null)
	add_custom_type("AdditivePercentFormula", "Resource", preload("core/additive_percent_formula.gd"), null)
	add_custom_type("BaseStatBlock", "Resource", preload("core/base_stat_block.gd"), null)
	add_custom_type("StatBlock", "Resource", preload("core/stat_block.gd"), null)

	# Runtime node.
	add_custom_type("StatComponent", "Node", preload("core/stat_component.gd"), null)

	# Conditional effect registration: gated by Task 14.
	_register_effects_if_inventory_enabled()

func _exit_tree() -> void:
	remove_custom_type("StatDefinition")
	remove_custom_type("StatModifier")
	remove_custom_type("StatFormula")
	remove_custom_type("AdditivePercentFormula")
	remove_custom_type("BaseStatBlock")
	remove_custom_type("StatBlock")
	remove_custom_type("StatComponent")
	_unregister_effects_if_inventory_enabled()

# Filled in by Task 14.
func _register_effects_if_inventory_enabled() -> void:
	pass

func _unregister_effects_if_inventory_enabled() -> void:
	pass
```

- [ ] **Step 2: Sanity-load**

Run:
```bash
godot --headless --quit
```
Expected: no script errors. The stat_system addon is now fully functional standalone — tests still pass:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 52 passed, 0 failed ===`.

- [ ] **Step 3: Commit**

```bash
git add addons/stat_system/stat_system_plugin.gd
git commit -m "feat(stat-system): register core types in editor plugin"
```

---

### Task 14: Effects + plugin gating

**Files:**
- Create: `addons/stat_system/effects/resource_effect.gd`
- Create: `addons/stat_system/effects/apply_modifier_effect.gd`
- Modify: `addons/stat_system/stat_system_plugin.gd` (gating logic)

The two effects extend `ItemEffect` from `inventory_system`. To keep stat_system standalone, the plugin only registers them if `inventory_system` is enabled in the project — and the scripts themselves use a runtime check on the `ItemEffect` class.

- [ ] **Step 1: Create `addons/stat_system/effects/resource_effect.gd`**

```gdscript
@tool
extends ItemEffect
class_name ResourceEffect
## Generic resource effect — applies a delta to one resource stat on the
## user's StatComponent. Replaces HealEffect and ManaEffect with a single
## data-driven effect.
##
## Authoring: target_stat = "health"/"mana"/"stamina", delta = +50, etc.
## Negative delta damages, positive heals/restores.

@export var target_stat: StringName = &""
@export var delta: float = 0.0

func _init() -> void:
	effect_name = "Resource"

func apply(user: Node) -> bool:
	if not can_apply(user):
		return false
	var sc := _find_stat_component(user)
	if sc == null:
		push_warning("ResourceEffect: no StatComponent on '%s'" % user.name)
		return false
	sc.modify_resource(target_stat, delta)
	return true

func can_apply(user: Node) -> bool:
	return user != null and _find_stat_component(user) != null

func _find_stat_component(user: Node) -> StatComponent:
	# Common patterns: a child named "StatComponent", or any descendant.
	var direct := user.get_node_or_null("StatComponent") as StatComponent
	if direct:
		return direct
	for child in user.get_children():
		if child is StatComponent:
			return child
	return null

func get_tooltip_text() -> String:
	if delta == 0.0 or target_stat == &"":
		return ""
	var sign := "+" if delta > 0.0 else ""
	var color := "lime" if delta > 0.0 else "red"
	return "[color=%s]%s%d %s[/color]" % [color, sign, int(delta), String(target_stat).capitalize()]
```

- [ ] **Step 2: Create `addons/stat_system/effects/apply_modifier_effect.gd`**

```gdscript
@tool
extends ItemEffect
class_name ApplyModifierEffect
## Pushes a (typically timed) StatModifier onto the user's StatComponent.
## Powers buff potions: e.g. "+5 attack for 60s".
##
## The modifier resource should have duration > 0 for a temporary buff.

@export var modifier: StatModifier

func _init() -> void:
	effect_name = "Apply Modifier"

func apply(user: Node) -> bool:
	if not can_apply(user):
		return false
	if modifier == null:
		push_warning("ApplyModifierEffect: no modifier configured")
		return false
	var sc := _find_stat_component(user)
	if sc == null:
		push_warning("ApplyModifierEffect: no StatComponent on '%s'" % user.name)
		return false
	# Duplicate so multiple uses don't share the same `remaining` counter.
	var mod_copy: StatModifier = modifier.duplicate()
	sc.add_modifier(mod_copy)
	return true

func can_apply(user: Node) -> bool:
	return user != null and modifier != null and _find_stat_component(user) != null

func _find_stat_component(user: Node) -> StatComponent:
	var direct := user.get_node_or_null("StatComponent") as StatComponent
	if direct:
		return direct
	for child in user.get_children():
		if child is StatComponent:
			return child
	return null

func get_tooltip_text() -> String:
	if modifier == null:
		return ""
	var op_label := "+" if modifier.value >= 0.0 else ""
	var unit := "%" if modifier.op == StatModifier.Op.PERCENT else ""
	var stat_label := String(modifier.stat_id).capitalize()
	var line := "[color=cyan]%s%d%s %s[/color]" % [op_label, int(modifier.value), unit, stat_label]
	if modifier.duration > 0.0:
		line += " [color=gray](%.0fs)[/color]" % modifier.duration
	return line
```

- [ ] **Step 3: Replace the gating stubs in `addons/stat_system/stat_system_plugin.gd`**

Replace the two stub functions at the bottom with:

```gdscript
func _register_effects_if_inventory_enabled() -> void:
	if not _inventory_addon_enabled():
		return
	add_custom_type("ResourceEffect", "Resource", preload("effects/resource_effect.gd"), null)
	add_custom_type("ApplyModifierEffect", "Resource", preload("effects/apply_modifier_effect.gd"), null)

func _unregister_effects_if_inventory_enabled() -> void:
	if not _inventory_addon_enabled():
		return
	remove_custom_type("ResourceEffect")
	remove_custom_type("ApplyModifierEffect")

func _inventory_addon_enabled() -> bool:
	# Detect by looking for the ItemEffect class. ClassDB.class_exists checks
	# core engine classes only, so use a path probe instead.
	return ResourceLoader.exists("res://addons/inventory_system/core/item_effect.gd")
```

- [ ] **Step 4: Sanity-load**

Run:
```bash
godot --headless --quit
```
Expected: no script errors. Run tests:
```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 52 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add addons/stat_system/effects/ addons/stat_system/stat_system_plugin.gd
git commit -m "feat(stat-system): add ResourceEffect and ApplyModifierEffect (gated)"
```

---

### Task 15: Example stat .tres files

**Files:**
- Create: `addons/stat_system/examples/stats/health.tres`
- Create: `addons/stat_system/examples/stats/mana.tres`
- Create: `addons/stat_system/examples/stats/stamina.tres`
- Create: `addons/stat_system/examples/stats/attack.tres`
- Create: `addons/stat_system/examples/stats/defense.tres`

These provide ready-to-drop stat definitions for projects using the addon. They're also referenced from the manual test scene (Task 20).

The Godot UID values below are placeholders — when the editor opens these files for the first time it will populate UIDs automatically. You can leave the `uid="uid://..."` line off; the editor will add it.

- [ ] **Step 1: Create `addons/stat_system/examples/stats/health.tres`**

```
[gd_resource type="Resource" script_class="StatDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/stat_system/core/stat_definition.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"health"
display_name = "Health"
base_value = 100.0
min_value = 0.0
max_value = 0.0
is_resource = true
regen_per_second = 1.0
color = Color(0.85, 0.2, 0.25, 1)
```

- [ ] **Step 2: Create `addons/stat_system/examples/stats/mana.tres`**

```
[gd_resource type="Resource" script_class="StatDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/stat_system/core/stat_definition.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"mana"
display_name = "Mana"
base_value = 50.0
min_value = 0.0
max_value = 0.0
is_resource = true
regen_per_second = 2.0
color = Color(0.25, 0.4, 0.95, 1)
```

- [ ] **Step 3: Create `addons/stat_system/examples/stats/stamina.tres`**

```
[gd_resource type="Resource" script_class="StatDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/stat_system/core/stat_definition.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"stamina"
display_name = "Stamina"
base_value = 100.0
min_value = 0.0
max_value = 0.0
is_resource = true
regen_per_second = 10.0
color = Color(0.95, 0.85, 0.2, 1)
```

- [ ] **Step 4: Create `addons/stat_system/examples/stats/attack.tres`**

```
[gd_resource type="Resource" script_class="StatDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/stat_system/core/stat_definition.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"attack"
display_name = "Attack"
base_value = 0.0
min_value = 0.0
max_value = 0.0
is_resource = false
regen_per_second = 0.0
color = Color(0.95, 0.5, 0.2, 1)
```

- [ ] **Step 5: Create `addons/stat_system/examples/stats/defense.tres`**

```
[gd_resource type="Resource" script_class="StatDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/stat_system/core/stat_definition.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"defense"
display_name = "Defense"
base_value = 0.0
min_value = 0.0
max_value = 0.0
is_resource = false
regen_per_second = 0.0
color = Color(0.4, 0.6, 0.85, 1)
```

- [ ] **Step 6: Sanity-load (Godot will populate UIDs)**

Run:
```bash
godot --headless --quit
```
Expected: no script errors. The editor will add `uid="uid://..."` lines to each file on first import — that's fine, commit them.

- [ ] **Step 7: Commit**

```bash
git add addons/stat_system/examples/
git commit -m "feat(stat-system): add example stat definitions (health, mana, stamina, attack, defense)"
```

---

### Task 16: stat_system addon README

**Files:**
- Modify: `addons/stat_system/README.md`

Replace the stub README with usage docs that match the inventory_system addon's depth.

- [ ] **Step 1: Replace the contents of `addons/stat_system/README.md`**

```markdown
# Stat System

Reusable Godot 4 addon for resource stats (HP/MP/stamina), flat stats with
flat+percent modifier stacks, and timed buffs/debuffs.

- **Standalone.** Zero hard dependency on other addons.
- **SOLID.** Strategy-based formula, abstract base block, ISP read view.
- **Save/load ready.** Resource currents are persisted; modifiers are
  re-pushed by their owners (equipment, buffs) on load.
- **Optional inventory integration.** When `inventory_system` is enabled,
  two effects (`ResourceEffect`, `ApplyModifierEffect`) and an `EquipmentItem`
  hook (`stat_modifiers` array) become available.

## Quick start

1. Enable the plugin in **Project Settings → Plugins**.
2. Author a `StatDefinition` `.tres` for each stat your game needs (see
   `examples/stats/` for `health`, `mana`, `stamina`, `attack`, `defense`).
3. Author a `StatBlock` `.tres` referencing those definitions.
4. Add a `StatComponent` Node to your player/NPC scene and assign the block.
5. Read values via `stat_component.get_value("attack")` and adjust resources
   via `stat_component.modify_resource("health", -10)`.

## Concepts

### Stats come in two flavors

- **Resource stats** (`is_resource = true`): HP, MP, stamina. Track
  `current` separately from computed `max`. Support per-second regen and
  fire `resource_depleted` / `resource_filled` signals.
- **Flat stats** (`is_resource = false`): attack, defense, crit_chance.
  A single value computed from `base + modifiers`.

### Modifier formula

Default formula (`AdditivePercentFormula`):

```
final = (base + sum_flat) × (1 + sum_percent / 100)
```

Result is clamped to `[min_value, max_value]` (treating `max_value == 0`
as unbounded). Replace by assigning a different `StatFormula` subclass
to `StatBlock.formula`.

### Modifiers carry a source

Every `StatModifier` has a `source_id` (e.g. `"iron_helmet"`,
`"haste_buff"`). `remove_modifiers_by_source(source_id)` removes every
modifier from that source in one call — that's how equip/unequip works
without leaks.

### Timed buffs

Set `StatModifier.duration > 0` to make a modifier expire after that many
seconds. The `StatComponent`'s `_process` ticks the countdown and removes
expired modifiers with reason `EXPIRED`. Permanent modifiers use
`duration = -1`.

## Public API

`StatComponent` exposes the entire contract consumers should depend on:

| Method | Purpose |
|---|---|
| `get_value(id)` | Final computed value (flat or resource max) |
| `get_max(id)` | Same as get_value; reads better for resource stats |
| `get_current(id)` | Persisted current for resource stats; equal to get_value for flat stats |
| `modify_resource(id, delta)` | Adjust a resource's current; clamps to `[0, max]` |
| `set_current(id, value)` | Direct set; clamps |
| `add_modifier(m)` | Add a modifier; recomputes and emits signals |
| `remove_modifier(m)` | Remove specific instance |
| `remove_modifiers_by_source(source_id)` | Remove all modifiers from one source |
| `get_active_modifiers()` | Read-only snapshot |
| `get_reader()` | Narrow read-only `StatReader` for UI consumers |
| `serialize()` / `deserialize(data)` | Save/load |

Signals: `stat_changed(id, old, new)`, `resource_depleted(id)`,
`resource_filled(id)`, `modifier_added(m)`, `modifier_removed(m, reason)`.

## Inventory integration (optional)

If `inventory_system` is enabled, two effects ship in `effects/`:

- **`ResourceEffect`** — replaces `HealEffect` and `ManaEffect`. Authoring:
  `target_stat = "health"`, `delta = +50`. Use as a child of a
  `ConsumableItem.effects` array.
- **`ApplyModifierEffect`** — pushes a (typically timed) modifier onto the
  user's `StatComponent`. Powers buff potions.

`EquipmentItem` gains a `stat_modifiers: Array[StatModifier]` field. Set
the `source_id` of each modifier to the item's id (e.g. `"iron_helmet"`).
When the item is equipped, `EquipmentComponent` (with its
`stat_component` export wired) auto-pushes those modifiers; on unequip,
it auto-removes them by source.

## Tests

Run the headless test suite from the repo root:

```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Exit code is non-zero on failure. The runner discovers any
`addons/stat_system/tests/test_*.gd` script automatically.
```

- [ ] **Step 2: Commit**

```bash
git add addons/stat_system/README.md
git commit -m "docs(stat-system): write addon README"
```

---

### Task 17: Migrate EquipmentItem

**Files:**
- Modify: `addons/inventory_system/core/equipment_item.gd`

Remove the legacy `defense`/`damage`/`stats` fields. Add `stat_modifiers: Array[StatModifier]` and `get_stat_modifiers()`. Update `get_tooltip_text` to render the new modifiers.

- [ ] **Step 1: Replace `addons/inventory_system/core/equipment_item.gd`**

```gdscript
@tool
extends InventoryItem
class_name EquipmentItem
## Equipment item that can be equipped to a slot.
## Stat bonuses are expressed as StatModifier resources, applied via
## EquipmentComponent's optional StatComponent injection.

## The name of the slot this item can equip to (e.g. "Head", "MainHand", "Chest").
@export var slot_type_name: String = ""

## Stat modifiers contributed by this item while equipped. Each modifier's
## source_id should be set to this item's id so unequip removes them cleanly.
@export var stat_modifiers: Array[StatModifier] = []

## Maximum durability for this equipment. 0 = no durability tracking.
@export_range(0, 1000, 1) var max_durability: int = 0

func is_equippable() -> bool:
	return slot_type_name != ""

## Returns the stat modifiers this item contributes. Implements the
## StatModifierProvider duck-typed contract used by EquipmentComponent.
func get_stat_modifiers() -> Array[StatModifier]:
	return stat_modifiers

func get_tooltip_text() -> String:
	var text := super.get_tooltip_text()
	text += _format_section_header(slot_type_name if slot_type_name else "Equipment", "yellow")

	for m in stat_modifiers:
		if m == null:
			continue
		var sign := "+" if m.value >= 0.0 else ""
		var unit := "%" if m.op == StatModifier.Op.PERCENT else ""
		var stat_label := String(m.stat_id).capitalize()
		text += "\n[color=lightblue]%s%g%s %s[/color]" % [sign, m.value, unit, stat_label]

	return text
```

- [ ] **Step 2: Sanity-load**

Run:
```bash
godot --headless --quit
```
Expected: no script errors. (The existing equipment `.tres` files will warn that `defense`/`damage`/`stats` are unknown properties — that's fine, Task 19 cleans them up.)

- [ ] **Step 3: Commit**

```bash
git add addons/inventory_system/core/equipment_item.gd
git commit -m "refactor(inventory): EquipmentItem uses stat_modifiers instead of defense/damage/stats"
```

---

### Task 18: Migrate EquipmentComponent

**Files:**
- Modify: `addons/inventory_system/core/equipment_component.gd`
- Modify: `addons/inventory_system/inventory_plugin.gd` (remove HealEffect/ManaEffect from registration)

Add the `@export var stat_component`. Push modifiers in `equip()`, remove by source in `unequip()`. Delete `get_total_stat()` and `get_all_stats()` — those methods are obsolete now that consumers query `stat_component.get_value(...)` directly.

- [ ] **Step 1: Replace `addons/inventory_system/core/equipment_component.gd`**

```gdscript
@tool
extends Node
class_name EquipmentComponent

signal equipment_changed(slot_name: String, item: Resource)
signal stats_changed()

# Dictionary mapping slot names to EquipmentItem
@export var equipment_slots: Dictionary = {}

# Define available slot names
@export var defined_slots: Array[String] = []

## Optional: when set, equipped items push their stat modifiers onto this
## StatComponent and unequipping removes them by source. Requires the
## stat_system addon to be enabled.
@export var stat_component: StatComponent


func _ready():
	for slot_name in defined_slots:
		if not equipment_slots.has(slot_name):
			equipment_slots[slot_name] = null


func equip(item: Resource, slot_name: String) -> bool:
	if not item:
		return unequip(slot_name)

	if not equipment_slots.has(slot_name):
		push_warning("EquipmentComponent: Slot '%s' does not exist. Defined slots: %s" % [slot_name, defined_slots])
		return false

	if item.slot_type_name != slot_name:
		return false

	# If something is already in this slot, unequip it first so its
	# modifiers are removed before the new ones are added.
	var existing = equipment_slots[slot_name]
	if existing != null:
		_remove_stat_modifiers_for(existing)

	equipment_slots[slot_name] = item
	_apply_stat_modifiers_for(item)
	equipment_changed.emit(slot_name, item)
	stats_changed.emit()
	return true


func unequip(slot_name: String) -> bool:
	if not equipment_slots.has(slot_name):
		push_warning("EquipmentComponent: Cannot unequip — slot '%s' does not exist" % slot_name)
		return false
	var existing = equipment_slots[slot_name]
	if existing != null:
		_remove_stat_modifiers_for(existing)
	equipment_slots[slot_name] = null
	equipment_changed.emit(slot_name, null)
	stats_changed.emit()
	return true


func get_item_in_slot(slot_name: String) -> Resource:
	return equipment_slots.get(slot_name, null)


## Push an item's stat modifiers onto the connected StatComponent.
## No-op if stat_component is null or the item doesn't implement the
## StatModifierProvider contract.
func _apply_stat_modifiers_for(item: Resource) -> void:
	if stat_component == null or item == null:
		return
	if not item.has_method("get_stat_modifiers"):
		return
	var mods: Array = item.get_stat_modifiers()
	for m in mods:
		if m == null:
			continue
		# Force the source_id to the item's id so removal-by-source works
		# even if the author forgot to set it on each modifier.
		var mod_copy: StatModifier = m.duplicate()
		mod_copy.source_id = StringName(item.id)
		stat_component.add_modifier(mod_copy)


func _remove_stat_modifiers_for(item: Resource) -> void:
	if stat_component == null or item == null:
		return
	stat_component.remove_modifiers_by_source(StringName(item.id))


## Serialize equipment state for save/load.
func serialize() -> Dictionary:
	var data := {}
	for slot_name in equipment_slots:
		var item = equipment_slots[slot_name]
		if item and item is EquipmentItem:
			data[slot_name] = {"id": item.id}
		else:
			data[slot_name] = null
	return data


## Deserialize equipment from saved data.
func deserialize(data: Dictionary) -> void:
	var item_db: Node = null
	var tree := Engine.get_main_loop()
	if tree and tree is SceneTree:
		item_db = tree.root.get_node_or_null("/root/ItemDatabase")
	for slot_name in data:
		var entry = data[slot_name]
		if entry == null:
			equipment_slots[slot_name] = null
		else:
			var item_id: String = entry.get("id", "")
			var item = item_db.get_item(item_id) if item_db else null
			if item:
				equipment_slots[slot_name] = item
				_apply_stat_modifiers_for(item)
			else:
				push_warning("EquipmentComponent.deserialize: item '%s' not found" % item_id)
				equipment_slots[slot_name] = null
	stats_changed.emit()
```

- [ ] **Step 2: Sanity-load**

Run:
```bash
godot --headless --quit
```
Expected: no script errors.

- [ ] **Step 3: Commit**

```bash
git add addons/inventory_system/core/equipment_component.gd
git commit -m "refactor(inventory): EquipmentComponent pushes stat modifiers via optional StatComponent"
```

---

### Task 19: Delete HealEffect/ManaEffect and unregister them

**Files:**
- Delete: `addons/inventory_system/core/heal_effect.gd`
- Delete: `addons/inventory_system/core/heal_effect.gd.uid`
- Delete: `addons/inventory_system/core/mana_effect.gd`
- Delete: `addons/inventory_system/core/mana_effect.gd.uid`
- Modify: `addons/inventory_system/inventory_plugin.gd`

The two old effects are replaced by the generic `ResourceEffect` from `stat_system`. The `.tres` files that referenced them are migrated in Task 20.

- [ ] **Step 1: Delete the old effect files**

Run:
```bash
rm "addons/inventory_system/core/heal_effect.gd"
rm "addons/inventory_system/core/heal_effect.gd.uid"
rm "addons/inventory_system/core/mana_effect.gd"
rm "addons/inventory_system/core/mana_effect.gd.uid"
```

- [ ] **Step 2: Remove the registrations from `addons/inventory_system/inventory_plugin.gd`**

Find and delete these two lines from `_enter_tree()`:
```gdscript
	add_custom_type("HealEffect", "Resource", preload("core/heal_effect.gd"), preload("icons/item.svg"))
	add_custom_type("ManaEffect", "Resource", preload("core/mana_effect.gd"), preload("icons/item.svg"))
```

…and these two from `_exit_tree()`:
```gdscript
	remove_custom_type("HealEffect")
	remove_custom_type("ManaEffect")
```

Also remove the `# Item Effects` comment if it's now empty in either function.

- [ ] **Step 3: Sanity-load**

Run:
```bash
godot --headless --quit
```
Expected: no script errors. (The `health_potion.tres` and `mana_potion.tres` files will fail to load their `HealEffect`/`ManaEffect` ext_resources — but the failure is silent at load time. Task 20 fixes them.)

- [ ] **Step 4: Commit**

```bash
git add -u addons/inventory_system/
git commit -m "refactor(inventory): delete HealEffect and ManaEffect, replaced by ResourceEffect"
```

---

### Task 20: Migrate items/*.tres to the new schema

**Files:**
- Modify: `items/iron_chestplate.tres`
- Modify: `items/iron_helmet.tres`
- Modify: `items/leather_boots.tres`
- Modify: `items/steel_sword.tres`
- Modify: `items/health_potion.tres`
- Modify: `items/mana_potion.tres`

Each file gets rewritten to the new schema. The old `defense`/`damage` properties on equipment become `stat_modifiers` sub-resources; the old `HealEffect`/`ManaEffect` sub-resources become `ResourceEffect`.

- [ ] **Step 1: Rewrite `items/iron_chestplate.tres`**

```
[gd_resource type="Resource" script_class="EquipmentItem" load_steps=4 format=3 uid="uid://dm0mqa8f3bvub"]

[ext_resource type="Script" uid="uid://cpwwgvl4f10kw" path="res://addons/inventory_system/core/equipment_item.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://d12ek0twpj7ag" path="res://items/icons/iron_chestplate.svg" id="2_icon"]
[ext_resource type="Script" path="res://addons/stat_system/core/stat_modifier.gd" id="3_mod"]

[sub_resource type="Resource" id="defense_mod"]
script = ExtResource("3_mod")
stat_id = &"defense"
op = 0
value = 12.0
source_id = &"iron_chestplate"

[resource]
script = ExtResource("1_script")
slot_type_name = "Chest"
stat_modifiers = [SubResource("defense_mod")]
name = "Iron Chestplate"
description = "Heavy iron armor for your torso."
icon = ExtResource("2_icon")
weight = 8.0
value = 200
id = "iron_chestplate"
```

- [ ] **Step 2: Rewrite `items/iron_helmet.tres`**

```
[gd_resource type="Resource" script_class="EquipmentItem" load_steps=4 format=3 uid="uid://vue4pfrskai"]

[ext_resource type="Script" uid="uid://cpwwgvl4f10kw" path="res://addons/inventory_system/core/equipment_item.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://dktu3rey65gkg" path="res://items/icons/iron_helmet.svg" id="2_icon"]
[ext_resource type="Script" path="res://addons/stat_system/core/stat_modifier.gd" id="3_mod"]

[sub_resource type="Resource" id="defense_mod"]
script = ExtResource("3_mod")
stat_id = &"defense"
op = 0
value = 5.0
source_id = &"iron_helmet"

[resource]
script = ExtResource("1_script")
slot_type_name = "Head"
stat_modifiers = [SubResource("defense_mod")]
name = "Iron Helmet"
description = "A sturdy iron helmet that provides basic protection."
icon = ExtResource("2_icon")
weight = 3.0
value = 100
id = "iron_helmet"
```

- [ ] **Step 3: Rewrite `items/leather_boots.tres`**

```
[gd_resource type="Resource" script_class="EquipmentItem" load_steps=4 format=3 uid="uid://dg8te2xa3a2i"]

[ext_resource type="Script" uid="uid://cpwwgvl4f10kw" path="res://addons/inventory_system/core/equipment_item.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://xbljpmhr4j5w" path="res://items/icons/leather_boots.svg" id="2_icon"]
[ext_resource type="Script" path="res://addons/stat_system/core/stat_modifier.gd" id="3_mod"]

[sub_resource type="Resource" id="defense_mod"]
script = ExtResource("3_mod")
stat_id = &"defense"
op = 0
value = 2.0
source_id = &"leather_boots"

[resource]
script = ExtResource("1_script")
slot_type_name = "Feet"
stat_modifiers = [SubResource("defense_mod")]
name = "Leather Boots"
description = "Light leather boots for quick movement."
icon = ExtResource("2_icon")
weight = 1.5
value = 50
id = "leather_boots"
```

- [ ] **Step 4: Rewrite `items/steel_sword.tres`**

```
[gd_resource type="Resource" script_class="EquipmentItem" load_steps=4 format=3 uid="uid://lx4nqji3xkmh"]

[ext_resource type="Script" uid="uid://cpwwgvl4f10kw" path="res://addons/inventory_system/core/equipment_item.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://cjmvqn3lj6lyk" path="res://items/icons/steel_sword.svg" id="2_icon"]
[ext_resource type="Script" path="res://addons/stat_system/core/stat_modifier.gd" id="3_mod"]

[sub_resource type="Resource" id="attack_mod"]
script = ExtResource("3_mod")
stat_id = &"attack"
op = 0
value = 15.0
source_id = &"steel_sword"

[resource]
script = ExtResource("1_script")
slot_type_name = "MainHand"
stat_modifiers = [SubResource("attack_mod")]
name = "Steel Sword"
description = "A well-crafted steel sword."
icon = ExtResource("2_icon")
weight = 4.0
value = 150
id = "steel_sword"
```

- [ ] **Step 5: Rewrite `items/health_potion.tres`**

```
[gd_resource type="Resource" script_class="ConsumableItem" load_steps=4 format=3 uid="uid://br2km4c8qqcbc"]

[ext_resource type="Script" path="res://addons/inventory_system/core/consumable_item.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://d3amswjnbi248" path="res://items/icons/health_potion.svg" id="2_icon"]
[ext_resource type="Script" path="res://addons/stat_system/effects/resource_effect.gd" id="3_resource_effect"]

[sub_resource type="Resource" id="heal_effect"]
script = ExtResource("3_resource_effect")
effect_name = "Heal"
target_stat = &"health"
delta = 50.0

[resource]
script = ExtResource("1_script")
effects = [SubResource("heal_effect")]
name = "Health Potion"
description = "Restores 50 health points."
icon = ExtResource("2_icon")
max_stack = 10
weight = 0.5
value = 25
id = "health_potion"
```

- [ ] **Step 6: Rewrite `items/mana_potion.tres`**

```
[gd_resource type="Resource" script_class="ConsumableItem" load_steps=4 format=3 uid="uid://b23g6itd0d51a"]

[ext_resource type="Script" path="res://addons/inventory_system/core/consumable_item.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://crx7oas5jxo1c" path="res://items/icons/mana_potion.svg" id="2_icon"]
[ext_resource type="Script" path="res://addons/stat_system/effects/resource_effect.gd" id="3_resource_effect"]

[sub_resource type="Resource" id="mana_effect"]
script = ExtResource("3_resource_effect")
effect_name = "Restore Mana"
target_stat = &"mana"
delta = 30.0

[resource]
script = ExtResource("1_script")
effects = [SubResource("mana_effect")]
name = "Mana Potion"
description = "Restores 30 mana points."
icon = ExtResource("2_icon")
max_stack = 10
weight = 0.5
value = 30
id = "mana_potion"
```

- [ ] **Step 7: Sanity-load and run tests**

Run:
```bash
godot --headless --quit
```
Expected: no script errors related to `items/*.tres`.

```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 52 passed, 0 failed ===`.

- [ ] **Step 8: Commit**

```bash
git add items/iron_chestplate.tres items/iron_helmet.tres items/leather_boots.tres items/steel_sword.tres items/health_potion.tres items/mana_potion.tres
git commit -m "refactor(items): migrate equipment to stat_modifiers and potions to ResourceEffect"
```

---

### Task 21: Update inventory_system README + project README

**Files:**
- Modify: `addons/inventory_system/README.md`
- Modify: `README.md` (project root)

Document the optional integration in the inventory addon's README, and move "Stat System" from "Planned" to "Available" in the project README.

- [ ] **Step 1: Append an "Optional integrations" section to `addons/inventory_system/README.md`**

Read the current file first to find a good insertion point. Append at the end (or after the existing usage docs) the following section:

```markdown

## Optional integrations

### Stat System (`addons/stat_system/`)

When the `stat_system` addon is enabled, the inventory system gains:

- **`stat_component` field on `EquipmentComponent`** — when set, equipped
  items push their `stat_modifiers` onto the StatComponent and unequipping
  removes them by source.
- **`stat_modifiers: Array[StatModifier]`** on `EquipmentItem` — express
  equipment bonuses as modifiers instead of hardcoded `defense`/`damage`
  fields.
- **`ResourceEffect`** — replaces the old `HealEffect` / `ManaEffect`. Use
  in `ConsumableItem.effects` arrays to heal/damage/restore any resource
  stat by name.
- **`ApplyModifierEffect`** — pushes a (typically timed) modifier onto the
  user's StatComponent. Powers buff potions like "+5 attack for 60s".

The inventory addon does not require the stat addon. If `stat_system` is
not enabled, leave `EquipmentComponent.stat_component` null and equipment
behaves like a pure container.
```

- [ ] **Step 2: Update the project root `README.md`**

In the "Available Addons" table, add a new row for Stat System:

Before:
```markdown
| [Player Control 3rd Person](addons/player_control_3rd_person/) | Third-person orbit camera with collision | ✅ Complete |
```

After:
```markdown
| [Player Control 3rd Person](addons/player_control_3rd_person/) | Third-person orbit camera with collision | ✅ Complete |
| [Stat System](addons/stat_system/) | Resource stats (HP/MP/stamina), flat stats with flat+percent modifiers, timed buffs | ✅ Complete |
```

In the "Planned Addons" section, **delete** the line:
```markdown
- **Stat System** — RPG stats with modifiers and buffs
```

In the "Addon Dependencies" diagram, append a line showing the optional
inventory→stat dependency:

Before:
```
inventory_system (standalone)
```

After:
```
inventory_system ── (optional) ──▶ stat_system
```

- [ ] **Step 3: Commit**

```bash
git add addons/inventory_system/README.md README.md
git commit -m "docs: announce stat_system addon in project and inventory READMEs"
```

---

### Task 22: Final verification

**Files:** none — verification only.

- [ ] **Step 1: Run the full test suite**

```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```
Expected: `=== 52 passed, 0 failed ===`. Exit code 0.

- [ ] **Step 2: Open the project in the editor (optional, for visual confirmation)**

If you have an editor available, open `project.godot`. Verify:
- The Plugins tab lists `Stat System` as enabled.
- Right-clicking in the FileSystem dock and choosing "New Resource…" shows
  `StatDefinition`, `StatModifier`, `StatBlock`, etc. in the search.
- The migrated `items/*.tres` files load without import errors.

- [ ] **Step 3: Tag the work as feature-complete**

```bash
git log --oneline | head -25
```
Verify that the recent commits form a clean sequence from the bootstrap
through to the README update. There should be no `WIP` or `fixup!`
commits.

- [ ] **Step 4: Done.** Hand the branch off to the user for merge or PR.

---

## Out of scope (intentional)

Per the spec's "Non-Goals" section, the following are deliberately NOT in this plan and should be deferred to a future plan:

- Primary → derived stat formulas (STR → HP). Add as a `DerivedStatFormula` resource later.
- Multi-tier multiplicative stacking. Add as a `MultiplicativeTierFormula` resource later.
- Built-in UI bars / buff list widgets. Project-side concern; the `StatReader` exists to support them.
- A new manual test scene with a player + equipment + buff potions wired into the stat system. The existing test scenes already cover the inventory side; adding a stat-specific test scene is a valuable follow-up but not required for the addon to be complete.




