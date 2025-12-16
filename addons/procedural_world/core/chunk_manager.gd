@tool
extends Node
class_name ChunkManager
## Manages chunk loading, unloading, and lifecycle.
## Handles editor preview and runtime chunk streaming.

## Emitted when a chunk has been generated and is ready for use
signal chunk_ready(coord: Vector2i)

## Emitted when a chunk has been unloaded
signal chunk_unloaded(coord: Vector2i)

## Emitted during generation with progress (completed, total)
signal generation_progress(completed: int, total: int)

## World configuration resource
@export var world_config: WorldConfig:
	set(value):
		if world_config and world_config.config_changed.is_connected(_on_config_changed):
			world_config.config_changed.disconnect(_on_config_changed)
		world_config = value
		if world_config:
			world_config.config_changed.connect(_on_config_changed)
		if Engine.is_editor_hint() and preview_enabled:
			_regenerate_preview.call_deferred()

## Reference to the player for chunk streaming (runtime only)
@export var player: Node3D

## Enable terrain preview in editor
@export var preview_enabled: bool = true:
	set(value):
		preview_enabled = value
		if Engine.is_editor_hint():
			if preview_enabled:
				_regenerate_preview.call_deferred()
			else:
				_clear_all_chunks()

## Number of preview chunks in each direction from center (editor only)
@export_range(0, 4) var preview_radius: int = 1:
	set(value):
		preview_radius = value
		if Engine.is_editor_hint() and preview_enabled:
			_regenerate_preview.call_deferred()

## Currently active chunks (coord -> TerrainChunk)
var _active_chunks: Dictionary = {}

## Pool of unused TerrainChunk nodes for reuse
var _chunk_pool: Array[TerrainChunk] = []

## Last known player chunk coordinate
var _last_player_coord: Vector2i = Vector2i(-99999, -99999)

## Flag to prevent recursive regeneration
var _is_regenerating: bool = false

## Chunks with collision currently enabled
var _collision_chunks: Dictionary = {}


## Returns number of currently active chunks
func get_active_chunk_count() -> int:
	return _active_chunks.size()


## Returns number of chunks in the reuse pool
func get_pool_size() -> int:
	return _chunk_pool.size()


## Returns number of chunks with collision enabled
func get_collision_chunk_count() -> int:
	return _collision_chunks.size()


func _ready() -> void:
	if Engine.is_editor_hint():
		if preview_enabled:
			_regenerate_preview.call_deferred()
	else:
		# Runtime: try to find player if not assigned
		if not player:
			_try_find_player()
		
		# Initial chunk generation around player or origin
		call_deferred("_initial_runtime_generation")


func _try_find_player() -> void:
	# Look for a node in the "player" group
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0] as Node3D
		print("ChunkManager: Auto-detected player: ", player.name)


func _initial_runtime_generation() -> void:
	if player:
		_update_chunks_around_player()
	else:
		# No player found, generate around origin
		_generate_chunks_around_position(Vector3.ZERO)


func _generate_chunks_around_position(world_pos: Vector3) -> void:
	if not world_config:
		return
	
	var center_coord := world_to_coord(world_pos)
	var view_distance := world_config.view_distance
	var collision_radius := world_config.collision_radius
	
	for z in range(-view_distance, view_distance + 1):
		for x in range(-view_distance, view_distance + 1):
			var coord := center_coord + Vector2i(x, z)
			if is_coord_valid(coord):
				_load_chunk(coord)
	
	# Enable collision on nearby chunks
	_update_chunk_collision(center_coord, collision_radius)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return # No per-frame updates in editor
	
	# Try to find player if we don't have one yet
	if not player:
		_try_find_player()
	
	# Runtime: check if player moved to a new chunk
	if player:
		var player_coord := world_to_coord(player.global_position)
		if player_coord != _last_player_coord:
			_last_player_coord = player_coord
			_update_chunks_around_player()


## Converts chunk coordinate to world position (chunk corner at origin)
func coord_to_world(coord: Vector2i) -> Vector3:
	if not world_config:
		return Vector3.ZERO
	return Vector3(
		coord.x * world_config.chunk_size,
		0.0,
		coord.y * world_config.chunk_size
	)


## Converts world position to chunk coordinate
func world_to_coord(world_position: Vector3) -> Vector2i:
	if not world_config or world_config.chunk_size <= 0:
		return Vector2i.ZERO
	return Vector2i(
		floori(world_position.x / world_config.chunk_size),
		floori(world_position.z / world_config.chunk_size)
	)


## Returns true if the coordinate is within world bounds
func is_coord_valid(coord: Vector2i) -> bool:
	if not world_config:
		return false
	return (
		coord.x >= 0 and coord.x < world_config.world_size.x and
		coord.y >= 0 and coord.y < world_config.world_size.y
	)


## Returns the chunk at a world position, or null if not loaded
func get_chunk_at(world_position: Vector3) -> TerrainChunk:
	var coord := world_to_coord(world_position)
	return _active_chunks.get(coord)


## Force regeneration of all visible chunks
func regenerate() -> void:
	if Engine.is_editor_hint():
		_regenerate_preview()
	else:
		_clear_all_chunks()
		_update_chunks_around_player()


## Gets or creates a TerrainChunk from the pool
func _get_chunk_from_pool() -> TerrainChunk:
	if _chunk_pool.is_empty():
		var chunk := TerrainChunk.new()
		return chunk
	return _chunk_pool.pop_back()


