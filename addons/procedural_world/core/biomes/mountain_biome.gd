@tool
extends BiomeData
class_name MountainBiome
## Rocky mountain biome at high elevations.
## Uses the rock texture (splatmap channel G) with ridged terrain.

## Ridged noise for mountain peaks
var _ridge_noise: FastNoiseLite


func _init() -> void:
	biome_name = "Mountain"
	priority = 30 # High priority for elevation-based selection
	splatmap_channel = 1 # G = rock
	terrain_color = Color(0.5, 0.5, 0.5) # Gray
	
	# Mountains occur at high elevations (any moisture)
	min_elevation = 0.65
	max_elevation = 1.0
	min_moisture = 0.0
	max_moisture = 1.0
	
	# Setup ridged noise for peaks - higher frequency for sharper detail
	_ridge_noise = FastNoiseLite.new()
	_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridge_noise.frequency = 0.025 # Increased from 0.015 for sharper features
	_ridge_noise.fractal_octaves = 5 # More octaves for detail
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge_noise.fractal_lacunarity = 2.5 # Sharper ridges
	_ridge_noise.fractal_gain = 0.6


## Add ridged peaks to mountain terrain
func modify_height(base_height: float, world_x: float, world_z: float) -> float:
	if not _ridge_noise:
		return base_height
	
	# Get ridged noise (already in -1 to 1 range, but ridged pushes toward 1)
	var ridge_value := _ridge_noise.get_noise_2d(world_x, world_z)
	
	# Convert to 0-1 range and apply as height boost
	var ridge_factor := (ridge_value + 1.0) * 0.5
	
	# Apply stronger effect at higher base elevations (smooth ramp-in)
	var elevation_factor := clampf((base_height - 0.5) * 2.0, 0.0, 1.0)
	elevation_factor = elevation_factor * elevation_factor # Quadratic for smoother transition
	
	# Add up to 15% height for dramatic peaks
	return base_height * (1.0 + ridge_factor * elevation_factor * 0.15)
