class_name PlayerMotor3D
extends Node
## Applies movement physics to a CharacterBody3D or RigidBody3D.
##
## Uses orthogonal Gait (walk/run/sprint) and Stance (standing/crouching)
## enums with per-gait physics data from GaitData resources.
## Supports both player input (via input_router) and direct AI API.


## Gait determines speed tier and acceleration profile.
enum Gait { WALK, RUN, SPRINT }

## Stance determines collision height and speed multiplier.
enum Stance { STANDING, CROUCHING }

## Body type detection for duck typing.
enum BodyType { UNKNOWN, CHARACTER_BODY, RIGID_BODY }


# =============================================================================
# SIGNALS
# =============================================================================

signal grounded_changed(is_grounded: bool)
signal jumped()
signal velocity_changed(velocity: Vector3, speed: float)
signal gait_changed(new_gait: Gait)
signal stance_changed(new_stance: Stance)


# =============================================================================
# EXPORTS
# =============================================================================

@export_group("References")
## The body to move. Supports CharacterBody3D or RigidBody3D.
@export var body: Node3D
## The node to read movement intent from. Optional for AI-driven characters.
@export var input_router: PlayerInputRouter3D

@export_group("Settings")
## Movement tuning values. If null, uses defaults.
@export var movement_settings: MovementSettings3D


# =============================================================================
# PUBLIC STATE
# =============================================================================

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

## Current gait (walk/run/sprint).
var gait: Gait = Gait.RUN:
	set(value):
		if gait != value:
			gait = value
			gait_changed.emit(gait)

## Current stance (standing/crouching).
var stance: Stance = Stance.STANDING:
	set(value):
		if stance != value:
			stance = value
			stance_changed.emit(stance)

## External basis for movement direction. Set by controller each frame.
var movement_basis: Basis = Basis.IDENTITY

## Actual velocity based on real displacement (for pose warping).
var actual_velocity: Vector3 = Vector3.ZERO

## Previous position for calculating actual velocity.
var previous_position: Vector3 = Vector3.ZERO

## Whether the character is actually moving.
var is_moving: bool:
	get: return actual_velocity.length() > 0.1

## Whether input is requesting movement.
var input_is_moving: bool:
	get: return input_router != null and input_router.movement_intent.length() > 0.1

## Current floor normal (updated each physics frame when grounded).
var floor_normal: Vector3 = Vector3.UP

## Current slope angle in radians.
var slope_angle: float = 0.0


# =============================================================================
# PRIVATE STATE
# =============================================================================

var _body_type: BodyType = BodyType.UNKNOWN
var _direct_move_direction: Vector3 = Vector3.ZERO
var _direct_move_gait: Gait = Gait.RUN
var _use_direct_move: bool = false
var _jump_requested_direct: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_validate_dependencies()
	_detect_body_type()
	if body:
		previous_position = body.global_position


func _validate_dependencies() -> void:
	if not body:
		push_warning("PlayerMotor3D: 'body' is not assigned.")
	if not input_router:
		push_warning("PlayerMotor3D: 'input_router' is not assigned. Use AI API methods instead.")


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


func _physics_process(delta: float) -> void:
	if not enabled or not body:
		return
	match _body_type:
		BodyType.CHARACTER_BODY:
			_process_character_body(delta)
		BodyType.RIGID_BODY:
			_process_rigid_body(delta)


# =============================================================================
# CHARACTER BODY PHYSICS
# =============================================================================

func _process_character_body(delta: float) -> void:
	is_grounded = body.is_on_floor()

	# Update floor data
	if is_grounded:
		floor_normal = body.get_floor_normal()
		slope_angle = acos(floor_normal.dot(Vector3.UP))
	else:
		floor_normal = Vector3.UP
		slope_angle = 0.0

	_apply_horizontal_movement(delta)
	body.move_and_slide()
	_calculate_actual_velocity(delta)


