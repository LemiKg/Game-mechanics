# Vegetation Expansion Design

## Goal

Make the procedural world feel dense and lush by using more of the nature-kit assets, increasing decoration densities, adding natural props (stumps, logs), and tuning clustering for layered vegetation.

## Approach

All changes are resource/configuration only — no code changes. The VegetationSpawner and DecorationDefinition systems already support everything needed. We create new `.tres` decoration definitions, increase densities on existing ones, wire them to biomes, and raise max_per_chunk.

---

## 1. New Decoration Definitions (18 new types)

### Plains (3 → 8 types)

| Name | Asset(s) | Density | Clustering | Notes |
|---|---|---|---|---|
| Grass Large Leafs | grass_leafsLarge.glb | 0.2 | Low (0.2) | Dense ground carpet |
| Flowers Purple | flower_purpleA/B/C.glb | 0.06 | High (0.7) | Tight flower patches |
| Flowers Red | flower_redA/B/C.glb | 0.06 | High (0.7) | Tight flower patches |
| Bush Detailed | bush_detailed.glb | 0.02 | Medium (0.4) | Scattered accent |
| Stumps | stump_round.glb, stump_roundDetailed.glb | 0.003 | None | Rare natural props |

### Forest (4 → 10 types)

| Name | Asset(s) | Density | Clustering | Notes |
|---|---|---|---|---|
| Birch Trees | tree_birch*.glb variants | 0.008 | High (0.7) | Clustered groves, same cluster_group_id as tall pines |
| Dark Pine Trees | tree_cone_dark.glb, tree_blocks_dark.glb | 0.006 | Medium (0.5) | Fill canopy gaps |
| Fall Trees | tree_blocks_fall.glb | 0.003 | Low (0.3) | Rare color accent |
| Bush Flat Short | bush_flatShort.glb | 0.08 | Medium (0.4) | Dense undergrowth |
| Logs | log.glb | 0.004 | None | Fallen tree props |
| Stumps | stump_round.glb | 0.005 | None | Cut tree remains |

### Desert (3 → 6 types)

| Name | Asset(s) | Density | Clustering | Notes |
|---|---|---|---|---|
| Rocks Small | rock_smallA-G.glb (7 variants) | 0.04 | Low (0.2) | Rocky ground scatter |
| Stones Flat | stone_flatA-C.glb (3 variants) | 0.03 | Low (0.2) | Desert pavement |
| Dead Stumps | stump_round.glb | 0.002 | None | Bleached dead wood |

### Mountain (3 → 7 types)

| Name | Asset(s) | Density | Clustering | Notes |
|---|---|---|---|---|
| Rocks Large | rock_largeA-F.glb (6 variants) | 0.01 | Medium (0.5) | Boulder fields |
| Rocks Small | rock_smallA-G.glb (7 variants) | 0.05 | Low (0.3) | Dense scree |
| Stones Small | stone_smallA-E.glb (5 variants) | 0.06 | Low (0.2) | Ground scatter |
| Ground Pine | tree_pineGroundA/B.glb | 0.008 | Medium (0.4) | Low alpine scrub |

---

## 2. Density Increases on Existing Decorations

| Biome | Decoration | Current | New |
|---|---|---|---|
| Plains | Grass Clumps | 0.15 | 0.3 |
| Plains | Flowers Mixed | 0.08 | 0.15 |
| Forest | Pine Trees Tall | 0.005 | 0.012 |
| Forest | Pine Trees Round | 0.01 | 0.02 |
| Forest | Bushes Large | 0.05 | 0.1 |
| Forest | Mushrooms | 0.02 | 0.04 |
| Desert | Rocks Flat | 0.02 | 0.05 |
| Mountain | Rocks Tall | 0.008 | 0.015 |
| Mountain | Stones Large | 0.005 | 0.012 |

---

## 3. Clustering and Layering

Decorations are grouped into visual layers per biome using `cluster_group_id` so related types clump together naturally.

### Forest Layers
- **Canopy (group 1):** Pine Tall, Birch Trees — cluster together for forest groves
- **Mid (group 2):** Dark Pines, Fall Trees — fill between groves
- **Understory (group 3):** Large Bushes, Flat Short Bushes — dense under canopy
- **Ground (no clustering):** Mushrooms, Logs, Stumps — scattered everywhere

### Plains Layers
- **Ground cover (group 1):** Grass Clumps, Large Leaf Grass — carpet, minimal clustering
- **Flower patches (group 2):** All flower types — tight clusters form visible patches
- **Accent (group 3):** Small Bushes, Detailed Bushes — loose clusters

### Desert Layers
- **Cacti (group 1):** Tall Cactus, Short Cactus — existing clusters
- **Rock fields (group 2):** All rock/stone types — loose clustering for rocky areas
- **Props (no clustering):** Dead Stumps — rare scatter

### Mountain Layers
- **Boulders (group 1):** Rocks Large, Rocks Tall — clustered boulder fields
- **Scree (group 2):** Rocks Small, Stones Small, Stones Large — dense ground cover
- **Alpine vegetation (group 3):** Small Pines, Ground Pine — sparse, clustered

---

## 4. Performance Configuration

- **max_per_chunk:** 1000 → 5000
- **Existing safeguards remain:** MultiMesh batching, distance culling, spawn radius

---

## 5. Files Summary

### New files (18 decoration .tres)
| File | Biome |
|---|---|
| `addons/procedural_world/decorations/plains_grass_large_leafs.tres` | Plains |
| `addons/procedural_world/decorations/plains_flowers_purple.tres` | Plains |
| `addons/procedural_world/decorations/plains_flowers_red.tres` | Plains |
| `addons/procedural_world/decorations/plains_bush_detailed.tres` | Plains |
| `addons/procedural_world/decorations/plains_stumps.tres` | Plains |
| `addons/procedural_world/decorations/forest_birch_trees.tres` | Forest |
| `addons/procedural_world/decorations/forest_dark_pines.tres` | Forest |
| `addons/procedural_world/decorations/forest_fall_trees.tres` | Forest |
| `addons/procedural_world/decorations/forest_bush_flat.tres` | Forest |
| `addons/procedural_world/decorations/forest_logs.tres` | Forest |
| `addons/procedural_world/decorations/forest_stumps.tres` | Forest |
| `addons/procedural_world/decorations/desert_rocks_small.tres` | Desert |
| `addons/procedural_world/decorations/desert_stones_flat.tres` | Desert |
| `addons/procedural_world/decorations/desert_dead_stumps.tres` | Desert |
| `addons/procedural_world/decorations/mountain_rocks_large.tres` | Mountain |
| `addons/procedural_world/decorations/mountain_rocks_small.tres` | Mountain |
| `addons/procedural_world/decorations/mountain_stones_small.tres` | Mountain |
| `addons/procedural_world/decorations/mountain_ground_pine.tres` | Mountain |

### Modified files
| File | Changes |
|---|---|
| 9 existing decoration `.tres` files | Density increases per table in Section 2 |
| `world/biomes/plains.tres` | Add 5 new decorations to decorations array |
| `world/biomes/forest.tres` | Add 6 new decorations to decorations array |
| `world/biomes/desert.tres` | Add 3 new decorations to decorations array |
| `world/biomes/mountain.tres` | Add 4 new decorations to decorations array |
| `scenes/procedural.tscn` | max_per_chunk = 5000 |
