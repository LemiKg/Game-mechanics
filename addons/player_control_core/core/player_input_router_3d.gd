class_name PlayerInputRouter3D
extends Node
## Converts raw input into normalized intent for movement and look.
##
## Reads input actions and mouse motion, exposing properties that
## the motor and look controller consume each frame.


## Emitted when look delta changes (for components that prefer signals).
signal look_delta_changed(delta: Vector2)

@export_group("Settings")
## Input action configuration. If null, uses default action names.
@export var input_actions: InputActions3D

## Whether input processing is enabled.
var enabled: bool = true:
	set(value):
		enabled = value
		set_process_unhandled_input(value)
		if not value:
			# Clear intent when disabled
			movement_intent = Vector2.ZERO
			jump_pressed = false
			sprint_held = false
			crouch_held = false
			look_delta = Vector2.ZERO

## Current movement intent as a normalized 2D vector (x = strafe, y = forward/back).
var movement_intent: Vector2 = Vector2.ZERO

## True if jump was pressed this frame.
var jump_pressed: bool = false

## True if sprint is currently held.
var sprint_held: bool = false

## True if crouch is currently held.
var crouch_held: bool = false

## Mouse look delta accumulated this frame.
var look_delta: Vector2 = Vector2.ZERO

# Cached action names
var _move_forward: StringName = &"move_forward"
var _move_back: StringName = &"move_back"
var _move_left: StringName = &"move_left"
var _move_right: StringName = &"move_right"
var _jump: StringName = &"jump"
var _sprint: StringName = &"sprint"
var _crouch: StringName = &"crouch"


func _ready() -> void:
	_cache_action_names()


func _cache_action_names() -> void:
	if input_actions:
		_move_forward = input_actions.move_forward
		_move_back = input_actions.move_back
		_move_left = input_actions.move_left
		_move_right = input_actions.move_right
		_jump = input_actions.jump
		_sprint = input_actions.sprint
		_crouch = input_actions.crouch


func _process(_delta: float) -> void:
	if not enabled:
		return
	
	# Read movement input
	movement_intent = Input.get_vector(_move_left, _move_right, _move_forward, _move_back)
	
	# Read jump input (pressed this frame)
	jump_pressed = Input.is_action_just_pressed(_jump)
	
	# Read sprint/crouch (held)
	sprint_held = Input.is_action_pressed(_sprint)
	crouch_held = Input.is_action_pressed(_crouch)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	
	# Handle mouse motion for look - accumulate until consumed
	if event is InputEventMouseMotion:
		look_delta += event.relative
		look_delta_changed.emit(look_delta)


## Called by look controller after consuming the delta.
func consume_look_delta() -> Vector2:
	var delta := look_delta
	look_delta = Vector2.ZERO
	return delta


## Call when input_actions resource changes to update cached names.
func refresh_action_names() -> void:
	_cache_action_names()
