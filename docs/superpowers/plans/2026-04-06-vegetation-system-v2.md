# Vegetation System v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace nature-kit vegetation with environment pack assets and add weighted biome decoration blending for seamless biome transitions.

**Architecture:** Modify VegetationSpawner to collect decorations from ALL biomes present in a chunk, with per-instance biome weight sampling that naturally thins decorations at biome boundaries. Replace all decoration .tres files with environment pack GLBs that use a colormap texture atlas for reliable material rendering.

**Tech Stack:** Godot 4.x, GDScript, environment pack GLBs with colormap.png texture atlas

**Important context for implementers:**
- Environment pack assets are at `res://assets/environment/` and use `colormap.png` texture atlas — materials render correctly in MultiMesh
- Biome weights are stored in `ChunkData.biome_weights` as a `PackedFloat32Array` with 4 floats per vertex (RGBA = channels 0-3) in row-major order (width * depth * 4 total)
- Splatmap channels: 0=R (grass/plains), 1=G (rock/mountain), 2=B (sand/desert), 3=A (snow)
- Each biome has a `splatmap_channel` property indicating which channel it uses

---

## File Structure

### Delete (old nature-kit decorations)
All `.tres` files in `addons/procedural_world/decorations/` — 31 files total

### New decoration .tres files (16)
| File | Description |
|---|---|
| `addons/procedural_world/decorations/trees_standard_sparse.tres` | Trees for plains |
| `addons/procedural_world/decorations/trees_standard_dense.tres` | Trees for forest |
| `addons/procedural_world/decorations/trees_autumn.tres` | Autumn trees for forest |
| `addons/procedural_world/decorations/tree_trunks_forest.tres` | Dead trunks for forest |
| `addons/procedural_world/decorations/tree_trunks_mountain.tres` | Dead trunks for mountain |
| `addons/procedural_world/decorations/rocks_standard.tres` | Rocks for mountain/forest |
| `addons/procedural_world/decorations/rocks_flat.tres` | Flat rocks for plains/forest |
| `addons/procedural_world/decorations/rocks_sandy.tres` | Sandy rocks for desert |
| `addons/procedural_world/decorations/resource_stones.tres` | Boulder stones for mountain |
| `addons/procedural_world/decorations/grass_patches.tres` | Grass ground cover |
| `addons/procedural_world/decorations/ground_patches.tres` | Ground patches for plains |
| `addons/procedural_world/decorations/fallen_logs.tres` | Fallen logs for forest |
| `addons/procedural_world/decorations/resource_wood.tres` | Scattered wood for forest |
| `addons/procedural_world/decorations/campfire_remains.tres` | Rare campfires |
| `addons/procedural_world/decorations/signposts.tres` | Rare signposts |
| `addons/procedural_world/decorations/tents.tres` | Rare tents |

### Modified files
| File | Changes |
|---|---|
| `addons/procedural_world/core/vegetation_spawner.gd` | `_get_decorations_for_chunk()` returns tagged decorations from all biomes; `_generate_sample_transforms()` adds biome weight check; `spawn_for_chunk()` updated for tagged decorations |
| `world/biomes/plains.tres` | New decoration references |
| `world/biomes/forest.tres` | New decoration references |
| `world/biomes/desert.tres` | New decoration references |
| `world/biomes/mountain.tres` | New decoration references |

---

### Task 1: Modify VegetationSpawner for weighted biome blending

**Files:**
- Modify: `addons/procedural_world/core/vegetation_spawner.gd`

- [ ] **Step 1: Change `_get_decorations_for_chunk()` to return tagged decorations from all biomes**

Find the method `_get_decorations_for_chunk` (around line 712). Replace its entire body:

```gdscript
func _get_decorations_for_chunk(chunk_data: ChunkData) -> Array[Dictionary]:
	var tagged: Array[Dictionary] = []

	if not world_config or not world_config.biome_map:
		return tagged

	for biome in world_config.biome_map.biomes:
		if not biome:
			continue
		for decoration in biome.get_decorations():
			if decoration:
				tagged.append({
					"decoration": decoration,
					"splatmap_channel": biome.splatmap_channel,
				})

	return tagged
```

Note: The return type changes from `Array[DecorationDefinition]` to `Array[Dictionary]`.

- [ ] **Step 2: Add biome weight parameter to `_generate_sample_transforms()`**

Find `_generate_sample_transforms` (around line 238). Change its signature to add `splatmap_channel` parameter:

```gdscript
func _generate_sample_transforms(
	decoration: DecorationDefinition,
	chunk_data: ChunkData,
	world_offset: Vector3,
	chunk_size: float,
	cell_size: float,
	resolution: int,
	splatmap_channel: int = -1
) -> Array[Transform3D]:
```

