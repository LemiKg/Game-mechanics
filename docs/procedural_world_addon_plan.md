# Procedural World Generation Addon - Development Plan

## Overview

A modular, chunk-based procedural terrain generation addon for Godot 4.x. Designed for performance, extensibility, and clean architecture following SOLID principles.

**Key Features:**
- Chunk-based world streaming with configurable bounds
- LOD system using Godot's visibility ranges + pre-generated mesh LODs
- HeightMapShape3D collision within player radius
- Extensible biome system with priority-based lookup
- Triplanar splatmap shader for seamless terrain texturing
- `@tool` support for editor preview
- Async-ready architecture (synchronous first, threading phase 2)
- Vegetation spawner stub for future MultiMesh-based foliage

---

## Architecture Decisions

### World Limits
- **Finite world** using `Vector2i` chunk coordinates
- World size configurable via `WorldConfig.world_size: Vector2i`
- No floating-point origin issues (no infinite world support)
- Bounds enforced by `ChunkManager.is_coord_valid()`

### LOD Strategy
- **Godot visibility ranges** (`visibility_range_begin/end`) for automatic mesh swapping
- Pre-generated LOD meshes at 1/2, 1/4, 1/8 resolution stored in `ChunkData`
- Each `TerrainChunk` contains multiple `MeshInstance3D` children, one per LOD level
- Fade mode `VISIBILITY_RANGE_FADE_SELF` for smooth transitions (Forward+ only)

### Collision Strategy
- **HeightMapShape3D** for efficient terrain collision
- Collision enabled only within configurable radius (2-3 chunks) around player
- `CollisionController` manages enable/disable based on player chunk coordinate
- Collision data generated alongside mesh data for consistency

### Biome Extensibility
- Abstract `BiomeData` Resource with virtual `matches()` method
- Priority-sorted lookup in `BiomeMap`
- New biomes added by:
  1. Creating new Resource extending `BiomeData`
  2. Overriding `matches()` and optionally `modify_height()`
  3. Adding to `BiomeMap.biomes` array
- **No code modification required** in existing classes (Open/Closed Principle)

### Threading Strategy
- **Phase 1**: Synchronous generation with async-ready interfaces
- **Phase 2**: `Thread` + `Mutex` pattern for background generation
- All scene tree modifications via `call_deferred()` on main thread
- Stateless generators (`HeightGenerator`, `TerrainMeshBuilder`) safe for threading

### Editor Preview
- `@tool` annotations on `ChunkManager` and `TerrainChunk`
- Preview chunks generated around `Vector3.ZERO` in editor
- `Engine.is_editor_hint()` guards for runtime vs editor behavior
- Regeneration triggered by `WorldConfig` property changes

---

## File Structure