## Returns a chunk to the pool
func _return_chunk_to_pool(chunk: TerrainChunk) -> void:
	if not is_instance_valid(chunk):
		return
	chunk.reset()
	if chunk.get_parent():
		chunk.get_parent().remove_child(chunk)
	_chunk_pool.append(chunk)


## Generates and loads a chunk at the specified coordinate
func _load_chunk(coord: Vector2i) -> void:
	if not world_config:
		push_warning("ChunkManager: No world_config assigned")
		return
	
	if _active_chunks.has(coord):
		return # Already loaded
	
	if not is_coord_valid(coord):
		return # Out of bounds
	
	# Validate config
	var errors := world_config.validate()
	if not errors.is_empty():
		for error in errors:
			push_error("ChunkManager: " + error)
		return
	
	# Generate chunk data
	var chunk_data := ChunkData.new()
	chunk_data.initialize(coord, world_config.chunk_resolution)
	
	# Generate heights
	chunk_data.height_data = HeightGenerator.generate_height_data(coord, world_config)
	chunk_data.moisture_data = HeightGenerator.generate_moisture_data(coord, world_config)
	
	# Build meshes
	var cell_size := world_config.get_cell_size()
	var lod_count := world_config.lod_distances.size() + 1
	chunk_data.mesh_lods = TerrainMeshBuilder.build_lod_meshes(
		chunk_data.height_data,
		chunk_data.width,
		chunk_data.depth,
		cell_size,
		lod_count
	)
	
	chunk_data.state = ChunkData.GenerationState.READY
	
	# Get chunk node from pool and initialize
	var chunk := _get_chunk_from_pool()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.initialize(chunk_data, world_config.terrain_material, cell_size)
	
	# Set LOD distances
	if not world_config.lod_distances.is_empty():
		chunk.set_lod_distances(world_config.lod_distances)
	
	# Position chunk in world
	chunk.position = coord_to_world(coord)
	
	# Add to scene and track
	add_child(chunk)
	_active_chunks[coord] = chunk
	
	chunk_ready.emit(coord)


## Unloads a chunk at the specified coordinate
func _unload_chunk(coord: Vector2i) -> void:
	if not _active_chunks.has(coord):
		return
	
	var chunk: TerrainChunk = _active_chunks[coord]
	_active_chunks.erase(coord)
	_return_chunk_to_pool(chunk)
	
	chunk_unloaded.emit(coord)


## Clears all loaded chunks
func _clear_all_chunks() -> void:
	var coords := _active_chunks.keys().duplicate()
	for coord in coords:
		_unload_chunk(coord)


## Updates chunks around the player position
func _update_chunks_around_player() -> void:
	if not player or not world_config:
		return
	
	var player_coord := world_to_coord(player.global_position)
	var view_distance := world_config.view_distance
	var collision_radius := world_config.collision_radius
	
	# Determine which chunks should be loaded
	var desired_chunks: Array[Vector2i] = []
	for z in range(-view_distance, view_distance + 1):
		for x in range(-view_distance, view_distance + 1):
			var coord := player_coord + Vector2i(x, z)
			if is_coord_valid(coord):
				desired_chunks.append(coord)
	
	# Sort by distance to player (load closest first)
	desired_chunks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var dist_a := (a - player_coord).length_squared()
		var dist_b := (b - player_coord).length_squared()
		return dist_a < dist_b
	)
	
	# Unload chunks that are too far
	var chunks_to_unload: Array[Vector2i] = []
	for coord in _active_chunks.keys():
		if coord not in desired_chunks:
			chunks_to_unload.append(coord)
	
	for coord in chunks_to_unload:
		_unload_chunk(coord)
	
	# Load new chunks
	for coord in desired_chunks:
		if not _active_chunks.has(coord):
			_load_chunk(coord)
	
	# Update collision based on distance to player
	_update_chunk_collision(player_coord, collision_radius)


## Enables/disables collision on chunks based on distance to player
func _update_chunk_collision(player_coord: Vector2i, collision_radius: int) -> void:
	# Clear old collision tracking
	_collision_chunks.clear()
	
	for coord in _active_chunks.keys():
		var chunk: TerrainChunk = _active_chunks[coord]
		var distance := maxi(absi(coord.x - player_coord.x), absi(coord.y - player_coord.y))
		
		if distance <= collision_radius:
			if not chunk.has_collision():
				chunk.enable_collision()
			_collision_chunks[coord] = true
		else:
			if chunk.has_collision():
				chunk.disable_collision()


## Regenerates preview chunks (editor only)
func _regenerate_preview() -> void:
	if not Engine.is_editor_hint():
		return
	
	if _is_regenerating:
		return
	
	_is_regenerating = true
	
	# Clear existing chunks
	_clear_all_chunks()
	
	if not world_config or not preview_enabled:
		_is_regenerating = false
		return
	
	# Generate chunks around origin (0,0) for editor preview
	# Use coords starting at 0 so terrain appears at world origin
	var total := (preview_radius * 2 + 1) * (preview_radius * 2 + 1)
	var completed := 0
	
	for z in range(0, preview_radius * 2 + 1):
		for x in range(0, preview_radius * 2 + 1):
			var coord := Vector2i(x, z)
			if is_coord_valid(coord):
				_load_chunk(coord)
			completed += 1
			generation_progress.emit(completed, total)
	
	_is_regenerating = false


## Called when world_config changes
func _on_config_changed() -> void:
	if Engine.is_editor_hint() and preview_enabled:
		_regenerate_preview.call_deferred()


func _exit_tree() -> void:
	# Clean up pooled chunks
	for chunk in _chunk_pool:
		if is_instance_valid(chunk):
			chunk.queue_free()
	_chunk_pool.clear()
