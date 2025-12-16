@tool
extends BiomeData
class_name DesertBiome
## Sandy desert biome in dry areas (low moisture).
## Uses the sand texture (splatmap channel B) with dune patterns.

## Dune noise for wave-like sand patterns
var _dune_noise: FastNoiseLite


func _init() -> void:
	biome_name = "Desert"
	priority = 25 # Higher than plains, overrides in dry areas
	splatmap_channel = 2 # B = sand
	terrain_color = Color(0.9, 0.8, 0.5) # Sandy yellow
	
	# Deserts occur in dry areas at low-to-mid elevations
	min_elevation = 0.0
	max_elevation = 0.7
	min_moisture = 0.0
	max_moisture = 0.4
	
	# Setup dune noise for wave patterns
	_dune_noise = FastNoiseLite.new()
	_dune_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_dune_noise.frequency = 0.03
	_dune_noise.fractal_octaves = 2
	_dune_noise.domain_warp_enabled = true
	_dune_noise.domain_warp_amplitude = 20.0


## Add dune wave patterns to desert terrain
func modify_height(base_height: float, world_x: float, world_z: float) -> float:
	if not _dune_noise:
		return base_height
	
	# Get dune pattern (warped for organic look)
	var dune_value := _dune_noise.get_noise_2d(world_x, world_z)
	
	# Convert to 0-1 and create wave-like pattern
	var dune_wave := (dune_value + 1.0) * 0.5
	
	# Apply subtle dune effect (~2% height variation, reduced from 8%)
	return base_height * (1.0 + (dune_wave - 0.5) * 0.02)
