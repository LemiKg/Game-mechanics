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
	
	# Calculate normals from height gradients (consistent at chunk edges)
	normals = _calculate_normals_from_heights(heights, width, depth, cell_size)

	# Add edge skirts to hide LOD seam cracks
	var skirt_result := _add_skirts(vertices, normals, uvs, indices, width, depth)
	vertices = skirt_result["vertices"]
	normals = skirt_result["normals"]
	uvs = skirt_result["uvs"]
	indices = skirt_result["indices"]

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
## Calculate normals from height gradients using central differences.
## Unlike face-accumulated normals, this produces consistent results at chunk
## edges because each vertex's normal depends only on its immediate neighbors
## in the height grid, not on which triangles happen to exist on each side.
static func _calculate_normals_from_heights(
	heights: PackedFloat32Array,
	width: int,
	depth: int,
	cell_size: float
) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(width * depth)

	for z in range(depth):
		for x in range(width):
			var idx := z * width + x

			# Central differences, clamped at edges
			var xl := maxi(x - 1, 0)
			var xr := mini(x + 1, width - 1)
			var zu := maxi(z - 1, 0)
			var zd := mini(z + 1, depth - 1)

			var h_left := heights[z * width + xl]
			var h_right := heights[z * width + xr]
			var h_up := heights[zu * width + x]
			var h_down := heights[zd * width + x]

			# Height gradient scaled by actual sample distance
			var dx_dist := float(xr - xl) * cell_size
			var dz_dist := float(zd - zu) * cell_size

			var nx := (h_left - h_right) / maxf(dx_dist, 0.001)
			var nz := (h_up - h_down) / maxf(dz_dist, 0.001)

			normals[idx] = Vector3(nx, 1.0, nz).normalized()

	return normals


## Add downward skirts along chunk edges to hide LOD seam cracks.
static func _add_skirts(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	width: int,
	depth: int,
	skirt_depth: float = 0.5
) -> Dictionary:
	var edge_indices: Array[int] = []

	# Top edge (z=0)
	for x in range(width):
		edge_indices.append(x)
	# Bottom edge (z=depth-1)
	for x in range(width):
		edge_indices.append((depth - 1) * width + x)
	# Left edge (x=0), skip corners already added
	for z in range(1, depth - 1):
		edge_indices.append(z * width)
	# Right edge (x=width-1), skip corners
	for z in range(1, depth - 1):
		edge_indices.append(z * width + (width - 1))

	var new_vertices := vertices.duplicate()
	var new_normals := normals.duplicate()
	var new_uvs := uvs.duplicate()
	var new_indices := indices.duplicate()

	# For each edge vertex, create a dropped vertex
	var edge_map: Dictionary = {}
	for orig_idx in edge_indices:
		var dropped_pos := vertices[orig_idx]
		dropped_pos.y -= skirt_depth
		var new_idx := new_vertices.size()
		new_vertices.append(dropped_pos)
		new_normals.append(normals[orig_idx])
		new_uvs.append(uvs[orig_idx])
		edge_map[orig_idx] = new_idx

	# Top edge skirt (z=0, faces -Z)
	for x in range(width - 1):
		var a := x
		var b := x + 1
		new_indices.append(a)
		new_indices.append(edge_map[a])
		new_indices.append(b)
		new_indices.append(b)
		new_indices.append(edge_map[a])
		new_indices.append(edge_map[b])

	# Bottom edge skirt (z=depth-1, faces +Z)
	for x in range(width - 1):
		var a := (depth - 1) * width + x
		var b := (depth - 1) * width + x + 1
		new_indices.append(a)
		new_indices.append(b)
		new_indices.append(edge_map[a])
		new_indices.append(b)
		new_indices.append(edge_map[b])
		new_indices.append(edge_map[a])

	# Left edge skirt (x=0, faces -X)
	for z in range(depth - 1):
		var a := z * width
		var b := (z + 1) * width
		new_indices.append(a)
		new_indices.append(b)
		new_indices.append(edge_map[a])
		new_indices.append(b)
		new_indices.append(edge_map[b])
		new_indices.append(edge_map[a])

	# Right edge skirt (x=width-1, faces +X)
	for z in range(depth - 1):
		var a := z * width + (width - 1)
		var b := (z + 1) * width + (width - 1)
		new_indices.append(a)
		new_indices.append(edge_map[a])
		new_indices.append(b)
		new_indices.append(b)
		new_indices.append(edge_map[a])
		new_indices.append(edge_map[b])

	return {
		"vertices": new_vertices,
		"normals": new_normals,
		"uvs": new_uvs,
		"indices": new_indices
	}


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


## Builds a splatmap texture from biome weights for shader blending
## @param biome_weights: PackedFloat32Array with RGBA values per vertex (size = width * depth * 4)
## @param width: Number of vertices in X direction
## @param depth: Number of vertices in Z direction
## @return: ImageTexture suitable for shader splatmap uniform
static func build_splatmap_texture(
	biome_weights: PackedFloat32Array,
	width: int,
	depth: int
) -> ImageTexture:
	if biome_weights.size() != width * depth * 4:
		push_error("TerrainMeshBuilder: Biome weights size mismatch (expected %d, got %d)" % [width * depth * 4, biome_weights.size()])
		return null
	
	# Create image from biome weights
	var image := Image.create(width, depth, false, Image.FORMAT_RGBA8)
	
	for z in range(depth):
		for x in range(width):
			var idx := (z * width + x) * 4
			var color := Color(
				biome_weights[idx], # R
				biome_weights[idx + 1], # G
				biome_weights[idx + 2], # B
				biome_weights[idx + 3] # A
			)
			image.set_pixel(x, z, color)
	
	# Create texture from image
	var texture := ImageTexture.create_from_image(image)
	return texture
