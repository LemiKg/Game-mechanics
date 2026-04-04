# Procedural World Improvements - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 9 issues in the procedural world addon: moisture noise, domain warping, load/unload hysteresis, LOD fade, mesh skirts, vegetation distance culling, WorkerThreadPool, smoothstep biome blending, and terrain shader height-based micro-blending.

**Architecture:** Each improvement is independent and touches 1-2 files. Changes are additive — no architectural restructuring needed.

**Tech Stack:** GDScript, Godot 4.5, GLSL (gdshader), FastNoiseLite, SkeletonModifier3D API, WorkerThreadPool

---

## File Structure

| File | Action | Tasks |
|------|--------|-------|
| `world/world_config.tres` | Modify | 1 |
| `addons/procedural_world/core/chunk_manager.gd` | Modify | 2 |
| `addons/procedural_world/core/terrain_chunk.gd` | Modify | 3 |
| `addons/procedural_world/core/terrain_mesh_builder.gd` | Modify | 4 |
| `addons/procedural_world/core/vegetation_spawner.gd` | Modify | 5 |
| `addons/procedural_world/core/async_generation_handler.gd` | Modify | 6 |
| `addons/procedural_world/core/biome_data.gd` | Modify | 7 |
| `addons/procedural_world/shaders/terrain_triplanar.gdshader` | Modify | 8 |

---

### Task 1: Configure Moisture Noise and Domain Warping

**Files:**
- Modify: `world/world_config.tres`

Currently `moisture_noise` is null — all vertices default to 0.5 moisture, making biome distribution purely elevation-based. The terrain noise also lacks domain warping, producing "blobby" terrain.

- [ ] **Step 1: Read the current world_config.tres**

Read `world/world_config.tres` to see the current state.

- [ ] **Step 2: Add moisture noise and enable domain warping on primary noise**

Edit `world/world_config.tres` to:
1. Add a second `FastNoiseLite` sub-resource for moisture with a different seed and frequency
2. Enable domain warping on the primary terrain noise

The primary noise sub-resource currently looks like:
```
[sub_resource type="FastNoiseLite" id="FastNoiseLite_jfupg"]
noise_type = 0
frequency = 0.0062
fractal_octaves = 4
fractal_gain = 0.4
```

Change it to add domain warping:
```
[sub_resource type="FastNoiseLite" id="FastNoiseLite_jfupg"]
noise_type = 0
frequency = 0.0062
fractal_octaves = 4
fractal_gain = 0.4
domain_warp_enabled = true
domain_warp_type = 0
domain_warp_amplitude = 30.0
domain_warp_frequency = 0.006
domain_warp_fractal_type = 1
domain_warp_fractal_octaves = 3
domain_warp_fractal_lacunarity = 2.0
domain_warp_fractal_gain = 0.5
```

Add a new sub-resource for moisture noise (different seed, lower frequency for large-scale biome regions):
```
[sub_resource type="FastNoiseLite" id="FastNoiseLite_moisture"]
noise_type = 0
seed = 42
frequency = 0.003
fractal_octaves = 3
fractal_gain = 0.5
```

Then add the `moisture_noise` property to the `[resource]` section:
```
moisture_noise = SubResource("FastNoiseLite_moisture")
```

And update `load_steps` from 5 to 6 (one more sub-resource).

- [ ] **Step 3: Commit**

```bash
git add world/world_config.tres
git commit -m "feat: add moisture noise and domain warping to world config"
```

---

### Task 2: Add Load/Unload Hysteresis

**Files:**
- Modify: `addons/procedural_world/core/chunk_manager.gd`

Currently the same `view_distance` is used for both loading and unloading, causing chunks at the boundary to thrash (load/unload repeatedly) as the player oscillates.

- [ ] **Step 1: Read chunk_manager.gd and find `_update_chunks_around_player()`**

Read `addons/procedural_world/core/chunk_manager.gd` and locate the `_update_chunks_around_player()` method (around line 414).

- [ ] **Step 2: Add hysteresis to unloading**

In `_update_chunks_around_player()`, the unload check currently uses the same `desired_chunks` set (which uses `view_distance`). Change the unload logic to use `view_distance + 2` so chunks don't unload until the player is 2 chunks beyond the load boundary.

