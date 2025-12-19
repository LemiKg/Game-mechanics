@tool
extends Node
class_name VegetationSpawner
## Spawns vegetation and decorations on terrain chunks using MultiMesh.
## Uses jittered grid placement for natural-looking distribution.
##
## Connect to ChunkManager.chunk_ready and chunk_unloaded signals
## to automatically populate/clear chunks.

## Reference to the chunk manager for terrain data access
@export var chunk_manager: ChunkManager

## World configuration for height sampling
@export var world_config: WorldConfig

## Default decorations to spawn if biomes don't define any
@export var default_decorations: Array[DecorationDefinition] = []

## Random seed for reproducible placement
@export var seed: int = 12345

## Maximum decorations per chunk (performance limit)
@export var max_per_chunk: int = 500

## Enable spawning (can be toggled at runtime)
@export var spawning_enabled: bool = true

## Only spawn within this many chunks of the player
@export var spawn_radius: int = 4

## MultiMesh instances per chunk (coord -> Array of MultiMeshInstance3D)
var _chunk_multimeshes: Dictionary = {}

## Collision bodies per chunk (coord -> Array of StaticBody3D)
var _chunk_collisions: Dictionary = {}

## Cached decoration meshes (decoration index -> ArrayMesh)
var _cached_meshes: Dictionary = {}

## Random number generator (seeded per chunk for reproducibility)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Noise generator for clustering
var _cluster_noise: FastNoiseLite

## Poisson disk sampling constants
const POISSON_MAX_ATTEMPTS := 30
const POISSON_MARGIN_FACTOR := 0.2


func _ready() -> void:
	if Engine.is_editor_hint():
		return # No spawning in editor
	
	# Initialize cluster noise
	_cluster_noise = FastNoiseLite.new()
	_cluster_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cluster_noise.seed = seed
	_cluster_noise.frequency = 0.02
	
	# Connect to chunk manager if assigned
	if chunk_manager:
		_connect_to_chunk_manager()


## Connect to chunk manager signals
func _connect_to_chunk_manager() -> void:
	if not chunk_manager:
		return
	
	if not chunk_manager.chunk_ready.is_connected(_on_chunk_ready):
		chunk_manager.chunk_ready.connect(_on_chunk_ready)
	
	if not chunk_manager.chunk_unloaded.is_connected(_on_chunk_unloaded):
		chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)


## Called when a chunk is ready
func _on_chunk_ready(coord: Vector2i) -> void:
	if not spawning_enabled or Engine.is_editor_hint():
		return
	
	# Check if within spawn radius
	if chunk_manager and chunk_manager.player:
		var player_coord := chunk_manager.world_to_coord(chunk_manager.player.global_position)
		var distance := maxi(absi(coord.x - player_coord.x), absi(coord.y - player_coord.y))
		if distance > spawn_radius:
			return
	
	spawn_for_chunk(coord)


## Called when a chunk is unloaded
func _on_chunk_unloaded(coord: Vector2i) -> void:
	clear_chunk(coord)


