@tool
class_name MovementSettings3D
extends Resource
## Tuning values for player movement physics.
##
## Create a .tres file to customize movement feel per project or character.
## Used by both FPS and third-person controllers.


@export_group("Speed")
## Walking speed in units per second.
@export_range(0.0, 50.0, 0.1) var walk_speed: float = 5.0
## Sprinting speed in units per second.
@export_range(0.0, 50.0, 0.1) var sprint_speed: float = 8.0
## Crouching speed in units per second.
@export_range(0.0, 50.0, 0.1) var crouch_speed: float = 2.5

@export_group("Acceleration")
## How quickly the player reaches target speed (units/second²).
@export_range(0.0, 100.0, 0.5) var acceleration: float = 25.0
## How quickly the player stops when no input (units/second²).
@export_range(0.0, 100.0, 0.5) var deceleration: float = 30.0
## Movement control multiplier while airborne (0 = no air control, 1 = full).
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.3

@export_group("Jump & Gravity")
## Upward velocity applied when jumping.
@export_range(0.0, 20.0, 0.1) var jump_velocity: float = 4.5
## Gravity strength (positive = downward).
@export_range(0.0, 50.0, 0.1) var gravity: float = 9.8

@export_group("Jump Feel")
## Grace period after leaving platform where jump still works (coyote time).
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.1
## How long a jump input is buffered before landing.
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.1

@export_group("Crouch")
## Height of collision shape when crouching.
@export_range(0.0, 3.0, 0.1) var crouch_height: float = 1.0
## Height of collision shape when standing.
@export_range(0.0, 3.0, 0.1) var stand_height: float = 1.8

@export_group("State Timing")
## Grace period after landing before movement animations resume.
@export_range(0.0, 1.0, 0.05) var landing_grace_time: float = 0.5
## Minimum time in air before landing can be detected (prevents false positives).
@export_range(0.0, 0.5, 0.01) var min_airtime: float = 0.1


@export_group("RigidBody Settings")
## Force multiplier for RigidBody movement (higher = snappier).
@export_range(1.0, 200.0, 1.0) var rigid_body_force_multiplier: float = 50.0
## Raycast distance for RigidBody ground detection.
@export_range(0.05, 0.5, 0.01) var rigid_body_ground_raycast_distance: float = 0.1


@export_group("Rotate in Place")
## Enable rotate-in-place animations when camera exceeds angle threshold.
@export var enable_rotate_in_place: bool = false
## Angle threshold (degrees) before triggering rotate-in-place.
@export_range(30.0, 180.0, 5.0) var rotation_threshold_degrees: float = 90.0
## Rotation speed during rotate-in-place (degrees per second).
@export_range(60.0, 360.0, 10.0) var rotation_in_place_speed: float = 180.0
## Animation name for turning left.
@export var turn_left_animation: StringName = &"turn_left"
## Animation name for turning right.
@export var turn_right_animation: StringName = &"turn_right"


@export_group("Stance Overrides")
## Optional settings override for crouching (null = use base values).
@export var crouch_settings_override: MovementSettings3D
## Optional settings override for sprinting (null = use base values).
@export var sprint_settings_override: MovementSettings3D


## Get effective walk speed for current stance.
func get_walk_speed_for_stance(is_crouching: bool, is_sprinting: bool) -> float:
	if is_crouching and crouch_settings_override:
		return crouch_settings_override.walk_speed
	elif is_sprinting and sprint_settings_override:
		return sprint_settings_override.walk_speed
	return walk_speed


## Get effective acceleration for current stance.
func get_acceleration_for_stance(is_crouching: bool, is_sprinting: bool) -> float:
	if is_crouching and crouch_settings_override:
		return crouch_settings_override.acceleration
	elif is_sprinting and sprint_settings_override:
		return sprint_settings_override.acceleration
	return acceleration


## Get effective deceleration for current stance.
func get_deceleration_for_stance(is_crouching: bool, is_sprinting: bool) -> float:
	if is_crouching and crouch_settings_override:
		return crouch_settings_override.deceleration
	elif is_sprinting and sprint_settings_override:
		return sprint_settings_override.deceleration
	return deceleration
