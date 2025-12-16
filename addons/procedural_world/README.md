# Procedural World Generation Addon

A modular, chunk-based procedural terrain generation system for Godot 4.x.

## Features

- **Chunk-based streaming** - Load/unload terrain chunks based on player position
- **LOD system** - Automatic level-of-detail using Godot's visibility ranges
- **Collision** - HeightMapShape3D collision within configurable radius
- **Triplanar shader** - Seamless terrain texturing without UV stretching
- **Editor preview** - See terrain directly in the editor viewport
- **Extensible biomes** - (Phase 2) Add custom biomes via Resources

## Quick Start

### 1. Enable the Plugin

Go to **Project > Project Settings > Plugins** and enable "Procedural World".

### 2. Create a WorldConfig

1. Create a new Resource of type `WorldConfig`
2. Configure the settings:
   - `world_size`: Number of chunks (e.g., 16x16)
   - `chunk_size`: World units per chunk (e.g., 64.0)
   - `chunk_resolution`: Vertices per side (e.g., 65)
   - `height_scale`: Vertical exaggeration (e.g., 50.0)
   - `noise`: Create a FastNoiseLite resource

### 3. Add ChunkManager to Scene

1. Add a `ChunkManager` node to your scene
2. Assign the `WorldConfig` resource
3. (Optional) Assign a terrain shader material
4. Enable `preview_enabled` to see terrain in editor

### 4. Runtime Setup

For runtime streaming:
1. Assign the `player` property to your player node
2. Configure `view_distance` in WorldConfig
3. Configure `collision_radius` for physics

## Configuration

### WorldConfig Properties

| Property | Type | Description |
|----------|------|-------------|
| `world_size` | Vector2i | World dimensions in chunks |
| `chunk_size` | float | Size of each chunk in world units |
| `chunk_resolution` | int | Vertices per chunk side (2^n + 1 recommended) |
| `height_scale` | float | Vertical scale multiplier |
| `collision_radius` | int | Chunks around player with collision |
| `view_distance` | int | Chunk loading distance |
| `lod_distances` | Array[float] | Distance thresholds for LOD levels |
| `noise` | FastNoiseLite | Primary terrain noise |
| `moisture_noise` | FastNoiseLite | Secondary noise for biomes |
| `terrain_material` | ShaderMaterial | Terrain rendering material |

### Recommended Noise Settings

```
noise_type: TYPE_SIMPLEX_SMOOTH
fractal_type: FRACTAL_FBM
fractal_octaves: 5
fractal_lacunarity: 2.0
fractal_gain: 0.5
frequency: 0.005
```

## Shader

The included `terrain_triplanar.gdshader` provides:

- Triplanar texture projection (no UV stretching on slopes)
- 4-texture splatmap blending (grass, rock, sand, snow)
- Procedural height-based snow
- Slope-based rock blending

### Shader Uniforms

| Uniform | Description |
|---------|-------------|
| `texture_grass` | Base grass texture |
| `texture_rock` | Rock/cliff texture |
| `texture_sand` | Sand/desert texture |
| `texture_snow` | Snow/peak texture |
| `texture_scale` | UV tiling scale |
| `snow_height` | Height where snow appears |
| `rock_slope_start/end` | Slope range for rock |

## Performance Tips

1. **Chunk resolution**: Use 33 or 65 for good balance
2. **LOD distances**: Set appropriate distances to reduce distant geometry
3. **Collision radius**: Keep at 2-3 to minimize physics overhead
4. **View distance**: Balance visual range vs chunk count

## API

### ChunkManager

```gdscript
# Signals
signal chunk_ready(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

# Methods
func coord_to_world(coord: Vector2i) -> Vector3
func world_to_coord(world_position: Vector3) -> Vector2i
func is_coord_valid(coord: Vector2i) -> bool
func get_chunk_at(world_position: Vector3) -> TerrainChunk
func regenerate() -> void
```

### TerrainChunk

```gdscript
# Methods
func enable_collision() -> void
func disable_collision() -> void
func has_collision() -> bool
func get_chunk_aabb() -> AABB
```

## Roadmap

- [x] Phase 1: Core terrain generation
- [ ] Phase 2: Biome system with splatmap blending
- [ ] Phase 3: Collision controller
- [ ] Phase 4: Async generation & vegetation

## License

MIT License - See project root for details.
