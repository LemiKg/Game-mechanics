# Vegetation Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the procedural world dense and lush with 18 new decoration types, increased densities, layered clustering, and natural props using unused nature-kit assets.

**Architecture:** All changes are resource files (`.tres`) — no code changes. New `DecorationDefinition` resources reference existing GLB models, get wired into biome `.tres` files, and density/clustering parameters are tuned for layered, natural-looking vegetation.

**Tech Stack:** Godot 4.x Resource files, nature-kit GLB assets

**Important context for implementers:**
- Decoration `.tres` files follow the pattern shown in existing files like `pine_trees_tall.tres`
- `decoration_type` values: 0=Tree, 1=Rock, 2=Grass, 3=Flower, 4=Bush
- `scene_variants` is an `Array[PackedScene]` — multiple variants get random selection per instance
- `cluster_group_id` groups decorations that should clump together spatially
- GLB assets are at `res://assets/nature-kit/`
- Decoration `.tres` files go in `addons/procedural_world/decorations/`
- Biome `.tres` files are at `world/biomes/`

---

## File Structure

### New decoration .tres files (18)
| File | Biome | Assets |
|---|---|---|
| `plains_grass_large_leafs.tres` | Plains | grass_leafsLarge.glb |
| `plains_flowers_purple.tres` | Plains | flower_purpleA/B/C.glb |
| `plains_flowers_red.tres` | Plains | flower_redA/B/C.glb |
| `plains_bush_detailed.tres` | Plains | plant_bushDetailed.glb |
| `plains_stumps.tres` | Plains | stump_round.glb, stump_roundDetailed.glb |
| `forest_oak_trees.tres` | Forest | tree_oak.glb, tree_default.glb, tree_detailed.glb |
| `forest_dark_pines.tres` | Forest | tree_cone_dark.glb, tree_blocks_dark.glb |
| `forest_fall_trees.tres` | Forest | tree_blocks_fall.glb, tree_cone_fall.glb |
| `forest_bush_flat.tres` | Forest | plant_flatShort.glb, plant_flatTall.glb |
| `forest_logs.tres` | Forest | log.glb, log_large.glb |
| `forest_stumps.tres` | Forest | stump_round.glb, stump_old.glb |
| `desert_rocks_small.tres` | Desert | rock_smallA-G.glb |
| `desert_stones_flat.tres` | Desert | stone_smallFlatA/B/C.glb |
| `desert_dead_stumps.tres` | Desert | stump_old.glb, stump_oldTall.glb |
| `mountain_rocks_large.tres` | Mountain | rock_largeA-F.glb |
| `mountain_rocks_small.tres` | Mountain | rock_smallA-G.glb |
| `mountain_stones_small.tres` | Mountain | stone_smallA-F.glb |
| `mountain_ground_pine.tres` | Mountain | tree_pineGroundA/B.glb |

### Modified files
| File | Changes |
|---|---|
| 9 existing decoration `.tres` files | Density increases |
| `world/biomes/plains.tres` | Add 5 decorations, update load_steps |
| `world/biomes/forest.tres` | Add 6 decorations, update load_steps |
| `world/biomes/desert.tres` | Add 3 decorations, update load_steps |
| `world/biomes/mountain.tres` | Add 4 decorations, update load_steps |
| `scenes/procedural.tscn` | max_per_chunk = 5000 |

---

### Task 1: Create Plains decoration .tres files and update densities

**Files:**
- Create: `addons/procedural_world/decorations/plains_grass_large_leafs.tres`
- Create: `addons/procedural_world/decorations/plains_flowers_purple.tres`
- Create: `addons/procedural_world/decorations/plains_flowers_red.tres`
- Create: `addons/procedural_world/decorations/plains_bush_detailed.tres`
- Create: `addons/procedural_world/decorations/plains_stumps.tres`
- Modify: `addons/procedural_world/decorations/grass_clumps.tres`
- Modify: `addons/procedural_world/decorations/flowers_mixed.tres`

- [ ] **Step 1: Create plains_grass_large_leafs.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/grass_leafsLarge.glb" id="2_scene1"]

