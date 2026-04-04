# UI Theme System - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a toggleable UI theme system with three visual themes (Medieval, Dark, Light) cycled via F4, plus a background blur shader for panels.

**Architecture:** ThemeManager node builds Theme resources programmatically at runtime and applies them to the CanvasLayer. A blur shader provides frosted-glass effect behind panels. The stamina bar reads theme colors instead of hardcoded values.

**Tech Stack:** GDScript, Godot 4.5, GLSL (gdshader)

**Spec:** `docs/superpowers/specs/2026-04-04-ui-theme-system-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `addons/inventory_system/ui/themes/theme_manager.gd` | Create | Builds 3 themes, handles cycling, applies to CanvasLayer |
| `addons/inventory_system/ui/shaders/ui_blur.gdshader` | Create | Gaussian blur for panel backgrounds |
| `addons/player_control_core/ui/stamina_bar_ui.gd` | Modify | Read colors from theme instead of hardcoded |
| `scenes/player.tscn` | Modify | Add ThemeManager, wrap HUD labels, add blur behind inventory |
| `project.godot` | Modify | Add F4 input action |

---

### Task 1: Create the Blur Shader

**Files:**
- Create: `addons/inventory_system/ui/shaders/ui_blur.gdshader`

- [ ] **Step 1: Create the blur shader file**

```glsl
shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.1;
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec4 color = vec4(0.0);

	// 9-tap gaussian blur
	float offsets[3] = {0.0, 1.3846153846, 3.2307692308};
	float weights[3] = {0.2270270270, 0.3162162162, 0.0702702703};

	// Horizontal + vertical combined (two-pass approximation in single pass)
	for (int i = 0; i < 3; i++) {
		float w = weights[i];
		float o = offsets[i] * blur_amount;
		color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(o, 0.0) * ps) * w;
		color += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(o, 0.0) * ps) * w;
		color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, o) * ps) * w;
		color += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, o) * ps) * w;
	}
	color /= 4.0; // Normalize (4 directions)

	// Apply tint
	color = mix(color, tint_color, tint_strength);
	color.a = tint_color.a;

	COLOR = color;
}
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/ui/shaders/ui_blur.gdshader
git commit -m "feat: add gaussian blur shader for UI panel backgrounds"
```

---

### Task 2: Create ThemeManager

**Files:**
- Create: `addons/inventory_system/ui/themes/theme_manager.gd`

This is the core file. It builds three Theme resources programmatically and handles cycling.

- [ ] **Step 1: Create the ThemeManager script**

```gdscript
class_name ThemeManager
extends Node
## Manages multiple UI themes and allows cycling between them at runtime.
##
## Add as a child of CanvasLayer. Builds themes programmatically on _ready().
## Press the cycle action (default F4) to switch themes.


signal theme_changed(theme_name: String)


@export_group("Settings")
## Input action to cycle themes.
@export var cycle_action: StringName = &"cycle_theme"

## Names for display.
var theme_names: Array[String] = ["Medieval", "Dark", "Light"]

## Built theme resources.
var _themes: Array[Theme] = []

## Current theme index.
var _current_index: int = 0

## Toast label for showing theme name.
var _toast_label: Label
var _toast_timer: float = 0.0


func _ready() -> void:
	_themes = [
		_build_medieval_theme(),
		_build_dark_theme(),
		_build_light_theme(),
	]
	_create_toast_label()
	# Apply first theme
	_apply_current_theme()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(cycle_action):
		cycle_theme()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _toast_timer > 0:
		_toast_timer -= delta
		if _toast_label:
			_toast_label.modulate.a = clampf(_toast_timer / 0.5, 0.0, 1.0)
			if _toast_timer <= 0:
				_toast_label.visible = false


## Cycle to the next theme.
func cycle_theme() -> void:
	_current_index = (_current_index + 1) % _themes.size()
	_apply_current_theme()
	_show_toast()
	theme_changed.emit(theme_names[_current_index])


## Apply the current theme to the parent CanvasLayer.
func _apply_current_theme() -> void:
	var parent := get_parent()
	if parent is CanvasLayer:
		# Apply to all Control children
		for child in parent.get_children():
			if child is Control:
				child.theme = _themes[_current_index]
	elif parent is Control:
		parent.theme = _themes[_current_index]


func _show_toast() -> void:
	if _toast_label:
		_toast_label.text = "Theme: %s" % theme_names[_current_index]
		_toast_label.visible = true
		_toast_label.modulate.a = 1.0
		_toast_timer = 2.0


func _create_toast_label() -> void:
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.anchors_preset = Control.PRESET_CENTER_TOP
	_toast_label.offset_top = 40.0
	_toast_label.offset_left = -150.0
	_toast_label.offset_right = 150.0
	_toast_label.visible = false
	# Add directly to parent so it's a sibling of other UI
	get_parent().call_deferred("add_child", _toast_label)


# =========================================================================
# THEME BUILDERS
# =========================================================================

