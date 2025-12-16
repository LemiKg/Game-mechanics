@tool
extends Node
class_name AsyncGenerationHandler
## Handles asynchronous chunk data generation using a background thread.
## Thread-safe: uses Mutex for queue access, call_deferred for results.
##
## Usage:
## 1. Connect to chunk_generated signal
## 2. Call request_chunk(coord) to queue generation
## 3. Results arrive via signal on main thread

## Emitted when a chunk has been generated (main thread, via call_deferred)
signal chunk_generated(coord: Vector2i, data: ChunkData)

## Emitted when the queue size changes
signal queue_size_changed(size: int)

## World configuration (required for generation)
@export var world_config: WorldConfig

## Maximum chunks to generate per frame when draining queue synchronously
@export var max_sync_per_frame: int = 2

## Whether async generation is enabled (false = synchronous fallback)
var async_enabled: bool = true

## Generation queue (thread-safe access via mutex)
var _queue: Array[Vector2i] = []
var _queue_mutex: Mutex = Mutex.new()

## Pending results waiting to be delivered
var _results: Array[Dictionary] = []  # [{coord, data}]
var _results_mutex: Mutex = Mutex.new()

## Worker thread
var _thread: Thread = null
var _thread_running: bool = false
var _should_stop: bool = false

## Cancelled requests (checked before delivering results)
var _cancelled: Dictionary = {}
var _cancelled_mutex: Mutex = Mutex.new()

## Biome map reference for height modifications
var _biome_map: BiomeMap


func _ready() -> void:
	if Engine.is_editor_hint():
		# Use synchronous generation in editor
		async_enabled = false
		return
	
	# Start worker thread for runtime
	_start_thread()


func _exit_tree() -> void:
	_stop_thread()


func _process(_delta: float) -> void:
	# Deliver any pending results on main thread
	_deliver_results()
	
	# Synchronous fallback if async disabled
	if not async_enabled:
		_process_queue_sync()


## Request a chunk to be generated asynchronously
## @param coord Chunk coordinate to generate
func request_chunk(coord: Vector2i) -> void:
	if not world_config:
		push_error("AsyncGenerationHandler: No world_config assigned")
		return
	
	_queue_mutex.lock()
	if coord not in _queue:
		_queue.append(coord)
		queue_size_changed.emit(_queue.size())
	_queue_mutex.unlock()
	
	# Remove from cancelled if re-requested
	_cancelled_mutex.lock()
	_cancelled.erase(coord)
	_cancelled_mutex.unlock()


## Cancel a pending chunk request
## @param coord Chunk coordinate to cancel
func cancel_request(coord: Vector2i) -> void:
	_queue_mutex.lock()
	var idx := _queue.find(coord)
	if idx >= 0:
		_queue.remove_at(idx)
		queue_size_changed.emit(_queue.size())
	_queue_mutex.unlock()
	
	# Mark as cancelled so any in-progress result is discarded
	_cancelled_mutex.lock()
	_cancelled[coord] = true
	_cancelled_mutex.unlock()


## Cancel all pending requests
func cancel_all() -> void:
	_queue_mutex.lock()
	_queue.clear()
	queue_size_changed.emit(0)
	_queue_mutex.unlock()


## Get the current queue size
func get_queue_size() -> int:
	_queue_mutex.lock()
	var size := _queue.size()
	_queue_mutex.unlock()
	return size


## Check if a coord is queued for generation
func is_queued(coord: Vector2i) -> bool:
	_queue_mutex.lock()
	var found := coord in _queue
	_queue_mutex.unlock()
	return found


## Start the worker thread
func _start_thread() -> void:
	if _thread != null and _thread.is_alive():
		return
	
	_should_stop = false
	_thread_running = true
	_thread = Thread.new()
	_thread.start(_worker_loop)
	print("AsyncGenerationHandler: Worker thread started")


## Stop the worker thread
func _stop_thread() -> void:
	if _thread == null:
		return
	
	_should_stop = true
	
	if _thread.is_alive():
		_thread.wait_to_finish()
	
	_thread = null
	_thread_running = false
	print("AsyncGenerationHandler: Worker thread stopped")


## Worker thread main loop
func _worker_loop() -> void:
	while not _should_stop:
		var coord: Variant = null
		
		# Get next item from queue
		_queue_mutex.lock()
		if not _queue.is_empty():
			coord = _queue.pop_front()
			queue_size_changed.emit.call_deferred(_queue.size())
		_queue_mutex.unlock()
		
		if coord != null:
			# Check if cancelled
			_cancelled_mutex.lock()
			var was_cancelled := _cancelled.has(coord)
			_cancelled_mutex.unlock()
			
			if not was_cancelled:
				# Generate chunk data (thread-safe)
				var data := _generate_chunk_data(coord as Vector2i)
				
				# Queue result for main thread
				_results_mutex.lock()
				_results.append({"coord": coord, "data": data})
				_results_mutex.unlock()
		else:
			# No work, sleep briefly
			OS.delay_msec(5)


