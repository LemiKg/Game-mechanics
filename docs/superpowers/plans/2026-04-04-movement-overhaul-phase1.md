# Movement Overhaul Phase 1: Core Physics & Game Feel

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace flat speed/acceleration model with orthogonal gait/stance composition and per-gait physics data, add variable jump height, enhanced fall gravity, and slope handling.

**Architecture:** Add `GaitData` resource and `Gait`/`Stance` enums to `PlayerMotor3D`. Replace `move_toward()` with lerp-based acceleration using per-gait values. Modify `AirborneState` for jump feel. Keep existing state machine pattern — only change what's inside states.

**Tech Stack:** GDScript, Godot 4.5, CharacterBody3D

**Spec:** `docs/superpowers/specs/2026-04-04-movement-overhaul-design.md` (Section 1 & 2)

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `addons/player_control_core/core/gait_data.gd` | Create | Per-gait speed/accel/decel/rotation resource |
| `addons/player_control_core/core/movement_settings_3d.gd` | Modify | Add gait dictionary, jump feel params, slope params |
| `addons/player_control_core/core/player_motor_3d.gd` | Modify | Gait/stance enums, per-gait physics, slope handling, enhanced gravity, AI API |
| `addons/player_control_core/core/player_input_router_3d.gd` | Modify | Add dodge input action |
| `addons/player_control_core/core/state_machine/grounded_state.gd` | Modify | Use motor gait/stance enums instead of local booleans |
| `addons/player_control_core/core/state_machine/airborne_state.gd` | Modify | Variable jump height, enhanced fall gravity |
| `addons/player_control_core/player_control_core_plugin.gd` | Modify | Register GaitData |

---

### Task 1: Create GaitData Resource

**Files:**
- Create: `addons/player_control_core/core/gait_data.gd`

- [ ] **Step 1: Create the GaitData resource file**

```gdscript
@tool
class_name GaitData
extends Resource
## Per-gait movement tuning values.
##
## Each gait (walk, run, sprint) has its own speed, acceleration,
## deceleration, and rotation rate. Create as .tres files or inline
## in MovementSettings3D.


## Target movement speed for this gait (units/second).
@export_range(0.0, 50.0, 0.1) var speed: float = 5.0

## How fast the player reaches target speed (units/second²).
@export_range(0.0, 100.0, 0.5) var acceleration: float = 25.0

## How fast the player stops when no input (units/second²).
@export_range(0.0, 100.0, 0.5) var deceleration: float = 30.0

## How fast the body turns to face movement direction (degrees/second).
@export_range(0.0, 720.0, 5.0) var rotation_rate: float = 360.0
```

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/core/gait_data.gd
git commit -m "feat: add GaitData resource for per-gait movement tuning"
```

---

### Task 2: Add Gait/Stance Enums and New Fields to MovementSettings3D

**Files:**
- Modify: `addons/player_control_core/core/movement_settings_3d.gd`

- [ ] **Step 1: Read the current file**

Read `addons/player_control_core/core/movement_settings_3d.gd`.

- [ ] **Step 2: Replace the file contents**

The key changes:
- Remove flat `walk_speed`, `sprint_speed`, `crouch_speed`, `acceleration`, `deceleration` fields
- Remove `get_walk_speed_for_stance()`, `get_acceleration_for_stance()`, `get_deceleration_for_stance()` methods
- Remove `crouch_settings_override`, `sprint_settings_override`
- Add `gait_walk`, `gait_run`, `gait_sprint` as `GaitData` exports
- Add `stance_crouch_speed_multiplier`
- Add jump feel params: `jump_cut_multiplier`, `fall_gravity_multiplier`, `jump_cut_gravity_multiplier`
- Add slope params: `slope_speed_reduction`, `downhill_speed_boost`, `max_walkable_slope`

Replace the entire file with:

```gdscript
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
```

- [ ] **Step 3: Commit**

```bash
git add addons/player_control_core/core/movement_settings_3d.gd
git commit -m "refactor: replace flat speed fields with GaitData-based movement settings"
```

---

### Task 3: Add Gait/Stance Enums and Rework PlayerMotor3D

**Files:**
- Modify: `addons/player_control_core/core/player_motor_3d.gd`

This is the biggest change. The motor gets gait/stance enums, per-gait physics, slope handling, and an AI-friendly movement API.

- [ ] **Step 1: Read the current file completely**

Read `addons/player_control_core/core/player_motor_3d.gd`.

- [ ] **Step 2: Replace the file contents**

Key changes from old version:
- Add `enum Gait { WALK, RUN, SPRINT }` and `enum Stance { STANDING, CROUCHING }`
- Replace `current_speed` with computed property from gait + stance
- Replace `move_toward()` acceleration with lerp-based per-gait acceleration
- Add slope speed adjustment using `body.get_floor_normal()`
- Add enhanced gravity methods: `apply_gravity_enhanced(delta, jump_held)`
- Add AI API methods: `move_in_direction()`, `request_jump()`, `set_gait()`, `set_stance()`
- Remove `set_walk_speed()`, `set_sprint_speed()`, `set_crouch_speed()` (replaced by gait/stance setters)
- Keep `_calculate_actual_velocity()` for pose warping

Replace the entire file with:

```gdscript
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

	# Determine if going uphill or downhill by dot product of move dir and floor tangent
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


