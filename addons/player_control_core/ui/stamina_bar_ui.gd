class_name StaminaBarUI
extends Control
## Displays a stamina bar that connects to StaminaComponent.
##
## Shows current stamina as a colored progress bar with smooth transitions.
## Fades out when stamina is full, fades in when draining.


@export_group("References")
## The stamina component to display.
@export var stamina_component: Node

@export_group("Appearance")
## Color when stamina is high (> 50%).
@export var color_full: Color = Color(0.2, 0.8, 0.3, 0.9)
## Color when stamina is low (< 25%).
@export var color_low: Color = Color(0.9, 0.2, 0.1, 0.9)
## Color of the background bar.
@export var color_background: Color = Color(0.1, 0.1, 0.1, 0.5)
## Whether to auto-hide when stamina is full.
@export var auto_hide: bool = true
## Seconds to wait at full before hiding.
@export_range(0.0, 5.0, 0.1) var hide_delay: float = 2.0

## Internal state
var _bar: ProgressBar
var _bg: ColorRect
var _hide_timer: float = 0.0
var _target_alpha: float = 0.0
var _showing: bool = false


func _ready() -> void:
	# Build the bar programmatically
	_build_ui()

	if stamina_component and stamina_component.has_signal("stamina_changed"):
		stamina_component.stamina_changed.connect(_on_stamina_changed)
	if stamina_component and stamina_component.has_signal("stamina_depleted"):
		stamina_component.stamina_depleted.connect(_on_stamina_depleted)

	# Start hidden if auto_hide
	if auto_hide:
		modulate.a = 0.0


func _build_ui() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.color = color_background
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Progress bar
	_bar = ProgressBar.new()
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 100.0
	_bar.show_percentage = false

	# Style the bar
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color_full
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color.TRANSPARENT
	_bar.add_theme_stylebox_override("background", bg_style)

	add_child(_bar)


func _process(delta: float) -> void:
	# Smooth fade in/out
	if auto_hide:
		if _showing:
			_target_alpha = 1.0
		else:
			_hide_timer -= delta
			if _hide_timer <= 0:
				_target_alpha = 0.0

		modulate.a = lerpf(modulate.a, _target_alpha, 8.0 * delta)


func _on_stamina_changed(current: float, maximum: float) -> void:
	if not _bar:
		return

	_bar.max_value = maximum
	_bar.value = current

	# Update color based on ratio
	var ratio := current / maxf(maximum, 1.0)
	var fill_style: StyleBoxFlat = _bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = color_low.lerp(color_full, ratio)

	# Show/hide logic
	if ratio < 1.0:
		_showing = true
		_hide_timer = hide_delay
	else:
		_showing = false


func _on_stamina_depleted() -> void:
	# Flash effect when depleted
	_showing = true
	_hide_timer = hide_delay
	if _bar:
		var fill_style: StyleBoxFlat = _bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			fill_style.bg_color = Color(1.0, 0.0, 0.0, 1.0)
