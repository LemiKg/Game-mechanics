class_name BiomeWeightPass
extends ChunkGenerationPass
## Calculates per-vertex biome weights for splatmap rendering.


func apply(chunk_data: ChunkData, coord: Vector2i, config) -> void:
	ChunkGenerator.calculate_biome_weights(chunk_data, coord, config)
