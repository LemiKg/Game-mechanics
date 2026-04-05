# Vegetation System v2 Design

> Supersedes `2026-04-05-vegetation-expansion-design.md`.

## Goal

Replace the current vegetation system's asset set (nature-kit GLBs with broken materials) with the environment pack assets (colormap-textured, reliable rendering), and fix biome-decoration mismatches at chunk boundaries with weighted biome blending.

## Problems with v1

1. **Broken materials:** Nature-kit GLBs use inline `baseColorFactor` colors that get lost during MultiMesh mesh extraction. Trees render white/untextured.
2. **Wrong biome placement:** Single center-sample determines ALL decorations for a chunk. Transition zones show forest trees on desert terrain.
3. **Too many decoration types:** 31 types created complexity without visual payoff due to broken materials.

## Approach

1. Replace all nature-kit decorations with environment pack GLBs (use `colormap.png` texture atlas — materials work reliably)
2. Change spawner to collect decorations from ALL biomes present in a chunk, weighted by per-vertex biome strength
3. Add rare world structure decorations (campfires, signposts, tents)

---

## 1. Environment Pack Decoration Set (14 types)

### Trees
| Name | Assets | Biomes | Density | Notes |
|---|---|---|---|---|
| Trees Standard | tree.glb, tree-tall.glb | Plains (0.003), Forest (0.015) | Varies | Poisson sampling, collision |
| Trees Autumn | tree-autumn.glb, tree-autumn-tall.glb | Forest (0.004) | Low | Color accent, Poisson |
| Tree Trunks | tree-trunk.glb, tree-autumn-trunk.glb | Forest (0.005), Mountain (0.003) | Low | Dead/fallen trees |

### Rocks
| Name | Assets | Biomes | Density | Notes |
|---|---|---|---|---|
| Rocks Standard | rock-a.glb, rock-b.glb, rock-c.glb | Mountain (0.02), Forest (0.008) | Medium | Scale variance, tilt |
| Rocks Flat | rock-flat.glb, rock-flat-grass.glb | Plains (0.01), Forest (0.005) | Low | Align to normal |
| Rocks Sandy | rock-sand-a.glb, rock-sand-b.glb, rock-sand-c.glb | Desert (0.03) | Medium | Desert ground scatter |
| Resource Stones | resource-stone.glb, resource-stone-large.glb | Mountain (0.015) | Medium | Boulder fields |

### Vegetation
| Name | Assets | Biomes | Density | Notes |
|---|---|---|---|---|
| Grass Patches | grass.glb, grass-large.glb | Plains (0.2), Forest (0.1) | High | Ground cover, align to normal |
| Ground Patches | patch-grass.glb, patch-grass-large.glb | Plains (0.15) | High | Ground carpet |

### Props
| Name | Assets | Biomes | Density | Notes |
|---|---|---|---|---|
| Fallen Logs | tree-log.glb, tree-log-small.glb | Forest (0.004) | Low | Collision, tilt |
| Resource Wood | resource-wood.glb, resource-planks.glb | Forest (0.002) | Rare | Scattered lumber |

### Structures (very rare)
| Name | Assets | Biomes | Density | Notes |
|---|---|---|---|---|
| Campfire Remains | campfire-pit.glb | Plains (0.0005), Forest (0.0005) | Very rare | Collision |
| Signposts | signpost.glb, signpost-single.glb | Plains (0.0003) | Very rare | Collision |
| Tents | tent.glb, tent-canvas.glb | Plains (0.0003) | Very rare | Collision |

All assets from `res://assets/environment/`. All use `colormap.png` texture atlas.

---

## 2. Weighted Biome Decoration Blending

### Current behavior (broken)
```
chunk ready → sample center point → get ONE biome → spawn only that biome's decorations
```

### New behavior
```
chunk ready → collect decorations from ALL biomes with presence in chunk
→ for each decoration type, for each candidate instance:
   → sample biome weight at instance world position from chunk biome_weights
   → roll random 0-1, compare to biome weight
   → spawn only if roll < biome weight
```

### Changes to `_get_decorations_for_chunk()`

Returns decorations from ALL biomes, tagged with their splatmap channel:

```gdscript
func _get_decorations_for_chunk(chunk_data: ChunkData) -> Array[Dictionary]:
    # Returns Array of { "decoration": DecorationDefinition, "splatmap_channel": int }
    var tagged: Array[Dictionary] = []
    for biome in world_config.biome_map.biomes:
        if biome:
            for decoration in biome.get_decorations():
                tagged.append({
                    "decoration": decoration,
                    "splatmap_channel": biome.splatmap_channel,
                })
    return tagged
```

### Changes to `_generate_sample_transforms()`

Add `splatmap_channel: int` and `chunk_data: ChunkData` parameters. Before accepting each instance, sample the biome weight at that position:

```gdscript
# Sample biome weight at this position from chunk's biome_weights
var grid_x := int(local_x / cell_size)
var grid_z := int(local_z / cell_size)
var weight_idx := (grid_z * resolution + grid_x) * 4 + splatmap_channel
var biome_weight := chunk_data.biome_weights[weight_idx] if weight_idx < chunk_data.biome_weights.size() else 0.0

# Weighted spawn: only spawn if random roll passes biome strength
if _rng.randf() > biome_weight:
    continue
```

### Changes to spawning loop in `spawn_for_chunk()`

The main loop changes from iterating `decorations` (Array[DecorationDefinition]) to iterating tagged decorations (Array[Dictionary]), passing the splatmap channel through to the transform generation.

---

## 3. Decoration .tres Files

### Shared vs per-biome .tres files

When a decoration type appears in multiple biomes with different densities (e.g., Trees Standard at 0.003 in Plains, 0.015 in Forest), create separate .tres files:
- `trees_standard_sparse.tres` (density 0.003, for Plains)
- `trees_standard_dense.tres` (density 0.015, for Forest)

When density is the same across biomes, share one .tres file.

---

## 4. Files Summary

### Delete
- All existing `.tres` files in `addons/procedural_world/decorations/` (31 files from nature-kit)

### New decoration .tres files
| File | Description |
|---|---|
| `trees_standard_sparse.tres` | Trees for plains (density 0.003) |
| `trees_standard_dense.tres` | Trees for forest (density 0.015) |
| `trees_autumn.tres` | Autumn accent trees for forest |
| `tree_trunks_forest.tres` | Dead trunks for forest |
| `tree_trunks_mountain.tres` | Dead trunks for mountain |
| `rocks_standard.tres` | Rocks for mountain/forest |
| `rocks_flat.tres` | Flat rocks for plains/forest |
| `rocks_sandy.tres` | Sandy rocks for desert |
| `resource_stones.tres` | Boulder stones for mountain |
| `grass_patches.tres` | Grass for plains/forest (shared, high density) |
| `ground_patches.tres` | Ground cover for plains |
| `fallen_logs.tres` | Logs for forest |
| `resource_wood.tres` | Scattered wood for forest |
| `campfire_remains.tres` | Rare campfire in plains/forest |
| `signposts.tres` | Rare signpost in plains |
| `tents.tres` | Rare tent in plains |

### Modified files
| File | Changes |
|---|---|
| `addons/procedural_world/core/vegetation_spawner.gd` | `_get_decorations_for_chunk()` returns tagged decorations from all biomes; `_generate_sample_transforms()` adds biome weight sampling; `spawn_for_chunk()` loop updated |
| `world/biomes/plains.tres` | New decoration references |
| `world/biomes/forest.tres` | New decoration references |
| `world/biomes/desert.tres` | New decoration references |
| `world/biomes/mountain.tres` | New decoration references |
