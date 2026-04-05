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
			jump_requested = false
			_jump_buffered = false
			sprint_held = false
			crouch_held = false
			dodge_requested = false
			_dodge_buffered = false
			sit_requested = false
			_sit_buffered = false
			dance_requested = false
			_dance_buffered = false
			torch_toggle_requested = false
			_torch_toggle_buffered = false
			look_delta = Vector2.ZERO

## Current movement intent as a normalized 2D vector (x = strafe, y = forward/back).
var movement_intent: Vector2 = Vector2.ZERO

## True if jump was requested (buffered for physics frame).
var jump_requested: bool = false

## Internal buffer for jump input.
var _jump_buffered: bool = false

## True if sprint is currently held.
var sprint_held: bool = false

## True if crouch is currently held.
var crouch_held: bool = false

## True if dodge was requested (buffered for physics frame).
var dodge_requested: bool = false

## Internal buffer for dodge input.
var _dodge_buffered: bool = false

## True if sit was requested (buffered for physics frame).
var sit_requested: bool = false

## Internal buffer for sit input.
var _sit_buffered: bool = false

## True if dance was requested (buffered for physics frame).
var dance_requested: bool = false

## Internal buffer for dance input.
var _dance_buffered: bool = false

## True if torch toggle was requested (buffered for physics frame).
var torch_toggle_requested: bool = false

## Internal buffer for torch toggle input.
var _torch_toggle_buffered: bool = false

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
var _dodge: StringName = &"dodge"
var _sit: StringName = &"sit"
var _dance: StringName = &"dance"
var _toggle_torch: StringName = &"toggle_torch"


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
		if "dodge" in input_actions:
			_dodge = input_actions.dodge
		if "sit" in input_actions:
			_sit = input_actions.sit
		if "dance" in input_actions:
			_dance = input_actions.dance
		if "toggle_torch" in input_actions:
			_toggle_torch = input_actions.toggle_torch


func _process(_delta: float) -> void:
	if not enabled:
		return
	
	# Read movement input
	movement_intent = Input.get_vector(_move_left, _move_right, _move_forward, _move_back)
	
	# Buffer jump input (persists until consumed by physics)
	if Input.is_action_just_pressed(_jump):
		_jump_buffered = true
	
	# Read sprint/crouch (held)
	sprint_held = Input.is_action_pressed(_sprint)
	crouch_held = Input.is_action_pressed(_crouch)
	if Input.is_action_just_pressed(_dodge):
		_dodge_buffered = true
	if Input.is_action_just_pressed(_sit):
		_sit_buffered = true
	if Input.is_action_just_pressed(_dance):
		_dance_buffered = true
	if Input.is_action_just_pressed(_toggle_torch):
		_torch_toggle_buffered = true


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	
	# Transfer buffered jump to physics-safe property
	jump_requested = _jump_buffered
	_jump_buffered = false
	dodge_requested = _dodge_buffered
	_dodge_buffered = false
	sit_requested = _sit_buffered
	_sit_buffered = false
	dance_requested = _dance_buffered
	_dance_buffered = false
	torch_toggle_requested = _torch_toggle_buffered
	_torch_toggle_buffered = false


## Consume and clear the jump request. Returns true if jump was requested.
func consume_jump() -> bool:
	var was_requested := jump_requested
	jump_requested = false
	return was_requested


## Consume and clear the dodge request. Returns true if dodge was requested.
func consume_dodge() -> bool:
	var was_requested := dodge_requested
	dodge_requested = false
	return was_requested


## Consume and clear the sit request. Returns true if sit was requested.
func consume_sit() -> bool:
	var was_requested := sit_requested
	sit_requested = false
	return was_requested


## Consume and clear the dance request. Returns true if dance was requested.
func consume_dance() -> bool:
	var was_requested := dance_requested
	dance_requested = false
	return was_requested


## Consume and clear the torch toggle request. Returns true if torch toggle was requested.
func consume_torch_toggle() -> bool:
	var was_requested := torch_toggle_requested
	torch_toggle_requested = false
	return was_requested


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
