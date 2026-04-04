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
	get_parent().call_deferred("add_child", _toast_label)


# =========================================================================
# THEME BUILDERS
# =========================================================================

func _build_medieval_theme() -> Theme:
	var t := Theme.new()
	var font_color := Color(0.95, 0.9, 0.8)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.6)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.25, 0.15, 0.1, 0.95)
	panel.border_color = Color(0.7, 0.55, 0.2, 1.0)
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel)

	t.set_color("font_color", "Label", font_color)
	t.set_color("font_shadow_color", "Label", shadow_color)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.12, 0.08, 0.05, 0.8)
	pb_bg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.7, 0.55, 0.2, 1.0)
	pb_fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	var sep := StyleBoxFlat.new()
	sep.bg_color = Color(0.5, 0.4, 0.2, 0.6)
	sep.set_content_margin_all(0)
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep)

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

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	panel.border_color = Color(0.3, 0.3, 0.4, 0.8)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel)

	t.set_color("font_color", "Label", font_color)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.1, 0.1, 0.15, 0.7)
	pb_bg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.2, 0.6, 0.8, 1.0)
	pb_fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	var sep := StyleBoxFlat.new()
	sep.bg_color = Color(0.25, 0.25, 0.35, 0.5)
	sep.set_content_margin_all(0)
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep)

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

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.95, 0.93, 0.9, 0.92)
	panel.border_color = Color(0.7, 0.68, 0.65, 1.0)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel)

	t.set_color("font_color", "Label", font_color)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.8, 0.78, 0.75, 0.6)
	pb_bg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.3, 0.7, 0.4, 1.0)
	pb_fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	var sep := StyleBoxFlat.new()
	sep.bg_color = Color(0.7, 0.68, 0.65, 0.4)
	sep.set_content_margin_all(0)
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep)

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
