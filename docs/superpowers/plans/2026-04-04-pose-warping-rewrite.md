# Pose Warping System Rewrite - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the pose warping addon so stride warping scales IK foot positions (not FK bone origins), orientation warping uses signed angles, slope warping excludes self-collision, and all bone name defaults match the Quaternius skeleton.

**Architecture:** Controller + SkeletonModifier3D pattern. PoseWarpingController reads velocity via duck typing from PlayerMotor3D and distributes data to three modifiers (Orientation, Stride, Slope) that are children of Skeleton3D. Modifiers process in tree order: orientation first, then stride, then slope.

**Tech Stack:** GDScript, Godot 4.5, SkeletonModifier3D API

**Spec:** `docs/superpowers/specs/2026-04-04-pose-warping-rewrite-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `addons/pose_warping/core/pose_warping_settings.gd` | Rewrite | Settings resource with correct bone names and stride fields |
| `addons/pose_warping/core/pose_warping_controller.gd` | Rewrite | Velocity/direction reading, modifier distribution |
| `addons/pose_warping/core/orientation_warping_modifier.gd` | Rewrite | Spine twist toward look direction using signed atan2 |
| `addons/pose_warping/core/stride_warping_modifier.gd` | Rewrite | Foot position scaling relative to hips + pelvis pull-down |
| `addons/pose_warping/core/slope_warping_modifier.gd` | Rewrite | Raycast foot placement with self-exclusion |
| `addons/pose_warping/default_pose_warping_settings.tres` | Create | Proper resource file with Quaternius defaults |
| `addons/pose_warping/pose_warping_plugin.gd` | No change | Already correct |

---

### Task 1: Rewrite PoseWarpingSettings

**Files:**
- Rewrite: `addons/pose_warping/core/pose_warping_settings.gd`

- [ ] **Step 1: Replace the entire file with the new settings resource**

```gdscript
class_name PoseWarpingSettings
extends Resource
## Centralized configuration for all pose warping behaviors.
##
## Assign this resource to PoseWarpingController. Settings are forwarded
## to each modifier automatically.


# =============================================================================
# STRIDE WARPING
# =============================================================================

@export_group("Stride Warping")

## Enable or disable stride warping.
@export var enable_stride_warping: bool = true

## The Walk animation's intended speed (m/s). Stride scales relative to this.
@export_range(0.1, 10.0, 0.1) var base_walk_speed: float = 2.0

## The Sprint animation's intended speed (m/s). Used when speed exceeds walk threshold.
@export_range(0.1, 20.0, 0.1) var base_sprint_speed: float = 5.0

## Maximum stride scale multiplier (1.2 = 20% stretch, industry standard).
@export_range(1.0, 1.5, 0.05) var max_speed_scale: float = 1.2

## Minimum stride scale multiplier (0.8 = 20% compression).
@export_range(0.5, 1.0, 0.05) var min_speed_scale: float = 0.8

## Minimum speed before stride warping activates.
@export_range(0.0, 2.0, 0.1) var min_speed_for_stride: float = 0.5

## How fast stride warping interpolates to target values.
@export_range(1.0, 30.0, 1.0) var stride_blend_speed: float = 10.0

## Foot bone names (end effectors to scale relative to hips).
@export var foot_bone_names: Array[String] = ["DEF-foot.L", "DEF-foot.R"]

## Hips bone name (reference point for foot offset calculation).
@export var hips_bone_name: String = "DEF-hips"

## Thigh bone names (for leg chain length calculation, same order as foot_bone_names).
@export var thigh_bone_names: Array[String] = ["DEF-thigh.L", "DEF-thigh.R"]

## Shin bone names (for leg chain length calculation, same order as foot_bone_names).
@export var shin_bone_names: Array[String] = ["DEF-shin.L", "DEF-shin.R"]

## Maximum pelvis pull-down distance when legs hyper-extend (meters in bone-local space).
@export_range(0.0, 1.0, 0.01) var max_stride_pelvis_pulldown: float = 0.3


# =============================================================================
# ORIENTATION WARPING
# =============================================================================

@export_group("Orientation Warping")

## Enable or disable orientation warping.
@export var enable_orientation_warping: bool = true

## Maximum angle (degrees) the spine can rotate toward look direction.
@export_range(0.0, 180.0, 5.0) var max_orientation_angle: float = 90.0

## How fast orientation warping interpolates to target values.
@export_range(1.0, 30.0, 1.0) var orientation_blend_speed: float = 10.0