## Apply simple gravity (for backwards compatibility / non-enhanced use).
func apply_gravity(delta: float) -> void:
	if not body:
		return
	match _body_type:
		BodyType.CHARACTER_BODY:
			var g := movement_settings.gravity if movement_settings else 9.8
			body.velocity.y -= g * delta
		BodyType.RIGID_BODY:
			pass # Godot handles RigidBody gravity


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
```

- [ ] **Step 3: Commit**

```bash
git add addons/player_control_core/core/player_motor_3d.gd
git commit -m "refactor: rework PlayerMotor3D with gait/stance enums, per-gait physics, slope handling, AI API"
```

---

### Task 4: Update GroundedState to Use Gait/Stance Enums

**Files:**
- Modify: `addons/player_control_core/core/state_machine/grounded_state.gd`

Replace inline `is_sprinting`/`is_crouching` booleans with motor's gait/stance enums.

- [ ] **Step 1: Read the current file**

Read `addons/player_control_core/core/state_machine/grounded_state.gd`.

- [ ] **Step 2: Replace the file contents**

Key changes:
- Remove `is_sprinting`, `is_crouching` booleans
- Use `motor.gait` and `motor.stance` instead
- `_update_movement_modifiers()` sets motor.gait and motor.stance based on input
- Animation logic uses motor.gait and motor.stance
- Keep rotate-in-place, landing grace, and jump handling

```gdscript
class_name GroundedState
extends PlayerState
## Active when the player is on the floor.
##
## Handles gait selection (walk/run/sprint), stance (stand/crouch),
## jumping, and rotate-in-place. Transitions to Airborne when jumping or falling.


## Track last animation to avoid redundant requests.
var _current_animation: StringName = &""

## Grace period after landing to ignore brief "not grounded" moments.
var _landing_grace_timer: float = 0.0

## Whether we just landed (skip immediate animation update).
var _just_landed: bool = false

## Whether currently in a rotate-in-place turn.
var _is_rotating_in_place: bool = false

## Target yaw for rotate-in-place.
var _rotation_target: float = 0.0

## Debug logger for this state.
var _logger := DebugLogger.new("[GroundedState]")


func enter() -> void:
	_logger.debug("ENTER")
	_current_animation = &""
	_is_rotating_in_place = false
	if motor:
		motor.gait = PlayerMotor3D.Gait.RUN
		motor.stance = PlayerMotor3D.Stance.STANDING

	var grace_time := movement_settings.landing_grace_time if movement_settings else 0.5
	_landing_grace_timer = grace_time
	_just_landed = true


func exit() -> void:
	_is_rotating_in_place = false


