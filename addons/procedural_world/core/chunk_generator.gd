class_name ChunkGenerator
extends RefCounted
## Stateless chunk generation pipeline.
##
## Encapsulates the full generation pipeline: heights, moisture, biome
## modifications, biome weights, and mesh building. Thread-safe.
## Used by both ChunkManager (sync) and AsyncGenerationHandler (async).


## Generate a complete chunk with all passes.
static func generate(coord: Vector2i, config) -> ChunkData:
	var chunk_data := ChunkData.new()
	chunk_data.initialize(coord, config.chunk_resolution)

	# Pass 1: Generate base heights and moisture
	chunk_data.height_data = HeightGenerator.generate_height_data(coord, config)
	chunk_data.moisture_data = HeightGenerator.generate_moisture_data(coord, config)

	# Pass 2: Apply biome height modifications
	apply_biome_heights(chunk_data, coord, config)

	# Pass 3: Calculate biome weights for splatmap
	calculate_biome_weights(chunk_data, coord, config)

	# Pass 4: Build LOD meshes
	var cell_size := config.get_cell_size()
	var lod_count := config.lod_distances.size() + 1
	chunk_data.mesh_lods = TerrainMeshBuilder.build_lod_meshes(
		chunk_data.height_data,
		chunk_data.width,
		chunk_data.depth,
		cell_size,
		lod_count
	)

	chunk_data.state = ChunkData.GenerationState.READY
	return chunk_data


## Apply biome height modifications to chunk data.
static func apply_biome_heights(chunk_data: ChunkData, coord: Vector2i, config) -> void:
	if not config or not config.biome_map:
		return

	var biome_map := config.biome_map
	var cell_size := config.get_cell_size()
	var resolution := chunk_data.width

	var world_offset_x := coord.x * config.chunk_size
	var world_offset_z := coord.y * config.chunk_size

	for z in range(resolution):
		for x in range(resolution):
			var idx := z * resolution + x
			var height := chunk_data.height_data[idx]
			var moisture := chunk_data.moisture_data[idx]
			var elevation := HeightGenerator.get_normalized_elevation(height, config)
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


## Calculate biome weights for splatmap rendering.
static func calculate_biome_weights(chunk_data: ChunkData, coord: Vector2i, config) -> void:
	var biome_map = config.biome_map if config else null
	var cell_size := config.get_cell_size() if config else 1.0
	var resolution := chunk_data.width

	var world_offset_x := coord.x * config.chunk_size if config else 0.0
	var world_offset_z := coord.y * config.chunk_size if config else 0.0

	for z in range(resolution):
		for x in range(resolution):
			var idx := z * resolution + x
			var weight_idx := idx * 4

			if biome_map:
				var height := chunk_data.height_data[idx]
				var moisture := chunk_data.moisture_data[idx]
				var elevation := HeightGenerator.get_normalized_elevation(height, config)
				var weights := biome_map.get_biome_weights(elevation, moisture)

				chunk_data.biome_weights[weight_idx] = weights.r
				chunk_data.biome_weights[weight_idx + 1] = weights.g
				chunk_data.biome_weights[weight_idx + 2] = weights.b
				chunk_data.biome_weights[weight_idx + 3] = weights.a
			else:
				chunk_data.biome_weights[weight_idx] = 1.0
				chunk_data.biome_weights[weight_idx + 1] = 0.0
				chunk_data.biome_weights[weight_idx + 2] = 0.0
				chunk_data.biome_weights[weight_idx + 3] = 0.0