func _apply_horizontal_movement(delta: float) -> void:
	# Get movement direction
	var direction: Vector3
	if _use_direct_move:
		direction = _direct_move_direction
	elif input_router:
		var input_dir := input_router.movement_intent
		direction = (movement_basis.x * input_dir.x + movement_basis.z * input_dir.y).normalized()
	else:
		direction = Vector3.ZERO

	# Get gait data
	var active_gait := _direct_move_gait if _use_direct_move else gait
	var gait_data := _get_current_gait_data(active_gait)
	var target_speed := gait_data.speed

	# Apply stance multiplier
	if stance == Stance.CROUCHING:
		var multiplier := movement_settings.stance_crouch_speed_multiplier if movement_settings else 0.5
		target_speed *= multiplier

	# Apply slope adjustment
	if is_grounded and slope_angle > 0.01:
		target_speed = _apply_slope_speed(target_speed, direction)

	# Calculate target velocity
	var target_velocity := direction * target_speed

	# Determine acceleration rate
	var accel_rate: float
	if direction.length() > 0.1:
		accel_rate = gait_data.acceleration
	else:
		accel_rate = gait_data.deceleration

	# Apply air control modifier
	if not is_grounded:
		var air_ctrl := movement_settings.air_control if movement_settings else 0.3
		accel_rate *= air_ctrl

	# Lerp-based acceleration (weightier feel than move_toward)
	var lerp_factor := clampf(accel_rate / maxf(target_speed, 1.0) * delta, 0.0, 1.0)
	body.velocity.x = lerpf(body.velocity.x, target_velocity.x, lerp_factor)
	body.velocity.z = lerpf(body.velocity.z, target_velocity.z, lerp_factor)

	# Clear direct move after use
	_use_direct_move = false


func _apply_slope_speed(base_speed: float, move_direction: Vector3) -> float:
	if not movement_settings:
		return base_speed

	var floor_tangent := floor_normal.cross(Vector3.UP).cross(floor_normal).normalized()
	var slope_dot := move_direction.dot(floor_tangent)
	var slope_factor := sin(slope_angle)

	if slope_dot < -0.1:
		# Going uphill
		return base_speed * (1.0 - slope_factor * movement_settings.slope_speed_reduction)
	elif slope_dot > 0.1:
		# Going downhill
		return base_speed * (1.0 + slope_factor * movement_settings.downhill_speed_boost)

	return base_speed


# =============================================================================
# GRAVITY
# =============================================================================

## Apply gravity with enhanced fall feel.
## Call from AirborneState with jump_held tracking.
func apply_gravity_enhanced(delta: float, jump_held: bool) -> void:
	if not body or _body_type != BodyType.CHARACTER_BODY:
		return

	var base_gravity := movement_settings.gravity if movement_settings else 9.8
	var gravity_scale: float

	if body.velocity.y < 0:
		# Falling — enhanced gravity for snappy landings
		gravity_scale = movement_settings.fall_gravity_multiplier if movement_settings else 1.8
	elif body.velocity.y > 0 and not jump_held:
		# Ascending but jump released — cut the jump short
		gravity_scale = movement_settings.jump_cut_gravity_multiplier if movement_settings else 2.5
	else:
		# Ascending with jump held — normal gravity
		gravity_scale = 1.0

	body.velocity.y -= base_gravity * gravity_scale * delta


## Apply simple gravity (for backwards compatibility).
func apply_gravity(delta: float) -> void:
	if not body:
		return
	match _body_type:
		BodyType.CHARACTER_BODY:
			var g := movement_settings.gravity if movement_settings else 9.8
			body.velocity.y -= g * delta
		BodyType.RIGID_BODY:
			pass


# =============================================================================
# JUMPING
# =============================================================================

## Attempt to jump. Returns true if jump was performed.
func try_jump() -> bool:
	if not body or not is_grounded:
		return false

	var jv := movement_settings.jump_velocity if movement_settings else 4.5

	match _body_type:
		BodyType.CHARACTER_BODY:
			body.velocity.y = jv
		BodyType.RIGID_BODY:
			body.apply_central_impulse(Vector3.UP * jv * body.mass)

	jumped.emit()
	return true


## Cut jump velocity on early release (variable jump height).
func cut_jump() -> void:
	if not body or body.velocity.y <= 0:
		return
	var multiplier := movement_settings.jump_cut_multiplier if movement_settings else 0.5
	body.velocity.y *= multiplier