func _build_medieval_theme() -> Theme:
	var t := Theme.new()
	var font_color := Color(0.95, 0.9, 0.8)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.6)

	# PanelContainer
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.25, 0.15, 0.1, 0.95)
	panel.border_color = Color(0.7, 0.55, 0.2, 1.0)
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel)

	# Label
	t.set_color("font_color", "Label", font_color)
	t.set_color("font_shadow_color", "Label", shadow_color)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	# ProgressBar
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.12, 0.08, 0.05, 0.8)
	pb_bg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.7, 0.55, 0.2, 1.0)
	pb_fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# HSeparator
	var sep := StyleBoxFlat.new()
	sep.bg_color = Color(0.5, 0.4, 0.2, 0.6)
	sep.set_content_margin_all(0)
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep)

	# VScrollBar
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.15, 0.1, 0.07, 0.5)
	scroll_bg.set_corner_radius_all(3)
	t.set_stylebox("scroll", "VScrollBar", scroll_bg)

	var scroll_grabber := StyleBoxFlat.new()
	scroll_grabber.bg_color = Color(0.5, 0.4, 0.2, 0.7)
	scroll_grabber.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", scroll_grabber)

	var scroll_grabber_hl := StyleBoxFlat.new()
	scroll_grabber_hl.bg_color = Color(0.6, 0.5, 0.25, 0.9)
	scroll_grabber_hl.set_corner_radius_all(3)
	t.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber_hl)

	return t


func _build_dark_theme() -> Theme:
	var t := Theme.new()
	var font_color := Color(0.85, 0.85, 0.9)

	# PanelContainer
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	panel.border_color = Color(0.3, 0.3, 0.4, 0.8)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel)

	# Label
	t.set_color("font_color", "Label", font_color)

	# ProgressBar
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.1, 0.1, 0.15, 0.7)
	pb_bg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.2, 0.6, 0.8, 1.0)
	pb_fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# HSeparator
	var sep := StyleBoxFlat.new()
	sep.bg_color = Color(0.25, 0.25, 0.35, 0.5)
	sep.set_content_margin_all(0)
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep)

	# VScrollBar
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.1, 0.1, 0.15, 0.5)
	scroll_bg.set_corner_radius_all(3)
	t.set_stylebox("scroll", "VScrollBar", scroll_bg)

	var scroll_grabber := StyleBoxFlat.new()
	scroll_grabber.bg_color = Color(0.3, 0.3, 0.4, 0.7)
	scroll_grabber.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", scroll_grabber)

	var scroll_grabber_hl := StyleBoxFlat.new()
	scroll_grabber_hl.bg_color = Color(0.4, 0.4, 0.5, 0.9)
	scroll_grabber_hl.set_corner_radius_all(3)
	t.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber_hl)

	return t