[resource]
script = ExtResource("1_script")
decoration_type = 2
scene_variants = Array[PackedScene]([ExtResource("2_scene1")])
density = 0.2
min_scale = 0.7
max_scale = 1.5
max_slope = 0.3
align_to_normal = true
random_rotation = 6.283
cluster_strength = 0.2
cluster_scale = 0.02
cluster_group_id = 1
cluster_seed_offset = 10
```

- [ ] **Step 2: Create plains_flowers_purple.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=5 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/flower_purpleA.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/flower_purpleB.glb" id="3_scene2"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/flower_purpleC.glb" id="4_scene3"]

[resource]
script = ExtResource("1_script")
decoration_type = 3
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2"), ExtResource("4_scene3")])
density = 0.06
max_scale = 1.3
max_slope = 0.25
align_to_normal = true
random_rotation = 6.283
cluster_strength = 0.7
cluster_scale = 0.03
cluster_group_id = 2
cluster_seed_offset = 20
```

- [ ] **Step 3: Create plains_flowers_red.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=5 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/flower_redA.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/flower_redB.glb" id="3_scene2"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/flower_redC.glb" id="4_scene3"]

[resource]
script = ExtResource("1_script")
decoration_type = 3
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2"), ExtResource("4_scene3")])
density = 0.06
max_scale = 1.3
max_slope = 0.25
align_to_normal = true
random_rotation = 6.283
cluster_strength = 0.7
cluster_scale = 0.03
cluster_group_id = 2
cluster_seed_offset = 30
```

- [ ] **Step 4: Create plains_bush_detailed.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/plant_bushDetailed.glb" id="2_scene1"]

[resource]
script = ExtResource("1_script")
decoration_type = 4
scene_variants = Array[PackedScene]([ExtResource("2_scene1")])
density = 0.02
min_scale = 0.8
max_scale = 1.4
max_slope = 0.35
align_to_normal = false
random_rotation = 6.283
cluster_strength = 0.4
cluster_scale = 0.02
cluster_group_id = 3
cluster_seed_offset = 0
```

- [ ] **Step 5: Create plains_stumps.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stump_round.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stump_roundDetailed.glb" id="3_scene2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2")])
density = 0.003
min_scale = 0.8
max_scale = 1.2
max_slope = 0.3
align_to_normal = false
random_rotation = 6.283
y_offset = -0.1
y_offset_variance = 0.05
has_collision = true
collision_shape = 0
collision_radius = 0.3
collision_height = 0.5
collision_distance = 30.0
```

- [ ] **Step 6: Update density in grass_clumps.tres**

Change `density = 0.15` to `density = 0.3`

- [ ] **Step 7: Update density in flowers_mixed.tres**

Change `density = 0.08` to `density = 0.15`

- [ ] **Step 8: Commit**

```bash
git add addons/procedural_world/decorations/plains_*.tres addons/procedural_world/decorations/grass_clumps.tres addons/procedural_world/decorations/flowers_mixed.tres
git commit -m "feat: add 5 new plains decorations and increase densities"
```

---

### Task 2: Create Forest decoration .tres files and update densities

**Files:**
- Create: `addons/procedural_world/decorations/forest_oak_trees.tres`
- Create: `addons/procedural_world/decorations/forest_dark_pines.tres`
- Create: `addons/procedural_world/decorations/forest_fall_trees.tres`
- Create: `addons/procedural_world/decorations/forest_bush_flat.tres`
- Create: `addons/procedural_world/decorations/forest_logs.tres`
- Create: `addons/procedural_world/decorations/forest_stumps.tres`
- Modify: `addons/procedural_world/decorations/pine_trees_tall.tres`
- Modify: `addons/procedural_world/decorations/pine_trees_round.tres`
- Modify: `addons/procedural_world/decorations/bushes_large.tres`
- Modify: `addons/procedural_world/decorations/mushrooms.tres`

- [ ] **Step 1: Create forest_oak_trees.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=5 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/tree_oak.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/tree_default.glb" id="3_scene2"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/tree_detailed.glb" id="4_scene3"]

[resource]
script = ExtResource("1_script")
decoration_type = 0
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2"), ExtResource("4_scene3")])
density = 0.008
min_scale = 1.5
max_scale = 3.0
max_slope = 0.4
align_to_normal = false
random_rotation = 6.283
cluster_strength = 0.7
cluster_scale = 0.015
cluster_group_id = 1
cluster_seed_offset = 50
cluster_edge_scale_falloff = 0.3
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.5
collision_height = 8.0
collision_distance = 60.0
```

- [ ] **Step 2: Create forest_dark_pines.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/tree_cone_dark.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/tree_blocks_dark.glb" id="3_scene2"]