Find this code block:
```gdscript
	# Unload chunks that are too far
	var chunks_to_unload: Array[Vector2i] = []
	for coord in _active_chunks.keys():
		if coord not in desired_chunks:
			chunks_to_unload.append(coord)
```

Replace it with:
```gdscript
	# Unload chunks that are too far (use hysteresis to prevent thrashing)
	var unload_distance := view_distance + 2
	var chunks_to_unload: Array[Vector2i] = []
	for coord in _active_chunks.keys():
		var dist := (coord - player_coord).length()
		if dist > unload_distance:
			chunks_to_unload.append(coord)
```

Note: `Vector2i.length()` returns a float — the Euclidean distance. This replaces the set membership check with a distance check using a larger radius.

- [ ] **Step 3: Commit**

```bash
git add addons/procedural_world/core/chunk_manager.gd
git commit -m "feat: add load/unload hysteresis to prevent chunk thrashing at view distance boundary"
```

---

### Task 3: Switch LOD Fade Mode

**Files:**
- Modify: `addons/procedural_world/core/terrain_chunk.gd`

Currently uses `VISIBILITY_RANGE_FADE_DISABLED` which causes hard LOD pops. Switch to `FADE_SELF` for smoother transitions.

- [ ] **Step 1: Read terrain_chunk.gd and find set_lod_distances()**

Read `addons/procedural_world/core/terrain_chunk.gd` and find the `set_lod_distances()` method (around line 98).

- [ ] **Step 2: Change fade mode**

Find this line:
```gdscript
		mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
```

Replace with:
```gdscript
		mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
```

- [ ] **Step 3: Commit**

```bash
git add addons/procedural_world/core/terrain_chunk.gd
git commit -m "feat: enable LOD fade mode for smoother terrain transitions"
```

---

### Task 4: Add Mesh Skirts to Chunk Edges

**Files:**
- Modify: `addons/procedural_world/core/terrain_mesh_builder.gd`

Adjacent chunks at different LOD levels have mismatched vertex counts on shared edges, causing visible T-junction cracks. Adding downward-facing "skirts" along chunk edges hides these gaps.

- [ ] **Step 1: Read terrain_mesh_builder.gd**

Read `addons/procedural_world/core/terrain_mesh_builder.gd` completely.

- [ ] **Step 2: Add a skirt generation method**

Add a new static method `_add_skirts()` that extends the mesh with downward-facing triangles along all 4 edges of the chunk. The skirt drops each edge vertex straight down by a configurable amount.

Add this method after `_calculate_normals()`:

```gdscript
## Add downward skirts along chunk edges to hide LOD seam cracks.
## skirt_depth is how far down (in world units) the skirt extends.
static func _add_skirts(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	width: int,
	depth: int,
	skirt_depth: float = 5.0
) -> Dictionary:
	# Collect edge vertex indices (top, bottom, left, right edges of the grid)
	var edge_indices: Array[int] = []
	
	# Top edge (z=0)
	for x in range(width):
		edge_indices.append(x)
	# Bottom edge (z=depth-1)
	for x in range(width):
		edge_indices.append((depth - 1) * width + x)
	# Left edge (x=0), skip corners (already added)
	for z in range(1, depth - 1):
		edge_indices.append(z * width)
	# Right edge (x=width-1), skip corners
	for z in range(1, depth - 1):
		edge_indices.append(z * width + (width - 1))
	
	var base_vertex_count := vertices.size()
	var new_vertices := vertices.duplicate()
	var new_normals := normals.duplicate()
	var new_uvs := uvs.duplicate()
	var new_indices := indices.duplicate()
	
	# For each edge vertex, create a corresponding dropped vertex
	var edge_map: Dictionary = {} # original index -> new (dropped) index
	for orig_idx in edge_indices:
		var dropped_pos := vertices[orig_idx]
		dropped_pos.y -= skirt_depth
		var new_idx := new_vertices.size()
		new_vertices.append(dropped_pos)
		new_normals.append(normals[orig_idx]) # Same normal as surface
		new_uvs.append(uvs[orig_idx])
		edge_map[orig_idx] = new_idx
	
	# Create triangles connecting edge vertices to their dropped counterparts.
	# Walk each edge and create quads (2 triangles per segment).
	
	# Top edge (z=0): x goes 0..width-1
	for x in range(width - 1):
		var a := x
		var b := x + 1
		var a_drop: int = edge_map[a]
		var b_drop: int = edge_map[b]
		# Skirt faces outward (winding for -Z facing)
		new_indices.append(a)
		new_indices.append(a_drop)
		new_indices.append(b)
		new_indices.append(b)
		new_indices.append(a_drop)
		new_indices.append(b_drop)
	
	# Bottom edge (z=depth-1): x goes 0..width-1
	for x in range(width - 1):
		var a := (depth - 1) * width + x
		var b := (depth - 1) * width + x + 1
		var a_drop: int = edge_map[a]
		var b_drop: int = edge_map[b]
		# Skirt faces outward (+Z facing, reversed winding)
		new_indices.append(a)
		new_indices.append(b)
		new_indices.append(a_drop)
		new_indices.append(b)
		new_indices.append(b_drop)
		new_indices.append(a_drop)
	
	# Left edge (x=0): z goes 0..depth-1
	for z in range(depth - 1):
		var a := z * width
		var b := (z + 1) * width
		var a_drop: int = edge_map[a]
		var b_drop: int = edge_map[b]
		# Skirt faces outward (-X facing, reversed winding)
		new_indices.append(a)
		new_indices.append(b)
		new_indices.append(a_drop)
		new_indices.append(b)
		new_indices.append(b_drop)
		new_indices.append(a_drop)
	
	# Right edge (x=width-1): z goes 0..depth-1
	for z in range(depth - 1):
		var a := z * width + (width - 1)
		var b := (z + 1) * width + (width - 1)
		var a_drop: int = edge_map[a]
		var b_drop: int = edge_map[b]
		# Skirt faces outward (+X facing)
		new_indices.append(a)
		new_indices.append(a_drop)
		new_indices.append(b)
		new_indices.append(b)
		new_indices.append(a_drop)
		new_indices.append(b_drop)
	
	return {
		"vertices": new_vertices,
		"normals": new_normals,
		"uvs": new_uvs,
		"indices": new_indices
	}
```

- [ ] **Step 3: Integrate skirts into build_mesh()**

In `build_mesh()`, after normals are calculated and before the ArrayMesh is built, add the skirt geometry. Find this section (around line 72-82):

```gdscript
	# Calculate normals
	normals = _calculate_normals(vertices, indices)
	
	# Build ArrayMesh
	var arrays := []
```

Insert the skirt call between them:

```gdscript
	# Calculate normals
	normals = _calculate_normals(vertices, indices)
	
	# Add edge skirts to hide LOD seam cracks
	var skirt_result := _add_skirts(vertices, normals, uvs, indices, width, depth)
	vertices = skirt_result["vertices"]
	normals = skirt_result["normals"]
	uvs = skirt_result["uvs"]
	indices = skirt_result["indices"]
	
	# Build ArrayMesh
	var arrays := []
```

- [ ] **Step 4: Commit**

```bash
git add addons/procedural_world/core/terrain_mesh_builder.gd
git commit -m "feat: add mesh skirts to chunk edges to hide LOD seam cracks"
```

---

### Task 5: Vegetation Distance Culling

**Files:**
- Modify: `addons/procedural_world/core/vegetation_spawner.gd`

Vegetation currently has no distance-based LOD — MultiMesh instances appear/disappear abruptly. Add `visibility_range` to MultiMeshInstance3D nodes for smooth distance fading.

- [ ] **Step 1: Read vegetation_spawner.gd**

Read `addons/procedural_world/core/vegetation_spawner.gd` and find the `_create_multimesh_instance()` method (around line 705) and `_create_multimesh_from_mesh()` (around line 736).

- [ ] **Step 2: Add visibility_range to both MultiMesh creation methods**

In `_create_multimesh_instance()`, before the `return mmi` line, add:

```gdscript
	# Distance-based culling with fade
	var max_distance := spawn_radius * world_config.chunk_size if world_config else 500.0
	mmi.visibility_range_end = max_distance
	mmi.visibility_range_end_margin = max_distance * 0.1
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
```

