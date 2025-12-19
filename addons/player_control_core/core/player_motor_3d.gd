class_name PlayerMotor3D
extends Node
## Applies movement physics to a CharacterBody3D or RigidBody3D.
##
## Handles walking, jumping, gravity, and grounded state.
## Designed to be driven by a state machine - states call motor methods.
## Supports both CharacterBody3D (move_and_slide) and RigidBody3D (forces).


## Body type detection for duck typing.
enum BodyType {UNKNOWN, CHARACTER_BODY, RIGID_BODY}


## Emitted when grounded state changes.
signal grounded_changed(is_grounded: bool)
## Emitted when the player jumps.
signal jumped()
## Emitted when actual velocity changes (for pose warping integration).
signal velocity_changed(velocity: Vector3, speed: float)


@export_group("References")
## The body to move. Supports CharacterBody3D or RigidBody3D.
@export var body: Node3D
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

## Actual velocity based on real displacement (for pose warping).
var actual_velocity: Vector3 = Vector3.ZERO

## Previous position for calculating actual velocity.
var previous_position: Vector3 = Vector3.ZERO

## Whether the character is actually moving (based on actual_velocity).
var is_moving: bool:
	get: return actual_velocity.length() > 0.1

## Whether input is requesting movement.
var input_is_moving: bool:
	get: return input_router != null and input_router.movement_intent.length() > 0.1

## Detected body type (duck typing).
var _body_type: BodyType = BodyType.UNKNOWN

# Cached settings (use defaults if no resource)
var _walk_speed: float = 5.0
var _sprint_speed: float = 8.0
var _crouch_speed: float = 2.5
var _acceleration: float = 25.0
var _deceleration: float = 30.0
var _air_control: float = 0.3
var _jump_velocity: float = 4.5
var _gravity: float = 9.8

# RigidBody settings
var _rigid_body_force_multiplier: float = 50.0
var _rigid_body_ground_raycast_distance: float = 0.1


func _ready() -> void:
	_cache_settings()
	_validate_dependencies()
	_detect_body_type()
	if body:
		previous_position = body.global_position


func _validate_dependencies() -> void:
	if not body:
		push_warning("PlayerMotor3D: 'body' is not assigned. Motor will not function.")
	if not input_router:
		push_warning("PlayerMotor3D: 'input_router' is not assigned. Motor will not function.")


func _detect_body_type() -> void:
	if not body:
		_body_type = BodyType.UNKNOWN
		return
	
	if body.has_method("move_and_slide"):
		_body_type = BodyType.CHARACTER_BODY
	elif body.has_method("apply_central_force"):
		_body_type = BodyType.RIGID_BODY
	else:
		_body_type = BodyType.UNKNOWN
		push_warning("PlayerMotor3D: body is neither CharacterBody3D nor RigidBody3D")


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
		_rigid_body_force_multiplier = movement_settings.rigid_body_force_multiplier
		_rigid_body_ground_raycast_distance = movement_settings.rigid_body_ground_raycast_distance
	current_speed = _walk_speed


func _physics_process(delta: float) -> void:
	if not enabled or not body or not input_router:
		return
	
	match _body_type:
		BodyType.CHARACTER_BODY:
			_process_character_body(delta)
		BodyType.RIGID_BODY:
			_process_rigid_body(delta)
		BodyType.UNKNOWN:
			pass


func _process_character_body(delta: float) -> void:
	# Update grounded state
	is_grounded = body.is_on_floor()
	
	# Apply movement
	_apply_horizontal_movement_character(delta)
	
	# Move the body
	body.move_and_slide()
	
	# Calculate actual velocity
	_calculate_actual_velocity(delta)


func _process_rigid_body(delta: float) -> void:
	# Update grounded state via raycast
	_update_grounded_state_rigid()
	
	# Apply movement via forces
	_apply_horizontal_movement_rigid(delta)
	
	# Calculate actual velocity
	_calculate_actual_velocity(delta)