[resource]
script = ExtResource("1_script")
decoration_type = 0
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2")])
density = 0.006
min_scale = 1.2
max_scale = 2.5
max_slope = 0.4
align_to_normal = false
random_rotation = 6.283
cluster_strength = 0.5
cluster_scale = 0.02
cluster_group_id = 2
cluster_seed_offset = 0
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.4
collision_height = 6.0
collision_distance = 50.0
```

- [ ] **Step 3: Create forest_fall_trees.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/tree_blocks_fall.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/tree_cone_fall.glb" id="3_scene2"]

[resource]
script = ExtResource("1_script")
decoration_type = 0
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2")])
density = 0.003
min_scale = 1.2
max_scale = 2.5
max_slope = 0.4
align_to_normal = false
random_rotation = 6.283
cluster_strength = 0.3
cluster_scale = 0.02
cluster_group_id = 2
cluster_seed_offset = 10
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 0.4
collision_height = 6.0
collision_distance = 50.0
```

- [ ] **Step 4: Create forest_bush_flat.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/plant_flatShort.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/plant_flatTall.glb" id="3_scene2"]

[resource]
script = ExtResource("1_script")
decoration_type = 4
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2")])
density = 0.08
min_scale = 0.6
max_scale = 1.3
max_slope = 0.3
align_to_normal = true
random_rotation = 6.283
cluster_strength = 0.4
cluster_scale = 0.025
cluster_group_id = 3
cluster_seed_offset = 0
```

- [ ] **Step 5: Create forest_logs.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/log.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/log_large.glb" id="3_scene2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2")])
density = 0.004
min_scale = 0.8
max_scale = 1.5
max_slope = 0.3
align_to_normal = true
random_rotation = 6.283
y_offset = -0.15
y_offset_variance = 0.1
random_tilt = 0.15
has_collision = true
collision_shape = 0
collision_radius = 0.4
collision_height = 0.5
collision_distance = 25.0
```

- [ ] **Step 6: Create forest_stumps.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stump_round.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stump_old.glb" id="3_scene2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2")])
density = 0.005
min_scale = 0.8
max_scale = 1.2
max_slope = 0.3
align_to_normal = false
random_rotation = 6.283
y_offset = -0.1
y_offset_variance = 0.05
has_collision = true
collision_shape = 0
collision_radius = 0.3
collision_height = 0.5
collision_distance = 25.0
```

- [ ] **Step 7: Update existing forest decoration densities**

In `pine_trees_tall.tres`: change `density = 0.005` to `density = 0.012`
In `pine_trees_round.tres`: change `density = 0.01` to `density = 0.02`
In `bushes_large.tres`: change its density to `0.1` (read file first to find current value)
In `mushrooms.tres`: change its density to `0.04` (read file first to find current value)

- [ ] **Step 8: Commit**

```bash
git add addons/procedural_world/decorations/forest_*.tres addons/procedural_world/decorations/pine_trees_tall.tres addons/procedural_world/decorations/pine_trees_round.tres addons/procedural_world/decorations/bushes_large.tres addons/procedural_world/decorations/mushrooms.tres
git commit -m "feat: add 6 new forest decorations and increase densities"
```

---

### Task 3: Create Desert decoration .tres files and update densities

**Files:**
- Create: `addons/procedural_world/decorations/desert_rocks_small.tres`
- Create: `addons/procedural_world/decorations/desert_stones_flat.tres`
- Create: `addons/procedural_world/decorations/desert_dead_stumps.tres`
- Modify: `addons/procedural_world/decorations/rocks_flat.tres`

- [ ] **Step 1: Create desert_rocks_small.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=9 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallA.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallB.glb" id="3_s2"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallC.glb" id="4_s3"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallD.glb" id="5_s4"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallE.glb" id="6_s5"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallF.glb" id="7_s6"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallG.glb" id="8_s7"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2"), ExtResource("4_s3"), ExtResource("5_s4"), ExtResource("6_s5"), ExtResource("7_s6"), ExtResource("8_s7")])
density = 0.04
min_scale = 0.5
max_scale = 1.2
max_slope = 0.6
align_to_normal = false
random_rotation = 6.283
scale_variance = Vector3(0.2, 0.15, 0.2)
random_tilt = 0.25
y_offset = -0.05
y_offset_variance = 0.05
cluster_strength = 0.2
cluster_scale = 0.03
cluster_group_id = 2
cluster_seed_offset = 0
```

- [ ] **Step 2: Create desert_stones_flat.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=5 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stone_smallFlatA.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stone_smallFlatB.glb" id="3_s2"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stone_smallFlatC.glb" id="4_s3"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2"), ExtResource("4_s3")])
density = 0.03
min_scale = 0.6
max_scale = 1.3
max_slope = 0.5
align_to_normal = true
random_rotation = 6.283
random_tilt = 0.1
y_offset = -0.05
cluster_strength = 0.2
cluster_scale = 0.03
cluster_group_id = 2
cluster_seed_offset = 10
```

- [ ] **Step 3: Create desert_dead_stumps.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stump_old.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stump_oldTall.glb" id="3_scene2"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2")])
density = 0.002
min_scale = 0.7
max_scale = 1.1
max_slope = 0.3
align_to_normal = false
random_rotation = 6.283
y_offset = -0.1
has_collision = true
collision_shape = 0
collision_radius = 0.25
collision_height = 0.6
collision_distance = 25.0
```