In `_create_multimesh_from_mesh()`, before the `return mmi` line, add the same block:

```gdscript
	# Distance-based culling with fade
	var max_distance := spawn_radius * world_config.chunk_size if world_config else 500.0
	mmi.visibility_range_end = max_distance
	mmi.visibility_range_end_margin = max_distance * 0.1
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
```

Note: `spawn_radius` and `world_config` are class-level properties on VegetationSpawner. Check that they're accessible — read the @export declarations at the top of the file to confirm.

- [ ] **Step 3: Commit**

```bash
git add addons/procedural_world/core/vegetation_spawner.gd
git commit -m "feat: add visibility_range distance culling to vegetation MultiMesh instances"
```

---

### Task 6: Replace Thread with WorkerThreadPool

**Files:**
- Modify: `addons/procedural_world/core/async_generation_handler.gd`

Currently uses a single `Thread` with `OS.delay_msec(5)` polling. Replace with Godot's `WorkerThreadPool` for better thread management and potential parallel chunk generation.

- [ ] **Step 1: Read async_generation_handler.gd**

Read `addons/procedural_world/core/async_generation_handler.gd` completely.

- [ ] **Step 2: Replace thread management with WorkerThreadPool**

The key changes:
1. Remove `_thread: Thread`, `_should_stop`, `_thread_running` variables
2. Replace `_start_thread()` / `_stop_thread()` with simpler lifecycle
3. Replace `_worker_loop()` (continuous polling loop) with individual task dispatching
4. In `request_chunk()`, dispatch each chunk as a separate WorkerThreadPool task
5. Results still go through `_results` array with mutex protection

Replace `_start_thread()` and `_stop_thread()`:
```gdscript
func _start_thread() -> void:
	_running = true

func _stop_thread() -> void:
	_running = false
	# Wait for any pending tasks to complete
	WorkerThreadPool.wait_for_group_task_completion(_task_group)
```

Replace `request_chunk()` to dispatch individual tasks:
```gdscript
func request_chunk(coord: Vector2i) -> void:
	if not _running:
		return
	
	_queue_mutex.lock()
	if _queue.has(coord):
		_queue_mutex.unlock()
		return
	_queue.append(coord)
	queue_size_changed.emit(_queue.size())
	_queue_mutex.unlock()
	
	# Dispatch as a WorkerThreadPool task
	WorkerThreadPool.add_task(_process_next_in_queue)
```

Add a new `_process_next_in_queue()` method:
```gdscript
func _process_next_in_queue() -> void:
	var coord: Variant = null
	
	_queue_mutex.lock()
	if not _queue.is_empty():
		coord = _queue.pop_front()
		queue_size_changed.emit.call_deferred(_queue.size())
	_queue_mutex.unlock()
	
	if coord == null:
		return
	
	# Check if cancelled
	_cancelled_mutex.lock()
	var was_cancelled := _cancelled.has(coord)
	if was_cancelled:
		_cancelled.erase(coord)
	_cancelled_mutex.unlock()
	
	if was_cancelled:
		return
	
	# Generate chunk data (thread-safe)
	var data := _generate_chunk_data(coord as Vector2i)
	
	# Queue result for main thread
	_results_mutex.lock()
	_results.append({"coord": coord, "data": data})
	_results_mutex.unlock()
```

Remove the old `_worker_loop()` method entirely.

Remove the `_thread`, `_should_stop`, `_thread_running` variables and add `_running: bool = false`.

- [ ] **Step 3: Commit**

```bash
git add addons/procedural_world/core/async_generation_handler.gd
git commit -m "refactor: replace manual Thread with WorkerThreadPool for chunk generation"
```

---

### Task 7: Smoothstep Biome Blending

**Files:**
- Modify: `addons/procedural_world/core/biome_data.gd`

The current `get_match_strength()` uses linear distance falloff (`1.0 - max(elev_dist, moist_dist)`). Replace with smoothstep for more natural, S-curve transitions.

- [ ] **Step 1: Read biome_data.gd**

Read `addons/procedural_world/core/biome_data.gd` and find `get_match_strength()` (around line 59).

