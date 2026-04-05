class_name ChunkGenerator
extends RefCounted
## Stateless chunk generation pipeline.
##
## Runs an ordered array of ChunkGenerationPass instances against chunk data.
## The default pipeline handles heights, biomes, and mesh building.
## Custom pipelines can insert erosion, caves, rivers, etc.


## The default generation pipeline used when no custom pipeline is provided.
static var default_pipeline: Array[ChunkGenerationPass] = [
	HeightPass.new(),
	BiomeHeightPass.new(),
	BiomeWeightPass.new(),
	MeshPass.new(),
]


## Generate a complete chunk using the provided pipeline (or default).
static func generate(coord: Vector2i, config: WorldConfig, pipeline: Array[ChunkGenerationPass] = []) -> ChunkData:
	var chunk_data := ChunkData.new()
	chunk_data.initialize(coord, config.chunk_resolution)

	var passes := pipeline if not pipeline.is_empty() else default_pipeline
	for pass_step in passes:
		pass_step.apply(chunk_data, coord, config)

	chunk_data.state = ChunkData.GenerationState.READY
	return chunk_data


## Apply biome height modifications to chunk data.
static func apply_biome_heights(chunk_data: ChunkData, coord: Vector2i, config: WorldConfig) -> void:
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
static func calculate_biome_weights(chunk_data: ChunkData, coord: Vector2i, config: WorldConfig) -> void:
	var biome_map: BiomeMap = config.biome_map if config else null
	var cell_size: float = config.get_cell_size() if config else 1.0
	var resolution := chunk_data.width

	var world_offset_x: float = coord.x * config.chunk_size if config else 0.0
	var world_offset_z: float = coord.y * config.chunk_size if config else 0.0

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


## Determine which biome dominates a chunk based on total biome weight sums.
## Returns the BiomeData with the highest total weight, or fallback_biome.
static func get_dominant_biome(chunk_data: ChunkData, biome_map: BiomeMap) -> BiomeData:
	if not biome_map:
		return null

	# Sum weights per splatmap channel across all vertices
	var channel_sums := [0.0, 0.0, 0.0, 0.0]
	var vertex_count := chunk_data.width * chunk_data.depth

	for i in range(vertex_count):
		var idx := i * 4
		channel_sums[0] += chunk_data.biome_weights[idx]
		channel_sums[1] += chunk_data.biome_weights[idx + 1]
		channel_sums[2] += chunk_data.biome_weights[idx + 2]
		channel_sums[3] += chunk_data.biome_weights[idx + 3]

	# Find dominant channel
	var max_sum := 0.0
	var dominant_channel := 0
	for ch in range(4):
		if channel_sums[ch] > max_sum:
			max_sum = channel_sums[ch]
			dominant_channel = ch

	# Find the biome that uses this channel
	for biome in biome_map.biomes:
		if biome and biome.splatmap_channel == dominant_channel:
			return biome

	return biome_map.fallback_biome
