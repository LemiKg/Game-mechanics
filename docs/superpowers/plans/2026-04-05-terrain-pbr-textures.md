# Terrain PBR Textures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace flat procedural terrain colors with stylized 1K PBR textures assigned per biome, with per-chunk material instances selecting the dominant biome's texture set.

**Architecture:** A new `TerrainMaterialSet` resource groups 12 texture references (4 channels x albedo/normal/roughness). BiomeData gains a `terrain_materials` export. ChunkManager determines the dominant biome per chunk and passes its material set to TerrainChunk, which applies the textures to the duplicated shader material.

**Tech Stack:** Godot 4.x, GDScript, GDSHADER (existing), CC0 textures from AmbientCG/Polyhaven

---

## File Structure

### New files
| File | Responsibility |
|---|---|
| `addons/procedural_world/core/terrain_material_set.gd` | Resource class grouping textures for 4 splatmap channels |
| `assets/textures/terrain/plains/*.png` | 9 texture files (grass, rock, ground x albedo/normal/roughness) |
| `assets/textures/terrain/forest/*.png` | 9 texture files |
| `assets/textures/terrain/desert/*.png` | 9 texture files |
| `assets/textures/terrain/mountain/*.png` | 9 texture files |
| `assets/textures/terrain/shared/*.png` | 3 texture files (snow) |
| `world/materials/plains_terrain.tres` | Plains TerrainMaterialSet instance |
| `world/materials/forest_terrain.tres` | Forest TerrainMaterialSet instance |
| `world/materials/desert_terrain.tres` | Desert TerrainMaterialSet instance |
| `world/materials/mountain_terrain.tres` | Mountain TerrainMaterialSet instance |

### Modified files
| File | Changes |
|---|---|
| `addons/procedural_world/core/biome_data.gd` | Add `terrain_materials: TerrainMaterialSet` export |
| `addons/procedural_world/core/chunk_generator.gd` | Add `get_dominant_biome()` static method |
| `addons/procedural_world/core/chunk_manager.gd` | Look up dominant biome, pass material set to chunk |
| `addons/procedural_world/core/terrain_chunk.gd` | Accept and apply TerrainMaterialSet in `initialize()` |
| `world/biomes/plains.tres` | Reference plains_terrain material set |
| `world/biomes/forest.tres` | Reference forest_terrain material set |
| `world/biomes/desert.tres` | Reference desert_terrain material set |
| `world/biomes/mountain.tres` | Reference mountain_terrain material set |
| `world/terrain_material.tres` | Assign shared snow textures to A channel |

---

### Task 1: Create TerrainMaterialSet resource class

**Files:**
- Create: `addons/procedural_world/core/terrain_material_set.gd`

- [ ] **Step 1: Create the resource class**

```gdscript
@tool
extends Resource
class_name TerrainMaterialSet
## Groups PBR textures for all 4 splatmap channels.
##
## Each channel (R, G, B, A) has albedo, normal, and roughness textures.
## Assign to a BiomeData's terrain_materials property to define
## per-biome terrain appearance.


@export_group("Channel R (Vegetation)")
@export var channel_r_albedo: Texture2D
@export var channel_r_normal: Texture2D
@export var channel_r_roughness: Texture2D

@export_group("Channel G (Rock)")
@export var channel_g_albedo: Texture2D
@export var channel_g_normal: Texture2D
@export var channel_g_roughness: Texture2D

@export_group("Channel B (Ground)")
@export var channel_b_albedo: Texture2D
@export var channel_b_normal: Texture2D
@export var channel_b_roughness: Texture2D

@export_group("Channel A (Snow)")
@export var channel_a_albedo: Texture2D
@export var channel_a_normal: Texture2D
@export var channel_a_roughness: Texture2D


## Apply all textures to a ShaderMaterial instance.
func apply_to_material(material: ShaderMaterial) -> void:
	if not material:
		return
	_set_if_valid(material, "texture_r_albedo", channel_r_albedo)
	_set_if_valid(material, "texture_r_normal", channel_r_normal)
	_set_if_valid(material, "texture_r_roughness", channel_r_roughness)
	_set_if_valid(material, "texture_g_albedo", channel_g_albedo)
	_set_if_valid(material, "texture_g_normal", channel_g_normal)
	_set_if_valid(material, "texture_g_roughness", channel_g_roughness)
	_set_if_valid(material, "texture_b_albedo", channel_b_albedo)
	_set_if_valid(material, "texture_b_normal", channel_b_normal)
	_set_if_valid(material, "texture_b_roughness", channel_b_roughness)
	_set_if_valid(material, "texture_a_albedo", channel_a_albedo)
	_set_if_valid(material, "texture_a_normal", channel_a_normal)
	_set_if_valid(material, "texture_a_roughness", channel_a_roughness)


func _set_if_valid(material: ShaderMaterial, uniform: String, texture: Texture2D) -> void:
	if texture:
		material.set_shader_parameter(uniform, texture)
```

