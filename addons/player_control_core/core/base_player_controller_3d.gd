class_name BasePlayerController3D
extends Node
## Abstract base controller for player movement.
##
## Provides the core orchestration for input routing, motor, and state machine.
## Extend this class for FPS or third-person implementations.
## Subclasses must override _get_movement_basis() to provide camera-relative movement.


## Emitted when gameplay enabled state changes.
signal gameplay_enabled_changed(enabled: bool)
## Emitted to request mouse capture mode change.
signal mouse_capture_requested(mode: Input.MouseMode)

@export_group("Rig References")
## The CharacterBody3D to control.
@export var body: CharacterBody3D

@export_group("Core Components")
## Input router component. Required.
@export var input_router: PlayerInputRouter3D
## Movement motor component. Required.
@export var motor: PlayerMotor3D
## State machine for player states. Required.
@export var state_machine: PlayerStateMachine

@export_group("Settings")
## Movement settings resource.
@export var movement_settings: MovementSettings3D:
	set(value):
		movement_settings = value
		if motor:
			motor.movement_settings = value
			motor.refresh_settings()

## Input actions resource.
@export var input_actions: InputActions3D:
	set(value):
		input_actions = value
		if input_router:
			input_router.input_actions = value
			input_router.refresh_action_names()


## Whether gameplay (movement) is currently enabled.
var _gameplay_enabled: bool = true


func _ready() -> void:
	_validate_dependencies()
	_wire_components()


func _physics_process(_delta: float) -> void:
	# Update motor's movement basis each frame
	if motor:
		motor.movement_basis = _get_movement_basis()


func _validate_dependencies() -> void:
	if not body:
		push_warning("%s: 'body' is not assigned." % get_class())
	if not input_router:
		push_warning("%s: 'input_router' is not assigned." % get_class())
	if not motor:
		push_warning("%s: 'motor' is not assigned." % get_class())
	if not state_machine:
		push_warning("%s: 'state_machine' is not assigned." % get_class())


func _wire_components() -> void:
	# Wire body to motor
	if motor and body:
		motor.body = body
	
	# Wire input router to motor
	if input_router and motor:
		motor.input_router = input_router
	
	# Wire settings to components
	if input_router and input_actions:
		input_router.input_actions = input_actions
		input_router.refresh_action_names()
	
	if motor and movement_settings:
		motor.movement_settings = movement_settings
		motor.refresh_settings()
	
	# Wire controller to state machine
	if state_machine:
		state_machine.controller = self


## Override in subclasses to provide camera-relative or body-relative basis.
## FPS controllers return body.global_transform.basis.
## Third-person controllers return flattened camera basis.
func _get_movement_basis() -> Basis:
	return body.global_transform.basis if body else Basis.IDENTITY


## Enable or disable gameplay.
## Emits gameplay_enabled_changed and mouse_capture_requested signals.
func set_gameplay_enabled(enabled: bool) -> void:
	if _gameplay_enabled == enabled:
		return
	
	_gameplay_enabled = enabled
	
	# Use state machine to handle state transition
	if state_machine:
		if enabled:
			state_machine.exit_ui_state()
		else:
			state_machine.enter_ui_state()
	else:
		# Fallback if no state machine: manually toggle components
		if input_router:
			input_router.enabled = enabled
		if motor:
			motor.enabled = enabled
	
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


## Called by UIState when entering. Override in subclasses for additional behavior.
func _on_ui_state_entered() -> void:
	pass


## Called by UIState when exiting. Override in subclasses for additional behavior.
func _on_ui_state_exited() -> void:
	pass