- [ ] **Step 4: Update density in rocks_flat.tres**

Change density to `0.05` (read file first to find current value)

- [ ] **Step 5: Commit**

```bash
git add addons/procedural_world/decorations/desert_*.tres addons/procedural_world/decorations/rocks_flat.tres
git commit -m "feat: add 3 new desert decorations and increase rock density"
```

---

### Task 4: Create Mountain decoration .tres files and update densities

**Files:**
- Create: `addons/procedural_world/decorations/mountain_rocks_large.tres`
- Create: `addons/procedural_world/decorations/mountain_rocks_small.tres`
- Create: `addons/procedural_world/decorations/mountain_stones_small.tres`
- Create: `addons/procedural_world/decorations/mountain_ground_pine.tres`
- Modify: `addons/procedural_world/decorations/rocks_tall.tres`
- Modify: `addons/procedural_world/decorations/stones_large.tres`

- [ ] **Step 1: Create mountain_rocks_large.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=8 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_largeA.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_largeB.glb" id="3_s2"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_largeC.glb" id="4_s3"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_largeD.glb" id="5_s4"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_largeE.glb" id="6_s5"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_largeF.glb" id="7_s6"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2"), ExtResource("4_s3"), ExtResource("5_s4"), ExtResource("6_s5"), ExtResource("7_s6")])
density = 0.01
min_scale = 0.8
max_scale = 2.0
max_slope = 0.8
align_to_normal = false
random_rotation = 6.283
scale_variance = Vector3(0.3, 0.2, 0.3)
random_tilt = 0.2
y_offset = -0.3
y_offset_variance = 0.2
cluster_strength = 0.5
cluster_scale = 0.02
cluster_group_id = 1
cluster_seed_offset = 0
use_poisson_sampling = true
has_collision = true
collision_shape = 0
collision_radius = 1.0
collision_height = 3.0
collision_distance = 50.0
```

- [ ] **Step 2: Create mountain_rocks_small.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=9 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallA.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallB.glb" id="3_s2"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallC.glb" id="4_s3"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallD.glb" id="5_s4"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallE.glb" id="6_s5"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallF.glb" id="7_s6"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/rock_smallG.glb" id="8_s7"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2"), ExtResource("4_s3"), ExtResource("5_s4"), ExtResource("6_s5"), ExtResource("7_s6"), ExtResource("8_s7")])
density = 0.05
min_scale = 0.4
max_scale = 1.0
max_slope = 0.7
align_to_normal = false
random_rotation = 6.283
scale_variance = Vector3(0.2, 0.15, 0.2)
random_tilt = 0.3
y_offset = -0.05
y_offset_variance = 0.05
cluster_strength = 0.3
cluster_scale = 0.025
cluster_group_id = 2
cluster_seed_offset = 0
```

- [ ] **Step 3: Create mountain_stones_small.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=8 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stone_smallA.glb" id="2_s1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stone_smallB.glb" id="3_s2"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stone_smallC.glb" id="4_s3"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stone_smallD.glb" id="5_s4"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stone_smallE.glb" id="6_s5"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/stone_smallF.glb" id="7_s6"]

[resource]
script = ExtResource("1_script")
decoration_type = 1
scene_variants = Array[PackedScene]([ExtResource("2_s1"), ExtResource("3_s2"), ExtResource("4_s3"), ExtResource("5_s4"), ExtResource("6_s5"), ExtResource("7_s6")])
density = 0.06
min_scale = 0.3
max_scale = 0.8
max_slope = 0.6
align_to_normal = true
random_rotation = 6.283
random_tilt = 0.2
y_offset = -0.03
cluster_strength = 0.2
cluster_scale = 0.03
cluster_group_id = 2
cluster_seed_offset = 10
```

- [ ] **Step 4: Create mountain_ground_pine.tres**

```tres
[gd_resource type="Resource" script_class="DecorationDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/procedural_world/core/decoration_definition.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/tree_pineGroundA.glb" id="2_scene1"]
[ext_resource type="PackedScene" path="res://assets/nature-kit/tree_pineGroundB.glb" id="3_scene2"]

