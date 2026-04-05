class_name MeshPass
extends ChunkGenerationPass
## Builds LOD mesh hierarchy from height data.


func apply(chunk_data: ChunkData, coord: Vector2i, config) -> void:
	var cell_size := config.get_cell_size()
	var lod_count := config.lod_distances.size() + 1
	chunk_data.mesh_lods = TerrainMeshBuilder.build_lod_meshes(
		chunk_data.height_data,
		chunk_data.width,
		chunk_data.depth,
		cell_size,
		lod_count
	)
