@tool
extends Resource
class_name ChunkData
## Container for all generated data of a single terrain chunk.
## Holds heightmap, moisture, biome weights, and pre-generated LOD meshes.

## Generation state of the chunk
enum GenerationState {
	PENDING, ## Chunk is queued for generation
	GENERATING, ## Chunk is currently being generated
	READY ## Chunk generation is complete
}

## Chunk coordinate in the world grid
var coord: Vector2i = Vector2i.ZERO

## Height values for each vertex (row-major order: z * width + x)
var height_data: PackedFloat32Array = PackedFloat32Array()

## Moisture values for each vertex (used for biome selection)
var moisture_data: PackedFloat32Array = PackedFloat32Array()

## RGBA biome weights per vertex (for splatmap blending)
## Packed as: [r0, g0, b0, a0, r1, g1, b1, a1, ...]
var biome_weights: PackedFloat32Array = PackedFloat32Array()

## Pre-generated meshes for each LOD level (index 0 = highest detail)
var mesh_lods: Array[ArrayMesh] = []

## Current generation state
var state: GenerationState = GenerationState.PENDING

## Width of the height data grid (chunk_resolution)
var width: int = 0

## Depth of the height data grid (chunk_resolution)
var depth: int = 0


## Initializes the chunk data with the specified dimensions
func initialize(chunk_coord: Vector2i, resolution: int) -> void:
	coord = chunk_coord
	width = resolution
	depth = resolution
	
	var total_vertices := width * depth
	height_data.resize(total_vertices)
	moisture_data.resize(total_vertices)
	biome_weights.resize(total_vertices * 4) # RGBA per vertex
	
	# Initialize to zero
	height_data.fill(0.0)
	moisture_data.fill(0.5)
	biome_weights.fill(0.0)
	
	mesh_lods.clear()
	state = GenerationState.PENDING


## Gets the height at a specific grid position
func get_height(x: int, z: int) -> float:
	if x < 0 or x >= width or z < 0 or z >= depth:
		return 0.0
	return height_data[z * width + x]


## Sets the height at a specific grid position
func set_height(x: int, z: int, value: float) -> void:
	if x < 0 or x >= width or z < 0 or z >= depth:
		return
	height_data[z * width + x] = value


## Gets the moisture at a specific grid position
func get_moisture(x: int, z: int) -> float:
	if x < 0 or x >= width or z < 0 or z >= depth:
		return 0.5
	return moisture_data[z * width + x]


## Sets the moisture at a specific grid position
func set_moisture(x: int, z: int, value: float) -> void:
	if x < 0 or x >= width or z < 0 or z >= depth:
		return
	moisture_data[z * width + x] = value


## Gets the biome weights (RGBA) at a specific grid position
func get_biome_weight(x: int, z: int) -> Color:
	if x < 0 or x >= width or z < 0 or z >= depth:
		return Color.WHITE
	var idx := (z * width + x) * 4
	return Color(
		biome_weights[idx],
		biome_weights[idx + 1],
		biome_weights[idx + 2],
		biome_weights[idx + 3]
	)


## Sets the biome weights (RGBA) at a specific grid position
func set_biome_weight(x: int, z: int, weight: Color) -> void:
	if x < 0 or x >= width or z < 0 or z >= depth:
		return
	var idx := (z * width + x) * 4
	biome_weights[idx] = weight.r
	biome_weights[idx + 1] = weight.g
	biome_weights[idx + 2] = weight.b
	biome_weights[idx + 3] = weight.a


## Returns the minimum height in the chunk
func get_min_height() -> float:
	if height_data.is_empty():
		return 0.0
	var min_h := height_data[0]
	for h in height_data:
		if h < min_h:
			min_h = h
	return min_h


## Returns the maximum height in the chunk
func get_max_height() -> float:
	if height_data.is_empty():
		return 0.0
	var max_h := height_data[0]
	for h in height_data:
		if h > max_h:
			max_h = h
	return max_h


## Clears all data and resets to initial state
func clear() -> void:
	height_data.clear()
	moisture_data.clear()
	biome_weights.clear()
	mesh_lods.clear()
	state = GenerationState.PENDING
	width = 0
	depth = 0
