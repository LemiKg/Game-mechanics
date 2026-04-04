class_name PoseWarpingController
extends Node
## Orchestrates all pose warping modifiers and manages velocity input.
##
## Reads velocity from any compatible source using duck typing and distributes
## warping data to SkeletonModifier3D nodes on the skeleton.
##
## Supports: CharacterBody3D, RigidBody3D, PlayerMotor3D, or any custom node
## with a get_velocity() method or velocity/actual_velocity/linear_velocity property.


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when warping activates (speed exceeds idle threshold).
signal warping_started()

## Emitted when warping deactivates (speed drops below idle threshold).
signal warping_stopped()

## Emitted every physics frame with current velocity data.
signal velocity_updated(velocity: Vector3, speed: float)


# =============================================================================
# DEPENDENCIES
# =============================================================================

@export_group("References")

## The skeleton to apply warping to. Must be assigned.
@export var skeleton: Skeleton3D

## Any node that provides velocity. Uses duck typing to detect velocity.
@export var velocity_source: Node

## Optional: Separate node for look direction. If null, uses velocity_source.
@export var direction_source: Node

## Optional: The CharacterBody3D or RigidBody3D for self-exclusion in raycasts.
## If null, attempts to find it from velocity_source.
@export var character_body: Node3D

@export_group("Modifiers")

## Reference to the stride warping modifier on the Skeleton3D.
@export var stride_modifier: SkeletonModifier3D

## Reference to the orientation warping modifier on the Skeleton3D.
@export var orientation_modifier: SkeletonModifier3D

## Reference to the slope warping modifier on the Skeleton3D.
@export var slope_modifier: SkeletonModifier3D

@export_group("Settings")

## Shared settings resource for all warping behavior.
@export var settings: PoseWarpingSettings


# =============================================================================
# PUBLIC STATE
# =============================================================================

## Enable or disable all warping.
var enabled: bool = true

## Current velocity from the velocity source.
var current_velocity: Vector3 = Vector3.ZERO

## Current horizontal speed.
var current_speed: float = 0.0

## Normalized movement direction (horizontal plane).
var movement_direction: Vector3 = Vector3.ZERO

## Normalized look/aim direction.
var look_direction: Vector3 = Vector3.FORWARD

## Whether warping is currently active.
var is_warping: bool = false


# =============================================================================
# PRIVATE STATE
# =============================================================================

## Cached RID for raycast self-exclusion.
var _character_rid: RID


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if not settings:
		push_warning("PoseWarpingController: 'settings' is not assigned. Using defaults.")
		settings = PoseWarpingSettings.new()
	if not skeleton:
		push_warning("PoseWarpingController: 'skeleton' is not assigned.")
	if not velocity_source:
		push_warning("PoseWarpingController: 'velocity_source' is not assigned.")
	_cache_character_rid()


func _physics_process(delta: float) -> void:
	if not enabled or not skeleton or not velocity_source or not settings:
		return

	_update_velocity()
	_update_directions()
	_distribute_to_modifiers(delta)


# =============================================================================
# SETUP
# =============================================================================

func _cache_character_rid() -> void:
	# Try explicit reference first
	var body: Node3D = character_body
	# Fallback: check if velocity_source has a body reference (PlayerMotor3D pattern)
	if not body and velocity_source and "body" in velocity_source:
		body = velocity_source.body
	# Fallback: check if velocity_source is itself a physics body
	if not body and velocity_source is CharacterBody3D:
		body = velocity_source
	if body and body.has_method("get_rid"):
		_character_rid = body.get_rid()


# =============================================================================
# VELOCITY DETECTION (DUCK TYPING)
# =============================================================================

func _update_velocity() -> void:
	current_velocity = _get_velocity_from_source()
	# Horizontal speed only (ignore vertical component)
	current_speed = Vector2(current_velocity.x, current_velocity.z).length()
	velocity_updated.emit(current_velocity, current_speed)


func _get_velocity_from_source() -> Vector3:
	# Try method first (most explicit)
	if velocity_source.has_method("get_velocity"):
		return velocity_source.get_velocity()
	# Try common velocity properties
	if "actual_velocity" in velocity_source:
		return velocity_source.actual_velocity
	if "velocity" in velocity_source:
		return velocity_source.velocity
	if "linear_velocity" in velocity_source:
		return velocity_source.linear_velocity
	if velocity_source.has_method("get_linear_velocity"):
		return velocity_source.get_linear_velocity()
	return Vector3.ZERO


# =============================================================================
# DIRECTION DETECTION
# =============================================================================

func _update_directions() -> void:
	var horizontal_velocity := Vector3(current_velocity.x, 0.0, current_velocity.z)
	if horizontal_velocity.length_squared() > 0.001:
		movement_direction = horizontal_velocity.normalized()

	look_direction = _get_look_direction()


func _get_look_direction() -> Vector3:
	var source: Node = direction_source if direction_source else velocity_source
	if not source:
		return Vector3.FORWARD

	if source.has_method("get_look_direction"):
		return source.get_look_direction()
	if source is Node3D:
		return -source.global_basis.z

	if not movement_direction.is_zero_approx():
		return movement_direction
	return Vector3.FORWARD


# =============================================================================
# MODIFIER DISTRIBUTION
# =============================================================================

func _distribute_to_modifiers(delta: float) -> void:
	var should_warp := current_speed > settings.idle_speed_threshold

	if should_warp != is_warping:
		is_warping = should_warp
		if is_warping:
			warping_started.emit()
		else:
			warping_stopped.emit()

	# Orientation modifier
	if orientation_modifier and orientation_modifier.has_method("update_warping"):
		orientation_modifier.update_warping(
			movement_direction, look_direction, is_warping, settings, delta
		)

	# Stride modifier
	if stride_modifier and stride_modifier.has_method("update_warping"):
		stride_modifier.update_warping(
			current_velocity, current_speed, is_warping, settings, delta
		)

	# Slope modifier
	if slope_modifier and slope_modifier.has_method("update_warping"):
		var char_position := Vector3.ZERO
		if velocity_source is Node3D:
			char_position = velocity_source.global_position
		elif character_body:
			char_position = character_body.global_position
		slope_modifier.update_warping(
			char_position, _character_rid, is_warping, settings, delta
		)


# =============================================================================
# PUBLIC API
# =============================================================================

## Manually override velocity (useful for networked characters or replays).
func set_velocity_override(velocity: Vector3) -> void:
	current_velocity = velocity
	current_speed = Vector2(velocity.x, velocity.z).length()
	velocity_updated.emit(current_velocity, current_speed)


## Force refresh of character RID cache.
func refresh_character_rid() -> void:
	_cache_character_rid()