# =============================================================================
# RIGIDBODY PHYSICS
# =============================================================================

func _process_rigid_body(delta: float) -> void:
	_update_grounded_state_rigid()

	var input_dir := input_router.movement_intent if input_router else Vector2.ZERO
	var direction := (movement_basis.x * input_dir.x + movement_basis.z * input_dir.y).normalized()
	var gait_data := _get_current_gait_data(gait)
	var target_speed := gait_data.speed

	var target_velocity := direction * target_speed
	var current_velocity := Vector3(body.linear_velocity.x, 0, body.linear_velocity.z)
	var velocity_diff := target_velocity - current_velocity

	var accel_rate := gait_data.acceleration
	if direction.length() < 0.1:
		accel_rate = gait_data.deceleration

	if not is_grounded:
		var air_ctrl := movement_settings.air_control if movement_settings else 0.3
		accel_rate *= air_ctrl

	var rigid_force_mult := movement_settings.rigid_body_force_multiplier if movement_settings else 50.0
	var force := velocity_diff * rigid_force_mult * accel_rate / maxf(gait_data.acceleration, 1.0)
	body.apply_central_force(force)

	var horizontal := Vector2(body.linear_velocity.x, body.linear_velocity.z)
	if horizontal.length() > target_speed:
		horizontal = horizontal.normalized() * target_speed
		body.linear_velocity.x = horizontal.x
		body.linear_velocity.z = horizontal.y

	_calculate_actual_velocity(delta)


func _update_grounded_state_rigid() -> void:
	var space_state := body.get_world_3d().direct_space_state
	var dist := movement_settings.rigid_body_ground_raycast_distance if movement_settings else 0.1
	var query := PhysicsRayQueryParameters3D.create(
		body.global_position,
		body.global_position + Vector3.DOWN * dist,
		body.collision_mask if "collision_mask" in body else 1
	)
	query.exclude = [body.get_rid()]
	var result := space_state.intersect_ray(query)
	is_grounded = result != null and result.size() > 0


# =============================================================================
# VELOCITY TRACKING
# =============================================================================

func _calculate_actual_velocity(delta: float) -> void:
	if delta > 0:
		actual_velocity = (body.global_position - previous_position) / delta
	else:
		actual_velocity = Vector3.ZERO
	previous_position = body.global_position
	velocity_changed.emit(actual_velocity, actual_velocity.length())


# =============================================================================
# AI / DIRECT MOVEMENT API
# =============================================================================

## Move in a direction without requiring input router. For AI use.
func move_in_direction(direction: Vector3, move_gait: Gait = Gait.RUN) -> void:
	_direct_move_direction = direction.normalized() if direction.length() > 0.1 else Vector3.ZERO
	_direct_move_gait = move_gait
	_use_direct_move = true


## Request a jump via API (for AI use). Executes on next physics frame.
func request_jump() -> void:
	_jump_requested_direct = true


## Consume the direct jump request. Called by states.
func consume_direct_jump() -> bool:
	var was := _jump_requested_direct
	_jump_requested_direct = false
	return was


# =============================================================================
# HELPERS
# =============================================================================

func _get_current_gait_data(g: Gait = gait) -> GaitData:
	if movement_settings:
		return movement_settings.get_gait_data(g)
	return MovementSettings3D._default_run()


## Get current target speed accounting for gait and stance.
func get_target_speed() -> float:
	var gait_data := _get_current_gait_data()
	var speed := gait_data.speed
	if stance == Stance.CROUCHING:
		var mult := movement_settings.stance_crouch_speed_multiplier if movement_settings else 0.5
		speed *= mult
	return speed


## Get the current GaitData for the active gait.
func get_current_gait_data() -> GaitData:
	return _get_current_gait_data()


## Get current velocity (for duck typing / pose warping integration).
func get_velocity() -> Vector3:
	return actual_velocity


## Get current speed (for duck typing / pose warping integration).
func get_speed() -> float:
	return actual_velocity.length()


## Call when movement_settings resource changes.
func refresh_settings() -> void:
	_detect_body_type()
