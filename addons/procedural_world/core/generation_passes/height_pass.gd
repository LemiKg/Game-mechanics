class_name HeightPass
extends ChunkGenerationPass
## Generates base terrain heights and moisture data from noise.


func apply(chunk_data: ChunkData, coord: Vector2i, config: WorldConfig) -> void:
	chunk_data.height_data = HeightGenerator.generate_height_data(coord, config)
	chunk_data.moisture_data = HeightGenerator.generate_moisture_data(coord, config)
