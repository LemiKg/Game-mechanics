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