- [ ] **Step 2: Commit**

```bash
git add addons/procedural_world/core/terrain_material_set.gd
git commit -m "feat: add TerrainMaterialSet resource for per-biome terrain textures"
```

---

### Task 2: Add terrain_materials export to BiomeData

**Files:**
- Modify: `addons/procedural_world/core/biome_data.gd`

- [ ] **Step 1: Add the export property**

After line 40 (`@export var decorations: Array[DecorationDefinition] = []`), add:

```gdscript
## Terrain texture set for this biome. Applied to chunks where this biome dominates.
@export var terrain_materials: TerrainMaterialSet
```

- [ ] **Step 2: Commit**

```bash
git add addons/procedural_world/core/biome_data.gd
git commit -m "feat: add terrain_materials export to BiomeData"
```

---

### Task 3: Add get_dominant_biome() to ChunkGenerator

**Files:**
- Modify: `addons/procedural_world/core/chunk_generator.gd`

- [ ] **Step 1: Add the static method**

Add after the `calculate_biome_weights()` method (at the end of the file):

```gdscript
## Determine which biome dominates a chunk based on total biome weight sums.
## Returns the BiomeData with the highest total weight, or fallback_biome.
static func get_dominant_biome(chunk_data: ChunkData, biome_map: BiomeMap) -> BiomeData:
	if not biome_map:
		return null

	# Sum weights per splatmap channel across all vertices
	var channel_sums := [0.0, 0.0, 0.0, 0.0]
	var vertex_count := chunk_data.width * chunk_data.depth

	for i in range(vertex_count):
		var idx := i * 4
		channel_sums[0] += chunk_data.biome_weights[idx]
		channel_sums[1] += chunk_data.biome_weights[idx + 1]
		channel_sums[2] += chunk_data.biome_weights[idx + 2]
		channel_sums[3] += chunk_data.biome_weights[idx + 3]

	# Find dominant channel
	var max_sum := 0.0
	var dominant_channel := 0
	for ch in range(4):
		if channel_sums[ch] > max_sum:
			max_sum = channel_sums[ch]
			dominant_channel = ch

	# Find the biome that uses this channel
	for biome in biome_map.biomes:
		if biome and biome.splatmap_channel == dominant_channel:
			return biome

	return biome_map.fallback_biome
```

- [ ] **Step 2: Commit**

```bash
git add addons/procedural_world/core/chunk_generator.gd
git commit -m "feat: add get_dominant_biome() for per-chunk texture selection"
```

---

### Task 4: Update TerrainChunk to accept and apply material sets

**Files:**
- Modify: `addons/procedural_world/core/terrain_chunk.gd`

- [ ] **Step 1: Update the initialize() method signature**

The current `initialize()` signature (line 38) is:

```gdscript
func initialize(data: ChunkData, material: ShaderMaterial, cell_size: float = 1.0) -> void:
```

Change it to:

```gdscript
func initialize(data: ChunkData, material: ShaderMaterial, cell_size: float = 1.0, material_set: TerrainMaterialSet = null) -> void:
```

- [ ] **Step 2: Apply the material set after splatmap setup**

After the line `_setup_splatmap()` (around line 52), add:

```gdscript
		if material_set:
			material_set.apply_to_material(_material)
```

So the block reads:

```gdscript
	if material:
		_material = material.duplicate() as ShaderMaterial
		_setup_splatmap()
		if material_set:
			material_set.apply_to_material(_material)
	else:
		_material = null
```

- [ ] **Step 3: Commit**

```bash
git add addons/procedural_world/core/terrain_chunk.gd
git commit -m "feat: apply TerrainMaterialSet textures during chunk initialization"
```