```
addons/procedural_world/
├── plugin.cfg                          # Addon metadata
├── world_generation_plugin.gd          # EditorPlugin - type registration
├── README.md                           # User documentation
│
├── core/
│   │
│   │  ══════════════════════════════════
│   │  CONFIGURATION RESOURCES
│   │  ══════════════════════════════════
│   │
│   ├── world_config.gd                 # WorldConfig Resource
│   │   - world_size: Vector2i          # World bounds in chunks
│   │   - chunk_size: float             # World units per chunk (e.g., 64.0)
│   │   - chunk_resolution: int         # Vertices per chunk side (e.g., 65)
│   │   - height_scale: float           # Vertical exaggeration
│   │   - collision_radius: int         # Chunks around player with collision
│   │   - view_distance: int            # How far chunks are loaded
│   │   - lod_distances: Array[float]   # Distance thresholds for LOD levels
│   │   - noise: FastNoiseLite          # Primary terrain noise
│   │   - moisture_noise: FastNoiseLite # Secondary noise for biome selection
│   │   - terrain_material: ShaderMaterial
│   │   - fog_enabled: bool             # Toggle distance fog
│   │   - fog_light_color: Color        # Fog color
│   │   - fog_density: float            # Base fog density
│   │   - fog_sky_affect: float         # Sky blend amount
│   │   + get_auto_fog_density() -> float  # Calculate optimal density
│   │   - biome_map: BiomeMap           # Biome lookup table (Phase 2)
│   │   - terrain_material: ShaderMaterial
│   │
│   ├── chunk_data.gd                   # ChunkData Resource
│   │   - coord: Vector2i
│   │   - height_data: PackedFloat32Array
│   │   - moisture_data: PackedFloat32Array
│   │   - biome_weights: PackedFloat32Array  # RGBA weights for splatmap
│   │   - mesh_lods: Array[ArrayMesh]   # Pre-generated LOD meshes
│   │   - state: GenerationState        # PENDING, GENERATING, READY
│   │
│   ├── biome_data.gd                   # BiomeData Resource (ABSTRACT)
│   │   - biome_name: String
│   │   - priority: int                 # Higher = checked first
│   │   - splatmap_channel: int         # 0=R, 1=G, 2=B, 3=A
│   │   - terrain_color: Color          # For debug/minimap
│   │   + matches(elevation, moisture, temperature) -> bool  # VIRTUAL
│   │   + modify_height(base_height, world_x, world_z) -> float  # VIRTUAL
│   │   + get_decorations() -> Array[DecorationDefinition]  # VIRTUAL
│   │
│   ├── biome_map.gd                    # BiomeMap Resource
│   │   - biomes: Array[BiomeData]
│   │   - fallback_biome: BiomeData
│   │   + get_biome(elevation, moisture, temperature) -> BiomeData
│   │   + get_biome_weights(elevation, moisture) -> Color  # For blending
│   │
│   ├── decoration_definition.gd        # DecorationDefinition Resource
│   │   - mesh: Mesh
│   │   - density: float                # Instances per unit area
│   │   - min_scale: float
│   │   - max_scale: float
│   │   - min_slope: float              # Radians
│   │   - max_slope: float
│   │   - align_to_normal: bool
│   │
│   │  ══════════════════════════════════
│   │  GENERATION LAYER (Thread-Safe)
│   │  ══════════════════════════════════
│   │
│   ├── height_generator.gd             # HeightGenerator (Stateless Utility)
│   │   + generate_height_data(coord, config) -> PackedFloat32Array
│   │   + generate_moisture_data(coord, config) -> PackedFloat32Array
│   │   + sample_height(world_x, world_z, config) -> float
│   │   + sample_moisture(world_x, world_z, config) -> float
│   │
│   ├── terrain_mesh_builder.gd         # TerrainMeshBuilder (Stateless Utility)
│   │   + build_mesh(heights, width, depth, cell_size) -> ArrayMesh
│   │   + build_lod_meshes(heights, width, depth, cell_size, lod_levels) -> Array[ArrayMesh]
│   │   + calculate_normals(vertices, indices) -> PackedVector3Array
│   │
│   ├── async_generation_handler.gd     # AsyncGenerationHandler
│   │   - generation_queue: Array[Vector2i]
│   │   - pending_results: Dictionary
│   │   + request_chunk(coord: Vector2i) -> void
│   │   + cancel_request(coord: Vector2i) -> void
│   │   + signal chunk_generated(coord: Vector2i, data: ChunkData)
│   │   # Phase 1: Synchronous implementation
│   │   # Phase 2: Thread pool with Mutex
│   │
│   │  ══════════════════════════════════
│   │  RUNTIME NODES
│   │  ══════════════════════════════════
│   │
│   ├── chunk_manager.gd                # ChunkManager (Node) [@tool]
│   │   @export var world_config: WorldConfig
│   │   @export var player: Node3D
│   │   @export var preview_enabled: bool  # Editor preview toggle
│   │   - active_chunks: Dictionary[Vector2i, TerrainChunk]
│   │   - chunk_pool: Array[TerrainChunk]
│   │   - height_generator: HeightGenerator
│   │   - mesh_builder: TerrainMeshBuilder
│   │   - async_handler: AsyncGenerationHandler
│   │   + get_chunk_at(world_position: Vector3) -> TerrainChunk
│   │   + coord_to_world(coord: Vector2i) -> Vector3
│   │   + world_to_coord(world_position: Vector3) -> Vector2i
│   │   + is_coord_valid(coord: Vector2i) -> bool
│   │   + signal chunk_ready(coord: Vector2i)
│   │   + signal chunk_unloaded(coord: Vector2i)
│   │
│   ├── terrain_chunk.gd                # TerrainChunk (Node3D) [@tool]
│   │   @export var chunk_data: ChunkData
│   │   - lod_mesh_instances: Array[MeshInstance3D]
│   │   - collision_body: StaticBody3D
│   │   - collision_shape: CollisionShape3D
│   │   - has_collision: bool
│   │   + initialize(data: ChunkData, material: ShaderMaterial) -> void
│   │   + set_lod_distances(distances: Array[float]) -> void
│   │   + enable_collision() -> void
│   │   + disable_collision() -> void
│   │   + reset() -> void  # For pool reuse
│   │   + signal chunk_loaded(coord: Vector2i)
│   │
│   ├── collision_controller.gd         # CollisionController (Node)
│   │   @export var chunk_manager: ChunkManager
│   │   @export var player: Node3D
│   │   @export var collision_radius: int = 2
│   │   - chunks_with_collision: Array[Vector2i]
│   │   + _on_player_chunk_changed(old_coord, new_coord) -> void
│   │
│   ├── vegetation_spawner.gd           # VegetationSpawner (Node) [STUB]
│   │   @export var chunk_manager: ChunkManager
│   │   - multimesh_instances: Dictionary[Vector2i, MultiMeshInstance3D]
│   │   + spawn_for_chunk(chunk: TerrainChunk, biome: BiomeData) -> void
│   │   + clear_chunk(coord: Vector2i) -> void
│   │   # Phase 1: Empty implementation
│   │   # Phase 4: MultiMesh + Poisson disk sampling
│   │
│   │  ══════════════════════════════════
│   │  BIOME IMPLEMENTATIONS
│   │  ══════════════════════════════════
│   │
│   └── biomes/
│       ├── plains_biome.gd             # PlainsBiome extends BiomeData
│       │   - min_elevation: 0.2
│       │   - max_elevation: 0.4
│       │   - min_moisture: 0.3
│       │   - splatmap_channel: 0 (R = grass)
│       │
│       ├── forest_biome.gd             # ForestBiome extends BiomeData
│       │   - min_elevation: 0.3
│       │   - max_elevation: 0.6
│       │   - min_moisture: 0.5
│       │   - splatmap_channel: 0 (R = grass)
│       │   + modify_height() -> adds rolling hills
│       │
│       ├── mountain_biome.gd           # MountainBiome extends BiomeData
│       │   - min_elevation: 0.6
│       │   - splatmap_channel: 1 (G = rock)
│       │   + modify_height() -> adds ridged noise
│       │
│       └── desert_biome.gd             # DesertBiome extends BiomeData
│           - max_moisture: 0.3
│           - splatmap_channel: 2 (B = sand)
│           + modify_height() -> adds dune patterns
│
├── shaders/
│   └── terrain_triplanar.gdshader      # Triplanar splatmap terrain shader
│       - texture_grass, texture_rock, texture_sand, texture_snow
│       - color_grass, color_rock, color_sand, color_snow (procedural fallbacks)
│       - use_textures: bool            # Toggle texture vs color mode
│       - splatmap uniform (from biome weights)
│       - triplanar projection to avoid UV stretching
│       - height-based snow override
│       - slope-based rock blending
│
├── ui/
│   ├── debug_overlay_ui.gd             # DebugOverlayUI (CanvasLayer)
│   │   @export var chunk_manager: ChunkManager
│   │   @export var toggle_action: String  # Custom input action (default F3)
│   │   @export var update_interval: float # Stats refresh rate
│   │   @export var show_memory: bool      # Toggle memory stats
│   │   - Displays: FPS, frame time, chunks, pool, collision, memory, draw calls
│   │
│   └── debug_overlay_ui.tscn           # Scene for easy instancing
│
└── icons/
    ├── world.svg                       # Icon for WorldConfig, ChunkManager
    ├── chunk.svg                       # Icon for ChunkData, TerrainChunk
    └── biome.svg                       # Icon for BiomeData, BiomeMap
```