func _build_light_theme() -> Theme:
	var t := Theme.new()
	var font_color := Color(0.15, 0.15, 0.18)

	# PanelContainer
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.95, 0.93, 0.9, 0.92)
	panel.border_color = Color(0.7, 0.68, 0.65, 1.0)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel)

	# Label
	t.set_color("font_color", "Label", font_color)

	# ProgressBar
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.8, 0.78, 0.75, 0.6)
	pb_bg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.3, 0.7, 0.4, 1.0)
	pb_fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# HSeparator
	var sep := StyleBoxFlat.new()
	sep.bg_color = Color(0.7, 0.68, 0.65, 0.4)
	sep.set_content_margin_all(0)
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep)

	# VScrollBar
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.85, 0.83, 0.8, 0.5)
	scroll_bg.set_corner_radius_all(3)
	t.set_stylebox("scroll", "VScrollBar", scroll_bg)

	var scroll_grabber := StyleBoxFlat.new()
	scroll_grabber.bg_color = Color(0.6, 0.58, 0.55, 0.7)
	scroll_grabber.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", scroll_grabber)

	var scroll_grabber_hl := StyleBoxFlat.new()
	scroll_grabber_hl.bg_color = Color(0.5, 0.48, 0.45, 0.9)
	scroll_grabber_hl.set_corner_radius_all(3)
	t.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber_hl)

	return t
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/ui/themes/theme_manager.gd
git commit -m "feat: add ThemeManager with three toggleable UI themes"
```

---

### Task 3: Wrap HUD Labels and Wire ThemeManager in Scene

**Files:**
- Modify: `scenes/player.tscn`
- Modify: `project.godot`

- [ ] **Step 1: Add F4 input action to project.godot**

Read `project.godot`. After the `shoulder_switch` input action block, add:

```
cycle_theme={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194312,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

(keycode 4194312 = F3. Actually use F4 = 4194313)

Correction: F4 keycode is 4194313.

- [ ] **Step 2: Add ThemeManager ext_resource and node to player.tscn**

Read `scenes/player.tscn`. Add an ext_resource for the ThemeManager script:

```
[ext_resource type="Script" path="res://addons/inventory_system/ui/themes/theme_manager.gd" id="33_theme_mgr"]
```

Add a ThemeManager node as the FIRST child of CanvasLayer (before InventoryUI):

```
[node name="ThemeManager" type="Node" parent="CanvasLayer"]
script = ExtResource("33_theme_mgr")
```

- [ ] **Step 3: Wrap HUD label in PanelContainer**

In `scenes/player.tscn`, find the HUD Label node. Replace the plain Label with a PanelContainer wrapping a Label. Find:

```
[node name="HUD" type="Label" parent="CanvasLayer"]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -200.0
offset_top = 10.0
offset_right = 200.0
offset_bottom = 50.0
grow_horizontal = 2
text = "WASD: Move | Space: Jump | Shift: Sprint | Ctrl: Crouch | Alt: Dodge | V: Perspective | F2: Shoulder | I: Inventory"
horizontal_alignment = 1
```

Replace with:

```
[node name="HUD" type="PanelContainer" parent="CanvasLayer"]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -350.0
offset_top = 10.0
offset_right = 350.0
grow_horizontal = 2

[node name="Label" type="Label" parent="CanvasLayer/HUD"]
layout_mode = 2
text = "WASD: Move | Space: Jump | Shift: Sprint | Ctrl: Crouch | Alt: Dodge | V: Perspective | F2: Shoulder | F4: Theme | I: Inventory"
horizontal_alignment = 1
```

Do the same for PerspectiveLabel — wrap in PanelContainer:

Find:
```
[node name="PerspectiveLabel" type="Label" parent="CanvasLayer"]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -200.0
offset_top = 10.0
offset_bottom = 30.0
grow_horizontal = 0
text = "Perspective: First Person"
horizontal_alignment = 2
```

Replace with:
```
[node name="PerspectiveLabel" type="PanelContainer" parent="CanvasLayer"]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -220.0
offset_top = 10.0
grow_horizontal = 0

[node name="Label" type="Label" parent="CanvasLayer/PerspectiveLabel"]
layout_mode = 2
text = "Perspective: First Person"
horizontal_alignment = 2
```

Update `load_steps` count (+1 for the new ext_resource).

- [ ] **Step 4: Commit**

```bash
git add scenes/player.tscn project.godot
git commit -m "feat: wire ThemeManager, wrap HUD labels in PanelContainers, add F4 theme cycling"
```

---

### Task 4: Update Stamina Bar to Use Theme Colors

**Files:**
- Modify: `addons/player_control_core/ui/stamina_bar_ui.gd`

- [ ] **Step 1: Read the file and modify _build_ui()**

The stamina bar currently hardcodes fill colors. Instead, it should read the ProgressBar fill/background styles from the active theme, and lerp colors based on stamina ratio using exported high/low colors.

The key change: remove the hardcoded StyleBox creation in `_build_ui()` and let the ProgressBar inherit styles from the theme. Keep the color lerp logic but apply it by modifying the inherited fill StyleBox.

Read `addons/player_control_core/ui/stamina_bar_ui.gd`. In `_build_ui()`, remove the fill_style and bg_style creation. Replace the ProgressBar setup section with:

```gdscript
	# Progress bar — inherits fill/background styles from theme
	_bar = ProgressBar.new()
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 100.0
	_bar.show_percentage = false
	add_child(_bar)
```

Remove the `_bg = ColorRect.new()` block entirely (the theme's ProgressBar background handles this).

In `_on_stamina_changed()`, update the color lerp to modify the fill style from theme:

```gdscript
func _on_stamina_changed(current: float, maximum: float) -> void:
	if not _bar:
		return

	_bar.max_value = maximum
	_bar.value = current

	var ratio := current / maxf(maximum, 1.0)

	# Get or create fill style override for color lerp
	var fill_style := _bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style = fill_style.duplicate() as StyleBoxFlat
		fill_style.bg_color = color_low.lerp(color_full, ratio)
		_bar.add_theme_stylebox_override("fill", fill_style)

	if ratio < 1.0:
		_showing = true
		_hide_timer = hide_delay
	else:
		_showing = false
```

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/ui/stamina_bar_ui.gd
git commit -m "feat: stamina bar inherits theme styles with color lerp overlay"
```

---

### Task 5: Fix Scene References for Wrapped Labels

**Files:**
- Modify: `scenes/reusable_player.gd` (if it references HUD or PerspectiveLabel directly)

- [ ] **Step 1: Search for references to HUD and PerspectiveLabel**

Search the codebase for any scripts that set text on the HUD or PerspectiveLabel nodes. These now have an extra child Label that needs to be accessed instead.

Check `scenes/reusable_player.gd` specifically — it likely updates PerspectiveLabel text when perspective changes.

If it references `$CanvasLayer/PerspectiveLabel.text`, change to `$CanvasLayer/PerspectiveLabel/Label.text`.
If it references `$CanvasLayer/HUD.text`, change to `$CanvasLayer/HUD/Label.text`.

- [ ] **Step 2: Commit any fixes**

```bash
git add -A
git commit -m "fix: update label references for PanelContainer-wrapped HUD labels"
```