## Spawn decorations for a chunk
## @param coord Chunk coordinate
func spawn_for_chunk(coord: Vector2i) -> void:
	if not world_config:
		return
	
	# Clear existing decorations for this chunk
	clear_chunk(coord)
	
	# Get chunk data
	var chunk := chunk_manager.get_chunk_at(chunk_manager.coord_to_world(coord)) if chunk_manager else null
	if not chunk or not chunk.chunk_data:
		return
	
	var chunk_data := chunk.chunk_data
	
	# Get decorations from biomes or use defaults
	var decorations := _get_decorations_for_chunk(chunk_data)
	if decorations.is_empty():
		decorations = default_decorations
	
	if decorations.is_empty():
		return
	
	# Seed RNG for reproducible placement based on chunk coord
	_rng.seed = seed + coord.x * 73856093 + coord.y * 19349663
	
	var chunk_size := world_config.chunk_size
	var cell_size := world_config.get_cell_size()
	var resolution := chunk_data.width
	
	# World offset for this chunk
	var world_offset := Vector3(
		coord.x * chunk_size,
		0.0,
		coord.y * chunk_size
	)
	
	# Spawn each decoration type
	var multimeshes: Array[MultiMeshInstance3D] = []
	var collision_bodies: Array[StaticBody3D] = []
	
	for decoration in decorations:
		if not decoration:
			continue
		
		var all_instances: Array[Transform3D] = []
		
		# Check if decoration has mesh variants
		if decoration.has_variants():
			# Generate instances grouped by mesh variant
			var variant_instances := _generate_instances_with_variants(
				decoration,
				chunk_data,
				world_offset,
				chunk_size,
				cell_size,
				resolution
			)
			
			# Get cached meshes extracted from scenes
			var variant_meshes := decoration.get_variant_meshes()
			
			# Create one MultiMesh per variant for GPU batching
			for variant_idx in variant_instances:
				var instances: Array[Transform3D] = variant_instances[variant_idx]
				if instances.is_empty():
					continue
				
				if variant_idx >= variant_meshes.size():
					continue
				
				var mesh: Mesh = variant_meshes[variant_idx]
				var mmi := _create_multimesh_from_mesh(mesh, instances, decoration.material)
				if mmi:
					add_child(mmi)
					multimeshes.append(mmi)
				
				# Collect all transforms for collision
				all_instances.append_array(instances)
		else:
			# Single mesh - use original logic
			var instances := _generate_instances(
				decoration,
				chunk_data,
				world_offset,
				chunk_size,
				cell_size,
				resolution
			)
			
			if instances.is_empty():
				continue
			
			# Create MultiMesh for this decoration type
			var mmi := _create_multimesh_instance(decoration, instances)
			if mmi:
				add_child(mmi)
				multimeshes.append(mmi)
			
			all_instances = instances
		
		# Spawn collision bodies if enabled
		if decoration.has_collision and not all_instances.is_empty():
			var bodies := _spawn_collision_bodies(decoration, all_instances)
			collision_bodies.append_array(bodies)
	
	if not multimeshes.is_empty():
		_chunk_multimeshes[coord] = multimeshes
	
	if not collision_bodies.is_empty():
		_chunk_collisions[coord] = collision_bodies


