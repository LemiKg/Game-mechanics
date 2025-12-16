@tool
extends Resource
class_name BiomeData
## Abstract base class for biome definitions.
## Extend this class to create custom biomes with unique terrain characteristics.
##
## Each biome defines:
## - Selection criteria (elevation, moisture thresholds)
## - Splatmap blending channel (R, G, B, or A)
## - Optional height modification for terrain shaping
## - Decoration definitions for vegetation/props (Phase 4)

## Display name for the biome
@export var biome_name: String = "Unknown"

## Higher priority biomes are checked first during selection.
## Use this to create specific biomes that override general ones.
@export var priority: int = 0

## Splatmap channel for this biome's texture (0=R, 1=G, 2=B, 3=A)
## Multiple biomes can share a channel if they use the same texture.
@export_range(0, 3) var splatmap_channel: int = 0

## Debug/minimap color for visualization
@export var terrain_color: Color = Color.WHITE

## Minimum elevation (0-1 normalized) for this biome
@export_range(0.0, 1.0) var min_elevation: float = 0.0

## Maximum elevation (0-1 normalized) for this biome
@export_range(0.0, 1.0) var max_elevation: float = 1.0

## Minimum moisture (0-1 normalized) for this biome
@export_range(0.0, 1.0) var min_moisture: float = 0.0

## Maximum moisture (0-1 normalized) for this biome
@export_range(0.0, 1.0) var max_moisture: float = 1.0

## Decorations to spawn in this biome (used by VegetationSpawner)
@export var decorations: Array[DecorationDefinition] = []


## Check if this biome matches the given environmental conditions.
## Override in subclasses for custom selection logic.
## @param elevation Normalized terrain height (0-1)
## @param moisture Normalized moisture value (0-1)
## @param temperature Normalized temperature value (0-1), unused in base implementation
## @return True if this biome should be selected
func matches(elevation: float, moisture: float, _temperature: float = 0.5) -> bool:
	return (elevation >= min_elevation and elevation <= max_elevation and
			moisture >= min_moisture and moisture <= max_moisture)


## Calculate how strongly this biome matches the conditions.
## Used for smooth blending between biomes at boundaries.
## @param elevation Normalized terrain height (0-1)
## @param moisture Normalized moisture value (0-1)
## @return Match strength (0-1), higher = stronger match
func get_match_strength(elevation: float, moisture: float) -> float:
	if not matches(elevation, moisture):
		return 0.0
	
	# Calculate distance from biome center (0 = center, 1 = edge)
	var elev_center := (min_elevation + max_elevation) / 2.0
	var elev_range := (max_elevation - min_elevation) / 2.0
	var elev_dist := absf(elevation - elev_center) / elev_range if elev_range > 0.0 else 0.0
	
	var moist_center := (min_moisture + max_moisture) / 2.0
	var moist_range := (max_moisture - min_moisture) / 2.0
	var moist_dist := absf(moisture - moist_center) / moist_range if moist_range > 0.0 else 0.0
	
	# Convert distance to strength (1 at center, 0 at edge)
	var strength := 1.0 - maxf(elev_dist, moist_dist)
	return clampf(strength, 0.0, 1.0)


## Modify the base terrain height for biome-specific features.
## Override in subclasses to add hills, dunes, ridges, etc.
## @param base_height The original height value from noise generation
## @param world_x World X coordinate (for secondary noise sampling)
## @param world_z World Z coordinate (for secondary noise sampling)
## @return Modified height value
func modify_height(base_height: float, _world_x: float, _world_z: float) -> float:
	return base_height


## Get decorations for this biome.
## Override for custom decoration logic.
## @return Array of DecorationDefinition resources
func get_decorations() -> Array[DecorationDefinition]:
	return decorations