Then, inside the `for point in sample_points:` loop, right after the clustering check (after the `cluster_edge_factor` block, before `# Height and slope`), add the biome weight check:

```gdscript
		# Biome weight check — skip if this biome is not dominant here
		if splatmap_channel >= 0 and not chunk_data.biome_weights.is_empty():
			var grid_x := clampi(int(local_x / cell_size), 0, resolution - 1)
			var grid_z := clampi(int(local_z / cell_size), 0, resolution - 1)
			var weight_idx := (grid_z * resolution + grid_x) * 4 + splatmap_channel
			if weight_idx < chunk_data.biome_weights.size():
				var biome_weight := chunk_data.biome_weights[weight_idx]
				if _rng.randf() > biome_weight:
					continue
```

- [ ] **Step 3: Update `spawn_for_chunk()` to use tagged decorations**

In `spawn_for_chunk()` (around line 112), change the decoration retrieval and loop.

Replace the block from `# Get decorations from biomes or use defaults` through the entire `for decoration in decorations:` loop header. The key changes:

1. Change the type of `decorations` from `Array[DecorationDefinition]` to `Array[Dictionary]`
2. Change the fallback: if tagged decorations are empty and `default_decorations` is set, wrap them as tagged with channel -1
3. Inside the loop, extract `decoration` and `splatmap_channel` from each dict
4. Pass `splatmap_channel` through to `_generate_sample_transforms()`, `_generate_instances()`, and `_generate_instances_with_variants()`

Replace lines 126-154 (from `# Get decorations` through `var all_instances`) with:

```gdscript
	# Get decorations from ALL biomes present in this chunk
	var tagged_decorations := _get_decorations_for_chunk(chunk_data)
	if tagged_decorations.is_empty():
		# Fallback to defaults (untagged, no biome filtering)
		for dec in default_decorations:
			if dec:
				tagged_decorations.append({"decoration": dec, "splatmap_channel": -1})

	if tagged_decorations.is_empty():
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

	for tagged in tagged_decorations:
		var decoration: DecorationDefinition = tagged["decoration"]
		var splatmap_channel: int = tagged["splatmap_channel"]
		if not decoration:
			continue

		var all_instances: Array[Transform3D] = []
```

Then update the calls to pass `splatmap_channel`. The variant path calls `_generate_instances_with_variants` — update that too.

- [ ] **Step 4: Update `_generate_instances()` to pass splatmap_channel**

Change the `_generate_instances` method signature and body:

```gdscript
func _generate_instances(
	decoration: DecorationDefinition,
	chunk_data: ChunkData,
	world_offset: Vector3,
	chunk_size: float,
	cell_size: float,
	resolution: int,
	splatmap_channel: int = -1
) -> Array[Transform3D]:
	return _generate_sample_transforms(decoration, chunk_data, world_offset, chunk_size, cell_size, resolution, splatmap_channel)
```

- [ ] **Step 5: Update `_generate_instances_with_variants()` to pass splatmap_channel**

Change the method signature to add `splatmap_channel: int = -1` parameter, and pass it to `_generate_sample_transforms`:

```gdscript
func _generate_instances_with_variants(
	decoration: DecorationDefinition,
	chunk_data: ChunkData,
	world_offset: Vector3,
	chunk_size: float,
	cell_size: float,
	resolution: int,
	splatmap_channel: int = -1
) -> Dictionary:
	var variant_instances: Dictionary = {}
	var variant_count := decoration.get_mesh_count()

	for i in range(variant_count):
		variant_instances[i] = [] as Array[Transform3D]

	var all_transforms := _generate_sample_transforms(decoration, chunk_data, world_offset, chunk_size, cell_size, resolution, splatmap_channel)

	for transform in all_transforms:
		var variant_idx := _rng.randi() % variant_count
		variant_instances[variant_idx].append(transform)

	return variant_instances
```

- [ ] **Step 6: Update the spawning calls in `spawn_for_chunk()` to pass splatmap_channel**

In the spawning loop body, update the two calls to `_generate_instances_with_variants` and `_generate_instances` to pass `splatmap_channel`:

For the variant path (around the line that calls `_generate_instances_with_variants`):
```gdscript
			var variant_instances := _generate_instances_with_variants(
				decoration,
				chunk_data,
				world_offset,
				chunk_size,
				cell_size,
				resolution,
				splatmap_channel
			)
```

For the single mesh path (around the line that calls `_generate_instances`):
```gdscript
			var instances := _generate_instances(
				decoration,
				chunk_data,
				world_offset,
				chunk_size,
				cell_size,
				resolution,
				splatmap_channel
			)
```

- [ ] **Step 7: Commit**

