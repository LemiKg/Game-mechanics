@tool
extends BiomeData
class_name ForestBiome
## Dense forest biome at mid elevations with high moisture.
## Uses the grass texture (splatmap channel R) with rolling hills terrain.

## Secondary noise for rolling hills
var _hill_noise: FastNoiseLite


func _init() -> void:
	biome_name = "Forest"
	priority = 20 # Higher than plains to override in overlap
	splatmap_channel = 0 # R = grass (same as plains)
	terrain_color = Color(0.2, 0.5, 0.2) # Dark green
	
	# Forests occur at mid elevations with high moisture
	min_elevation = 0.15
	max_elevation = 0.8
	min_moisture = 0.45
	max_moisture = 1.0
	
	# Setup hill noise
	_hill_noise = FastNoiseLite.new()
	_hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_hill_noise.frequency = 0.02
	_hill_noise.fractal_octaves = 2


## Add gentle rolling hills to forest terrain
func modify_height(base_height: float, world_x: float, world_z: float) -> float:
	if not _hill_noise:
		return base_height
	
	# Add subtle rolling hills (amplitude ~1.5% of base height)
	var hill_offset := _hill_noise.get_noise_2d(world_x, world_z) * 0.015
	return base_height * (1.0 + hill_offset)
