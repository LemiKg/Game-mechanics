@tool
extends BiomeData
class_name PlainsBiome
## Flat grassland biome at low-to-mid elevations with moderate moisture.
## Uses the grass texture (splatmap channel R).

func _init() -> void:
	biome_name = "Plains"
	priority = 10
	splatmap_channel = 0 # R = grass
	terrain_color = Color(0.4, 0.7, 0.3) # Green
	
	# Plains occur at low-to-mid elevations with moderate moisture
	min_elevation = 0.0
	max_elevation = 0.7
	min_moisture = 0.2
	max_moisture = 0.8