## Generate instance transforms for a decoration
func _generate_instances(
	decoration: DecorationDefinition,
	chunk_data: ChunkData,
	world_offset: Vector3,
	chunk_size: float,
	cell_size: float,
	resolution: int
) -> Array[Transform3D]:
	var instances: Array[Transform3D] = []
	
	# Calculate min distance based on density
	var min_distance := 1.0 / sqrt(decoration.density) if decoration.density > 0 else 10.0
	
	# Configure cluster noise for this decoration
	var use_clustering := decoration.cluster_strength > 0.0 and _cluster_noise
	if use_clustering:
		_cluster_noise.frequency = decoration.cluster_scale
		# Use cluster_group_id for base pattern, cluster_seed_offset for variation
		_cluster_noise.seed = seed + decoration.cluster_group_id * 1000 + decoration.cluster_seed_offset
	
	# Get sample points - either Poisson disk or jittered grid
	var sample_points: Array[Vector2] = []
	if decoration.use_poisson_sampling:
		var decoration_seed := decoration.cluster_group_id * 1000 + decoration.cluster_seed_offset
		sample_points = _generate_poisson_points_with_margin(chunk_data.coord, chunk_size, min_distance, decoration_seed)
	else:
		sample_points = _generate_jittered_grid_points(chunk_size, min_distance)
	
	for point in sample_points:
		if instances.size() >= max_per_chunk:
			break
		
		var local_x := point.x
		var local_z := point.y
		
		# Skip if outside chunk bounds
		if local_x >= chunk_size or local_z >= chunk_size:
			continue
		
		# Apply clustering - use noise to determine spawn probability
		var cluster_edge_factor := 1.0 # 1.0 = cluster center, 0.0 = cluster edge
		if use_clustering:
			var world_x := world_offset.x + local_x
			var world_z := world_offset.z + local_z
			var noise_val := (_cluster_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5 # 0-1
			var threshold := decoration.cluster_strength * 0.7 # Higher strength = higher threshold
			if noise_val < threshold:
				continue # Skip this position (creates gaps = clusters)
			
			# Calculate edge factor for scale falloff
			if decoration.cluster_edge_scale_falloff > 0.0:
				cluster_edge_factor = clampf((noise_val - threshold) / (1.0 - threshold + 0.001), 0.0, 1.0)
		
		# Sample height from chunk data
		var height := _sample_height_at(local_x, local_z, chunk_data, cell_size, resolution)
		
		# Calculate slope at this position
		var slope := _calculate_slope_at(local_x, local_z, chunk_data, cell_size, resolution)
		
		# Check slope constraints
		if not decoration.is_slope_valid(slope):
			continue
		
		# Calculate Y offset with variance (negative = buried)
		var y_off := decoration.y_offset
		if decoration.y_offset_variance > 0.0:
			y_off -= _rng.randf() * decoration.y_offset_variance
		
		# Create transform
		var pos := world_offset + Vector3(local_x, height + y_off, local_z)
		var rotation := decoration.get_random_rotation(_rng)
		
		# Get base scale with cluster edge falloff
		var base_scale := decoration.get_random_scale(_rng)
		if decoration.cluster_edge_scale_falloff > 0.0:
			var min_edge_scale := lerpf(decoration.min_scale, base_scale, 1.0 - decoration.cluster_edge_scale_falloff)
			base_scale = lerpf(min_edge_scale, base_scale, cluster_edge_factor)
		
		var transform := Transform3D.IDENTITY
		
		# Apply normal alignment if enabled (with angle limit)
		if decoration.align_to_normal:
			var normal := _sample_normal_at(local_x, local_z, chunk_data, cell_size, resolution)
			transform = _align_to_normal_limited(normal, decoration.max_align_angle)
		
		# Apply random tilt on X/Z axes for natural settling
		if decoration.random_tilt > 0.0:
			var tilt_x := _rng.randf_range(-decoration.random_tilt, decoration.random_tilt)
			var tilt_z := _rng.randf_range(-decoration.random_tilt, decoration.random_tilt)
			transform = transform.rotated(transform.basis.x.normalized(), tilt_x)
			transform = transform.rotated(transform.basis.z.normalized(), tilt_z)
		
		# Apply rotation around Y axis
		transform = transform.rotated(Vector3.UP, rotation)
		
		# Apply scale (non-uniform if variance is set)
		var scale_vec := Vector3.ONE * base_scale
		if decoration.scale_variance != Vector3.ZERO:
			scale_vec.x *= 1.0 + _rng.randf_range(-decoration.scale_variance.x, decoration.scale_variance.x)
			scale_vec.y *= 1.0 + _rng.randf_range(-decoration.scale_variance.y, decoration.scale_variance.y)
			scale_vec.z *= 1.0 + _rng.randf_range(-decoration.scale_variance.z, decoration.scale_variance.z)
		transform = transform.scaled(scale_vec)
		
		# Apply position
		transform.origin = pos
		
		instances.append(transform)
	
	return instances


## Generate jittered grid sample points (fallback when not using Poisson)
func _generate_jittered_grid_points(chunk_size: float, grid_cell: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var grid_count := int(ceil(chunk_size / grid_cell))
	
	for gz in range(grid_count):
		for gx in range(grid_count):
			var jitter_x := _rng.randf() * grid_cell
			var jitter_z := _rng.randf() * grid_cell
			
			var local_x := gx * grid_cell + jitter_x
			var local_z := gz * grid_cell + jitter_z
			
			if local_x < chunk_size and local_z < chunk_size:
				points.append(Vector2(local_x, local_z))
	
	return points


## Generate instance transforms grouped by mesh variant
## Returns Dictionary[int, Array[Transform3D]] where key is variant index
func _generate_instances_with_variants(
	decoration: DecorationDefinition,
	chunk_data: ChunkData,
	world_offset: Vector3,
	chunk_size: float,
	cell_size: float,
	resolution: int
) -> Dictionary:
	var variant_instances: Dictionary = {}
	var variant_count := decoration.get_mesh_count()
	
	# Initialize arrays for each variant
	for i in range(variant_count):
		variant_instances[i] = [] as Array[Transform3D]
	
	# Calculate min distance based on density
	var min_distance := 1.0 / sqrt(decoration.density) if decoration.density > 0 else 10.0
	var total_count := 0
	
	# Configure cluster noise for this decoration
	var use_clustering := decoration.cluster_strength > 0.0 and _cluster_noise
	if use_clustering:
		_cluster_noise.frequency = decoration.cluster_scale
		# Use cluster_group_id for base pattern, cluster_seed_offset for variation
		_cluster_noise.seed = seed + decoration.cluster_group_id * 1000 + decoration.cluster_seed_offset
	
	# Get sample points - either Poisson disk or jittered grid
	var sample_points: Array[Vector2] = []
	if decoration.use_poisson_sampling:
		var decoration_seed := decoration.cluster_group_id * 1000 + decoration.cluster_seed_offset
		sample_points = _generate_poisson_points_with_margin(chunk_data.coord, chunk_size, min_distance, decoration_seed)
	else:
		sample_points = _generate_jittered_grid_points(chunk_size, min_distance)
	
	for point in sample_points:
		if total_count >= max_per_chunk:
			break
		
		var local_x := point.x
		var local_z := point.y
		
		# Skip if outside chunk bounds
		if local_x >= chunk_size or local_z >= chunk_size:
			continue
		
		# Apply clustering - use noise to determine spawn probability
		var cluster_edge_factor := 1.0 # 1.0 = cluster center, 0.0 = cluster edge
		if use_clustering:
			var world_x := world_offset.x + local_x
			var world_z := world_offset.z + local_z
			var noise_val := (_cluster_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5 # 0-1
			var threshold := decoration.cluster_strength * 0.7 # Higher strength = higher threshold
			if noise_val < threshold:
				continue # Skip this position (creates gaps = clusters)
			
			# Calculate edge factor for scale falloff
			if decoration.cluster_edge_scale_falloff > 0.0:
				cluster_edge_factor = clampf((noise_val - threshold) / (1.0 - threshold + 0.001), 0.0, 1.0)
		
		# Sample height from chunk data
		var height := _sample_height_at(local_x, local_z, chunk_data, cell_size, resolution)
		
		# Calculate slope at this position
		var slope := _calculate_slope_at(local_x, local_z, chunk_data, cell_size, resolution)
		
		# Check slope constraints
		if not decoration.is_slope_valid(slope):
			continue
		
		# Pick a random variant
		var variant_idx := _rng.randi() % variant_count
		
		# Calculate Y offset with variance (negative = buried)
		var y_off := decoration.y_offset
		if decoration.y_offset_variance > 0.0:
			y_off -= _rng.randf() * decoration.y_offset_variance
		
		# Create transform
		var pos := world_offset + Vector3(local_x, height + y_off, local_z)
		var rotation := decoration.get_random_rotation(_rng)
		
		# Get base scale with cluster edge falloff
		var base_scale := decoration.get_random_scale(_rng)
		if decoration.cluster_edge_scale_falloff > 0.0:
			var min_edge_scale := lerpf(decoration.min_scale, base_scale, 1.0 - decoration.cluster_edge_scale_falloff)
			base_scale = lerpf(min_edge_scale, base_scale, cluster_edge_factor)
		
		var transform := Transform3D.IDENTITY
		
		# Apply normal alignment if enabled (with angle limit)
		if decoration.align_to_normal:
			var normal := _sample_normal_at(local_x, local_z, chunk_data, cell_size, resolution)
			transform = _align_to_normal_limited(normal, decoration.max_align_angle)
		
		# Apply random tilt on X/Z axes for natural settling
		if decoration.random_tilt > 0.0:
			var tilt_x := _rng.randf_range(-decoration.random_tilt, decoration.random_tilt)
			var tilt_z := _rng.randf_range(-decoration.random_tilt, decoration.random_tilt)
			transform = transform.rotated(transform.basis.x.normalized(), tilt_x)
			transform = transform.rotated(transform.basis.z.normalized(), tilt_z)
		
		# Apply rotation around Y axis
		transform = transform.rotated(Vector3.UP, rotation)
		
		# Apply scale (non-uniform if variance is set)
		var scale_vec := Vector3.ONE * base_scale
		if decoration.scale_variance != Vector3.ZERO:
			scale_vec.x *= 1.0 + _rng.randf_range(-decoration.scale_variance.x, decoration.scale_variance.x)
			scale_vec.y *= 1.0 + _rng.randf_range(-decoration.scale_variance.y, decoration.scale_variance.y)
			scale_vec.z *= 1.0 + _rng.randf_range(-decoration.scale_variance.z, decoration.scale_variance.z)
		transform = transform.scaled(scale_vec)
		
		# Apply position
		transform.origin = pos
		
		variant_instances[variant_idx].append(transform)
		total_count += 1
	
	return variant_instances


## ============================================
## POISSON DISK SAMPLING
## ============================================

## Generate Poisson disk distributed points using Bridson's algorithm
## Returns Array[Vector2] of local positions (0 to chunk_size)
func _generate_poisson_points(
	area_size: float,
	min_distance: float,
	coord: Vector2i,
	decoration_seed: int = 0
) -> Array[Vector2]:
	var cell_size := min_distance / sqrt(2.0)
	var grid_width := int(ceil(area_size / cell_size))
	
	# Spatial grid for fast neighbor lookup (-1 = empty)
	var grid: Array[int] = []
	grid.resize(grid_width * grid_width)
	grid.fill(-1)
	
	var points: Array[Vector2] = []
	var active_list: Array[int] = []
	
	# Seed RNG for reproducibility
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed + coord.x * 73856093 + coord.y * 19349663 + decoration_seed
	
	# Start with random initial point
	var initial := Vector2(local_rng.randf() * area_size, local_rng.randf() * area_size)
	points.append(initial)
	active_list.append(0)
	_poisson_grid_insert(grid, grid_width, cell_size, initial, 0)
	
	while not active_list.is_empty():
		var active_idx := local_rng.randi() % active_list.size()
		var point_idx := active_list[active_idx]
		var point := points[point_idx]
		
		var found := false
		for _attempt in range(POISSON_MAX_ATTEMPTS):
			var angle := local_rng.randf() * TAU
			var radius := min_distance + local_rng.randf() * min_distance
			var candidate := point + Vector2(cos(angle), sin(angle)) * radius
			
			# Check bounds
			if candidate.x < 0 or candidate.x >= area_size:
				continue
			if candidate.y < 0 or candidate.y >= area_size:
				continue
			
			# Check distance to nearby points
			if _is_valid_poisson_point(candidate, grid, grid_width, cell_size, points, min_distance):
				points.append(candidate)
				active_list.append(points.size() - 1)
				_poisson_grid_insert(grid, grid_width, cell_size, candidate, points.size() - 1)
				found = true
				break
		
		if not found:
			active_list.remove_at(active_idx)
	
	return points


## Generate Poisson points with margin for seamless chunk edges
func _generate_poisson_points_with_margin(
	coord: Vector2i,
	chunk_size: float,
	min_distance: float,
	decoration_seed: int = 0
) -> Array[Vector2]:
	var margin := min_distance * POISSON_MARGIN_FACTOR
	var extended_size := chunk_size + margin * 2.0
	
	# Generate in extended region
	var all_points := _generate_poisson_points(extended_size, min_distance, coord, decoration_seed)
	
	# Filter to actual chunk bounds
	var valid_points: Array[Vector2] = []
	for p in all_points:
		var adjusted := p - Vector2(margin, margin)
		if adjusted.x >= 0 and adjusted.x < chunk_size and adjusted.y >= 0 and adjusted.y < chunk_size:
			valid_points.append(adjusted)
	
	return valid_points


## Insert point into Poisson grid
func _poisson_grid_insert(grid: Array[int], grid_width: int, cell_size: float, point: Vector2, point_idx: int) -> void:
	var gx := int(point.x / cell_size)
	var gy := int(point.y / cell_size)
	if gx >= 0 and gx < grid_width and gy >= 0 and gy < grid_width:
		grid[gy * grid_width + gx] = point_idx


## Check if a candidate point is valid (far enough from all neighbors)
func _is_valid_poisson_point(
	candidate: Vector2,
	grid: Array[int],
	grid_width: int,
	cell_size: float,
	points: Array[Vector2],
	min_distance: float
) -> bool:
	var gx := int(candidate.x / cell_size)
	var gy := int(candidate.y / cell_size)
	
	var min_dist_sq := min_distance * min_distance
	
	# Check 5x5 neighborhood
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var nx := gx + dx
			var ny := gy + dy
			if nx < 0 or nx >= grid_width or ny < 0 or ny >= grid_width:
				continue
			
			var point_idx := grid[ny * grid_width + nx]
			if point_idx < 0:
				continue
			
			var neighbor := points[point_idx]
			if candidate.distance_squared_to(neighbor) < min_dist_sq:
				return false
	
	return true


## ============================================
## TERRAIN SAMPLING
## ============================================

## Sample height from chunk data at local position
func _sample_height_at(local_x: float, local_z: float, chunk_data: ChunkData, cell_size: float, resolution: int) -> float:
	# Convert local position to grid indices
	var fx := local_x / cell_size
	var fz := local_z / cell_size
	
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var x1 := mini(x0 + 1, resolution - 1)
	var z1 := mini(z0 + 1, resolution - 1)
	
	x0 = clampi(x0, 0, resolution - 1)
	z0 = clampi(z0, 0, resolution - 1)
	
	# Bilinear interpolation
	var tx := fx - x0
	var tz := fz - z0
	
	var h00 := chunk_data.height_data[z0 * resolution + x0]
	var h10 := chunk_data.height_data[z0 * resolution + x1]
	var h01 := chunk_data.height_data[z1 * resolution + x0]
	var h11 := chunk_data.height_data[z1 * resolution + x1]
	
	var h0 := lerpf(h00, h10, tx)
	var h1 := lerpf(h01, h11, tx)
	
	return lerpf(h0, h1, tz)


## Calculate terrain slope at local position (returns angle in radians)
func _calculate_slope_at(local_x: float, local_z: float, chunk_data: ChunkData, cell_size: float, resolution: int) -> float:
	var epsilon := cell_size * 0.5
	
	var h_center := _sample_height_at(local_x, local_z, chunk_data, cell_size, resolution)
	var h_right := _sample_height_at(minf(local_x + epsilon, (resolution - 1) * cell_size), local_z, chunk_data, cell_size, resolution)
	var h_forward := _sample_height_at(local_x, minf(local_z + epsilon, (resolution - 1) * cell_size), chunk_data, cell_size, resolution)
	
	var dx := (h_right - h_center) / epsilon
	var dz := (h_forward - h_center) / epsilon
	
	# Slope magnitude
	var slope_mag := sqrt(dx * dx + dz * dz)
	return atan(slope_mag)


## Sample terrain normal at local position
func _sample_normal_at(local_x: float, local_z: float, chunk_data: ChunkData, cell_size: float, resolution: int) -> Vector3:
	var epsilon := cell_size * 0.5
	
	var h_center := _sample_height_at(local_x, local_z, chunk_data, cell_size, resolution)
	var h_left := _sample_height_at(maxf(local_x - epsilon, 0), local_z, chunk_data, cell_size, resolution)
	var h_right := _sample_height_at(minf(local_x + epsilon, (resolution - 1) * cell_size), local_z, chunk_data, cell_size, resolution)
	var h_back := _sample_height_at(local_x, maxf(local_z - epsilon, 0), chunk_data, cell_size, resolution)
	var h_forward := _sample_height_at(local_x, minf(local_z + epsilon, (resolution - 1) * cell_size), chunk_data, cell_size, resolution)
	
	var dx := (h_left - h_right) / (2.0 * epsilon)
	var dz := (h_back - h_forward) / (2.0 * epsilon)
	
	return Vector3(dx, 1.0, dz).normalized()


## Create a transform that aligns Y-up to the given normal
func _align_to_normal(normal: Vector3) -> Transform3D:
	var up := normal.normalized()
	var right := Vector3.UP.cross(up)
	
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	
	var forward := up.cross(right).normalized()
	
	return Transform3D(Basis(right, up, forward), Vector3.ZERO)


## Create a transform that aligns Y-up to the given normal with angle limit
## @param normal The terrain normal to align to
## @param max_angle Maximum tilt angle from vertical in radians (1.57 = full alignment)
func _align_to_normal_limited(normal: Vector3, max_angle: float) -> Transform3D:
	# If max_angle is essentially full (90 degrees), use standard alignment
	if max_angle >= 1.57:
		return _align_to_normal(normal)
	
	# If max_angle is zero, return identity (upright)
	if max_angle <= 0.001:
		return Transform3D.IDENTITY
	
	# Calculate angle between normal and UP
	var up := Vector3.UP
	var angle := acos(clampf(normal.dot(up), -1.0, 1.0))
	
	# If terrain is flatter than max_angle, use full alignment
	if angle <= max_angle:
		return _align_to_normal(normal)
	
	# Limit the alignment angle
	var axis := up.cross(normal)
	if axis.length_squared() < 0.001:
		return Transform3D.IDENTITY
	
	axis = axis.normalized()
	var limited_normal := up.rotated(axis, max_angle)
	
	return _align_to_normal(limited_normal)


## Create a MultiMeshInstance3D for a set of instances
func _create_multimesh_instance(decoration: DecorationDefinition, instances: Array[Transform3D]) -> MultiMeshInstance3D:
	if instances.is_empty():
		return null
	
	# Get or create mesh
	var mesh := _get_decoration_mesh(decoration)
	if not mesh:
		return null
	
	# Create MultiMesh
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = instances.size()
	
	# Set transforms
	for i in range(instances.size()):
		multimesh.set_instance_transform(i, instances[i])
	
	# Create MultiMeshInstance3D
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = multimesh
	
	# Apply material override if specified
	if decoration.material:
		mmi.material_override = decoration.material
	
	return mmi


## Create a MultiMeshInstance3D directly from a mesh and transforms
func _create_multimesh_from_mesh(mesh: Mesh, instances: Array[Transform3D], material_override: Material = null) -> MultiMeshInstance3D:
	if instances.is_empty() or not mesh:
		return null
	
	# Create MultiMesh
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = instances.size()
	
	# Set transforms
	for i in range(instances.size()):
		multimesh.set_instance_transform(i, instances[i])
	
	# Create MultiMeshInstance3D
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = multimesh
	
	# Apply material override if specified
	if material_override:
		mmi.material_override = material_override
	
	return mmi
func _get_decoration_mesh(decoration: DecorationDefinition) -> Mesh:
	# Use provided mesh if available
	if decoration.mesh:
		return decoration.mesh
	
	# Check cache first
	var cache_key := decoration.get_instance_id()
	if _cached_meshes.has(cache_key):
		return _cached_meshes[cache_key]
	
	# Create placeholder based on decoration type
	var mesh: ArrayMesh
	match decoration.decoration_type:
		DecorationDefinition.DecorationType.TREE:
			mesh = DecorationMeshBuilder.build_tree_mesh()
		DecorationDefinition.DecorationType.ROCK:
			mesh = DecorationMeshBuilder.build_rock_mesh()
		DecorationDefinition.DecorationType.BUSH:
			mesh = DecorationMeshBuilder.build_bush_mesh()
		_:
			mesh = DecorationMeshBuilder.build_tree_mesh()
	
	_cached_meshes[cache_key] = mesh
	return mesh


## Get decorations for a chunk based on biome data
func _get_decorations_for_chunk(chunk_data: ChunkData) -> Array[DecorationDefinition]:
	var decorations: Array[DecorationDefinition] = []
	
	if not world_config or not world_config.biome_map:
		return decorations
	
	# Sample center of chunk for dominant biome
	var center_idx := (chunk_data.width / 2) * chunk_data.width + (chunk_data.width / 2)
	var height := chunk_data.height_data[center_idx] if center_idx < chunk_data.height_data.size() else 0.0
	var moisture := chunk_data.moisture_data[center_idx] if center_idx < chunk_data.moisture_data.size() else 0.5
	
	var elevation := HeightGenerator.get_normalized_elevation(height, world_config)
	var biome := world_config.biome_map.get_biome(elevation, moisture)
	
	if biome:
		decorations.append_array(biome.get_decorations())
	
	return decorations


## Spawn collision bodies for a decoration type at given transforms
## Only spawns collision within collision_distance from camera/player
func _spawn_collision_bodies(decoration: DecorationDefinition, instances: Array[Transform3D]) -> Array[StaticBody3D]:
	var bodies: Array[StaticBody3D] = []
	
	# Get player/camera position for distance culling
	var camera := get_viewport().get_camera_3d()
	var cull_origin := camera.global_position if camera else Vector3.ZERO
	var max_dist_sq := decoration.collision_distance * decoration.collision_distance
	
	for transform in instances:
		# Distance check for performance
		var dist_sq := cull_origin.distance_squared_to(transform.origin)
		if dist_sq > max_dist_sq:
			continue
		
		var body := StaticBody3D.new()
		body.transform.origin = transform.origin
		
		# Create collision shape
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = _create_collision_shape(decoration)
		
		# Extract scale from transform and apply to collision offset
		var scale_factor := transform.basis.get_scale().y
		collision_shape.position.y = decoration.collision_height * 0.5 * scale_factor
		
		body.add_child(collision_shape)
		add_child(body)
		bodies.append(body)
	
	return bodies


## Create a collision shape based on decoration settings
func _create_collision_shape(decoration: DecorationDefinition) -> Shape3D:
	match decoration.collision_shape:
		DecorationDefinition.CollisionShapeType.CYLINDER:
			var shape := CylinderShape3D.new()
			shape.radius = decoration.collision_radius
			shape.height = decoration.collision_height
			return shape
		DecorationDefinition.CollisionShapeType.BOX:
			var shape := BoxShape3D.new()
			shape.size = Vector3(
				decoration.collision_radius * 2.0,
				decoration.collision_height,
				decoration.collision_radius * 2.0
			)
			return shape
		DecorationDefinition.CollisionShapeType.CAPSULE:
			var shape := CapsuleShape3D.new()
			shape.radius = decoration.collision_radius
			shape.height = decoration.collision_height
			return shape
		_:
			var shape := CylinderShape3D.new()
			shape.radius = decoration.collision_radius
			shape.height = decoration.collision_height
			return shape


## Clear all decorations for a chunk
## @param coord Chunk coordinate
func clear_chunk(coord: Vector2i) -> void:
	# Clear visual MultiMeshes
	if _chunk_multimeshes.has(coord):
		var multimeshes: Array = _chunk_multimeshes[coord]
		for mmi in multimeshes:
			if is_instance_valid(mmi):
				mmi.queue_free()
		_chunk_multimeshes.erase(coord)
	
	# Clear collision bodies
	if _chunk_collisions.has(coord):
		var bodies: Array = _chunk_collisions[coord]
		for body in bodies:
			if is_instance_valid(body):
				body.queue_free()
		_chunk_collisions.erase(coord)


## Clear all decorations
func clear_all() -> void:
	var coords := _chunk_multimeshes.keys().duplicate()
	var collision_coords := _chunk_collisions.keys().duplicate()
	
	# Merge unique coords
	for c in collision_coords:
		if c not in coords:
			coords.append(c)
	
	for coord in coords:
		clear_chunk(coord)


## Get total decoration instance count
func get_total_instance_count() -> int:
	var total := 0
	for coord in _chunk_multimeshes:
		var multimeshes: Array = _chunk_multimeshes[coord]
		for mmi in multimeshes:
			if is_instance_valid(mmi) and mmi.multimesh:
				total += mmi.multimesh.instance_count
	return total


func _exit_tree() -> void:
	clear_all()
	_cached_meshes.clear()
