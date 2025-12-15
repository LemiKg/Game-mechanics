class_name PlayerLookController3D
extends Node
## Applies yaw and pitch rotation from mouse input to the FPS rig.
##
## Maintains internal yaw/pitch accumulators and applies them to
## the body (yaw) and pitch pivot (pitch) nodes.
## Note: Requires player_control_core addon to be enabled.


@export_group("References")
## The node to apply yaw rotation to (typically the CharacterBody3D).
@export var yaw_node: Node3D
## The node to apply pitch rotation to (typically a camera pivot).
@export var pitch_node: Node3D
## The input router to read look delta from (from core addon).
@export var input_router: PlayerInputRouter3D

@export_group("Settings")
## Look tuning values. If null, uses defaults.
@export var look_settings: FPSLookSettings3D

## Whether the look controller is enabled.
var enabled: bool = true:
	set(value):
		enabled = value
		set_physics_process(value)

## Current yaw angle in radians.
var yaw: float = 0.0
## Current pitch angle in radians.
var pitch: float = 0.0

# Cached settings
var _sensitivity: float = 0.002
var _invert_y: bool = false
var _min_pitch: float = -1.553 # ~-89 degrees in radians
var _max_pitch: float = 1.553 # ~89 degrees in radians


func _ready() -> void:
	_cache_settings()
	_validate_dependencies()
	_initialize_angles()


func _validate_dependencies() -> void:
	if not yaw_node:
		push_warning("PlayerLookController3D: 'yaw_node' is not assigned. Look will not function.")
	if not pitch_node:
		push_warning("PlayerLookController3D: 'pitch_node' is not assigned. Look will not function.")
	if not input_router:
		push_warning("PlayerLookController3D: 'input_router' is not assigned. Look will not function.")


func _cache_settings() -> void:
	if look_settings:
		_sensitivity = look_settings.mouse_sensitivity
		_invert_y = look_settings.invert_y
		_min_pitch = deg_to_rad(look_settings.min_pitch_degrees)
		_max_pitch = deg_to_rad(look_settings.max_pitch_degrees)


func _initialize_angles() -> void:
	# Initialize accumulators from current node rotations
	if yaw_node:
		yaw = yaw_node.rotation.y
	if pitch_node:
		pitch = pitch_node.rotation.x


func _physics_process(_delta: float) -> void:
	if not enabled or not input_router:
		return
	
	var look_delta := input_router.consume_look_delta()
	if look_delta == Vector2.ZERO:
		return
	
	# Apply yaw (horizontal mouse movement)
	yaw -= look_delta.x * _sensitivity
	
	# Apply pitch (vertical mouse movement)
	var pitch_direction := -1.0 if _invert_y else 1.0
	pitch -= look_delta.y * _sensitivity * pitch_direction
	
	# Clamp pitch to prevent camera flipping
	pitch = clamp(pitch, _min_pitch, _max_pitch)
	
	# Apply rotations to nodes
	if yaw_node:
		yaw_node.rotation.y = yaw
	if pitch_node:
		pitch_node.rotation.x = pitch


## Reset look angles to zero.
func reset_look() -> void:
	yaw = 0.0
	pitch = 0.0
	if yaw_node:
		yaw_node.rotation.y = yaw
	if pitch_node:
		pitch_node.rotation.x = pitch


## Set look angles directly (useful for respawn/teleport).
func set_look_angles(new_yaw: float, new_pitch: float) -> void:
	yaw = new_yaw
	pitch = clamp(new_pitch, _min_pitch, _max_pitch)
	if yaw_node:
		yaw_node.rotation.y = yaw
	if pitch_node:
		pitch_node.rotation.x = pitch


## Call when look_settings resource changes.
func refresh_settings() -> void:
	_cache_settings()
