class_name OrbitCameraController3D
extends Node
## Orbit camera controller for third-person view.
##
## Orbits around a target node with configurable distance, collision, and smoothing.
## Reads input from PlayerInputRouter3D.


@export_group("References")
## The node to orbit around (typically a point on the character).
@export var target: Node3D
## The camera to control.
@export var camera: Camera3D
## Input router for mouse look (from core addon).
@export var input_router: PlayerInputRouter3D

@export_group("Settings")
## Camera tuning values. If null, uses defaults.
@export var camera_settings: OrbitCameraSettings3D

## Whether the camera controller is enabled.
var enabled: bool = true:
	set(value):
		enabled = value
		set_physics_process(value)

## Current yaw angle in radians.
var yaw: float = 0.0
## Current pitch angle in radians.
var pitch: float = 0.3 # Slight downward angle by default
## Current distance from target.
var current_distance: float = 5.0

# Cached settings
var _default_distance: float = 5.0
var _min_distance: float = 1.5
var _max_distance: float = 10.0
var _height_offset: float = 1.5
var _orbit_sensitivity: float = 0.003
var _min_pitch: float = -1.2
var _max_pitch: float = 1.4
var _follow_smoothing: float = 10.0
var _collision_mask: int = 1
var _collision_margin: float = 0.2


func _ready() -> void:
	_cache_settings()
	_validate_dependencies()
	current_distance = _default_distance


func _validate_dependencies() -> void:
	if not target:
		push_warning("OrbitCameraController3D: 'target' is not assigned.")
	if not camera:
		push_warning("OrbitCameraController3D: 'camera' is not assigned.")
	if not input_router:
		push_warning("OrbitCameraController3D: 'input_router' is not assigned.")


func _cache_settings() -> void:
	if camera_settings:
		_default_distance = camera_settings.default_distance
		_min_distance = camera_settings.min_distance
		_max_distance = camera_settings.max_distance
		_height_offset = camera_settings.height_offset
		_orbit_sensitivity = camera_settings.orbit_sensitivity
		_min_pitch = camera_settings.min_pitch
		_max_pitch = camera_settings.max_pitch
		_follow_smoothing = camera_settings.follow_smoothing
		_collision_mask = camera_settings.collision_mask
		_collision_margin = camera_settings.collision_margin


func _physics_process(delta: float) -> void:
	if not enabled or not target or not camera:
		return
	
	# Get look input from router
	if input_router:
		var look_delta := input_router.consume_look_delta()
		
		# Apply yaw/pitch from mouse input
		yaw -= look_delta.x * _orbit_sensitivity
		pitch -= look_delta.y * _orbit_sensitivity
		pitch = clamp(pitch, _min_pitch, _max_pitch)
	
	# Calculate camera position
	var offset := Vector3.ZERO
	offset.z = current_distance
	offset = offset.rotated(Vector3.RIGHT, pitch)
	offset = offset.rotated(Vector3.UP, yaw)
	
	var target_pos := target.global_position + Vector3(0, _height_offset, 0)
	var desired_pos := target_pos + offset
	
	# Check for camera collision
	desired_pos = _check_collision(target_pos, desired_pos)
	
	# Smooth follow
	camera.global_position = camera.global_position.lerp(desired_pos, _follow_smoothing * delta)
	
	# Look at target
	camera.look_at(target_pos)


func _check_collision(from: Vector3, to: Vector3) -> Vector3:
	if not target:
		return to
	
	var space_state := target.get_world_3d().direct_space_state
	if not space_state:
		return to
	
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = _collision_mask
	
	# Exclude the target's body if it's a physics object
	var target_parent := target.get_parent()
	if target_parent is CollisionObject3D:
		query.exclude = [target_parent.get_rid()]
	
	var result := space_state.intersect_ray(query)
	if result:
		# Move camera to collision point with margin
		var direction := (from - to).normalized()
		return result.position + direction * _collision_margin
	
	return to


## Set camera distance (clamped to min/max).
func set_distance(distance: float) -> void:
	current_distance = clamp(distance, _min_distance, _max_distance)


## Reset orbit angles to defaults.
func reset_orbit() -> void:
	yaw = 0.0
	pitch = 0.3
	current_distance = _default_distance


## Call when camera_settings resource changes.
func refresh_settings() -> void:
	_cache_settings()
