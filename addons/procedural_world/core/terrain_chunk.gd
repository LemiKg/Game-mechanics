@tool
extends Node3D
class_name TerrainChunk
## Runtime representation of a single terrain chunk.
## Manages mesh instances for LOD levels and optional collision.

## Emitted when the chunk has finished loading and is ready
signal chunk_loaded(coord: Vector2i)

## The generated data for this chunk
var chunk_data: ChunkData

## Array of MeshInstance3D nodes, one per LOD level
var _lod_mesh_instances: Array[MeshInstance3D] = []

## Collision body (created on demand)
var _collision_body: StaticBody3D

## Collision shape (created on demand)
var _collision_shape: CollisionShape3D

## Whether collision is currently enabled
var _has_collision: bool = false

## Material applied to all LOD meshes
var _material: ShaderMaterial

## Cell size for collision positioning
var _cell_size: float = 1.0


func _ready() -> void:
	# Nothing to do on ready - initialization happens via initialize()
	pass


## Initializes the chunk with generated data and material
func initialize(data: ChunkData, material: ShaderMaterial, cell_size: float = 1.0) -> void:
	chunk_data = data
	_material = material
	_cell_size = cell_size
	
	# Clear existing meshes
	_clear_mesh_instances()
	
	if not chunk_data or chunk_data.mesh_lods.is_empty():
		push_warning("TerrainChunk: No mesh data to initialize")
		return
	
	# Create MeshInstance3D for each LOD level
	for i in range(chunk_data.mesh_lods.size()):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "LOD%d" % i
		mesh_instance.mesh = chunk_data.mesh_lods[i]
		
		if _material:
			mesh_instance.material_override = _material
		
		# Cast shadows only from highest detail LOD
		if i == 0:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		add_child(mesh_instance)
		_lod_mesh_instances.append(mesh_instance)
	
	chunk_loaded.emit(chunk_data.coord)


## Configures visibility ranges for LOD transitions
## @param distances: Array of distance thresholds [LOD0_end, LOD1_end, LOD2_end, ...]
func set_lod_distances(distances: Array[float]) -> void:
	if _lod_mesh_instances.is_empty():
		return
	
	# Ensure all LODs are visible (ranges control which one renders)
	for i in range(_lod_mesh_instances.size()):
		var mesh_instance := _lod_mesh_instances[i]
		mesh_instance.visible = true
		
		# LOD0 starts at distance 0
		if i == 0:
			mesh_instance.visibility_range_begin = 0.0
		else:
			# Start where previous LOD ends
			mesh_instance.visibility_range_begin = distances[i - 1] if i - 1 < distances.size() else 0.0
		
		# End at configured distance, or 0 (infinite) for last LOD
		if i < distances.size():
			mesh_instance.visibility_range_end = distances[i]
		else:
			mesh_instance.visibility_range_end = 0.0 # 0 = infinite/no limit for last LOD
		
		# Use hysteresis margin to prevent popping during transitions
		mesh_instance.visibility_range_begin_margin = 10.0
		mesh_instance.visibility_range_end_margin = 10.0
		
		# Disable fade mode - it can cause visibility issues
		mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Enables HeightMapShape3D collision for this chunk
func enable_collision() -> void:
	if _has_collision:
		return
	
	if not chunk_data or chunk_data.height_data.is_empty():
		push_warning("TerrainChunk: No height data for collision")
		return
	
	# Create collision structure
	_collision_body = StaticBody3D.new()
	_collision_body.name = "CollisionBody"
	
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape"
	
	var heightmap_shape := HeightMapShape3D.new()
	
	# Set dimensions BEFORE setting map_data
	heightmap_shape.map_width = chunk_data.width
	heightmap_shape.map_depth = chunk_data.depth
	heightmap_shape.map_data = chunk_data.height_data
	
	_collision_shape.shape = heightmap_shape
	_collision_body.add_child(_collision_shape)
	add_child(_collision_body)
	
	# HeightMapShape3D is centered at origin, so offset to align with mesh
	# The mesh starts at (0, 0, 0) and extends to (width * cell_size, h, depth * cell_size)
	# HeightMapShape3D center is at (width/2 * cell_size, 0, depth/2 * cell_size)
	var half_width := (chunk_data.width - 1) * _cell_size * 0.5
	var half_depth := (chunk_data.depth - 1) * _cell_size * 0.5
	_collision_body.position = Vector3(half_width, 0.0, half_depth)
	
	_has_collision = true


## Disables collision for this chunk
func disable_collision() -> void:
	if not _has_collision:
		return
	
	if _collision_body:
		_collision_body.queue_free()
		_collision_body = null
		_collision_shape = null
	
	_has_collision = false


## Returns whether collision is currently enabled
func has_collision() -> bool:
	return _has_collision


## Resets the chunk for pool reuse
func reset() -> void:
	disable_collision()
	_clear_mesh_instances()
	chunk_data = null
	_material = null


## Clears all mesh instances
func _clear_mesh_instances() -> void:
	for mesh_instance in _lod_mesh_instances:
		if is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
	_lod_mesh_instances.clear()


## Returns the chunk's world-space AABB
func get_chunk_aabb() -> AABB:
	if not chunk_data:
		return AABB()
	
	var size := Vector3(
		(chunk_data.width - 1) * _cell_size,
		chunk_data.get_max_height() - chunk_data.get_min_height(),
		(chunk_data.depth - 1) * _cell_size
	)
	var origin := global_position + Vector3(0, chunk_data.get_min_height(), 0)
	
	return AABB(origin, size)
