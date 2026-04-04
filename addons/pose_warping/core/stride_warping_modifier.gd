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

	var hips_global := skeleton.get_bone_global_pose(_hips_bone_idx)
	var max_pulldown := 0.0

	# Scale each foot's position relative to hips in skeleton-global space
	for i in _foot_bone_indices.size():
		var foot_idx: int = _foot_bone_indices[i]

		# Get current foot global pose (skeleton-local space, includes all parent transforms)
		var foot_global := skeleton.get_bone_global_pose(foot_idx)
		var old_foot_global_origin := foot_global.origin

		# Compute foot offset from hips in skeleton-global space
		var foot_offset := foot_global.origin - hips_global.origin

		# Scale the Z (forward) component to adjust stride reach
		foot_offset.z *= _current_scale

		# Compute the new desired foot global origin
		var new_foot_global_origin := hips_global.origin + foot_offset

		# Compute the delta in skeleton-global space
		var delta_global := new_foot_global_origin - old_foot_global_origin

		# Convert the delta into the foot's local (parent bone) space.
		# The foot's parent is the shin bone.
		var foot_parent_idx := skeleton.get_bone_parent(foot_idx)
		var delta_local: Vector3
		if foot_parent_idx >= 0:
			var foot_parent_global := skeleton.get_bone_global_pose(foot_parent_idx)
			delta_local = foot_parent_global.basis.inverse() * delta_global
		else:
			# No parent — skeleton-global space equals local space
			delta_local = delta_global

		# Apply as an additive offset to the foot's local pose
		var foot_pose := skeleton.get_bone_pose(foot_idx)
		foot_pose.origin += delta_local
		skeleton.set_bone_pose(foot_idx, foot_pose)

		# Check if this leg would hyper-extend after scaling.
		# Use the distance from hips to new foot position in skeleton-global space.
		if i < _max_leg_lengths.size():
			var current_extension := (new_foot_global_origin - hips_global.origin).length()
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
		var hips_pose := skeleton.get_bone_pose(_hips_bone_idx)
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