func physics_update(delta: float) -> void:
	if not motor or not input_router:
		return

	# Countdown landing grace period
	if _landing_grace_timer > 0:
		_landing_grace_timer -= delta
		var has_movement := input_router.movement_intent.length() > 0.3
		if has_movement and _landing_grace_timer < 0.35:
			_landing_grace_timer = 0

		if _landing_grace_timer <= 0:
			_just_landed = false
			_update_animation()

	# Check if we fell off a ledge
	if not motor.is_grounded and _landing_grace_timer <= 0:
		transition_to(&"airborne")
		return

	# Update gait and stance from input
	_update_movement_modifiers()

	# Rotate-in-place
	if movement_settings and movement_settings.enable_rotate_in_place:
		if not motor.is_moving:
			_check_rotate_in_place(delta)
		else:
			_is_rotating_in_place = false

	# Handle jump
	var jump_consumed := input_router.consume_jump() or motor.consume_direct_jump()
	if jump_consumed:
		if motor.try_jump():
			request_animation(&"jump", 0.1)
			transition_to(&"airborne")
			return

	# Update animation
	if not _just_landed:
		_update_animation()


func _update_movement_modifiers() -> void:
	if not input_router or not motor:
		return

	# Stance: crouch input
	if input_router.crouch_held:
		motor.stance = PlayerMotor3D.Stance.CROUCHING
	else:
		motor.stance = PlayerMotor3D.Stance.STANDING

	# Gait: sprint takes priority, then run (default), walk if desired
	# Cannot sprint while crouching
	if input_router.sprint_held and motor.stance != PlayerMotor3D.Stance.CROUCHING:
		motor.gait = PlayerMotor3D.Gait.SPRINT
	else:
		motor.gait = PlayerMotor3D.Gait.RUN


func _update_animation() -> void:
	if not input_router or not motor:
		return

	var new_animation: StringName
	var has_movement := input_router.movement_intent.length() > 0.1

	if motor.stance == PlayerMotor3D.Stance.CROUCHING:
		new_animation = &"crouch_idle" if not has_movement else &"crouch_walk"
	elif motor.gait == PlayerMotor3D.Gait.SPRINT and has_movement:
		new_animation = &"run"
	elif has_movement:
		new_animation = &"walk"
	else:
		new_animation = &"idle"

	if new_animation != _current_animation:
		_current_animation = new_animation
		request_animation(new_animation)


func _check_rotate_in_place(delta: float) -> void:
	var body_node := controller.body
	if not body_node:
		return

	var camera_yaw := _get_camera_yaw()
	var body_yaw := body_node.rotation.y
	var angle_diff := rad_to_deg(angle_difference(body_yaw, camera_yaw))
	var threshold := movement_settings.rotation_threshold_degrees

	if abs(angle_diff) > threshold and not _is_rotating_in_place:
		_is_rotating_in_place = true
		_rotation_target = camera_yaw
		var anim_name: StringName
		if angle_diff < 0:
			anim_name = movement_settings.turn_left_animation
		else:
			anim_name = movement_settings.turn_right_animation
		request_animation(anim_name, 0.1)
		_current_animation = anim_name

	if _is_rotating_in_place:
		var rotation_speed := deg_to_rad(movement_settings.rotation_in_place_speed)
		body_node.rotation.y = rotate_toward(body_node.rotation.y, _rotation_target, rotation_speed * delta)
		if abs(angle_difference(body_node.rotation.y, _rotation_target)) < deg_to_rad(5.0):
			_is_rotating_in_place = false
			request_animation(&"idle", 0.2)
			_current_animation = &"idle"


func _get_camera_yaw() -> float:
	if controller.has_method("get_camera_yaw"):
		return controller.get_camera_yaw()
	return 0.0
```

- [ ] **Step 3: Commit**

```bash
git add addons/player_control_core/core/state_machine/grounded_state.gd
git commit -m "refactor: use motor gait/stance enums instead of local sprint/crouch booleans"
```

---

### Task 5: Add Variable Jump Height and Enhanced Fall Gravity to AirborneState

**Files:**
- Modify: `addons/player_control_core/core/state_machine/airborne_state.gd`

- [ ] **Step 1: Read the current file**

Read `addons/player_control_core/core/state_machine/airborne_state.gd`.

- [ ] **Step 2: Replace the file contents**

Key changes:
- Track `_jump_held: bool` — set true on enter if jump action is held
- On jump release while ascending: call `motor.cut_jump()` for variable height
- Replace `motor.apply_gravity(delta)` with `motor.apply_gravity_enhanced(delta, _jump_held)`
- Check `motor.consume_direct_jump()` alongside `input_router.consume_jump()`

```gdscript
class_name AirborneState
extends PlayerState
## Active when the player is not on the floor.
##
## Applies enhanced gravity (snappier falls, variable jump height).
## Supports coyote time, jump buffering, and mantling.


