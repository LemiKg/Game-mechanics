class_name MantleDetector
extends Node
## Detects mantleable ledges using raycasts.
##
## Performs multi-step raycast detection to find valid ledges
## within the configured height range.


## Emitted when a valid ledge is detected.
signal ledge_detected(ledge_position: Vector3, ledge_normal: Vector3, ledge_height: float)


@export_group("References")
## The body to check mantling for. Required.
@export var body: Node3D

@export_group("Settings")
## Mantle configuration. Required.
@export var settings: MantleSettings3D


## Check for a mantleable ledge in front of the character.
## Returns a dictionary with position, normal, and height if found, empty otherwise.
func check_for_ledge() -> Dictionary:
	if not body or not settings:
		return {}
	
	var forward := -body.global_transform.basis.z
	var origin := body.global_position + Vector3.UP * settings.forward_ray_height
	
	# Step 1: Forward ray - check for wall
	var forward_result := _raycast(origin, forward * settings.forward_ray_length)
	if forward_result.is_empty():
		return {} # No wall ahead
	
	# Step 2: Ground ray from above - find ledge top
	var forward_hit_pos: Vector3 = forward_result.position
	var ledge_check_origin: Vector3 = forward_hit_pos + forward * 0.1 + Vector3.UP * settings.ground_ray_length
	var ground_result := _raycast(ledge_check_origin, Vector3.DOWN * settings.ground_ray_length)
	if ground_result.is_empty():
		return {} # No ledge top found
	
	# Step 3: Calculate ledge height
	var ground_hit_pos: Vector3 = ground_result.position
	var ledge_height: float = ground_hit_pos.y - body.global_position.y
	if ledge_height < settings.min_ledge_height or ledge_height > settings.max_ledge_height:
		return {} # Outside mantleable range
	
	# Step 4: Clearance ray - check if we can fit on top
	var clearance_origin: Vector3 = ground_hit_pos + Vector3.UP * 0.1
	var clearance_result := _raycast(clearance_origin, Vector3.UP * settings.clearance_ray_length)
	if not clearance_result.is_empty():
		return {} # Not enough clearance
	
	var result := {
		"position": ground_hit_pos + Vector3.UP * settings.mantle_height_offset,
		"normal": forward_result.normal,
		"height": ledge_height
	}
	
	ledge_detected.emit(result.position, result.normal, result.height)
	return result


## Perform a raycast and return the result dictionary.
func _raycast(origin: Vector3, direction: Vector3) -> Dictionary:
	var space_state := body.get_world_3d().direct_space_state
	if not space_state:
		return {}
	
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction,
		settings.collision_mask
	)
	
	# Exclude the body from the raycast
	if body.has_method("get_rid"):
		query.exclude = [body.get_rid()]
	
	return space_state.intersect_ray(query)


## Check if the detector is properly configured.
func is_configured() -> bool:
	return body != null and settings != null