---

### Task 5: Update ChunkManager to pass material set to chunks

**Files:**
- Modify: `addons/procedural_world/core/chunk_manager.gd`

- [ ] **Step 1: Determine dominant biome and pass material set**

In `_generate_and_apply_chunk()`, the current initialization line (around line 287) is:

```gdscript
	chunk.initialize(chunk_data, world_config.terrain_material, cell_size)
```

Replace it with:

```gdscript
	# Determine dominant biome for per-chunk texture selection
	var material_set: TerrainMaterialSet = null
	if world_config.biome_map:
		var dominant_biome := ChunkGenerator.get_dominant_biome(chunk_data, world_config.biome_map)
		if dominant_biome and dominant_biome.terrain_materials:
			material_set = dominant_biome.terrain_materials

	chunk.initialize(chunk_data, world_config.terrain_material, cell_size, material_set)
```

- [ ] **Step 2: Commit**

```bash
git add addons/procedural_world/core/chunk_manager.gd
git commit -m "feat: determine dominant biome and pass material set to chunks"
```

---

### Task 6: Download and organize terrain textures

**Files:**
- Create: `assets/textures/terrain/` directory structure with 39 texture files

This task requires downloading CC0 textures from the web. Search AmbientCG and Polyhaven for stylized/painterly textures at 1K resolution.

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p assets/textures/terrain/plains
mkdir -p assets/textures/terrain/forest
mkdir -p assets/textures/terrain/desert
mkdir -p assets/textures/terrain/mountain
mkdir -p assets/textures/terrain/shared
```

- [ ] **Step 2: Search and download textures**

For each biome, search for CC0 stylized textures. Target search terms:

| Biome | Channel R (Vegetation) | Channel G (Rock) | Channel B (Ground) |
|---|---|---|---|
| Plains | "grass stylized" or "meadow" | "limestone" or "light rock" | "dirt path" or "dry ground" |
| Forest | "moss grass" or "forest floor grass" | "mossy rock" or "moss stone" | "forest floor" or "mulch" |
| Desert | "dry grass" or "dead grass" | "sandstone" | "sand" or "desert sand" |
| Mountain | "alpine grass" or "tundra grass" | "granite" or "dark rock" | "gravel" or "scree" |
| Shared | — | — | "snow" |

Each texture set needs: `*_albedo.png`, `*_normal.png`, `*_roughness.png` (1024x1024).

Download using web search and WebFetch. Save to the appropriate directory with naming convention:
- `assets/textures/terrain/plains/grass_albedo.png`
- `assets/textures/terrain/plains/grass_normal.png`
- `assets/textures/terrain/plains/grass_roughness.png`
- (same pattern for rock_*, ground_*)

If a suitable stylized texture cannot be found, download the closest match — the 1K resolution and triplanar projection will soften photorealistic textures into a reasonable approximation.

- [ ] **Step 3: Commit textures**

```bash
git add assets/textures/terrain/
git commit -m "feat: add CC0 terrain PBR textures for all biomes"
```

---

### Task 7: Create TerrainMaterialSet .tres resources for each biome

**Files:**
- Create: `world/materials/plains_terrain.tres`
- Create: `world/materials/forest_terrain.tres`
- Create: `world/materials/desert_terrain.tres`
- Create: `world/materials/mountain_terrain.tres`

- [ ] **Step 1: Create materials directory**

```bash
mkdir -p world/materials
```

- [ ] **Step 2: Create plains_terrain.tres**

```tres
[gd_resource type="Resource" script_class="TerrainMaterialSet" load_steps=11 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/terrain_material_set.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/textures/terrain/plains/grass_albedo.png" id="2_r_alb"]
[ext_resource type="Texture2D" path="res://assets/textures/terrain/plains/grass_normal.png" id="3_r_nrm"]
[ext_resource type="Texture2D" path="res://assets/textures/terrain/plains/grass_roughness.png" id="4_r_rgh"]
[ext_resource type="Texture2D" path="res://assets/textures/terrain/plains/rock_albedo.png" id="5_g_alb"]
[ext_resource type="Texture2D" path="res://assets/textures/terrain/plains/rock_normal.png" id="6_g_nrm"]
[ext_resource type="Texture2D" path="res://assets/textures/terrain/plains/rock_roughness.png" id="7_g_rgh"]
[ext_resource type="Texture2D" path="res://assets/textures/terrain/plains/ground_albedo.png" id="8_b_alb"]
[ext_resource type="Texture2D" path="res://assets/textures/terrain/plains/ground_normal.png" id="9_b_nrm"]
[ext_resource type="Texture2D" path="res://assets/textures/terrain/plains/ground_roughness.png" id="10_b_rgh"]

[resource]
script = ExtResource("1_script")
channel_r_albedo = ExtResource("2_r_alb")
channel_r_normal = ExtResource("3_r_nrm")
channel_r_roughness = ExtResource("4_r_rgh")
channel_g_albedo = ExtResource("5_g_alb")
channel_g_normal = ExtResource("6_g_nrm")
channel_g_roughness = ExtResource("7_g_rgh")
channel_b_albedo = ExtResource("8_b_alb")
channel_b_normal = ExtResource("9_b_nrm")
channel_b_roughness = ExtResource("10_b_rgh")
```

Note: Snow (channel A) textures are omitted here — they're set on the base material.

- [ ] **Step 3: Create forest_terrain.tres**

Same structure as plains, but paths reference `assets/textures/terrain/forest/` files.

- [ ] **Step 4: Create desert_terrain.tres**

Same structure, paths reference `assets/textures/terrain/desert/` files.

- [ ] **Step 5: Create mountain_terrain.tres**

Same structure, paths reference `assets/textures/terrain/mountain/` files.

- [ ] **Step 6: Commit**

```bash
git add world/materials/
git commit -m "feat: add TerrainMaterialSet resources for all biomes"
```

---

### Task 8: Wire biome .tres files to material sets and apply snow to base material

**Files:**
- Modify: `world/biomes/plains.tres`
- Modify: `world/biomes/forest.tres`
- Modify: `world/biomes/desert.tres`
- Modify: `world/biomes/mountain.tres`
- Modify: `world/terrain_material.tres`

- [ ] **Step 1: Update each biome .tres to reference its material set**

For each biome resource file, add the `terrain_materials` property pointing to the corresponding `.tres` in `world/materials/`. This requires:

1. Adding an ext_resource line for the material set
2. Adding `terrain_materials = ExtResource("X_materials")` to the resource block
3. Incrementing `load_steps` by 1

Read each file first to understand its current structure, then add the reference.

Example for plains.tres — add:
```
[ext_resource type="Resource" path="res://world/materials/plains_terrain.tres" id="X_materials"]
```
And in the `[resource]` block:
```
terrain_materials = ExtResource("X_materials")
```

Repeat for forest, desert, mountain.

- [ ] **Step 2: Assign shared snow textures to base terrain material**

Read `world/terrain_material.tres` and set the A channel texture uniforms to the shared snow textures:

```
shader_parameter/texture_a_albedo = ExtResource("snow_alb")
shader_parameter/texture_a_normal = ExtResource("snow_nrm")
shader_parameter/texture_a_roughness = ExtResource("snow_rgh")
```

Add the corresponding ext_resource entries for the snow texture files.

- [ ] **Step 3: Commit**

```bash
git add world/biomes/ world/terrain_material.tres
git commit -m "feat: wire biome resources to material sets and apply shared snow textures"
```

---

### Task 9: Test end-to-end

- [ ] **Step 1: Test with Quaternius in textured terrain**

1. Make sure `scenes/player.tscn` CharacterMesh points to the Quaternius character
2. Open Godot and run the main scene
3. Walk around — verify:
   - Plains areas show meadow grass/limestone/dirt textures
   - Forest areas show mossy grass/mossy rock/mulch textures
   - Desert areas show dry grass/sandstone/sand textures
   - Mountain areas show alpine grass/granite/gravel textures
   - High elevation shows snow blending
   - Biome transitions are smooth (splatmap blends within chunks)
   - Chunk boundaries between biomes are not jarring

- [ ] **Step 2: Test fallback behavior**

1. Temporarily remove `terrain_materials` from one biome .tres
2. Run — verify that biome's chunks fall back to procedural colors (no crash)
3. Restore the reference

- [ ] **Step 3: Commit any fixes**

```bash
git add -u
git commit -m "fix: address issues found during terrain texture testing"
```
