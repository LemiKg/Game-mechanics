# Stat System UI Widgets Design

**Date:** 2026-04-07
**Status:** Approved for implementation planning
**Builds on:** `docs/superpowers/specs/2026-04-07-stat-system-design.md`
**Addon:** `addons/stat_system/` (UI subdirectory)

## Goal

Add reusable UI widgets to the stat_system addon so consumers can build a working game HUD without writing custom UI code:

- **`StatBarUI`** — a one-stat resource bar (HP/MP/stamina) with optional overlay text
- **`BuffBarUI`** — a horizontal row of icons + countdown for active timed modifiers
- **Test scene** — `stat_system_test_scene.tscn` wiring HP/MP/stamina + buff display to a player with bound keys for damage/heal/buff actions

The widgets close the gap left in the v1 spec, which deliberately deferred UI to "project-side concerns" but built `StatReader` specifically to support them.

## Non-Goals

- **Stat sheet panel** (Control listing all stats and their flat values for a character menu) — useful, but a separate widget for a separate use case. Deferred.
- **Damage numbers / floating text** — combat layer concern, not stat layer.
- **Scrolling buff overflow** — the parent container's responsibility, not the widget's.
- **Animation / tween on bar fill** — bars snap to value. Could be added later via a `transition_speed` export.
- **Colored fill via `StyleBoxFlat`** — modulate is the v1 approach. Theme-respectful and one-line. Future enhancement can swap.
- **Editor preview (`@tool`)** — widgets are runtime-only. Authoring works fine without editor preview.

## Architecture

### Layer placement

```
┌──────────────────────────────────────────────┐
│ UI Layer (NEW)                               │
│   StatBarUI    — binds to one stat by id     │
│   BuffBarUI    — shows all active modifiers  │
├──────────────────────────────────────────────┤
│ View Layer                                   │
│   StatReader   — narrow read interface       │
├──────────────────────────────────────────────┤
│ Runtime layer    StatComponent               │
│ Data layer       StatBlock + friends         │
└──────────────────────────────────────────────┘
```