func _update_grounded_state_rigid() -> void:
	var space_state := body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		body.global_position,
		body.global_position + Vector3.DOWN * _rigid_body_ground_raycast_distance,
		body.collision_mask if "collision_mask" in body else 1
	)
	query.exclude = [body.get_rid()]
	var result := space_state.intersect_ray(query)
	
	is_grounded = result != null and result.size() > 0


func _calculate_actual_velocity(delta: float) -> void:
	if delta > 0:
		actual_velocity = (body.global_position - previous_position) / delta
	else:
		actual_velocity = Vector3.ZERO
	previous_position = body.global_position
	velocity_changed.emit(actual_velocity, actual_velocity.length())


func _apply_horizontal_movement_character(delta: float) -> void:
	# Get movement direction relative to provided basis
	# input_dir.x = strafe (positive = right), input_dir.y = forward (positive = forward)
	# Basis: X=right, Z=back. Use +basis.z for forward input
	var input_dir := input_router.movement_intent
	var direction := (movement_basis.x * input_dir.x + movement_basis.z * input_dir.y).normalized()
	
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


func _apply_horizontal_movement_rigid(delta: float) -> void:
	# Get movement direction relative to provided basis
	# input_dir.x = strafe (positive = right), input_dir.y = forward (positive = forward)
	# Basis: X=right, Z=back. Use +basis.z for forward input
	var input_dir := input_router.movement_intent
	var direction := (movement_basis.x * input_dir.x + movement_basis.z * input_dir.y).normalized()
	
	# Calculate target horizontal velocity
	var target_velocity := direction * current_speed
	var current_velocity := Vector3(body.linear_velocity.x, 0, body.linear_velocity.z)
	var velocity_diff := target_velocity - current_velocity
	
	# Determine acceleration rate
	var accel_rate: float = _acceleration
	if direction.length() < 0.1:
		accel_rate = _deceleration
	
	# Apply air control modifier
	if not is_grounded:
		accel_rate *= _air_control
	
	# Apply force proportional to velocity difference
	var force := velocity_diff * _rigid_body_force_multiplier * accel_rate / _acceleration
	body.apply_central_force(force)
	
	# Clamp horizontal velocity to current speed
	var horizontal := Vector2(body.linear_velocity.x, body.linear_velocity.z)
	if horizontal.length() > current_speed:
		horizontal = horizontal.normalized() * current_speed
		body.linear_velocity.x = horizontal.x
		body.linear_velocity.z = horizontal.y


## Apply gravity. Called by states.
func apply_gravity(delta: float) -> void:
	if not body:
		return
	
	match _body_type:
		BodyType.CHARACTER_BODY:
			body.velocity.y -= _gravity * delta
		BodyType.RIGID_BODY:
			# RigidBody has built-in gravity, but we can add extra if needed
			pass # Let Godot handle RigidBody gravity


## Attempt to jump. Returns true if jump was performed.
func try_jump() -> bool:
	if not body or not is_grounded:
		return false
	
	match _body_type:
		BodyType.CHARACTER_BODY:
			body.velocity.y = _jump_velocity
		BodyType.RIGID_BODY:
			body.apply_central_impulse(Vector3.UP * _jump_velocity * body.mass)
	
	jumped.emit()
	return true


## Set current speed to walk speed.
func set_walk_speed() -> void:
	current_speed = _walk_speed


## Set current speed to sprint speed.
func set_sprint_speed() -> void:
	current_speed = _sprint_speed


## Set current speed to crouch speed.
func set_crouch_speed() -> void:
	current_speed = _crouch_speed


## Get current velocity (for duck typing / pose warping integration).
func get_velocity() -> Vector3:
	return actual_velocity


## Get current speed (for duck typing / pose warping integration).
func get_speed() -> float:
	return actual_velocity.length()


## Call when movement_settings resource changes.
func refresh_settings() -> void:
	_cache_settings()
	_detect_body_type()
