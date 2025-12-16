@tool
extends RefCounted
class_name TerrainMeshBuilder
## Stateless utility class for building terrain meshes from height data.
## Thread-safe: does not access scene tree, only uses provided parameters.


## Builds a terrain mesh from height data
## @param heights: PackedFloat32Array with width * depth values
## @param width: Number of vertices in X direction
## @param depth: Number of vertices in Z direction
## @param cell_size: World units between adjacent vertices
## @return: ArrayMesh with vertices, normals, UVs, and indices
static func build_mesh(
	heights: PackedFloat32Array,
	width: int,
	depth: int,
	cell_size: float
) -> ArrayMesh:
	if heights.size() != width * depth:
		push_error("TerrainMeshBuilder: Height data size mismatch")
		return null
	
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	
	# Pre-allocate arrays
	var vertex_count := width * depth
	var quad_count := (width - 1) * (depth - 1)
	var index_count := quad_count * 6 # 2 triangles per quad, 3 indices each
	
	vertices.resize(vertex_count)
	uvs.resize(vertex_count)
	indices.resize(index_count)
	
	# Generate vertices and UVs
	for z in range(depth):
		for x in range(width):
			var idx := z * width + x
			var height := heights[idx]
			
			vertices[idx] = Vector3(x * cell_size, height, z * cell_size)
			uvs[idx] = Vector2(float(x) / (width - 1), float(z) / (depth - 1))
	
	# Generate indices (two triangles per quad)
	var index_offset := 0
	for z in range(depth - 1):
		for x in range(width - 1):
			var top_left := z * width + x
			var top_right := top_left + 1
			var bottom_left := (z + 1) * width + x
			var bottom_right := bottom_left + 1
			
			# Triangle 1 (counter-clockwise winding for upward-facing normals)
			indices[index_offset] = top_left
			indices[index_offset + 1] = top_right
			indices[index_offset + 2] = bottom_left
			
			# Triangle 2
			indices[index_offset + 3] = top_right
			indices[index_offset + 4] = bottom_right
			indices[index_offset + 5] = bottom_left
			
			index_offset += 6
	
	# Calculate normals
	normals = _calculate_normals(vertices, indices)
	
	# Build ArrayMesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh


## Builds multiple LOD meshes from height data
## @param heights: Full resolution height data
## @param width: Full resolution width
## @param depth: Full resolution depth
## @param cell_size: World units between vertices at full resolution
## @param lod_levels: Number of LOD levels to generate (including LOD0)
## @return: Array of ArrayMesh, index 0 is highest detail
static func build_lod_meshes(
	heights: PackedFloat32Array,
	width: int,
	depth: int,
	cell_size: float,
	lod_levels: int = 3
) -> Array[ArrayMesh]:
	var meshes: Array[ArrayMesh] = []
	
	# LOD 0: Full resolution
	var lod0 := build_mesh(heights, width, depth, cell_size)
	if lod0:
		meshes.append(lod0)
	
	# Generate lower LOD levels by downsampling
	var current_heights := heights
	var current_width := width
	var current_depth := depth
	var current_cell_size := cell_size
	
	for lod in range(1, lod_levels):
		# Downsample by factor of 2
		var result := _downsample_heights(current_heights, current_width, current_depth)
		current_heights = result.heights
		current_width = result.width
		current_depth = result.depth
		current_cell_size *= 2.0
		
		if current_width < 3 or current_depth < 3:
			break # Can't downsample further
		
		var lod_mesh := build_mesh(current_heights, current_width, current_depth, current_cell_size)
		if lod_mesh:
			meshes.append(lod_mesh)
	
	return meshes


## Calculates smooth normals for vertices based on triangle faces
static func _calculate_normals(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	
	# Initialize normals to zero
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO
	
	# Accumulate face normals for each vertex
	for i in range(0, indices.size(), 3):
		var i0 := indices[i]
		var i1 := indices[i + 1]
		var i2 := indices[i + 2]
		
		var v0 := vertices[i0]
		var v1 := vertices[i1]
		var v2 := vertices[i2]
		
		# Calculate face normal (counter-clockwise winding)
		var edge1 := v1 - v0
		var edge2 := v2 - v0
		var face_normal := edge1.cross(edge2)
		
		# Accumulate (weighted by face area via non-normalized cross product)
		normals[i0] += face_normal
		normals[i1] += face_normal
		normals[i2] += face_normal
	
	# Normalize all normals
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
		# Handle degenerate case
		if normals[i].is_zero_approx():
			normals[i] = Vector3.UP
	
	return normals


## Downsamples height data by factor of 2 using bilinear interpolation
static func _downsample_heights(
	heights: PackedFloat32Array,
	width: int,
	depth: int
) -> Dictionary:
	var new_width := (width + 1) / 2
	var new_depth := (depth + 1) / 2
	
	# Ensure minimum size
	new_width = maxi(new_width, 3)
	new_depth = maxi(new_depth, 3)
	
	var new_heights := PackedFloat32Array()
	new_heights.resize(new_width * new_depth)
	
	for z in range(new_depth):
		for x in range(new_width):
			# Map to source coordinates
			var src_x := x * 2
			var src_z := z * 2
			
			# Clamp to valid range
			src_x = mini(src_x, width - 1)
			src_z = mini(src_z, depth - 1)
			
			# Sample 2x2 area and average
			var h00 := heights[src_z * width + src_x]
			var h10 := heights[src_z * width + mini(src_x + 1, width - 1)]
			var h01 := heights[mini(src_z + 1, depth - 1) * width + src_x]
			var h11 := heights[mini(src_z + 1, depth - 1) * width + mini(src_x + 1, width - 1)]
			
			new_heights[z * new_width + x] = (h00 + h10 + h01 + h11) * 0.25
	
	return {
		"heights": new_heights,
		"width": new_width,
		"depth": new_depth
	}


## Creates height data suitable for HeightMapShape3D collision
## @param heights: Source height data
## @param width: Source width
## @param depth: Source depth
## @return: Dictionary with "data" (PackedFloat32Array) and "width"/"depth"
static func create_collision_data(
	heights: PackedFloat32Array,
	width: int,
	depth: int
) -> Dictionary:
	# HeightMapShape3D expects row-major order, same as our format
	return {
		"data": heights.duplicate(),
		"width": width,
		"depth": depth
	}
