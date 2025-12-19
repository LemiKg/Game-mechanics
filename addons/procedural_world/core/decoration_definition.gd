@tool
extends Resource
class_name DecorationDefinition
## Defines a decoration type for vegetation/prop spawning.
## Used by VegetationSpawner to populate terrain chunks with objects.
##
## Each decoration defines:
## - The mesh to instance (or auto-generated from type)
## - Density and scale parameters
## - Slope constraints for placement validity
## - Normal alignment behavior

## Type of decoration (used for auto-generating placeholder mesh if none provided)
enum DecorationType {TREE, ROCK, BUSH, CUSTOM}

## Decoration type for automatic mesh generation
@export var decoration_type: DecorationType = DecorationType.TREE

## The mesh to use for this decoration (auto-generated if null based on type)
@export var mesh: Mesh

## Single scene (GLB/GLTF file) - mesh is extracted at runtime
## Use this for single model decorations, use scene_variants for multiple
@export var scene: PackedScene

## Array of scene variants (GLB/GLTF files import as PackedScene)
## Meshes are extracted from MeshInstance3D nodes at runtime
@export var scene_variants: Array[PackedScene] = []

## Cached meshes extracted from scene_variants (populated on first access)
var _cached_variant_meshes: Array[Mesh] = []

## Cached mesh from single scene
var _cached_scene_mesh: Mesh = null

## Optional material override (uses mesh material if null)
@export var material: Material

## Instances per square world unit (higher = more dense)
@export_range(0.001, 10.0, 0.001) var density: float = 0.1

## Minimum random scale factor
@export_range(0.1, 5.0, 0.01) var min_scale: float = 0.8

## Maximum random scale factor
@export_range(0.1, 5.0, 0.01) var max_scale: float = 1.2

## Minimum terrain slope in radians (0 = flat)
@export_range(0.0, 1.571, 0.01) var min_slope: float = 0.0

## Maximum terrain slope in radians (~1.57 = 90 degrees)
@export_range(0.0, 1.571, 0.01) var max_slope: float = 0.5

## Whether to align instances to terrain normal (true) or keep upright (false)
@export var align_to_normal: bool = false

## Vertical offset from terrain surface (use for buried roots, floating objects)
@export var y_offset: float = 0.0

## Random rotation range in radians (0 = no rotation, TAU = full 360)
@export_range(0.0, 6.283, 0.01) var random_rotation: float = TAU

## ============================================
## ADVANCED TRANSFORM
## ============================================
@export_group("Advanced Transform")

## Non-uniform scale variance per axis (0 = uniform, 0.2 = ±20% per axis)
@export var scale_variance: Vector3 = Vector3.ZERO

## Random tilt range on X/Z axes in radians (for natural settling)
@export_range(0.0, 0.5, 0.01) var random_tilt: float = 0.0

## Maximum normal alignment angle in radians (0 = ignore terrain, 1.57 = full alignment)
@export_range(0.0, 1.571, 0.01) var max_align_angle: float = 1.571

## Random Y offset variance for burial effect (negative values = buried)
@export_range(0.0, 1.0, 0.01) var y_offset_variance: float = 0.0

## ============================================
## CLUSTERING
## ============================================
@export_group("Clustering")

## Cluster strength (0 = uniform distribution, 1 = highly clustered)
@export_range(0.0, 1.0, 0.05) var cluster_strength: float = 0.0

## Scale of cluster noise (smaller = larger clusters)
@export_range(0.001, 0.1, 0.001) var cluster_scale: float = 0.02

## Cluster group ID - decorations with same ID share cluster pattern
@export var cluster_group_id: int = 0

## Seed offset for cluster noise (variation within same group)
@export var cluster_seed_offset: int = 0

## Scale falloff at cluster edges (0 = none, 1 = min_scale at edges)
@export_range(0.0, 1.0, 0.05) var cluster_edge_scale_falloff: float = 0.0

## ============================================
## SAMPLING
## ============================================
@export_group("Sampling")