Both widgets receive a `StatComponent` via `@export` (the only injectable thing — `StatReader` is `RefCounted` so it can't be exported), call `get_reader()` internally, and depend on the reader's narrow surface. No widget calls `add_modifier`/`modify_resource`/`set_current` — they're read-only by design, matching `StatReader`'s ISP intent.

### File layout

```
addons/stat_system/ui/
├── stat_bar_ui.gd
├── stat_bar_ui.tscn
├── buff_bar_ui.gd
└── buff_bar_ui.tscn

scenes/
├── stat_system_test_scene.tscn
└── stat_system_test_player.gd
```

`addons/stat_system/ui/` is created in this work; the addon previously had no `ui/` directory.

### `StatReader` extension

`StatReader` currently forwards `stat_changed`, `resource_depleted`, and `resource_filled`. The buff widget needs `modifier_added` and `modifier_removed` too. The reader is extended with two new signals + two forwarders. This is a small surgical change to `addons/stat_system/core/stat_reader.gd`. The ISP boundary is preserved — the reader is still read-only.

The alternative — having `BuffBarUI` connect directly to `StatComponent`'s modifier signals while connecting to `StatReader` for everything else — would split the dependency awkwardly across two layers. Extending the reader is cleaner.

## StatBarUI

A `Control` that displays one resource stat as a filled bar with overlay text.

### Authoring contract

```gdscript
class_name StatBarUI extends Control

@export var stat_component: StatComponent     # required, runtime injection
@export var stat_id: StringName = &"health"   # which stat this bar binds to
@export var show_label: bool = true           # toggle "75 / 100" overlay
@export var label_format: String = "%d / %d"  # printf-style for label text
```

### Scene structure (`stat_bar_ui.tscn`)

```
StatBarUI (Control, script: stat_bar_ui.gd)
├── ProgressBar (anchor: full rect)
│   - min_value 0, max_value 1
│   - show_percentage off
└── Label (anchor: center)
    - horizontal_alignment center
    - vertical_alignment center
```

Built-in `ProgressBar` is used (not `TextureProgressBar`) so the widget picks up `ThemeManager` styles automatically. Authors who want a textured fill can replace the `ProgressBar` child node in their own scene without touching the script — the script only references its children by `@onready` path.

The Label is a **sibling** of the ProgressBar, not a child. This is intentional: `modulate` applied to the ProgressBar (for stat color) does not bleed onto the Label.

### Behavior

```gdscript
@onready var _bar: ProgressBar = $ProgressBar
@onready var _label: Label = $Label

var _reader: StatReader

func _ready() -> void:
    _label.visible = show_label
    _bind()

func set_stat_component(c: StatComponent) -> void:
    stat_component = c
    if is_inside_tree():
        _bind()

func _bind() -> void:
    if not stat_component:
        return
    _reader = stat_component.get_reader()
    _reader.stat_changed.connect(_on_stat_changed)
    _apply_color()
    _refresh()

func _apply_color() -> void:
    # Read color from StatDefinition once at bind time. Tints the bar via
    # modulate, leaving the Label sibling unaffected.
    var def := _find_definition()
    if def and def.is_resource:
        _bar.modulate = def.color

func _on_stat_changed(id: StringName, _old: float, _new: float) -> void:
    if id == stat_id:
        _refresh()

func _refresh() -> void:
    if not _reader:
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

`_find_definition` looks up the `StatDefinition` resource on the bound `StatBlock` to read its color and to validate that the bound `stat_id` is a resource stat. If the stat is a flat stat, the widget pushes a one-time warning during `_bind` and renders an empty bar.

### Edge cases the tests will cover

| Case | Behavior |
|---|---|
| `stat_component == null` at `_ready` | Widget renders empty (bar=0); no error |
| `stat_id` is unknown | `get_max` returns 0, fill stays at 0, warning is pushed by StatBlock |
| `set_stat_component(c)` swap at runtime | Disconnects from old reader, binds to new |
| Resource depletes to 0 | `stat_changed` fires, bar updates to 0 |
| Modifier changes max (e.g. +50 HP buff) | `stat_changed` fires, bar refreshes; current/max ratio updates |
| `max_v <= 0` (misconfigured stat) | Bar reads 0 instead of dividing by zero |
| `stat_id` is a flat stat | Widget pushes a one-time warning, renders empty bar |
| `label_format` has wrong number of `%d` | Godot's printf raises a script error — author's responsibility |

## BuffBarUI

A `Control` that displays the active **timed** modifiers as a horizontal row of icon + countdown. Permanent modifiers (`duration < 0`) are intentionally excluded — equipment bonuses don't belong in a buff bar.

### Authoring contract

```gdscript
class_name BuffBarUI extends Control

@export var stat_component: StatComponent     # required, runtime injection
@export var icon_size: int = 32                # square slot size
@export var spacing: int = 4
@export var show_countdown_label: bool = true  # toggle "5s" text overlay
```

### Scene structure (`buff_bar_ui.tscn`)

```
BuffBarUI (Control, script: buff_bar_ui.gd)
└── HBoxContainer (anchor: full rect)
    - alignment: ALIGNMENT_BEGIN
```

Each active timed modifier produces one transient child node — a small `PanelContainer` containing a `TextureRect` (icon) and a `Label` (remaining seconds). These children are created/destroyed as modifiers are added/removed; not pooled (count is small, churn is rare).

### Behavior

```gdscript
@onready var _row: HBoxContainer = $HBoxContainer

var _reader: StatReader
var _slots: Dictionary = {}            # StatModifier -> child PanelContainer
var _running: Array[StatModifier] = [] # mirrors _slots keys for tick

func _ready() -> void:
    _row.add_theme_constant_override("separation", spacing)
    _bind()

func set_stat_component(c: StatComponent) -> void:
    stat_component = c
    if is_inside_tree():
        _bind()

func _bind() -> void:
    if not stat_component:
        return
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
    var node: Node = _slots.get(m)
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

### Why `_process` for countdown labels?

Countdown labels need to update every frame (or close to it). The alternative — emitting a `modifier_remaining_changed` signal from `StatBlock` every tick for every timed modifier — would multiply signal traffic by N modifiers per frame. Reading `m.remaining` directly in `_process` is O(timed buffs) per frame and bypasses the signal system entirely. The widget tolerates that the read is "this frame's value, not necessarily the latest" because it's only used for display.

### Edge cases

| Case | Behavior |
|---|---|
| `stat_component == null` | Empty row, no error |
| Modifier added without an icon | Slot still appears; TextureRect shows nothing |
| Buff expires mid-frame | `modifier_removed` fires with `EXPIRED`, slot disappears |
| Item unequipped | `modifier_removed` fires with `SOURCE_REMOVED`; slot was never added (filtered), `_slots.get(m)` is null, no-op |
| Many modifiers (50+) | HBoxContainer overflows the parent; widget does NOT scroll/wrap |
| `set_stat_component` swap | Disconnects old, rebinds new, full refresh |

### Permanent modifiers excluded

Equipment bonuses (`duration = -1`) are filtered at every entry point. The buff bar is for buffs/debuffs, not equipped items. If a future feature needs an "equipped passives" display, that's `StatSheetUI` — not in scope here.

## Test scene

### `scenes/stat_system_test_scene.tscn`

A standalone manual test scene. Not wired into any other test scene — opens cleanly on its own from the editor and `--quit`s gracefully when run headless.

```
StatSystemTestScene (Node3D)
├── DirectionalLight3D
├── Camera3D                    # static, framing the player
├── WorldEnvironment            # neutral grey sky
├── Floor (CSGBox3D, 20x1x20)
├── TestPlayer (Node3D, script: stat_system_test_player.gd)
│   ├── Mesh (CSGCylinder3D)
│   └── StatComponent (Node)
│       - stat_block: SubResource StatBlock referencing
│         addons/stat_system/examples/stats/{health,mana,stamina,attack,defense}.tres
└── HUD (CanvasLayer)
    ├── BarStack (VBoxContainer, anchored top-left)
    │   ├── HealthBar  (StatBarUI instance, stat_id="health")
    │   ├── ManaBar    (StatBarUI instance, stat_id="mana")
    │   └── StaminaBar (StatBarUI instance, stat_id="stamina")
    └── BuffBar (BuffBarUI instance, anchored top-right)
```

The `StatBlock` is an inline `SubResource` rather than a separate `.tres` file — keeps the test scene self-contained.

### `scenes/stat_system_test_player.gd`

A minimal `Node3D` script with bound keys:

| Key | Action |
|---|---|
| `1` | `modify_resource("health", -10)` (damage) |
| `2` | `modify_resource("mana", -15)` (spend) |
| `3` | `modify_resource("stamina", -25)` (sprint cost) |
| `4` | Apply a 5-second `+5 attack` buff via `add_modifier` |
| `5` | Apply a 10-second `-3 defense` debuff via `add_modifier` |
| `R` | Reset all resources to full via `set_current` |

Bindings use `Input.is_key_pressed(KEY_1)` etc. via `_input(event)` — no project input map setup required.

## Tests

The widgets get unit tests in the existing headless runner:

- **`test_stat_bar_ui.gd`** — instantiates `StatBarUI` outside SceneTree, sets a stub `StatComponent`, calls `_bind()` directly (since `_ready` won't fire without a tree), and asserts `_bar.value` and `_label.text` after each operation.
  - empty stat_component
  - basic bind to a resource stat
  - value reflects current/max
  - label format applied correctly
  - refresh after `modify_resource`
  - refresh after a modifier-induced max change
  - flat-stat warning + empty render

- **`test_buff_bar_ui.gd`** — instantiates `BuffBarUI`, calls `_bind()`, exercises `_on_modifier_added` / `_on_modifier_removed` directly. Asserts `_slots.size()` and that permanent modifiers are filtered.
  - empty stat_component
  - timed modifier added → slot count goes to 1
  - timed modifier removed → slot count goes to 0
  - permanent modifier filtered (slot count stays 0)
  - two timed modifiers → slot count goes to 2

- **`test_stat_reader_modifier_signals.gd`** — covers the `StatReader` extension: forwarding `modifier_added` and `modifier_removed` from the underlying block.
  - reader emits `modifier_added` when block emits
  - reader emits `modifier_removed` with reason payload preserved

**Total new tests: ~14.** Running total after this work: **60 + 14 = 74 tests**.

The test scene itself is a **manual smoke test**, not part of the automated suite. Headless test runners can't meaningfully verify "the bar visually fills correctly" — that's a human-eye task.

## Plugin registration

`addons/stat_system/stat_system_plugin.gd` is updated to register two new custom types in `_enter_tree`:

```gdscript
add_custom_type("StatBarUI", "Control", preload("ui/stat_bar_ui.gd"), null)
add_custom_type("BuffBarUI", "Control", preload("ui/buff_bar_ui.gd"), null)
```

…and the matching `remove_custom_type` calls in `_exit_tree`. These are core registrations (not gated by inventory), since they only depend on stat_system's own classes.

## File summary

| File | Type | New/Mod |
|---|---|---|
| `addons/stat_system/core/stat_reader.gd` | GDScript | Modified — adds 2 signals + 2 forwarders |
| `addons/stat_system/ui/stat_bar_ui.gd` | GDScript | New |
| `addons/stat_system/ui/stat_bar_ui.tscn` | Scene | New |
| `addons/stat_system/ui/buff_bar_ui.gd` | GDScript | New |
| `addons/stat_system/ui/buff_bar_ui.tscn` | Scene | New |
| `addons/stat_system/stat_system_plugin.gd` | GDScript | Modified — register `StatBarUI` and `BuffBarUI` |
| `addons/stat_system/tests/test_stat_bar_ui.gd` | GDScript | New |
| `addons/stat_system/tests/test_buff_bar_ui.gd` | GDScript | New |
| `addons/stat_system/tests/test_stat_reader_modifier_signals.gd` | GDScript | New |
| `scenes/stat_system_test_scene.tscn` | Scene | New |
| `scenes/stat_system_test_player.gd` | GDScript | New |
| `addons/stat_system/README.md` | Markdown | Modified — document new widgets |

12 files: 9 new, 3 modified.

## SOLID compliance

| Principle | How this design honors it |
|---|---|
| **SRP** | `StatBarUI` displays one stat. `BuffBarUI` displays the timed-modifier list. Test player handles input. Test scene wires them together. None overlap. |
| **OCP** | Both widgets use scene composition: authors swap the `ProgressBar` or `HBoxContainer` child to customize visuals without touching the script. The script only references children by `@onready` path. |
| **LSP** | Both widgets extend `Control` and honor its contract — they can be dropped anywhere a `Control` is expected. |
| **ISP** | Both widgets depend on `StatReader`, not on `StatComponent` or `StatBlock`. The widget surface area visible to the reader is exactly what UI needs (read + signals), nothing more. |
| **DIP** | `stat_component` is `@export`-injected, not looked up by path. `StatReader` is fetched via `get_reader()`, not constructed directly. |

## Migration impact

None. This is purely additive. No existing files in the inventory_system addon, no `items/*.tres` migrations, no test scene rewrites. The only existing file modified outside the addon is `addons/stat_system/README.md` (documentation refresh) and `addons/stat_system/core/stat_reader.gd` (the 2-signal extension).
