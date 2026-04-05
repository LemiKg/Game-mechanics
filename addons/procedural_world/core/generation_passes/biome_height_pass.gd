class_name BiomeHeightPass
extends ChunkGenerationPass
## Applies biome-specific height modifications using blended biome strengths.


func apply(chunk_data: ChunkData, coord: Vector2i, config: WorldConfig) -> void:
	ChunkGenerator.apply_biome_heights(chunk_data, coord, config)