```bash
git add addons/procedural_world/core/vegetation_spawner.gd
git commit -m "feat: add weighted biome decoration blending to VegetationSpawner"
```

---

### Task 2: Delete old nature-kit decoration .tres files

**Files:**
- Delete: all `.tres` files in `addons/procedural_world/decorations/`

- [ ] **Step 1: Remove all existing decoration .tres files**

```bash
git rm addons/procedural_world/decorations/*.tres
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: remove old nature-kit decoration definitions"
```

---

### Task 3: Create new decoration .tres files using environment pack

**Files:**
- Create: 16 `.tres` files in `addons/procedural_world/decorations/`

Read an existing `.tres` file first (if any remain) or use this template format. All environment assets are at `res://assets/environment/`.

- [ ] **Step 1: Create trees_standard_sparse.tres (Plains trees)**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/tree.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-tall.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 0
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.003
min_scale = 1.0
max_scale = 2.0
max_slope = 0.35
random_rotation = 6.283
cluster_strength = 0.3
cluster_scale = 0.015
cluster_group_id = 1
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.5
collision_height = 6.0
collision_distance = 60.0
```

- [ ] **Step 2: Create trees_standard_dense.tres (Forest trees)**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/tree.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-tall.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 0
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.015
min_scale = 1.0
max_scale = 2.5
max_slope = 0.4
random_rotation = 6.283
cluster_strength = 0.6
cluster_scale = 0.015
cluster_group_id = 1
cluster_edge_scale_falloff = 0.3
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.5
collision_height = 8.0
collision_distance = 60.0
```

- [ ] **Step 3: Create trees_autumn.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-autumn.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-autumn-tall.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 0
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.004
min_scale = 1.0
max_scale = 2.0
max_slope = 0.4
random_rotation = 6.283
cluster_strength = 0.4
cluster_scale = 0.02
cluster_group_id = 1
cluster_seed_offset = 20
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.5
collision_height = 6.0
collision_distance = 50.0
```

- [ ] **Step 4: Create tree_trunks_forest.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-trunk.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-autumn-trunk.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.005
min_scale = 0.8
max_scale = 1.3
max_slope = 0.3
random_rotation = 6.283
y_offset = -0.1
y_offset_variance = 0.05
has_collision = true
collision_shape = 0
collision_radius = 0.3
collision_height = 0.5
collision_distance = 25.0
```

- [ ] **Step 5: Create tree_trunks_mountain.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-trunk.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-autumn-trunk.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.003
min_scale = 0.6
max_scale = 1.0
max_slope = 0.5
random_rotation = 6.283
y_offset = -0.1
```

- [ ] **Step 6: Create rocks_standard.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=5 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/rock-a.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/rock-b.glb" id="3_s2"]
[ext_resource type="PackedScene" path="res://assets/environment/rock-c.glb" id="4_s3"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2"), ExtResource("4_s3")])
density = 0.02
min_scale = 0.6
max_scale = 1.5
max_slope = 0.7
random_rotation = 6.283
scale_variance = Vector3(0.2, 0.15, 0.2)
random_tilt = 0.2
y_offset = -0.1
y_offset_variance = 0.1
cluster_strength = 0.4
cluster_scale = 0.02
cluster_group_id = 2
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.6
collision_height = 1.5
collision_distance = 40.0
```

- [ ] **Step 7: Create rocks_flat.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/rock-flat.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/rock-flat-grass.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.01
min_scale = 0.7
max_scale = 1.3
max_slope = 0.4
align_to_normal = true
random_rotation = 6.283
y_offset = -0.05
cluster_strength = 0.2
cluster_scale = 0.03
cluster_group_id = 2
cluster_seed_offset = 10
```

- [ ] **Step 8: Create rocks_sandy.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=5 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/rock-sand-a.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/rock-sand-b.glb" id="3_s2"]
[ext_resource type="PackedScene" path="res://assets/environment/rock-sand-c.glb" id="4_s3"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2"), ExtResource("4_s3")])
density = 0.03
min_scale = 0.5
max_scale = 1.2
max_slope = 0.5
random_rotation = 6.283
scale_variance = Vector3(0.2, 0.15, 0.2)
random_tilt = 0.15
y_offset = -0.05
y_offset_variance = 0.05
cluster_strength = 0.3
cluster_scale = 0.03
cluster_group_id = 1
```

- [ ] **Step 9: Create resource_stones.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/resource-stone.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/resource-stone-large.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.015
min_scale = 0.6
max_scale = 1.2
max_slope = 0.6
random_rotation = 6.283
random_tilt = 0.2
y_offset = -0.1
cluster_strength = 0.5
cluster_scale = 0.02
cluster_group_id = 2
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.5
collision_height = 1.0
collision_distance = 35.0
```

- [ ] **Step 10: Create grass_patches.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/grass.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/grass-large.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 2
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.2
min_scale = 0.6
max_scale = 1.4
max_slope = 0.3
align_to_normal = true
random_rotation = 6.283
cluster_strength = 0.15
cluster_scale = 0.02
cluster_group_id = 3
```