@export_group("Mantling")
## Optional mantle detector for ledge climbing.
@export var mantle_detector: MantleDetector


## Time since leaving the ground (for coyote time).
var _time_since_left_ground: float = 0.0

## Whether coyote jump has been used.
var _coyote_used: bool = false

## Buffered jump request for landing.
var _jump_buffered: bool = false

## Time remaining on jump buffer.
var _jump_buffer_timer: float = 0.0

## Whether the jump button is currently held (for variable jump height).
var _jump_held: bool = false

## Whether we already cut the jump (prevent double-cut).
var _jump_cut_applied: bool = false

## Debug logger for this state.
var _logger := DebugLogger.new("[AirborneState]")


func enter() -> void:
	_logger.debug("ENTER")

	_time_since_left_ground = 0.0
	_coyote_used = false
	_jump_buffered = false
	_jump_buffer_timer = 0.0
	_jump_cut_applied = false

	# Check if jump is currently held (for variable jump height)
	if input_router:
		_jump_held = Input.is_action_pressed(input_router._jump)
	else:
		_jump_held = false

	request_animation(&"jump", 0.05)


func physics_update(delta: float) -> void:
	if not motor:
		return

	_time_since_left_ground += delta

	# Track jump button state for variable jump height
	if input_router:
		var was_held := _jump_held
		_jump_held = Input.is_action_pressed(input_router._jump)

		# Jump release while ascending — cut jump for short hop
		if was_held and not _jump_held and not _jump_cut_applied and motor.body.velocity.y > 0:
			motor.cut_jump()
			_jump_cut_applied = true

	# Handle jump input (coyote time or buffer)
	var jump_input := false
	if input_router:
		jump_input = input_router.consume_jump()
	if not jump_input:
		jump_input = motor.consume_direct_jump()

	if jump_input:
		if _can_coyote_jump():
			if motor.try_jump():
				_coyote_used = true
				_jump_held = true
				_jump_cut_applied = false
				request_animation(&"jump", 0.05)
		else:
			_jump_buffered = true
			_jump_buffer_timer = movement_settings.jump_buffer_time if movement_settings else 0.1

	# Decay jump buffer timer
	if _jump_buffered:
		_jump_buffer_timer -= delta
		if _jump_buffer_timer <= 0:
			_jump_buffered = false

	# Check for mantle
	if _should_check_mantle():
		var ledge_data := mantle_detector.check_for_ledge()
		if not ledge_data.is_empty():
			state_machine.set_meta("mantle_ledge_data", ledge_data)
			transition_to(&"mantle")
			return

	# Apply enhanced gravity (variable jump height + snappy falls)
	motor.apply_gravity_enhanced(delta, _jump_held)

	# Check if landed
	var min_airtime := movement_settings.min_airtime if movement_settings else 0.1
	if motor.is_grounded and _time_since_left_ground > min_airtime:
		_on_landed()
		return


func _should_check_mantle() -> bool:
	if not mantle_detector or not mantle_detector.is_configured():
		return false
	if not input_router:
		return false
	return input_router.movement_intent.y > 0.5


func _can_coyote_jump() -> bool:
	if _coyote_used:
		return false
	var coyote := movement_settings.coyote_time if movement_settings else 0.1
	return _time_since_left_ground <= coyote


func _on_landed() -> void:
	if _jump_buffered:
		if motor.try_jump():
			request_animation(&"jump", 0.05)
			_time_since_left_ground = 0.0
			_coyote_used = false
			_jump_buffered = false
			_jump_held = true
			_jump_cut_applied = false
			return

	request_animation(&"land", 0.05)
	transition_to(&"grounded")
