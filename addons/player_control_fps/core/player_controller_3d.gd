class_name PlayerController3D
extends Node
## Legacy orchestrator for FPS player control.
## 
## DEPRECATED: Use FPSPlayerController3D with state machine instead.
## This class is kept for backwards compatibility with existing scenes.
##
## Provides a single public API surface for enabling/disabling gameplay
## and coordinates the input router, motor, and look controller.


## Emitted when gameplay enabled state changes.
signal gameplay_enabled_changed(enabled: bool)
## Emitted to request mouse capture mode change.
signal mouse_capture_requested(mode: Input.MouseMode)

@export_group("Rig References")
## The CharacterBody3D to control. Passed to motor.
@export var body: CharacterBody3D
## The node for pitch rotation (camera pivot). Passed to look controller.
@export var pitch_pivot: Node3D
## The camera node (optional, for reference).
@export var camera: Camera3D

@export_group("Components")
## Input router component. Required (from core addon).
@export var input_router: PlayerInputRouter3D
## Movement motor component. Required (from core addon).
@export var motor: PlayerMotor3D
## Look controller component. Required.
@export var look_controller: PlayerLookController3D

@export_group("Settings")
## Movement settings resource (from core addon).
@export var movement_settings: MovementSettings3D:
	set(value):
		movement_settings = value
		if motor:
			motor.movement_settings = value
			motor.refresh_settings()

## Look settings resource.
@export var look_settings: FPSLookSettings3D:
	set(value):
		look_settings = value
		if look_controller:
			look_controller.look_settings = value
			look_controller.refresh_settings()

## Input actions resource (from core addon).
@export var input_actions: InputActions3D:
	set(value):
		input_actions = value
		if input_router:
			input_router.input_actions = value
			input_router.refresh_action_names()

## Whether gameplay (movement + look) is currently enabled.
var _gameplay_enabled: bool = true

var gameplay_enabled: bool:
	get:
		return _gameplay_enabled
	set(value):
		set_gameplay_enabled(value)


func _ready() -> void:
	_validate_dependencies()
	_wire_components()


func _validate_dependencies() -> void:
	if not body:
		push_warning("PlayerController3D: 'body' is not assigned.")
	if not pitch_pivot:
		push_warning("PlayerController3D: 'pitch_pivot' is not assigned.")
	if not input_router:
		push_warning("PlayerController3D: 'input_router' is not assigned.")
	if not motor:
		push_warning("PlayerController3D: 'motor' is not assigned.")
	if not look_controller:
		push_warning("PlayerController3D: 'look_controller' is not assigned.")


func _wire_components() -> void:
	# Wire body to motor
	if motor and body:
		motor.body = body
	
	# Wire input router to motor and look controller
	if input_router:
		if motor:
			motor.input_router = input_router
		if look_controller:
			look_controller.input_router = input_router
	
	# Wire look controller nodes
	if look_controller:
		if body:
			look_controller.yaw_node = body
		if pitch_pivot:
			look_controller.pitch_node = pitch_pivot
	
	# Wire settings
	if input_router and input_actions:
		input_router.input_actions = input_actions
		input_router.refresh_action_names()
	
	if motor and movement_settings:
		motor.movement_settings = movement_settings
		motor.refresh_settings()
	
	if look_controller and look_settings:
		look_controller.look_settings = look_settings
		look_controller.refresh_settings()


## Enable or disable gameplay (movement and look input).
## Emits gameplay_enabled_changed and mouse_capture_requested signals.
func set_gameplay_enabled(enabled: bool) -> void:
	if _gameplay_enabled == enabled:
		return
	
	_gameplay_enabled = enabled
	
	# Update component states
	if input_router:
		input_router.enabled = enabled
	if motor:
		motor.enabled = enabled
	if look_controller:
		look_controller.enabled = enabled
	
	# Emit signals
	gameplay_enabled_changed.emit(enabled)
	
	# Request appropriate mouse mode
	if enabled:
		mouse_capture_requested.emit(Input.MOUSE_MODE_CAPTURED)
	else:
		mouse_capture_requested.emit(Input.MOUSE_MODE_VISIBLE)


## Convenience method to check if gameplay is enabled.
func is_gameplay_enabled() -> bool:
	return _gameplay_enabled