---

## Class Diagrams

### Resource Hierarchy

```
Resource
├── WorldConfig
├── ChunkData
├── BiomeMap
├── DecorationDefinition
└── BiomeData (abstract)
    ├── PlainsBiome
    ├── ForestBiome
    ├── MountainBiome
    └── DesertBiome
```

### Node Hierarchy (Runtime)

```
WorldGenerator (Node3D)
├── ChunkManager (Node)
│   ├── TerrainChunk (Node3D) [pooled]
│   │   ├── LOD0_MeshInstance (MeshInstance3D)
│   │   ├── LOD1_MeshInstance (MeshInstance3D)
│   │   ├── LOD2_MeshInstance (MeshInstance3D)
│   │   └── CollisionBody (StaticBody3D)
│   │       └── CollisionShape (CollisionShape3D)
│   ├── TerrainChunk ...
│   └── TerrainChunk ...
├── CollisionController (Node)
└── VegetationSpawner (Node)
    └── MultiMeshInstance3D [per chunk, phase 4]
```

---

## Signal Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                           CHUNK LIFECYCLE                           │
└─────────────────────────────────────────────────────────────────────┘

Player moves
    │
    ▼
ChunkManager._process()
    │
    ├─► Calculate visible chunk coordinates
    │
    ├─► For chunks entering view:
    │       │
    │       ▼
    │   AsyncGenerationHandler.request_chunk(coord)
    │       │
    │       ▼ (Phase 1: sync, Phase 2: threaded)
    │   HeightGenerator.generate_height_data()
    │   TerrainMeshBuilder.build_lod_meshes()
    │       │
    │       ▼
    │   AsyncGenerationHandler.chunk_generated.emit(coord, data)
    │       │
    │       ▼
    │   ChunkManager._on_chunk_generated()
    │       │
    │       ├─► Get TerrainChunk from pool (or create)
    │       ├─► TerrainChunk.initialize(data)
    │       ├─► Add to active_chunks
    │       │
    │       ▼
    │   ChunkManager.chunk_ready.emit(coord)
    │       │
    │       ├─► CollisionController._on_chunk_ready()
    │       │       └─► enable_collision() if within radius
    │       │
    │       └─► VegetationSpawner._on_chunk_ready()
    │               └─► spawn_for_chunk() [Phase 4]
    │
    └─► For chunks leaving view:
            │
            ▼
        TerrainChunk.reset()
        Return to chunk_pool
            │
            ▼
        ChunkManager.chunk_unloaded.emit(coord)
            │
            ├─► CollisionController._on_chunk_unloaded()
            │       └─► disable_collision()
            │
            └─► VegetationSpawner._on_chunk_unloaded()
                    └─► clear_chunk()