[resource]
script = ExtResource("1_script")
decoration_type = 0
scene_variants = Array[PackedScene]([ExtResource("2_scene1"), ExtResource("3_scene2")])
density = 0.008
min_scale = 0.8
max_scale = 1.5
max_slope = 0.5
align_to_normal = false
random_rotation = 6.283
cluster_strength = 0.4
cluster_scale = 0.02
cluster_group_id = 3
cluster_seed_offset = 0
use_poisson_sampling = true
```

- [ ] **Step 5: Update existing mountain decoration densities**

In `rocks_tall.tres`: change `density = 0.003` to `density = 0.015`
In `stones_large.tres`: change density to `0.012` (read file first to find current value)

- [ ] **Step 6: Commit**

```bash
git add addons/procedural_world/decorations/mountain_*.tres addons/procedural_world/decorations/rocks_tall.tres addons/procedural_world/decorations/stones_large.tres
git commit -m "feat: add 4 new mountain decorations and increase densities"
```

---

### Task 5: Wire new decorations to biome .tres files

**Files:**
- Modify: `world/biomes/plains.tres`
- Modify: `world/biomes/forest.tres`
- Modify: `world/biomes/desert.tres`
- Modify: `world/biomes/mountain.tres`

- [ ] **Step 1: Update plains.tres**

Read the file. Add ext_resource entries for the 5 new decoration .tres files. Add them to the `decorations` array. Increment `load_steps` by 5.

New decorations to add:
- `res://addons/procedural_world/decorations/plains_grass_large_leafs.tres`
- `res://addons/procedural_world/decorations/plains_flowers_purple.tres`
- `res://addons/procedural_world/decorations/plains_flowers_red.tres`
- `res://addons/procedural_world/decorations/plains_bush_detailed.tres`
- `res://addons/procedural_world/decorations/plains_stumps.tres`

- [ ] **Step 2: Update forest.tres**

Read the file. Add ext_resource entries for the 6 new decoration .tres files. Add them to the `decorations` array. Increment `load_steps` by 6.

New decorations to add:
- `res://addons/procedural_world/decorations/forest_oak_trees.tres`
- `res://addons/procedural_world/decorations/forest_dark_pines.tres`
- `res://addons/procedural_world/decorations/forest_fall_trees.tres`
- `res://addons/procedural_world/decorations/forest_bush_flat.tres`
- `res://addons/procedural_world/decorations/forest_logs.tres`
- `res://addons/procedural_world/decorations/forest_stumps.tres`

- [ ] **Step 3: Update desert.tres**

Read the file. Add ext_resource entries for the 3 new decoration .tres files. Add them to the `decorations` array. Increment `load_steps` by 3.

New decorations to add:
- `res://addons/procedural_world/decorations/desert_rocks_small.tres`
- `res://addons/procedural_world/decorations/desert_stones_flat.tres`
- `res://addons/procedural_world/decorations/desert_dead_stumps.tres`

- [ ] **Step 4: Update mountain.tres**

Read the file. Add ext_resource entries for the 4 new decoration .tres files. Add them to the `decorations` array. Increment `load_steps` by 4.

New decorations to add:
- `res://addons/procedural_world/decorations/mountain_rocks_large.tres`
- `res://addons/procedural_world/decorations/mountain_rocks_small.tres`
- `res://addons/procedural_world/decorations/mountain_stones_small.tres`
- `res://addons/procedural_world/decorations/mountain_ground_pine.tres`

- [ ] **Step 5: Commit**

```bash
git add world/biomes/
git commit -m "feat: wire 18 new decorations to biome resources"
```

---

### Task 6: Increase max_per_chunk and test

**Files:**
- Modify: `scenes/procedural.tscn`

- [ ] **Step 1: Update max_per_chunk**

In `scenes/procedural.tscn`, find the VegetationSpawner node (around line 83):
```
max_per_chunk = 1000
```
Change to:
```
max_per_chunk = 5000
```

- [ ] **Step 2: Commit**

```bash
git add scenes/procedural.tscn
git commit -m "feat: increase max_per_chunk to 5000 for dense vegetation"
```

- [ ] **Step 3: Test in Godot**

Run `scenes/procedural.tscn` and verify:
1. Plains have dense grass carpet with scattered flower patches and occasional stumps
2. Forests feel thick with multiple tree types, undergrowth, logs, and stumps
3. Desert has scattered rocks and stones across the ground
4. Mountains have dense scree/rock fields with ground pines
5. Performance stays above 30 FPS (check debug overlay)
6. No missing assets or errors in Output panel
