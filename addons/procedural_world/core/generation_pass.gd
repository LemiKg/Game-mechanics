class_name ChunkGenerationPass
extends RefCounted
## Base class for a single step in the chunk generation pipeline.
##
## Subclass and override apply() to add custom generation stages.
## Passes are executed in order by ChunkGenerator.


## Apply this generation pass to the chunk data.
## Override in subclasses. Must be thread-safe.
func apply(chunk_data: ChunkData, coord: Vector2i, config) -> void:
	pass