## Generate chunk data (called on worker thread - must be thread-safe)
func _generate_chunk_data(coord: Vector2i) -> ChunkData:
	var chunk_data := ChunkData.new()
	chunk_data.initialize(coord, world_config.chunk_resolution)
	
	# Pass 1: Generate base heights and moisture
	chunk_data.height_data = HeightGenerator.generate_height_data(coord, world_config)
	chunk_data.moisture_data = HeightGenerator.generate_moisture_data(coord, world_config)
	
	# Pass 2: Apply biome height modifications
	_apply_biome_height_modifications(chunk_data, coord)
	
	# Pass 3: Calculate biome weights for splatmap
	_calculate_biome_weights(chunk_data, coord)
	
	# Pass 4: Build meshes
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
	return chunk_data


## Apply biome height modifications (thread-safe)
func _apply_biome_height_modifications(chunk_data: ChunkData, coord: Vector2i) -> void:
	if not world_config or not world_config.biome_map:
		return
	
	var biome_map := world_config.biome_map
	var cell_size := world_config.get_cell_size()
	var resolution := chunk_data.width
	
	var world_offset_x := coord.x * world_config.chunk_size
	var world_offset_z := coord.y * world_config.chunk_size
	
	for z in range(resolution):
		for x in range(resolution):
			var idx := z * resolution + x
			var height := chunk_data.height_data[idx]
			var moisture := chunk_data.moisture_data[idx]
			var elevation := HeightGenerator.get_normalized_elevation(height, world_config)
			var world_x := world_offset_x + x * cell_size
			var world_z := world_offset_z + z * cell_size
			
			var matching := biome_map.get_matching_biomes(elevation, moisture)
			if not matching.is_empty():
				var total_strength := 0.0
				var blended_height := 0.0
				
				for match_data in matching:
					var biome: BiomeData = match_data["biome"]
					var strength: float = match_data["strength"]
					var modified := biome.modify_height(height, world_x, world_z)
					blended_height += modified * strength
					total_strength += strength
				
				if total_strength > 0.0:
					chunk_data.height_data[idx] = blended_height / total_strength


## Calculate biome weights for splatmap (thread-safe)
func _calculate_biome_weights(chunk_data: ChunkData, coord: Vector2i) -> void:
	var biome_map := world_config.biome_map if world_config else null
	var cell_size := world_config.get_cell_size() if world_config else 1.0
	var resolution := chunk_data.width
	
	for z in range(resolution):
		for x in range(resolution):
			var idx := z * resolution + x
			var weight_idx := idx * 4
			
			if biome_map:
				var height := chunk_data.height_data[idx]
				var moisture := chunk_data.moisture_data[idx]
				var elevation := HeightGenerator.get_normalized_elevation(height, world_config)
				var weights := biome_map.get_biome_weights(elevation, moisture)
				
				chunk_data.biome_weights[weight_idx] = weights.r
				chunk_data.biome_weights[weight_idx + 1] = weights.g
				chunk_data.biome_weights[weight_idx + 2] = weights.b
				chunk_data.biome_weights[weight_idx + 3] = weights.a
			else:
				# Default to grass
				chunk_data.biome_weights[weight_idx] = 1.0
				chunk_data.biome_weights[weight_idx + 1] = 0.0
				chunk_data.biome_weights[weight_idx + 2] = 0.0
				chunk_data.biome_weights[weight_idx + 3] = 0.0


## Deliver pending results on main thread
func _deliver_results() -> void:
	_results_mutex.lock()
	var pending := _results.duplicate()
	_results.clear()
	_results_mutex.unlock()
	
	for result in pending:
		var coord: Vector2i = result["coord"]
		var data: ChunkData = result["data"]
		
		# Check if cancelled while generating
		_cancelled_mutex.lock()
		var was_cancelled := _cancelled.has(coord)
		_cancelled.erase(coord)
		_cancelled_mutex.unlock()
		
		if not was_cancelled:
			chunk_generated.emit(coord, data)


## Process queue synchronously (fallback for editor or disabled async)
func _process_queue_sync() -> void:
	var processed := 0
	
	while processed < max_sync_per_frame:
		var coord: Variant = null
		
		_queue_mutex.lock()
		if not _queue.is_empty():
			coord = _queue.pop_front()
			queue_size_changed.emit(_queue.size())
		_queue_mutex.unlock()
		
		if coord == null:
			break
		
		# Check if cancelled
		_cancelled_mutex.lock()
		var was_cancelled := _cancelled.has(coord)
		_cancelled.erase(coord)
		_cancelled_mutex.unlock()
		
		if not was_cancelled:
			var data := _generate_chunk_data(coord as Vector2i)
			chunk_generated.emit(coord, data)
		
		processed += 1
