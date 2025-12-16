@tool
extends Resource
class_name WorldConfig
## Configuration resource for procedural world generation.
## Contains all settings for terrain generation, LOD, and collision.

## Emitted when any configuration property changes (for editor preview refresh)
signal config_changed()

## World dimensions in chunks (e.g., 16x16 = 256 chunks total)
@export var world_size: Vector2i = Vector2i(16, 16):
	set(value):
		world_size = value
		emit_changed()
		config_changed.emit()

## Size of each chunk in world units
@export var chunk_size: float = 64.0:
	set(value):
		chunk_size = value
		emit_changed()
		config_changed.emit()

## Number of vertices per chunk side (should be 2^n + 1 for proper LOD, e.g., 33, 65, 129)
@export var chunk_resolution: int = 65:
	set(value):
		chunk_resolution = value
		emit_changed()
		config_changed.emit()

## Vertical scale multiplier for terrain height
@export var height_scale: float = 50.0:
	set(value):
		height_scale = value
		emit_changed()
		config_changed.emit()

## Number of chunks around player with physics collision enabled
@export var collision_radius: int = 2:
	set(value):
		collision_radius = value
		emit_changed()
		config_changed.emit()

## View distance in chunks (how far chunks are loaded)
@export var view_distance: int = 8:
	set(value):
		view_distance = value
		emit_changed()
		config_changed.emit()

## Distance thresholds for each LOD level (in world units)
@export var lod_distances: Array[float] = [100.0, 200.0, 400.0]:
	set(value):
		lod_distances = value
		emit_changed()
		config_changed.emit()

## Primary terrain noise generator
@export var noise: FastNoiseLite:
	set(value):
		if noise and noise.changed.is_connected(_on_noise_changed):
			noise.changed.disconnect(_on_noise_changed)
		noise = value
		if noise:
			noise.changed.connect(_on_noise_changed)
		emit_changed()
		config_changed.emit()

## Secondary noise for moisture/biome selection
@export var moisture_noise: FastNoiseLite:
	set(value):
		if moisture_noise and moisture_noise.changed.is_connected(_on_noise_changed):
			moisture_noise.changed.disconnect(_on_noise_changed)
		moisture_noise = value
		if moisture_noise:
			moisture_noise.changed.connect(_on_noise_changed)
		emit_changed()
		config_changed.emit()

## Terrain shader material
@export var terrain_material: ShaderMaterial:
	set(value):
		terrain_material = value
		emit_changed()
		config_changed.emit()

## Biome lookup table for terrain texturing and height modification
@export var biome_map: BiomeMap:
	set(value):
		biome_map = value
		emit_changed()
		config_changed.emit()


@export_group("Fog")

## Enable distance fog to hide terrain pop-in
@export var fog_enabled: bool = true:
	set(value):
		fog_enabled = value
		emit_changed()
		config_changed.emit()

## Fog color (blends with sky at distance)
@export var fog_light_color: Color = Color(0.7, 0.75, 0.85):
	set(value):
		fog_light_color = value
		emit_changed()
		config_changed.emit()

## Base fog density (auto-adjusted based on view distance)
@export_range(0.0, 0.1, 0.001) var fog_density: float = 0.01:
	set(value):
		fog_density = value
		emit_changed()
		config_changed.emit()

## How much fog affects the sky (0 = none, 1 = full)
@export_range(0.0, 1.0) var fog_sky_affect: float = 0.3:
	set(value):
		fog_sky_affect = value
		emit_changed()
		config_changed.emit()


## Returns calculated fog density based on view distance for proper fade
func get_auto_fog_density() -> float:
	var max_view_distance := view_distance * chunk_size
	# Density that makes fog nearly opaque at view distance
	# fog = 1 - exp(-density * distance), we want ~95% fog at max distance
	# 0.95 = 1 - exp(-d * dist) => d = -ln(0.05) / dist ≈ 3 / dist
	return 3.0 / max(max_view_distance, 100.0)


func _on_noise_changed() -> void:
	config_changed.emit()


## Returns the cell size (distance between vertices) based on chunk size and resolution
func get_cell_size() -> float:
	if chunk_resolution <= 1:
		return chunk_size
	return chunk_size / float(chunk_resolution - 1)


## Validates configuration and returns array of error messages (empty if valid)
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if world_size.x <= 0 or world_size.y <= 0:
		errors.append("World size must be positive in both dimensions")
	
	if chunk_size <= 0.0:
		errors.append("Chunk size must be positive")
	
	if chunk_resolution < 3:
		errors.append("Chunk resolution must be at least 3")
	
	if not noise:
		errors.append("Primary noise generator is required")
	
	return errors


## Creates a default noise configuration
static func create_default_noise() -> FastNoiseLite:
	var default_noise := FastNoiseLite.new()
	default_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	default_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	default_noise.fractal_octaves = 5
	default_noise.fractal_lacunarity = 2.0
	default_noise.fractal_gain = 0.5
	default_noise.frequency = 0.005
	return default_noise