## Names of spine bones to rotate. Order: lowest to highest.
@export var spine_bone_names: Array[String] = [
	"DEF-spine.001", "DEF-spine.002", "DEF-spine.003"
]

## Weight distribution for each spine bone. Should sum to ~1.0.
## Higher weight = more rotation applied to that bone.
@export var spine_weight_distribution: Array[float] = [0.25, 0.35, 0.40]


# =============================================================================
# SLOPE WARPING
# =============================================================================

@export_group("Slope Warping")

## Enable or disable slope warping. Disabled by default.
@export var enable_slope_warping: bool = false

## Length of downward raycast for ground detection.
@export_range(0.1, 3.0, 0.1) var slope_raycast_length: float = 1.5

## How fast feet adapt to terrain height changes.
@export_range(1.0, 30.0, 1.0) var slope_adaptation_speed: float = 10.0

## Collision mask for slope raycasts.
@export_flags_3d_physics var slope_collision_mask: int = 1

## Maximum pelvis height adjustment for slope (meters).
@export_range(0.0, 0.5, 0.01) var max_pelvis_offset: float = 0.3

## How much to rotate feet to align with ground normal (0-1).
@export_range(0.0, 1.0, 0.1) var foot_rotation_blend: float = 0.8

## Height offset from foot bone to ground contact point.
@export_range(0.0, 0.2, 0.01) var foot_height_offset: float = 0.05

## Raycast origin height above foot world position.
@export_range(0.0, 1.0, 0.1) var raycast_origin_height: float = 0.5


# =============================================================================
# THRESHOLDS
# =============================================================================

@export_group("Thresholds")