```

---

## Implementation Phases

### Phase 1: Core Terrain System ✅ COMPLETE
**Goal:** Basic terrain generation with editor preview

| Task | File | Priority | Status |
|------|------|----------|--------|
| Create addon scaffolding | `plugin.cfg`, `world_generation_plugin.gd` | 1 | ✅ |
| Implement WorldConfig | `core/world_config.gd` | 2 | ✅ |
| Implement HeightGenerator | `core/height_generator.gd` | 3 | ✅ |
| Implement TerrainMeshBuilder | `core/terrain_mesh_builder.gd` | 4 | ✅ |
| Implement ChunkData | `core/chunk_data.gd` | 5 | ✅ |
| Implement TerrainChunk (with LOD) | `core/terrain_chunk.gd` | 6 | ✅ |
| Implement ChunkManager (basic) | `core/chunk_manager.gd` | 7 | ✅ |
| Add `@tool` editor preview | `chunk_manager.gd`, `terrain_chunk.gd` | 8 | ✅ |
| Create basic terrain shader | `shaders/terrain_triplanar.gdshader` | 9 | ✅ |
| Create placeholder icons | `icons/*.svg` | 10 | ✅ |
| Write README | `README.md` | 11 | ✅ |

**Deliverable:** Single-chunk terrain visible in editor, regenerates on config change.

---

### Phase 1.5: Runtime Polish ✅ COMPLETE
**Goal:** Runtime collision, player streaming, debug tools, visual polish

| Task | File | Priority | Status |
|------|------|----------|--------|
| Auto-detect player via "player" group | `core/chunk_manager.gd` | 1 | ✅ |
| Enable collision within radius at runtime | `core/chunk_manager.gd` | 2 | ✅ |
| Fix LOD visibility range configuration | `core/terrain_chunk.gd` | 3 | ✅ |
| Fix mesh winding order for correct normals | `core/terrain_mesh_builder.gd` | 4 | ✅ |
| Create FPS debug overlay (F3 toggle) | `ui/debug_overlay_ui.gd` | 5 | ✅ |
| Add chunk stats (active/pooled/collision) | `core/chunk_manager.gd` | 6 | ✅ |
| Add fog settings to WorldConfig | `core/world_config.gd` | 7 | ✅ |
| Configure distance fog in scene | `scenes/procedural.tscn` | 8 | ✅ |
| Create procedural color shader fallback | `shaders/terrain_triplanar.gdshader` | 9 | ✅ |
| Create terrain material resource | `world/terrain_material.tres` | 10 | ✅ |
| Create world environment with fog | `world/world_environment.tres` | 11 | ✅ |
| Create reusable player scene | `scenes/player.tscn` | 12 | ✅ |
| Register DebugOverlayUI type | `world_generation_plugin.gd` | 13 | ✅ |

**Deliverable:** Walkable terrain with debug overlay, distance fog, procedural colors.

---

### Phase 2: Biomes + Splatmap Blending ✅ COMPLETE
**Goal:** Multiple biomes with smooth blending

| Task | File | Priority | Status |
|------|------|----------|--------|
| Implement BiomeData (abstract) | `core/biome_data.gd` | 1 | ✅ |
| Implement BiomeMap | `core/biome_map.gd` | 2 | ✅ |
| Create PlainsBiome | `core/biomes/plains_biome.gd` | 3 | ✅ |
| Create ForestBiome | `core/biomes/forest_biome.gd` | 4 | ✅ |
| Create MountainBiome | `core/biomes/mountain_biome.gd` | 5 | ✅ |
| Create DesertBiome | `core/biomes/desert_biome.gd` | 6 | ✅ |
| Add biome weight calculation | `core/chunk_manager.gd` | 7 | ✅ |
| Implement splatmap texture generation | `core/terrain_mesh_builder.gd` | 8 | ✅ |
| Enable splatmap blending in shader | `shaders/terrain_triplanar.gdshader` | 9 | ✅ |
| Update WorldConfig for biomes | `core/world_config.gd` | 10 | ✅ |
| Register biome types in plugin | `world_generation_plugin.gd` | 11 | ✅ |
| Create default biome resources | `world/biomes/*.tres` | 12 | ✅ |
| Blended height modifications | `core/chunk_manager.gd` | 13 | ✅ |
| Height-based snow in shader | `shaders/terrain_triplanar.gdshader` | 14 | ✅ |

**Deliverable:** Multiple chunks with different biomes, smooth blending at borders.

**Implementation Notes:**
- Biomes define elevation/moisture ranges with `matches()` and `get_match_strength()` for blending
- Height modifications are blended across all matching biomes (prevents cliff discontinuities)
- Per-chunk material duplication for unique splatmap textures
- Snow automatically applied at high elevations via shader (configurable `snow_height`)
- Default biome resources in `world/biomes/` with tuned thresholds:
  - Plains: elevation 0.0-0.7, moisture 0.2-0.8
  - Forest: elevation 0.15-0.8, moisture 0.45-1.0
  - Desert: elevation 0.0-0.7, moisture 0.0-0.4
  - Mountain: elevation 0.65-1.0, any moisture

---

### Phase 3: Collision Controller Refinement ✅ MOSTLY COMPLETE
**Goal:** Player can walk on terrain, chunks load/unload around player

| Task | File | Priority | Status |
|------|------|----------|--------|
| Add HeightMapShape3D to TerrainChunk | `core/terrain_chunk.gd` | 1 | ✅ |
| Implement chunk pooling | `core/chunk_manager.gd` | 2 | ✅ |
| Add player tracking | `core/chunk_manager.gd` | 3 | ✅ |
| Implement view distance culling | `core/chunk_manager.gd` | 4 | ✅ |
| Collision enable/disable by radius | `core/chunk_manager.gd` | 5 | ✅ |
| Extract CollisionController (optional) | `core/collision_controller.gd` | 6 | (inline in ChunkManager) |
| Add chunk load priority (distance) | `core/chunk_manager.gd` | 7 | |
| Test with CharacterBody3D | test scene | 8 | ✅ |

**Deliverable:** Walkable terrain with chunks streaming in/out as player moves.

**Status:** ✅ Core functionality complete. Player can walk on terrain, chunks stream around player.

---

### Phase 4: Async Generation + Vegetation ✅ COMPLETE
**Goal:** Smooth loading without frame drops, basic vegetation

| Task | File | Priority | Status |
|------|------|----------|--------|
| Implement AsyncGenerationHandler | `core/async_generation_handler.gd` | 1 | ✅ |
| Add Thread + Mutex pattern | `core/async_generation_handler.gd` | 2 | ✅ |
| Implement thread-safe generation | `height_generator.gd`, `terrain_mesh_builder.gd` | 3 | ✅ (already stateless) |
| Add call_deferred mesh application | `core/chunk_manager.gd` | 4 | ✅ |
| Implement DecorationDefinition | `core/decoration_definition.gd` | 5 | ✅ |
| Implement DecorationMeshBuilder | `core/decoration_mesh_builder.gd` | 6 | ✅ |
| Implement VegetationSpawner | `core/vegetation_spawner.gd` | 7 | ✅ |
| Add MultiMesh instancing | `core/vegetation_spawner.gd` | 8 | ✅ |
| Implement jittered grid sampling | `core/vegetation_spawner.gd` | 9 | ✅ |
| Add biome-specific decorations | `world/biomes/*.tres` | 10 | ✅ |
| Create placeholder meshes/materials | `meshes/*.tres` | 11 | ✅ |
| Register new types in plugin | `world_generation_plugin.gd` | 12 | ✅ |

**Deliverable:** Lag-free chunk loading, trees/rocks in appropriate biomes.

**Implementation Notes:**
- Single worker thread with Mutex for queue access
- `call_deferred()` used for all scene tree modifications
- Jittered grid placement (simpler than Poisson disk, good visual results)
- Procedural placeholder meshes via `DecorationMeshBuilder` (tree, rock, bush)
- Per-chunk MultiMeshInstance3D for efficient instancing
- Slope filtering and normal alignment support
- Forest biome: trees + bushes; Mountain biome: rocks

---

## API Reference

### WorldConfig

```gdscript
@tool
extends Resource
class_name WorldConfig

## World dimensions in chunks
@export var world_size: Vector2i = Vector2i(16, 16)

## Size of each chunk in world units
@export var chunk_size: float = 64.0

## Number of vertices per chunk side (must be 2^n + 1 for LOD)
@export var chunk_resolution: int = 65

## Vertical scale multiplier
@export var height_scale: float = 50.0

## Number of chunks around player with collision
@export var collision_radius: int = 2

## View distance in chunks
@export var view_distance: int = 8

## Distance thresholds for each LOD level
@export var lod_distances: Array[float] = [100.0, 200.0, 400.0]

## Primary terrain noise
@export var noise: FastNoiseLite

## Moisture noise for biome selection
@export var moisture_noise: FastNoiseLite

## Biome lookup table
@export var biome_map: BiomeMap

## Terrain shader material
@export var terrain_material: ShaderMaterial
```

### BiomeData (Abstract)

```gdscript
@tool
extends Resource
class_name BiomeData

## Display name
@export var biome_name: String = "Unknown"

## Higher priority biomes are checked first
@export var priority: int = 0

## Splatmap channel (0=R, 1=G, 2=B, 3=A)
@export var splatmap_channel: int = 0

## Debug/minimap color
@export var terrain_color: Color = Color.WHITE

## Decorations to spawn in this biome
@export var decorations: Array[DecorationDefinition] = []

## Override to define biome selection criteria
func matches(elevation: float, moisture: float, temperature: float = 0.5) -> bool:
    push_error("BiomeData.matches() is abstract - override in subclass")
    return false

## Override to modify terrain height for biome-specific features
func modify_height(base_height: float, world_x: float, world_z: float) -> float:
    return base_height

## Override for custom decoration logic
func get_decorations() -> Array[DecorationDefinition]:
    return decorations
```

### ChunkManager

```gdscript
@tool
extends Node
class_name ChunkManager

signal chunk_ready(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)
signal generation_progress(completed: int, total: int)

@export var world_config: WorldConfig
@export var player: Node3D
@export var preview_enabled: bool = true  ## Editor preview toggle

## Returns the chunk at a world position, or null
func get_chunk_at(world_position: Vector3) -> TerrainChunk

## Converts chunk coordinate to world position (chunk center)
func coord_to_world(coord: Vector2i) -> Vector3

## Converts world position to chunk coordinate
func world_to_coord(world_position: Vector3) -> Vector2i

## Returns true if coordinate is within world bounds
func is_coord_valid(coord: Vector2i) -> bool

## Force regeneration of all visible chunks
func regenerate() -> void
```

### TerrainChunk

```gdscript
@tool
extends Node3D
class_name TerrainChunk

signal chunk_loaded(coord: Vector2i)

@export var chunk_data: ChunkData

## Initialize chunk with generated data
func initialize(data: ChunkData, material: ShaderMaterial) -> void

## Configure LOD transition distances
func set_lod_distances(distances: Array[float]) -> void

## Enable HeightMapShape3D collision
func enable_collision() -> void

## Disable collision (chunk leaving player radius)
func disable_collision() -> void

## Reset for pool reuse
func reset() -> void
```

---

## Shader Uniforms

### terrain_triplanar.gdshader

| Uniform | Type | Description |
|---------|------|-------------|
| `texture_grass` | sampler2D | Grass/plains texture |
| `texture_rock` | sampler2D | Rock/cliff texture |
| `texture_sand` | sampler2D | Sand/desert texture |
| `texture_snow` | sampler2D | Snow/peak texture |
| `splatmap` | sampler2D | RGBA blend weights per vertex |
| `texture_scale` | float | UV tiling (default: 0.1) |
| `triplanar_sharpness` | float | Blend sharpness (default: 4.0) |
| `snow_height` | float | Height for snow override |
| `snow_blend` | float | Snow blend range |
| `slope_rock_threshold` | float | Slope angle for rock blend |

---

## Performance Considerations

### Chunk Resolution
- **65 vertices** per side = 64x64 quads = 8,192 triangles per chunk
- At 100 visible chunks = 819,200 triangles (manageable)
- LOD reduces distant chunk triangle count by 75% per level

### Memory Budget (Estimated)
| Data | Size per Chunk | 100 Chunks |
|------|----------------|------------|
| Height data (65x65 floats) | 16.9 KB | 1.7 MB |
| Mesh (LOD0 + LOD1 + LOD2) | ~500 KB | 50 MB |
| Collision shape | ~17 KB | 1.7 MB |
| **Total** | ~534 KB | **53 MB** |

### Optimization Strategies
1. **Chunk pooling** - Reuse TerrainChunk nodes instead of freeing
2. **Deferred collision** - Only create HeightMapShape3D when needed
3. **LOD mesh caching** - Store in ChunkData Resource
4. **Frustum culling** - Automatic via Godot's VisualServer
5. **Background generation** - Thread pool (Phase 4)

---

## Testing Checklist

### Phase 1 Tests
- [ ] Addon appears in Project Settings > Plugins
- [ ] WorldConfig creates with default values
- [ ] Single chunk generates in editor with preview_enabled
- [ ] Chunk regenerates when WorldConfig.noise changes
- [ ] Terrain shader displays basic color

### Phase 2 Tests
- [ ] BiomeData subclasses match expected elevation/moisture
- [ ] BiomeMap returns correct biome at sample points
- [ ] Splatmap shows biome transitions
- [ ] LOD meshes visible at configured distances
- [ ] No popping during LOD transitions

### Phase 3 Tests
- [ ] CharacterBody3D can walk on terrain
- [ ] Collision enables/disables based on distance
- [ ] Chunks unload outside view distance
- [ ] Chunk pool reuses nodes correctly
- [ ] No memory leaks after extended play

### Phase 4 Tests
- [ ] No frame drops during chunk generation
- [ ] Chunks load in priority order (closest first)
- [ ] Vegetation appears in appropriate biomes
- [ ] MultiMesh instances cull correctly
- [ ] Thread cleanup on scene exit

---

## Future Enhancements (Post-MVP)

1. **Water System** - Water plane with shoreline detection
2. **Cave Generation** - 3D noise for underground spaces
3. **Roads/Paths** - Spline-based path generation
4. **Structures** - Point-of-interest placement
5. **Serialization** - Save/load modified chunks
6. **Minimap** - Biome-colored overview map
7. **Runtime Biome Editing** - In-game world painting

---

## References

- [Godot FastNoiseLite Documentation](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html)
- [Red Blob Games - Terrain from Noise](https://www.redblobgames.com/maps/terrain-from-noise/)
- [Godot ArrayMesh Tutorial](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/arraymesh.html)
- [Godot Visibility Ranges](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html)
- [GDC - No Man's Sky Procedural Generation](https://www.youtube.com/watch?v=sCRzxEEcO2Y)

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-16 | 0.1.0 | Initial plan created |
| 2025-12-16 | 0.2.0 | Phase 1 implementation complete - Core terrain with editor preview, LOD, triplanar shader |
| 2025-12-16 | 0.3.0 | Phase 2 implementation complete - Biome system with BiomeData, BiomeMap, 4 biome types, splatmap blending |
| 2025-12-16 | 0.3.1 | Added blended height modifications to prevent biome boundary cliffs |
| 2025-12-16 | 0.3.2 | Added height-based snow to shader, tuned biome thresholds for balanced distribution |
| 2025-12-16 | 0.4.0 | Phase 4 implementation complete - AsyncGenerationHandler with Thread+Mutex, VegetationSpawner with MultiMesh+jittered grid, DecorationDefinition resources, procedural placeholder meshes |
