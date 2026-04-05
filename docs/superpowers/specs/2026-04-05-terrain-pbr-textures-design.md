# Terrain PBR Textures Design

## Goal

Replace flat procedural colors on terrain with stylized 1K PBR textures (albedo, normal, roughness) from free CC0 sources. Each biome gets its own texture set assigned per-chunk, so plains look different from forest floor, desert sand, and mountain rock.

## Approach: Per-chunk material instances with biome-specific textures

The existing triplanar shader already supports PBR texture uniforms for 4 splatmap channels — they're just empty. We populate them per chunk based on the dominant biome.

---

## 1. Texture Acquisition

**13 unique stylized/painterly texture sets** from AmbientCG or Polyhaven (CC0 licensed), 1K resolution. Each set contains albedo, normal, and roughness maps.

| Biome | R (Vegetation) | G (Rock) | B (Ground) |
|---|---|---|---|
| Plains | Bright meadow grass | Light limestone | Dry dirt/path |
| Forest | Dark mossy grass | Mossy rock | Forest floor/mulch |
| Desert | Dry scrub grass | Sandstone | Sand dunes |
| Mountain | Alpine grass | Dark granite | Gravel/scree |

**Shared across all biomes:**
- A (Snow): fresh snow — 1 set

**Total: 39 texture files** (~50-80MB on disk)

**File structure:**
```
assets/textures/terrain/
├── plains/
│   ├── grass_albedo.png, grass_normal.png, grass_roughness.png
│   ├── rock_albedo.png, rock_normal.png, rock_roughness.png
│   └── ground_albedo.png, ground_normal.png, ground_roughness.png
├── forest/
│   └── (same pattern)
├── desert/
│   └── (same pattern)
├── mountain/
│   └── (same pattern)
└── shared/
    └── snow_albedo.png, snow_normal.png, snow_roughness.png
```

**Style criteria:** Textures should be soft, low-contrast, painterly — complementing the stylized low-poly nature-kit models. Avoid photorealistic or high-frequency detail.

---

## 2. TerrainMaterialSet Resource

**New file:** `addons/procedural_world/core/terrain_material_set.gd`

A Resource that groups texture references for all 4 splatmap channels:

```
TerrainMaterialSet (Resource)
├── channel_r_albedo: Texture2D
├── channel_r_normal: Texture2D
├── channel_r_roughness: Texture2D
├── channel_g_albedo: Texture2D
├── channel_g_normal: Texture2D
├── channel_g_roughness: Texture2D
├── channel_b_albedo: Texture2D
├── channel_b_normal: Texture2D
├── channel_b_roughness: Texture2D
├── channel_a_albedo: Texture2D
├── channel_a_normal: Texture2D
├── channel_a_roughness: Texture2D
```

Each biome gets a `.tres` instance of this resource. The A channel (snow) is the same across all sets.

---

## 3. BiomeData Integration

**Modified file:** `addons/procedural_world/core/biomes/biome_data.gd`

Add one new export:

```gdscript
@export var terrain_materials: TerrainMaterialSet
```

Each biome `.tres` (plains.tres, forest.tres, desert.tres, mountain.tres) references its TerrainMaterialSet.

---

## 4. Dominant Biome Detection

**Modified file:** `addons/procedural_world/core/chunk_generator.gd`

New static method:

```
ChunkGenerator.get_dominant_biome(chunk_data: ChunkData, biome_map: BiomeMap) -> BiomeData
```

Sums biome_weights across all vertices per channel (R, G, B, A). The channel with the highest total determines the dominant biome. Looks up the corresponding BiomeData from the BiomeMap.

This is called by ChunkManager after chunk generation, before initializing the TerrainChunk.

---

## 5. Per-Chunk Texture Assignment

**Modified file:** `addons/procedural_world/core/terrain_chunk.gd`

`TerrainChunk.initialize()` already duplicates the base material and assigns the splatmap texture. Extended to also accept a `TerrainMaterialSet` and assign its textures to the material's shader uniforms:

```
texture_r_albedo = material_set.channel_r_albedo
texture_r_normal = material_set.channel_r_normal
texture_r_roughness = material_set.channel_r_roughness
... (same for G, B, A channels)
```

If no material set is provided (null), the shader falls back to procedural colors as it does today.

**Modified file:** `addons/procedural_world/core/chunk_manager.gd`

In `_generate_and_apply_chunk()`, after getting the chunk data:
1. Call `ChunkGenerator.get_dominant_biome()` to find the dominant biome
2. Get `terrain_materials` from the dominant biome
3. Pass it to `TerrainChunk.initialize()`

---

## 6. Shared Snow on Base Material

**Modified file:** `world/terrain_material.tres`

The shared snow textures are assigned directly to the base `terrain_material.tres` on the A channel uniforms. Since all per-chunk material instances are duplicated from this base, every chunk inherits the snow textures without per-chunk assignment.

Per-biome material sets still define A channel textures (pointing to the same shared snow), but the base material acts as the fallback.

---

## 7. Shader Changes

**None.** The existing `terrain_triplanar.gdshader` already has all required uniform slots and falls back to procedural colors when textures are unassigned.

---

## 8. Files Summary

### New files
| File | Purpose |
|---|---|
| `addons/procedural_world/core/terrain_material_set.gd` | TerrainMaterialSet resource class |
| `assets/textures/terrain/plains/*.png` | 9 texture files (3 channels x 3 maps) |
| `assets/textures/terrain/forest/*.png` | 9 texture files |
| `assets/textures/terrain/desert/*.png` | 9 texture files |
| `assets/textures/terrain/mountain/*.png` | 9 texture files |
| `assets/textures/terrain/shared/*.png` | 3 texture files (snow) |
| `world/materials/plains_terrain.tres` | Plains TerrainMaterialSet |
| `world/materials/forest_terrain.tres` | Forest TerrainMaterialSet |
| `world/materials/desert_terrain.tres` | Desert TerrainMaterialSet |
| `world/materials/mountain_terrain.tres` | Mountain TerrainMaterialSet |

### Modified files
| File | Changes |
|---|---|
| `addons/procedural_world/core/biomes/biome_data.gd` | Add `terrain_materials: TerrainMaterialSet` export |
| `addons/procedural_world/core/chunk_generator.gd` | Add `get_dominant_biome()` static method |
| `addons/procedural_world/core/chunk_manager.gd` | Determine dominant biome, pass material set to chunk |
| `addons/procedural_world/core/terrain_chunk.gd` | Apply material set textures during `initialize()` |
| `world/biomes/plains.tres` | Reference plains_terrain material set |
| `world/biomes/forest.tres` | Reference forest_terrain material set |
| `world/biomes/desert.tres` | Reference desert_terrain material set |
| `world/biomes/mountain.tres` | Reference mountain_terrain material set |
| `world/terrain_material.tres` | Assign shared snow textures to A channel |