## Speed below which the character is considered idle (no warping applied).
@export_range(0.0, 1.0, 0.05) var idle_speed_threshold: float = 0.1
```

- [ ] **Step 2: Verify the file has no syntax errors**

Open the file in a text editor and confirm it parses as valid GDScript. Check that all `@export` annotations have correct types and ranges.

- [ ] **Step 3: Commit**

```bash
git add addons/pose_warping/core/pose_warping_settings.gd
git commit -m "refactor: rewrite PoseWarpingSettings with correct bone names and stride fields"
```

---

### Task 2: Create Default Settings Resource

**Files:**
- Create: `addons/pose_warping/default_pose_warping_settings.tres`

- [ ] **Step 1: Create the .tres resource file**

```tres
[gd_resource type="Resource" script_class="PoseWarpingSettings" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/pose_warping/core/pose_warping_settings.gd" id="1"]

[resource]
script = ExtResource("1")
enable_stride_warping = true
base_walk_speed = 2.0
base_sprint_speed = 5.0
max_speed_scale = 1.2
min_speed_scale = 0.8
min_speed_for_stride = 0.5
stride_blend_speed = 10.0
foot_bone_names = Array[String](["DEF-foot.L", "DEF-foot.R"])
hips_bone_name = "DEF-hips"
thigh_bone_names = Array[String](["DEF-thigh.L", "DEF-thigh.R"])
shin_bone_names = Array[String](["DEF-shin.L", "DEF-shin.R"])
max_stride_pelvis_pulldown = 0.3
enable_orientation_warping = true
max_orientation_angle = 90.0
orientation_blend_speed = 10.0
spine_bone_names = Array[String](["DEF-spine.001", "DEF-spine.002", "DEF-spine.003"])
spine_weight_distribution = Array[float]([0.25, 0.35, 0.4])
enable_slope_warping = false
slope_raycast_length = 1.5
slope_adaptation_speed = 10.0
slope_collision_mask = 1
max_pelvis_offset = 0.3
foot_rotation_blend = 0.8
foot_height_offset = 0.05
raycast_origin_height = 0.5
idle_speed_threshold = 0.1
```

- [ ] **Step 2: Commit**

```bash
git add addons/pose_warping/default_pose_warping_settings.tres
git commit -m "fix: create proper default_pose_warping_settings.tres (was empty)"
```

---

### Task 3: Rewrite PoseWarpingController

**Files:**
- Rewrite: `addons/pose_warping/core/pose_warping_controller.gd`

The controller is mostly sound. Key changes: remove auto-detect from children (modifiers live on Skeleton3D, not as controller children), pass `is_warping` state to modifiers so they can blend to zero smoothly, and pass character body RID for slope warping self-exclusion.

- [ ] **Step 1: Replace the entire file**

```gdscript
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
```

- [ ] **Step 2: Commit**

```bash
git add addons/pose_warping/core/pose_warping_controller.gd
git commit -m "refactor: rewrite PoseWarpingController with horizontal speed, RID caching, is_warping passthrough"
```

---

### Task 4: Rewrite OrientationWarpingModifier

**Files:**
- Rewrite: `addons/pose_warping/core/orientation_warping_modifier.gd`

Key changes: use `atan2` for signed angle instead of unsigned `angle_to()`, accept `is_warping` flag to blend to zero smoothly, accept settings per-frame.

- [ ] **Step 1: Replace the entire file**

```gdscript
class_name OrientationWarpingModifier
extends SkeletonModifier3D
## Rotates spine bones toward the look direction while legs follow movement.
##
## Computes the signed angle between movement and look directions on the
## horizontal plane, then distributes that rotation across spine bones
## using configurable weights.
##
## Must be a child of Skeleton3D. Receives updates from PoseWarpingController.


# =============================================================================
# CACHED STATE
# =============================================================================

## Cached indices of spine bones.
var _spine_bone_indices: Array[int] = []

## Cached weights for each spine bone.
var _spine_weights: Array[float] = []

## Current rotation offset being applied (radians, smoothed).
var _current_rotation: float = 0.0

## Target rotation offset (radians).
var _target_rotation: float = 0.0

## Cached settings reference (for bone re-caching on change).
var _cached_settings: PoseWarpingSettings

## Active settings for this frame.
var _settings: PoseWarpingSettings

## Whether the controller says we should be warping.
var _is_warping: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_cache_bone_indices.call_deferred()


func _cache_bone_indices() -> void:
	_spine_bone_indices.clear()
	_spine_weights.clear()

	var skeleton := get_skeleton()
	if not skeleton or not _settings:
		return

	for i in _settings.spine_bone_names.size():
		var bone_name: String = _settings.spine_bone_names[i]
		var idx := skeleton.find_bone(bone_name)
		if idx >= 0:
			_spine_bone_indices.append(idx)
			var weight: float
			if i < _settings.spine_weight_distribution.size():
				weight = _settings.spine_weight_distribution[i]
			else:
				weight = 1.0 / _settings.spine_bone_names.size()
			_spine_weights.append(weight)
		else:
			push_warning("OrientationWarpingModifier: Bone '%s' not found." % bone_name)


# =============================================================================
# UPDATE FROM CONTROLLER
# =============================================================================

## Called by PoseWarpingController each physics frame.
func update_warping(
	movement_dir: Vector3,
	look_dir: Vector3,
	is_warping: bool,
	settings: PoseWarpingSettings,
	delta: float
) -> void:
	_settings = settings
	_is_warping = is_warping

	# Re-cache bones if settings resource changed
	if _cached_settings != settings:
		_cached_settings = settings
		_cache_bone_indices()

	if not _settings or not _settings.enable_orientation_warping:
		_target_rotation = 0.0
	elif not is_warping or movement_dir.is_zero_approx() or look_dir.is_zero_approx():
		_target_rotation = 0.0
	else:
		# Signed angle from movement to look direction on horizontal plane.
		# atan2 gives us a proper signed result (-PI to PI).
		var move_angle := atan2(movement_dir.x, movement_dir.z)
		var look_angle := atan2(look_dir.x, look_dir.z)
		var angle_diff := _wrap_angle(look_angle - move_angle)

		# Clamp to max orientation angle
		var max_rad := deg_to_rad(_settings.max_orientation_angle)
		angle_diff = clampf(angle_diff, -max_rad, max_rad)

		_target_rotation = angle_diff

	# Smooth interpolation
	var blend_speed := _settings.orientation_blend_speed if _settings else 10.0
	_current_rotation = lerpf(_current_rotation, _target_rotation, delta * blend_speed)


## Wrap angle to [-PI, PI] range.
func _wrap_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


# =============================================================================
# SKELETON MODIFICATION
# =============================================================================

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if not skeleton or _spine_bone_indices.is_empty():
		return

	# Skip if rotation is negligible
	if absf(_current_rotation) < 0.001:
		return

	for i in _spine_bone_indices.size():
		var bone_idx: int = _spine_bone_indices[i]
		var weight: float = _spine_weights[i]

		var pose := skeleton.get_bone_pose(bone_idx)
		var rotation_amount := _current_rotation * weight
		var additional_rotation := Basis(Vector3.UP, rotation_amount)
		pose.basis = additional_rotation * pose.basis
		skeleton.set_bone_pose(bone_idx, pose)


# =============================================================================
# PUBLIC API
# =============================================================================

## Get the current rotation offset (radians).
func get_current_rotation_offset() -> float:
	return _current_rotation


## Get the current rotation offset (degrees).
func get_current_rotation_degrees() -> float:
	return rad_to_deg(_current_rotation)


## Force recache of bone indices.
func refresh_bone_cache() -> void:
	_cache_bone_indices()
```

- [ ] **Step 2: Commit**

```bash
git add addons/pose_warping/core/orientation_warping_modifier.gd
git commit -m "refactor: rewrite OrientationWarpingModifier with signed atan2 angle and smooth blend-out"
```

---

### Task 5: Rewrite StrideWarpingModifier

**Files:**
- Rewrite: `addons/pose_warping/core/stride_warping_modifier.gd`

This is the most significant change. Instead of scaling FK bone origins, we scale foot end-effector positions relative to hips, and add pelvis pull-down when legs would hyper-extend.

- [ ] **Step 1: Replace the entire file**

```gdscript
class_name StrideWarpingModifier
extends SkeletonModifier3D
## Scales foot positions relative to hips to match actual movement speed.
##
## Adjusts the stride length by moving foot bone (end effector) positions
## closer to or further from the hips along the forward axis. Pulls the
## pelvis down when stride scaling would cause leg hyper-extension.
##
## Must be a child of Skeleton3D. Receives updates from PoseWarpingController.


# =============================================================================
# CACHED STATE
# =============================================================================

## Cached foot bone indices (same order as settings.foot_bone_names).
var _foot_bone_indices: Array[int] = []

## Cached hips bone index.
var _hips_bone_idx: int = -1

## Cached thigh bone indices (same order as foot bones).
var _thigh_bone_indices: Array[int] = []

## Cached shin bone indices (same order as foot bones).
var _shin_bone_indices: Array[int] = []

## Max leg chain length per leg (thigh + shin rest lengths).
var _max_leg_lengths: Array[float] = []

## Current stride scale (smoothed).
var _current_scale: float = 1.0

## Target stride scale.
var _target_scale: float = 1.0

## Current pelvis pull-down offset (smoothed, bone-local space).
var _current_pelvis_pulldown: float = 0.0

## Target pelvis pull-down.
var _target_pelvis_pulldown: float = 0.0

## Cached settings reference.
var _cached_settings: PoseWarpingSettings

## Active settings for this frame.
var _settings: PoseWarpingSettings

## Whether warping is active.
var _is_warping: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_cache_bone_data.call_deferred()


func _cache_bone_data() -> void:
	_foot_bone_indices.clear()
	_thigh_bone_indices.clear()
	_shin_bone_indices.clear()
	_max_leg_lengths.clear()
	_hips_bone_idx = -1

	var skeleton := get_skeleton()
	if not skeleton or not _settings:
		return

	# Cache hips
	_hips_bone_idx = skeleton.find_bone(_settings.hips_bone_name)
	if _hips_bone_idx < 0:
		push_warning("StrideWarpingModifier: Hips bone '%s' not found." % _settings.hips_bone_name)
		return

	# Cache foot, thigh, shin bones and compute max leg lengths
	for i in _settings.foot_bone_names.size():
		var foot_idx := skeleton.find_bone(_settings.foot_bone_names[i])
		if foot_idx < 0:
			push_warning("StrideWarpingModifier: Foot bone '%s' not found." % _settings.foot_bone_names[i])
			continue

		var thigh_idx := -1
		if i < _settings.thigh_bone_names.size():
			thigh_idx = skeleton.find_bone(_settings.thigh_bone_names[i])
		var shin_idx := -1
		if i < _settings.shin_bone_names.size():
			shin_idx = skeleton.find_bone(_settings.shin_bone_names[i])

		_foot_bone_indices.append(foot_idx)
		_thigh_bone_indices.append(thigh_idx)
		_shin_bone_indices.append(shin_idx)

		# Compute max leg length from rest pose bone positions
		var leg_length := _compute_leg_length(skeleton, thigh_idx, shin_idx, foot_idx)
		_max_leg_lengths.append(leg_length)


func _compute_leg_length(skeleton: Skeleton3D, thigh_idx: int, shin_idx: int, foot_idx: int) -> float:
	# Sum the rest pose bone origin lengths for the chain: thigh->shin + shin->foot
	var total := 0.0
	if thigh_idx >= 0 and shin_idx >= 0:
		var shin_rest := skeleton.get_bone_rest(shin_idx)
		total += shin_rest.origin.length()
	if shin_idx >= 0 and foot_idx >= 0:
		var foot_rest := skeleton.get_bone_rest(foot_idx)
		total += foot_rest.origin.length()
	# Fallback: if we couldn't compute, use a generous default
	if total < 0.01:
		total = 10.0
	return total


# =============================================================================
# UPDATE FROM CONTROLLER
# =============================================================================

## Called by PoseWarpingController each physics frame.
func update_warping(
	velocity: Vector3,
	speed: float,
	is_warping: bool,
	settings: PoseWarpingSettings,
	delta: float
) -> void:
	_settings = settings
	_is_warping = is_warping

	if _cached_settings != settings:
		_cached_settings = settings
		_cache_bone_data()

	if not _settings or not _settings.enable_stride_warping:
		_target_scale = 1.0
		_target_pelvis_pulldown = 0.0
	elif not is_warping or speed < _settings.min_speed_for_stride:
		_target_scale = 1.0
		_target_pelvis_pulldown = 0.0
	else:
		# Determine which base speed to use based on current speed.
		# If speed is closer to sprint range, use base_sprint_speed.
		var base_speed := _settings.base_walk_speed
		var walk_sprint_midpoint := (_settings.base_walk_speed + _settings.base_sprint_speed) * 0.5
		if speed > walk_sprint_midpoint:
			base_speed = _settings.base_sprint_speed

		# Guard against division by zero
		if base_speed < 0.01:
			base_speed = 1.0

		var speed_ratio := speed / base_speed
		_target_scale = clampf(speed_ratio, _settings.min_speed_scale, _settings.max_speed_scale)

	# Smooth interpolation
	_current_scale = lerpf(_current_scale, _target_scale, delta * _settings.stride_blend_speed)
	_current_pelvis_pulldown = lerpf(
		_current_pelvis_pulldown, _target_pelvis_pulldown,
		delta * _settings.stride_blend_speed
	)


# =============================================================================
# SKELETON MODIFICATION
# =============================================================================

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if not skeleton or _hips_bone_idx < 0 or _foot_bone_indices.is_empty():
		return

	# Skip if scale is effectively 1.0 (no change needed)
	if absf(_current_scale - 1.0) < 0.001 and absf(_current_pelvis_pulldown) < 0.001:
		return

	var hips_pose := skeleton.get_bone_pose(_hips_bone_idx)
	var max_pulldown := 0.0

	# Scale each foot's position relative to hips
	for i in _foot_bone_indices.size():
		var foot_idx: int = _foot_bone_indices[i]
		var foot_pose := skeleton.get_bone_pose(foot_idx)

		# Get the foot's position in hips-local space.
		# Since foot is a descendant of hips, we need the global pose offset.
		# However, SkeletonModifier3D works in bone-local space.
		# The foot's pose.origin is relative to its parent (shin).
		# We scale the foot's local Z (forward) component to adjust stride reach.
		var scaled_origin := foot_pose.origin
		scaled_origin.z *= _current_scale
		foot_pose.origin = scaled_origin
		skeleton.set_bone_pose(foot_idx, foot_pose)

		# Check if this leg would hyper-extend after scaling.
		# Compute approximate leg extension from the scaled foot position.
		if i < _max_leg_lengths.size() and i < _shin_bone_indices.size():
			var shin_idx: int = _shin_bone_indices[i]
			if shin_idx >= 0:
				var shin_pose := skeleton.get_bone_pose(shin_idx)
				# Approximate current leg extension: shin origin length + foot origin length
				var current_extension := shin_pose.origin.length() + foot_pose.origin.length()
				var max_length: float = _max_leg_lengths[i]
				if current_extension > max_length * 0.98:
					# Leg is near hyper-extension, compute needed pulldown
					var overshoot := current_extension - max_length * 0.98
					max_pulldown = maxf(max_pulldown, overshoot)

	# Apply pelvis pull-down if any leg would hyper-extend
	_target_pelvis_pulldown = clampf(
		max_pulldown,
		0.0,
		_settings.max_stride_pelvis_pulldown if _settings else 0.3
	)

	if absf(_current_pelvis_pulldown) > 0.001:
		hips_pose.origin.y -= _current_pelvis_pulldown
		skeleton.set_bone_pose(_hips_bone_idx, hips_pose)


# =============================================================================
# PUBLIC API
# =============================================================================

## Get the current stride scale.
func get_current_speed_scale() -> float:
	return _current_scale


## Get the current pelvis pull-down amount.
func get_current_pelvis_pulldown() -> float:
	return _current_pelvis_pulldown


## Force recache of bone data.
func refresh_bone_cache() -> void:
	_cache_bone_data()
```

- [ ] **Step 2: Commit**

```bash
git add addons/pose_warping/core/stride_warping_modifier.gd
git commit -m "refactor: rewrite StrideWarpingModifier with foot position scaling and pelvis pull-down"
```

---

### Task 6: Rewrite SlopeWarpingModifier

**Files:**
- Rewrite: `addons/pose_warping/core/slope_warping_modifier.gd`

Key changes: accept character RID for self-exclusion, raycast from foot world positions instead of character center with lateral offset, remove debug prints, accept `is_warping` flag.

- [ ] **Step 1: Replace the entire file**

```gdscript
class_name SlopeWarpingModifier
extends SkeletonModifier3D
## Adjusts foot placement and pelvis height for uneven terrain.
##
## Casts rays downward from each foot's world position to detect ground,
## then offsets foot bones and rotates them to match the terrain normal.
## The pelvis is lowered to accommodate the lowest foot.
##
## Must be a child of Skeleton3D. Receives updates from PoseWarpingController.


# =============================================================================
# CACHED STATE
# =============================================================================

## Cached foot bone indices (left, right).
var _foot_bone_indices: Array[int] = []

## Cached hips bone index (reuses hips_bone_name from settings).
var _hips_bone_idx: int = -1

## Current foot height offsets (smoothed).
var _foot_offsets: Array[float] = [0.0, 0.0]

## Target foot height offsets.
var _foot_target_offsets: Array[float] = [0.0, 0.0]

## Current foot ground normals (smoothed).
var _foot_normals: Array[Vector3] = [Vector3.UP, Vector3.UP]

## Target foot ground normals.
var _foot_target_normals: Array[Vector3] = [Vector3.UP, Vector3.UP]

## Current pelvis offset (smoothed).
var _pelvis_offset: float = 0.0

## Skeleton scale for world-to-local conversion.
var _skeleton_scale: float = 1.0

## Character body RID for raycast self-exclusion.
var _character_rid: RID

## Reference height (character's Y position at ground level).
var _reference_height: float = 0.0

## Cached settings reference.
var _cached_settings: PoseWarpingSettings

## Active settings for this frame.
var _settings: PoseWarpingSettings

## Whether warping is active.
var _is_warping: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_cache_bone_indices.call_deferred()


func _cache_bone_indices() -> void:
	_foot_bone_indices.clear()
	_hips_bone_idx = -1

	var skeleton := get_skeleton()
	if not skeleton or not _settings:
		return

	# Cache foot bones
	for bone_name in _settings.foot_bone_names:
		var idx := skeleton.find_bone(bone_name)
		if idx >= 0:
			_foot_bone_indices.append(idx)
		else:
			push_warning("SlopeWarpingModifier: Bone '%s' not found." % bone_name)

	# Cache hips bone
	_hips_bone_idx = skeleton.find_bone(_settings.hips_bone_name)
	if _hips_bone_idx < 0:
		push_warning("SlopeWarpingModifier: Hips bone '%s' not found." % _settings.hips_bone_name)

	# Initialize arrays to match foot count
	var count := _foot_bone_indices.size()
	_foot_offsets.resize(count)
	_foot_target_offsets.resize(count)
	_foot_normals.resize(count)
	_foot_target_normals.resize(count)
	for i in count:
		_foot_offsets[i] = 0.0
		_foot_target_offsets[i] = 0.0
		_foot_normals[i] = Vector3.UP
		_foot_target_normals[i] = Vector3.UP


# =============================================================================
# UPDATE FROM CONTROLLER
# =============================================================================

## Called by PoseWarpingController each physics frame.
func update_warping(
	character_position: Vector3,
	character_rid: RID,
	is_warping: bool,
	settings: PoseWarpingSettings,
	delta: float
) -> void:
	_settings = settings
	_is_warping = is_warping
	_character_rid = character_rid
	_reference_height = character_position.y

	if _cached_settings != settings:
		_cached_settings = settings
		_cache_bone_indices()

	if not _settings or not _settings.enable_slope_warping:
		_blend_to_zero(delta)
		return

	var skeleton := get_skeleton()
	if not skeleton:
		return

	_skeleton_scale = skeleton.global_transform.basis.get_scale().y
	if _skeleton_scale < 0.01:
		_skeleton_scale = 1.0

	var adaptation_speed := _settings.slope_adaptation_speed

	# Raycast from each foot's world position
	for i in _foot_bone_indices.size():
		var foot_idx: int = _foot_bone_indices[i]
		var foot_global_pos := skeleton.global_transform * skeleton.get_bone_global_pose(foot_idx).origin

		var ray_origin := foot_global_pos + Vector3.UP * _settings.raycast_origin_height
		var result := _raycast_ground(ray_origin)

		if result.hit:
			_foot_target_offsets[i] = result.position.y - _reference_height + _settings.foot_height_offset
			_foot_target_normals[i] = result.normal
		else:
			_foot_target_offsets[i] = 0.0
			_foot_target_normals[i] = Vector3.UP

		# Smooth interpolation
		_foot_offsets[i] = lerpf(_foot_offsets[i], _foot_target_offsets[i], delta * adaptation_speed)
		_foot_normals[i] = _foot_normals[i].lerp(_foot_target_normals[i], delta * adaptation_speed)

	# Pelvis: lower by the amount of the lowest foot
	var lowest := 0.0
	for offset in _foot_offsets:
		lowest = minf(lowest, offset)
	var target_pelvis := clampf(lowest, -_settings.max_pelvis_offset, 0.0)
	_pelvis_offset = lerpf(_pelvis_offset, target_pelvis, delta * adaptation_speed)


func _blend_to_zero(delta: float) -> void:
	var speed := 5.0
	for i in _foot_offsets.size():
		_foot_offsets[i] = lerpf(_foot_offsets[i], 0.0, delta * speed)
		_foot_normals[i] = _foot_normals[i].lerp(Vector3.UP, delta * speed)
	_pelvis_offset = lerpf(_pelvis_offset, 0.0, delta * speed)


func _raycast_ground(origin: Vector3) -> Dictionary:
	var skeleton := get_skeleton()
	if not skeleton:
		return {"hit": false, "position": origin, "normal": Vector3.UP}

	var space_state := skeleton.get_world_3d().direct_space_state
	if not space_state:
		return {"hit": false, "position": origin, "normal": Vector3.UP}

	var ray_end := origin + Vector3.DOWN * _settings.slope_raycast_length

	var query := PhysicsRayQueryParameters3D.create(
		origin, ray_end, _settings.slope_collision_mask
	)
	# Exclude the character's own collision body
	if _character_rid.is_valid():
		query.exclude = [_character_rid]

	var result := space_state.intersect_ray(query)
	if result:
		return {"hit": true, "position": result.position, "normal": result.normal}

	return {"hit": false, "position": origin, "normal": Vector3.UP}


# =============================================================================
# SKELETON MODIFICATION
# =============================================================================

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if not skeleton or _foot_bone_indices.is_empty():
		return

	# Apply pelvis offset
	if _hips_bone_idx >= 0 and absf(_pelvis_offset) > 0.001:
		var hips_pose := skeleton.get_bone_pose(_hips_bone_idx)
		hips_pose.origin.y += _pelvis_offset / _skeleton_scale
		skeleton.set_bone_pose(_hips_bone_idx, hips_pose)

	# Apply foot offsets and rotations
	for i in _foot_bone_indices.size():
		var foot_idx: int = _foot_bone_indices[i]
		var pose := skeleton.get_bone_pose(foot_idx)

		# Height adjustment (compensate for pelvis movement)
		var effective_offset := (_foot_offsets[i] - _pelvis_offset) / _skeleton_scale
		if absf(effective_offset) > 0.001:
			pose.origin.y += effective_offset

		# Foot rotation to align with ground normal
		var normal: Vector3 = _foot_normals[i]
		if _settings and _settings.foot_rotation_blend > 0.001 and not normal.is_equal_approx(Vector3.UP):
			var rotation := _calculate_ground_rotation(normal)
			if rotation != Basis.IDENTITY:
				var target_basis := rotation * pose.basis
				pose.basis = pose.basis.slerp(target_basis, _settings.foot_rotation_blend)

		skeleton.set_bone_pose(foot_idx, pose)


func _calculate_ground_rotation(ground_normal: Vector3) -> Basis:
	var rotation_axis := Vector3.UP.cross(ground_normal)
	if rotation_axis.length_squared() < 0.0001:
		return Basis.IDENTITY

	rotation_axis = rotation_axis.normalized()
	var angle := Vector3.UP.angle_to(ground_normal)
	angle = clampf(angle, -PI / 4.0, PI / 4.0)

	return Basis(rotation_axis, angle)


# =============================================================================
# PUBLIC API
# =============================================================================

## Get current foot height offset by index (0=left, 1=right).
func get_foot_offset(index: int) -> float:
	if index >= 0 and index < _foot_offsets.size():
		return _foot_offsets[index]
	return 0.0


## Get current pelvis offset.
func get_pelvis_offset() -> float:
	return _pelvis_offset


## Get ground normal at foot by index.
func get_foot_normal(index: int) -> Vector3:
	if index >= 0 and index < _foot_normals.size():
		return _foot_normals[index]
	return Vector3.UP


## Force recache of bone indices.
func refresh_bone_cache() -> void:
	_cache_bone_indices()
```

- [ ] **Step 2: Commit**

```bash
git add addons/pose_warping/core/slope_warping_modifier.gd
git commit -m "refactor: rewrite SlopeWarpingModifier with self-exclusion and foot-position raycasts"
```

---

### Task 7: Update Player Scene References

**Files:**
- Modify: `scenes/player.tscn` (lines 193-200)

The controller's `update_warping()` signatures changed (added `is_warping` param), but this is internal — the scene file just needs correct NodePath references. The main fix is verifying that StrideWarpingModifier, OrientationWarpingModifier, and SlopeWarpingModifier nodes actually exist as children of `Skeleton3D` in the scene. Currently the scene references paths like `../CharacterMesh/Rig/Skeleton3D/StrideWarpingModifier` but those nodes may not exist.

- [ ] **Step 1: Check if modifier nodes exist in the scene file**

Search `scenes/player.tscn` for nodes named `StrideWarpingModifier`, `OrientationWarpingModifier`, and `SlopeWarpingModifier`. If they do not exist as children of `Rig/Skeleton3D`, they need to be added.

- [ ] **Step 2: Add missing modifier nodes to the scene**

If the modifier nodes are missing, add them to `scenes/player.tscn`. They should appear as children of `Rig/Skeleton3D` inside the `CharacterMesh` instance. Add these node entries after the existing Skeleton3D overrides:

```tscn
[node name="OrientationWarpingModifier" type="SkeletonModifier3D" parent="CharacterMesh/Rig/Skeleton3D"]
script = ExtResource("orientation_warping_script_id")

[node name="StrideWarpingModifier" type="SkeletonModifier3D" parent="CharacterMesh/Rig/Skeleton3D"]
script = ExtResource("stride_warping_script_id")

[node name="SlopeWarpingModifier" type="SkeletonModifier3D" parent="CharacterMesh/Rig/Skeleton3D"]
script = ExtResource("slope_warping_script_id")
```

The exact `ext_resource` IDs will depend on the scene file format. Add corresponding `[ext_resource]` entries at the top of the file for each modifier script:
- `res://addons/pose_warping/core/orientation_warping_modifier.gd`
- `res://addons/pose_warping/core/stride_warping_modifier.gd`
- `res://addons/pose_warping/core/slope_warping_modifier.gd`

- [ ] **Step 3: Verify PoseWarpingController references match**

Ensure the controller's `stride_modifier`, `orientation_modifier`, and `slope_modifier` NodePaths point to the correct children of `Skeleton3D`:
```
stride_modifier = NodePath("../CharacterMesh/Rig/Skeleton3D/StrideWarpingModifier")
orientation_modifier = NodePath("../CharacterMesh/Rig/Skeleton3D/OrientationWarpingModifier")
slope_modifier = NodePath("../CharacterMesh/Rig/Skeleton3D/SlopeWarpingModifier")
```

- [ ] **Step 4: Commit**

```bash
git add scenes/player.tscn
git commit -m "fix: add modifier nodes to player scene and verify controller references"
```

---

### Task 8: Verify in Godot Editor

- [ ] **Step 1: Open the project in Godot**

Launch Godot and open the inventory-system project. Check the Output panel for errors.

- [ ] **Step 2: Open the player scene**

Open `scenes/player.tscn` in the editor. Verify:
1. `PoseWarpingController` node exists and its exported fields show valid references
2. `Skeleton3D` has three modifier children (Orientation, Stride, Slope)
3. The `settings` field on the controller shows the loaded resource (not null/empty)
4. No red warning icons on any nodes

- [ ] **Step 3: Check bone names match**

Select one of the modifier nodes and check the Output panel during load for any "bone not found" warnings. The bone names in settings should match: `DEF-hips`, `DEF-spine.001`, `DEF-spine.002`, `DEF-spine.003`, `DEF-thigh.L`, `DEF-thigh.R`, `DEF-shin.L`, `DEF-shin.R`, `DEF-foot.L`, `DEF-foot.R`.

- [ ] **Step 4: Run the scene**

Run the project and observe:
1. Character moves without errors in console
2. While walking, observe if stride warping adjusts foot reach (subtle at [0.8, 1.2] range)
3. While moving and looking sideways (3rd person), observe if upper body twists toward camera direction
4. No visible pops or jitter when starting/stopping movement

- [ ] **Step 5: Commit any fixes from testing**

```bash
git add -A
git commit -m "fix: address issues found during editor testing"
```