## Use Poisson disk sampling for better spacing (recommended for trees/large rocks)
@export var use_poisson_sampling: bool = false

## ============================================
## COLLISION
## ============================================
@export_group("Collision")

## Whether this decoration has collision
@export var has_collision: bool = false

## Collision shape type
enum CollisionShapeType {CYLINDER, BOX, CAPSULE}
@export var collision_shape: CollisionShapeType = CollisionShapeType.CYLINDER

## Collision radius (for cylinder/capsule)
@export_range(0.1, 5.0, 0.1) var collision_radius: float = 0.5

## Collision height
@export_range(0.1, 20.0, 0.1) var collision_height: float = 2.0

## Only spawn collision within this distance from player (0 = always spawn)
@export_range(0.0, 100.0, 1.0) var collision_distance: float = 50.0


## Validate that slope constraints are logical
func _validate_property(property: Dictionary) -> void:
	if property.name == "max_slope" and max_slope < min_slope:
		max_slope = min_slope


## Check if a slope angle is valid for this decoration
## @param slope_radians Terrain slope in radians
## @return True if decoration can spawn at this slope
func is_slope_valid(slope_radians: float) -> bool:
	return slope_radians >= min_slope and slope_radians <= max_slope


## Get a random scale value between min and max
## @param rng RandomNumberGenerator for deterministic results
## @return Random scale factor
func get_random_scale(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(min_scale, max_scale)


## Get a random Y rotation
## @param rng RandomNumberGenerator for deterministic results
## @return Random rotation in radians
func get_random_rotation(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(0.0, random_rotation)


## Get a random mesh from scene variants, or fallback to single mesh/scene
## @param rng RandomNumberGenerator for deterministic results
## @return A mesh from variants array, or the single mesh, or null
func get_random_mesh(rng: RandomNumberGenerator) -> Mesh:
	_ensure_meshes_cached()
	if not _cached_variant_meshes.is_empty():
		return _cached_variant_meshes[rng.randi() % _cached_variant_meshes.size()]
	if _cached_scene_mesh:
		return _cached_scene_mesh
	return mesh


## Check if this decoration has multiple mesh variants
func has_variants() -> bool:
	_ensure_meshes_cached()
	return _cached_variant_meshes.size() > 1


## Get total number of mesh options (variants or single mesh/scene)
func get_mesh_count() -> int:
	_ensure_meshes_cached()
	if not _cached_variant_meshes.is_empty():
		return _cached_variant_meshes.size()
	if _cached_scene_mesh or mesh:
		return 1
	return 0


## Get all cached variant meshes (for MultiMesh batching)
func get_variant_meshes() -> Array[Mesh]:
	_ensure_meshes_cached()
	return _cached_variant_meshes


## Ensure meshes are extracted from scene/scene_variants
func _ensure_meshes_cached() -> void:
	# Extract from single scene if not already cached
	if not _cached_scene_mesh and scene:
		_cached_scene_mesh = _extract_mesh_from_scene(scene)
	
	# Extract from scene_variants if not already cached
	if _cached_variant_meshes.is_empty() and not scene_variants.is_empty():
		for scene_variant in scene_variants:
			if not scene_variant:
				continue
			var extracted := _extract_mesh_from_scene(scene_variant)
			if extracted:
				_cached_variant_meshes.append(extracted)


## Extract the first mesh found in a PackedScene
func _extract_mesh_from_scene(scene: PackedScene) -> Mesh:
	var instance := scene.instantiate()
	if not instance:
		return null
	
	var found_mesh: Mesh = null
	
	# Check if root is a MeshInstance3D
	if instance is MeshInstance3D:
		found_mesh = instance.mesh
	else:
		# Search children for MeshInstance3D
		for child in instance.get_children():
			if child is MeshInstance3D:
				found_mesh = child.mesh
				break
			# Check grandchildren (common in GLB imports)
			for grandchild in child.get_children():
				if grandchild is MeshInstance3D:
					found_mesh = grandchild.mesh
					break
			if found_mesh:
				break
	
	instance.queue_free()
	return found_mesh