- [ ] **Step 11: Create ground_patches.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/patch-grass.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/patch-grass-large.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 2
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.15
min_scale = 0.7
max_scale = 1.5
max_slope = 0.3
align_to_normal = true
random_rotation = 6.283
cluster_strength = 0.2
cluster_scale = 0.025
cluster_group_id = 3
cluster_seed_offset = 5
```

- [ ] **Step 12: Create fallen_logs.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-log.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/tree-log-small.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.004
min_scale = 0.8
max_scale = 1.4
max_slope = 0.3
align_to_normal = true
random_rotation = 6.283
y_offset = -0.15
y_offset_variance = 0.1
random_tilt = 0.1
has_collision = true
collision_shape = 0
collision_radius = 0.4
collision_height = 0.5
collision_distance = 25.0
```

- [ ] **Step 13: Create resource_wood.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/resource-wood.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/resource-planks.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.002
min_scale = 0.7
max_scale = 1.1
max_slope = 0.25
random_rotation = 6.283
y_offset = -0.05
```

- [ ] **Step 14: Create campfire_remains.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/campfire-pit.glb" id="2_s1"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1")])
density = 0.0005
min_scale = 0.8
max_scale = 1.2
max_slope = 0.2
random_rotation = 6.283
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.5
collision_height = 0.3
collision_distance = 30.0
```

- [ ] **Step 15: Create signposts.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/signpost.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/signpost-single.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.0003
min_scale = 0.9
max_scale = 1.1
max_slope = 0.15
random_rotation = 6.283
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.2
collision_height = 2.0
collision_distance = 30.0
```

- [ ] **Step 16: Create tents.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/environment/tent.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/environment/tent-canvas.glb" id="3_s2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2")])
density = 0.0003
min_scale = 0.9
max_scale = 1.1
max_slope = 0.15
random_rotation = 6.283
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 1.0
collision_height = 2.0
collision_distance = 30.0
```

- [ ] **Step 17: Commit**

```bash
git add addons/procedural_world/decorations/
git commit -m "feat: add 16 environment pack decoration definitions"
```

---

### Task 4: Wire new decorations to biome .tres files

**Files:**
- Modify: `world/biomes/plains.tres`
- Modify: `world/biomes/forest.tres`
- Modify: `world/biomes/desert.tres`
- Modify: `world/biomes/mountain.tres`

- [ ] **Step 1: Update plains.tres**

Read the file. Remove all old decoration ext_resources and the old decorations array. Add new ext_resources and decorations array.

Plains decorations:
- `trees_standard_sparse.tres`
- `grass_patches.tres`
- `ground_patches.tres`
- `rocks_flat.tres`
- `campfire_remains.tres`
- `signposts.tres`
- `tents.tres`

Update `load_steps` accordingly.

- [ ] **Step 2: Update forest.tres**

Forest decorations:
- `trees_standard_dense.tres`
- `trees_autumn.tres`
- `tree_trunks_forest.tres`
- `grass_patches.tres`
- `rocks_standard.tres`
- `rocks_flat.tres`
- `fallen_logs.tres`
- `resource_wood.tres`
- `campfire_remains.tres`

- [ ] **Step 3: Update desert.tres**

Desert decorations:
- `rocks_sandy.tres`
- `rocks_flat.tres`

- [ ] **Step 4: Update mountain.tres**

Mountain decorations:
- `rocks_standard.tres`
- `resource_stones.tres`
- `tree_trunks_mountain.tres`

- [ ] **Step 5: Commit**

```bash
git add world/biomes/
git commit -m "feat: wire environment pack decorations to all biomes"
```

---

### Task 5: Test end-to-end

- [ ] **Step 1: Run the procedural scene**

Open Godot, run `scenes/procedural.tscn`. Verify:
1. Trees render with proper colors (brown trunks, green/autumn foliage) — NOT white or cyan
2. Forest areas have dense trees that thin out at biome boundaries
3. Desert areas have only sandy rocks — no trees
4. Mountain areas have rocks and dead trunks — no large trees
5. Plains have sparse trees, grass patches, and rare campfires/signposts/tents
6. Biome transitions show gradual decoration changes (not abrupt per-chunk switching)
7. Performance stays above 30 FPS

- [ ] **Step 2: Commit any fixes**

```bash
git add -u
git commit -m "fix: address issues found during vegetation v2 testing"
```
