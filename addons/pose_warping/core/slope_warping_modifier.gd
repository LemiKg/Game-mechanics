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