```

- [ ] **Step 3: Commit**

```bash
git add addons/player_control_core/core/state_machine/airborne_state.gd
git commit -m "feat: add variable jump height and enhanced fall gravity to AirborneState"
```

---

### Task 6: Add Dodge Input to PlayerInputRouter3D

**Files:**
- Modify: `addons/player_control_core/core/player_input_router_3d.gd`

- [ ] **Step 1: Read the current file**

Read `addons/player_control_core/core/player_input_router_3d.gd`.

- [ ] **Step 2: Add dodge input handling**

Add these properties alongside the existing ones:

After `var crouch_held: bool = false` (line 42), add:
```gdscript
## True if dodge was requested (buffered for physics frame).
var dodge_requested: bool = false
## Internal buffer for dodge input.
var _dodge_buffered: bool = false
```

Add `var _dodge: StringName = &"dodge"` after the existing cached action names (after line 55).

In `_cache_action_names()`, add after the crouch line:
```gdscript
		if "dodge" in input_actions:
			_dodge = input_actions.dodge
```

In `_process()`, add after the crouch_held line:
```gdscript
	if Input.is_action_just_pressed(_dodge):
		_dodge_buffered = true
```

In `_physics_process()`, add after the `_jump_buffered = false` line:
```gdscript
	dodge_requested = _dodge_buffered
	_dodge_buffered = false
```

Add a consume method after `consume_jump()`:
```gdscript
## Consume and clear the dodge request. Returns true if dodge was requested.
func consume_dodge() -> bool:
	var was_requested := dodge_requested
	dodge_requested = false
	return was_requested
```

In the `enabled` setter's clear block, add:
```gdscript
			dodge_requested = false
			_dodge_buffered = false
```

- [ ] **Step 3: Commit**

```bash
git add addons/player_control_core/core/player_input_router_3d.gd
git commit -m "feat: add dodge input action to PlayerInputRouter3D"
```

---

### Task 7: Register GaitData in Plugin

**Files:**
- Modify: `addons/player_control_core/player_control_core_plugin.gd`

- [ ] **Step 1: Read the current plugin file**

Read `addons/player_control_core/player_control_core_plugin.gd`.

- [ ] **Step 2: Add GaitData registration**

In `_enter_tree()`, add after the MantleSettings3D registration (before the closing of the function):

```gdscript
	add_custom_type(
		"GaitData",
		"Resource",
		preload("res://addons/player_control_core/core/gait_data.gd"),
		preload("res://addons/player_control_core/icons/settings.svg")
	)
```

In `_exit_tree()`, add after `remove_custom_type("MantleSettings3D")`:

```gdscript
	remove_custom_type("GaitData")
```

- [ ] **Step 3: Commit**

```bash
git add addons/player_control_core/player_control_core_plugin.gd
git commit -m "feat: register GaitData resource type in plugin"
```

---

### Task 8: Fix Compile Errors and Verify

**Files:**
- Potentially any file that references removed properties

The old `PlayerMotor3D` had `set_walk_speed()`, `set_sprint_speed()`, `set_crouch_speed()`, and `current_speed`. These are removed. Any code still calling them needs updating.

- [ ] **Step 1: Search for references to removed methods**

Search the codebase for:
- `set_walk_speed` 
- `set_sprint_speed`
- `set_crouch_speed`
- `motor.current_speed`
- `walk_speed` / `sprint_speed` / `crouch_speed` (on MovementSettings3D)

Fix any remaining references:
- `set_walk_speed()` → `motor.gait = PlayerMotor3D.Gait.RUN`
- `set_sprint_speed()` → `motor.gait = PlayerMotor3D.Gait.SPRINT`  
- `set_crouch_speed()` → `motor.stance = PlayerMotor3D.Stance.CROUCHING`
- `current_speed` → `motor.get_target_speed()`
- `movement_settings.walk_speed` → `movement_settings.get_gait_data(0).speed`

Check these files specifically:
- `addons/player_control_core/core/state_machine/mantle_state.gd`
- `addons/player_control_core/core/state_machine/ui_state.gd`
- `addons/player_control_core/core/base_player_controller_3d.gd`
- `addons/player_control_core/core/dual_perspective_controller_3d.gd`
- `addons/pose_warping/core/pose_warping_settings.gd` (base_walk_speed/base_sprint_speed)
- `scenes/reusable_player.gd`

- [ ] **Step 2: Fix all compile errors**

Update each file to use the new gait/stance API.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix: update all references to removed motor speed methods"
```