- [ ] **Step 2: Replace linear falloff with smoothstep**

Find:
```gdscript
	# Convert distance to strength (1 at center, 0 at edge)
	var strength := 1.0 - maxf(elev_dist, moist_dist)
	return clampf(strength, 0.0, 1.0)
```

Replace with:
```gdscript
	# Convert distance to strength using smoothstep for natural S-curve transitions
	var distance := maxf(elev_dist, moist_dist)
	var strength := 1.0 - clampf(distance, 0.0, 1.0)
	# Apply smoothstep for smoother biome transitions (S-curve instead of linear)
	strength = strength * strength * (3.0 - 2.0 * strength)
	return strength
```

The formula `x * x * (3 - 2x)` is the Hermite smoothstep — produces an S-curve that's 0 at 0, 1 at 1, with zero derivative at both endpoints. This creates more natural biome boundaries that don't change at a constant rate.

- [ ] **Step 3: Commit**

```bash
git add addons/procedural_world/core/biome_data.gd
git commit -m "feat: use smoothstep for biome blending transitions instead of linear falloff"
```

---

### Task 8: Height-Based Micro-Blending in Terrain Shader

**Files:**
- Modify: `addons/procedural_world/shaders/terrain_triplanar.gdshader`

Currently biome transitions are smooth gradients via splatmap weights. Adding height-based micro-blending uses world-space height detail to create irregular, natural-looking biome edges (e.g., rock poking through grass on slopes, grass patches in rocky areas).

- [ ] **Step 1: Read the current shader**

Read `addons/procedural_world/shaders/terrain_triplanar.gdshader`.

- [ ] **Step 2: Add height-blend uniforms and modify the splatmap blending**

Add a new uniform group after the `blending` group (after line 62):

```glsl
// ============================================
// HEIGHT-BASED MICRO-BLENDING
// ============================================
group_uniforms height_blending;
uniform float height_blend_sharpness : hint_range(0.01, 1.0) = 0.15;
uniform float height_blend_scale : hint_range(0.001, 0.5) = 0.05;
```

Then modify the `fragment()` function. After the splatmap is read and snow factor is applied (after the normalization at line 147), add height-based sharpening of the splatmap weights. Find:

```glsl
	float total = splat.r + splat.g + splat.b + splat.a;
	if (total > 0.001) { splat /= total; } else { splat = vec4(1.0, 0.0, 0.0, 0.0); }
	
	// ALBEDO
```

Replace with:

```glsl
	float total = splat.r + splat.g + splat.b + splat.a;
	if (total > 0.001) { splat /= total; } else { splat = vec4(1.0, 0.0, 0.0, 0.0); }
	
	// Height-based micro-blending: use world height detail to create irregular biome edges
	{
		float h = fract(world_position.y * height_blend_scale + world_position.x * 0.017 + world_position.z * 0.013);
		// Bias each channel by a different height offset to create irregular boundaries
		vec4 biased = vec4(
			splat.r + h * height_blend_sharpness,
			splat.g + fract(h + 0.37) * height_blend_sharpness,
			splat.b + fract(h + 0.71) * height_blend_sharpness,
			splat.a + fract(h + 0.53) * height_blend_sharpness
		);
		// Re-normalize
		float bt = biased.r + biased.g + biased.b + biased.a;
		if (bt > 0.001) { splat = biased / bt; }
	}
	
	// ALBEDO
```

This uses `fract()` of the world position scaled by `height_blend_scale` to create a pseudo-random height value, then biases each splatmap channel differently. The result: biome transition edges become irregular and natural-looking instead of smooth gradients. The `height_blend_sharpness` controls how strong the effect is (0 = no effect, higher = more irregular edges).

- [ ] **Step 3: Update the terrain material defaults**

Read `world/terrain_material.tres` and add the new shader parameters with sensible defaults. Add these lines to the `[resource]` section:

```
shader_parameter/height_blend_sharpness = 0.15
shader_parameter/height_blend_scale = 0.05
```

- [ ] **Step 4: Commit**

```bash
git add addons/procedural_world/shaders/terrain_triplanar.gdshader world/terrain_material.tres
git commit -m "feat: add height-based micro-blending to terrain shader for natural biome edges"
```
