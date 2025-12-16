@tool
extends RefCounted
class_name DecorationMeshBuilder
## Stateless utility class for building placeholder decoration meshes.
## Thread-safe: does not access scene tree, only creates mesh resources.
##
## Use these methods to generate simple procedural meshes for testing
## vegetation spawning before importing proper 3D assets.


## Build a pine tree mesh (trunk cylinder + cone canopy)
## @param trunk_height Height of the trunk cylinder
## @param trunk_radius Radius of the trunk
## @param canopy_radius Base radius of the cone canopy
## @param canopy_height Height of the cone canopy
## @param trunk_material Optional material for trunk
## @param canopy_material Optional material for canopy
## @return Combined ArrayMesh with two surfaces (trunk, canopy)
static func build_tree_mesh(
	trunk_height: float = 1.5,
	trunk_radius: float = 0.15,
	canopy_radius: float = 1.2,
	canopy_height: float = 3.5,
	trunk_material: Material = null,
	canopy_material: Material = null
) -> ArrayMesh:
	# Create trunk cylinder
	var trunk := CylinderMesh.new()
	trunk.height = trunk_height
	trunk.top_radius = trunk_radius * 0.8
	trunk.bottom_radius = trunk_radius
	trunk.radial_segments = 6
	trunk.rings = 1
	
	# Create cone canopy (pine tree shape)
	var canopy := CylinderMesh.new()
	canopy.height = canopy_height
	canopy.top_radius = 0.0  # Pointed top
	canopy.bottom_radius = canopy_radius
	canopy.radial_segments = 8
	canopy.rings = 1
	
	# Build combined mesh
	var mesh := ArrayMesh.new()
	
	# Add trunk surface (offset to sit at origin base)
	var trunk_arrays := trunk.get_mesh_arrays()
	trunk_arrays = _offset_vertices(trunk_arrays, Vector3(0, trunk_height * 0.5, 0))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk_arrays)
	if trunk_material:
		mesh.surface_set_material(0, trunk_material)
	
	# Add canopy surface (offset above trunk)
	var canopy_arrays := canopy.get_mesh_arrays()
	var canopy_y := trunk_height + canopy_height * 0.5
	canopy_arrays = _offset_vertices(canopy_arrays, Vector3(0, canopy_y, 0))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, canopy_arrays)
	if canopy_material:
		mesh.surface_set_material(1, canopy_material)
	
	return mesh


## Build a simple rock mesh (irregular boulder using box)
## @param size Base size of the rock
## @param material Optional material
## @return ArrayMesh rock
static func build_rock_mesh(
	size: float = 1.0,
	material: Material = null
) -> ArrayMesh:
	# Use a box mesh for a more solid-looking rock
	var box := BoxMesh.new()
	box.size = Vector3(size * 0.9, size * 0.6, size * 0.8)
	
	var mesh := ArrayMesh.new()
	var arrays := box.get_mesh_arrays()
	# Offset so bottom sits at y=0
	arrays = _offset_vertices(arrays, Vector3(0, size * 0.3, 0))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	if material:
		mesh.surface_set_material(0, material)
	
	return mesh


## Build a simple bush mesh (flattened sphere)
## @param radius Horizontal radius
## @param height Vertical height
## @param material Optional material
## @return ArrayMesh bush
static func build_bush_mesh(
	radius: float = 0.8,
	height: float = 0.6,
	material: Material = null
) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = 10
	sphere.rings = 5
	
	var mesh := ArrayMesh.new()
	var arrays := sphere.get_mesh_arrays()
	# Offset so bottom sits at y=0
	arrays = _offset_vertices(arrays, Vector3(0, height * 0.4, 0))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	if material:
		mesh.surface_set_material(0, material)
	
	return mesh


## Create a simple brown material for tree trunks
static func create_trunk_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.25, 0.1)  # Brown
	mat.roughness = 0.9
	return mat


## Create a simple green material for tree canopies/bushes
static func create_canopy_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.15)  # Forest green
	mat.roughness = 0.8
	return mat


## Create a simple gray material for rocks
static func create_rock_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)  # Gray
	mat.roughness = 0.95
	return mat


## Offset all vertices in a mesh array by a given vector
## @param arrays Mesh arrays from get_mesh_arrays()
## @param offset Vector3 offset to apply
## @return Modified mesh arrays
static func _offset_vertices(arrays: Array, offset: Vector3) -> Array:
	if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
		return arrays
	
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var new_vertices := PackedVector3Array()
	new_vertices.resize(vertices.size())
	
	for i in range(vertices.size()):
		new_vertices[i] = vertices[i] + offset
	
	var new_arrays := arrays.duplicate()
	new_arrays[Mesh.ARRAY_VERTEX] = new_vertices
	return new_arrays
