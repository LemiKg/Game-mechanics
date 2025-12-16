class_name PlayerMotor3D
extends Node
## Applies movement physics to a CharacterBody3D.
##
## Handles walking, jumping, gravity, and grounded state.
## Designed to be driven by a state machine - states call motor methods.


## Emitted when grounded state changes.
signal grounded_changed(is_grounded: bool)
## Emitted when the player jumps.
signal jumped()

@export_group("References")
## The CharacterBody3D to move. Required.
@export var body: CharacterBody3D
## The node to read movement intent from. Required.
@export var input_router: PlayerInputRouter3D

@export_group("Settings")
## Movement tuning values. If null, uses defaults.
@export var movement_settings: MovementSettings3D

## Whether the motor is enabled.
var enabled: bool = true:
	set(value):
		enabled = value
		set_physics_process(value)

## Current grounded state.
var is_grounded: bool = false:
	set(value):
		if is_grounded != value:
			is_grounded = value
			grounded_changed.emit(is_grounded)

## External basis for movement direction. Set by controller.
## Allows camera-relative movement for third-person.
var movement_basis: Basis = Basis.IDENTITY

## Current movement speed. Modified by states (walk/sprint/crouch).
var current_speed: float = 5.0

# Cached settings (use defaults if no resource)
var _walk_speed: float = 5.0
var _sprint_speed: float = 8.0
var _crouch_speed: float = 2.5
var _acceleration: float = 25.0
var _deceleration: float = 30.0
var _air_control: float = 0.3
var _jump_velocity: float = 4.5
var _gravity: float = 9.8


func _ready() -> void:
	_cache_settings()
	_validate_dependencies()


func _validate_dependencies() -> void:
	if not body:
		push_warning("PlayerMotor3D: 'body' is not assigned. Motor will not function.")
	if not input_router:
		push_warning("PlayerMotor3D: 'input_router' is not assigned. Motor will not function.")


func _cache_settings() -> void:
	if movement_settings:
		_walk_speed = movement_settings.walk_speed
		_sprint_speed = movement_settings.sprint_speed
		_crouch_speed = movement_settings.crouch_speed
		_acceleration = movement_settings.acceleration
		_deceleration = movement_settings.deceleration
		_air_control = movement_settings.air_control
		_jump_velocity = movement_settings.jump_velocity
		_gravity = movement_settings.gravity
	current_speed = _walk_speed


func _physics_process(delta: float) -> void:
	if not enabled or not body or not input_router:
		return
	
	# Update grounded state
	is_grounded = body.is_on_floor()
	
	# Apply movement (gravity and jump handled by states or apply_gravity/try_jump)
	_apply_horizontal_movement(delta)
	
	# Move the body
	body.move_and_slide()


func _apply_horizontal_movement(delta: float) -> void:
	# Get movement direction relative to provided basis
	var input_dir := input_router.movement_intent
	var direction := (movement_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Calculate target horizontal velocity
	var target_velocity := direction * current_speed
	
	# Determine acceleration rate
	var accel_rate: float
	if direction.length() > 0.1:
		accel_rate = _acceleration
	else:
		accel_rate = _deceleration
	
	# Apply air control modifier
	if not is_grounded:
		accel_rate *= _air_control
	
	# Interpolate horizontal velocity
	body.velocity.x = move_toward(body.velocity.x, target_velocity.x, accel_rate * delta)
	body.velocity.z = move_toward(body.velocity.z, target_velocity.z, accel_rate * delta)


## Apply gravity. Called by states.
func apply_gravity(delta: float) -> void:
	if body:
		body.velocity.y -= _gravity * delta


## Attempt to jump. Returns true if jump was performed.
func try_jump() -> bool:
	if body and is_grounded:
		body.velocity.y = _jump_velocity
		jumped.emit()
		return true
	return false


## Set current speed to walk speed.
func set_walk_speed() -> void:
	current_speed = _walk_speed


## Set current speed to sprint speed.
func set_sprint_speed() -> void:
	current_speed = _sprint_speed


## Set current speed to crouch speed.
func set_crouch_speed() -> void:
	current_speed = _crouch_speed


## Call when movement_settings resource changes.
func refresh_settings() -> void:
	_cache_settings()
