@tool
extends RefCounted
class_name HeightGenerator
## Stateless utility class for generating terrain height data.
## Thread-safe: does not access scene tree, only uses provided parameters.


## Generates height data for a chunk at the given coordinate
## Returns PackedFloat32Array with width * depth values in row-major order
static func generate_height_data(
	coord: Vector2i,
	config: WorldConfig
) -> PackedFloat32Array:
	if not config or not config.noise:
		push_error("HeightGenerator: Invalid config or missing noise")
		return PackedFloat32Array()
	
	var resolution := config.chunk_resolution
	var cell_size := config.get_cell_size()
	var height_scale := config.height_scale
	var noise := config.noise
	
	# Calculate world offset for this chunk
	var world_offset := Vector2(
		coord.x * config.chunk_size,
		coord.y * config.chunk_size
	)
	
	var height_data := PackedFloat32Array()
	height_data.resize(resolution * resolution)
	
	for z in range(resolution):
		for x in range(resolution):
			var world_x := world_offset.x + x * cell_size
			var world_z := world_offset.y + z * cell_size
			
			# Sample noise (returns -1 to 1, normalize to 0-1)
			var noise_value := noise.get_noise_2d(world_x, world_z)
			var normalized := (noise_value + 1.0) * 0.5
			
			# Apply height scale
			var height := normalized * height_scale
			
			height_data[z * resolution + x] = height
	
	return height_data


## Generates moisture data for a chunk at the given coordinate
## Returns PackedFloat32Array with width * depth values in row-major order (0-1 range)
static func generate_moisture_data(
	coord: Vector2i,
	config: WorldConfig
) -> PackedFloat32Array:
	var resolution := config.chunk_resolution
	var cell_size := config.get_cell_size()
	
	# Calculate world offset for this chunk
	var world_offset := Vector2(
		coord.x * config.chunk_size,
		coord.y * config.chunk_size
	)
	
	var moisture_data := PackedFloat32Array()
	moisture_data.resize(resolution * resolution)
	
	# Use moisture noise if available, otherwise default to 0.5
	if not config.moisture_noise:
		moisture_data.fill(0.5)
		return moisture_data
	
	var noise := config.moisture_noise
	
	for z in range(resolution):
		for x in range(resolution):
			var world_x := world_offset.x + x * cell_size
			var world_z := world_offset.y + z * cell_size
			
			# Sample noise and normalize to 0-1
			var noise_value := noise.get_noise_2d(world_x, world_z)
			var normalized := (noise_value + 1.0) * 0.5
			
			moisture_data[z * resolution + x] = normalized
	
	return moisture_data


## Samples height at a specific world position
static func sample_height(world_x: float, world_z: float, config: WorldConfig) -> float:
	if not config or not config.noise:
		return 0.0
	
	var noise_value := config.noise.get_noise_2d(world_x, world_z)
	var normalized := (noise_value + 1.0) * 0.5
	return normalized * config.height_scale


## Samples moisture at a specific world position
static func sample_moisture(world_x: float, world_z: float, config: WorldConfig) -> float:
	if not config or not config.moisture_noise:
		return 0.5
	
	var noise_value := config.moisture_noise.get_noise_2d(world_x, world_z)
	return (noise_value + 1.0) * 0.5


## Calculates the normalized elevation (0-1) from raw height
static func get_normalized_elevation(height: float, config: WorldConfig) -> float:
	if not config or config.height_scale <= 0:
		return 0.5
	return clampf(height / config.height_scale, 0.0, 1.0)
