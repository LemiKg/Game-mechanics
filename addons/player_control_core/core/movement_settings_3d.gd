@tool
class_name MovementSettings3D
extends Resource
## Tuning values for player movement physics.
##
## Create a .tres file to customize movement feel per project or character.
## Uses GaitData resources for per-gait tuning (walk, run, sprint).


# =============================================================================
# GAIT DATA
# =============================================================================

@export_group("Gait: Walk")
## Movement tuning for walking gait.
@export var gait_walk: GaitData

@export_group("Gait: Run")
## Movement tuning for running gait.
@export var gait_run: GaitData

@export_group("Gait: Sprint")
## Movement tuning for sprinting gait.
@export var gait_sprint: GaitData


# =============================================================================
# STANCE
# =============================================================================

@export_group("Stance")
## Speed multiplier when crouching (applied on top of gait speed).
@export_range(0.1, 1.0, 0.05) var stance_crouch_speed_multiplier: float = 0.5

## Movement control multiplier while airborne (0 = no air control, 1 = full).
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.3


# =============================================================================
# JUMP & GRAVITY
# =============================================================================

@export_group("Jump & Gravity")
## Upward velocity applied when jumping.
@export_range(0.0, 20.0, 0.1) var jump_velocity: float = 4.5
## Gravity strength (positive = downward).
@export_range(0.0, 50.0, 0.1) var gravity: float = 9.8


# =============================================================================
# JUMP FEEL
# =============================================================================

@export_group("Jump Feel")
## Velocity.y multiplied by this on early jump release (lower = shorter hop).
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier: float = 0.5
## Gravity multiplier when falling (higher = snappier landing).
@export_range(1.0, 5.0, 0.1) var fall_gravity_multiplier: float = 1.8
## Gravity multiplier when ascending with jump released (higher = faster peak).
@export_range(1.0, 5.0, 0.1) var jump_cut_gravity_multiplier: float = 2.5
## Grace period after leaving platform where jump still works (coyote time).
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.1
## How long a jump input is buffered before landing.
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.1


# =============================================================================
# SLOPES
# =============================================================================

@export_group("Slopes")
## Uphill speed penalty factor (0.3 = 30% slower at max slope).
@export_range(0.0, 1.0, 0.05) var slope_speed_reduction: float = 0.3
## Downhill speed bonus factor (0.15 = 15% faster at max slope).
@export_range(0.0, 1.0, 0.05) var downhill_speed_boost: float = 0.15
## Maximum walkable slope angle in degrees. Above this, character slides.
@export_range(15.0, 60.0, 1.0) var max_walkable_slope: float = 45.0


# =============================================================================
# CROUCH
# =============================================================================

@export_group("Crouch")
## Height of collision shape when crouching.
@export_range(0.0, 3.0, 0.1) var crouch_height: float = 1.0
## Height of collision shape when standing.
@export_range(0.0, 3.0, 0.1) var stand_height: float = 1.8


# =============================================================================
# STATE TIMING
# =============================================================================

@export_group("State Timing")
## Grace period after landing before movement animations resume.
@export_range(0.0, 1.0, 0.05) var landing_grace_time: float = 0.5
## Minimum time in air before landing can be detected.
@export_range(0.0, 0.5, 0.01) var min_airtime: float = 0.1


# =============================================================================
# RIGIDBODY
# =============================================================================

@export_group("RigidBody Settings")
## Force multiplier for RigidBody movement.
@export_range(1.0, 200.0, 1.0) var rigid_body_force_multiplier: float = 50.0
## Raycast distance for RigidBody ground detection.
@export_range(0.05, 0.5, 0.01) var rigid_body_ground_raycast_distance: float = 0.1


# =============================================================================
# ROTATE IN PLACE
# =============================================================================

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


# =============================================================================
# HELPERS
# =============================================================================

## Get GaitData for a given gait enum value (from PlayerMotor3D.Gait).
## Returns walk data as fallback if the requested gait data is null.
func get_gait_data(gait: int) -> GaitData:
	match gait:
		0: return gait_walk if gait_walk else _default_walk()
		1: return gait_run if gait_run else _default_run()
		2: return gait_sprint if gait_sprint else _default_sprint()
	return gait_walk if gait_walk else _default_walk()


static func _default_walk() -> GaitData:
	var d := GaitData.new()
	d.speed = 2.5; d.acceleration = 20.0; d.deceleration = 25.0; d.rotation_rate = 360.0
	return d

static func _default_run() -> GaitData:
	var d := GaitData.new()
	d.speed = 5.0; d.acceleration = 25.0; d.deceleration = 30.0; d.rotation_rate = 300.0
	return d

static func _default_sprint() -> GaitData:
	var d := GaitData.new()
	d.speed = 8.0; d.acceleration = 15.0; d.deceleration = 35.0; d.rotation_rate = 180.0
	return d
