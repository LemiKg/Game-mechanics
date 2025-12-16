@tool
extends Resource
class_name BiomeMap
## Container for biome lookup and blending.
## Manages a collection of biomes and provides selection/weight calculation.

## Array of available biomes (will be sorted by priority internally)
@export var biomes: Array[BiomeData] = []:
	set(value):
		biomes = value
		_sort_biomes_by_priority()
		emit_changed()

## Fallback biome when no other biome matches
@export var fallback_biome: BiomeData:
	set(value):
		fallback_biome = value
		emit_changed()

## Cached sorted biomes (highest priority first)
var _sorted_biomes: Array[BiomeData] = []


func _init() -> void:
	_sort_biomes_by_priority()


## Sort biomes by priority (highest first) for efficient lookup
func _sort_biomes_by_priority() -> void:
	_sorted_biomes = biomes.duplicate()
	_sorted_biomes.sort_custom(_compare_priority)


## Comparison function for sorting by priority (descending)
func _compare_priority(a: BiomeData, b: BiomeData) -> bool:
	if not a or not b:
		return false
	return a.priority > b.priority


## Get the dominant biome for the given conditions.
## Uses priority-based lookup - first matching biome wins.
## @param elevation Normalized terrain height (0-1)
## @param moisture Normalized moisture value (0-1)
## @param temperature Normalized temperature (0-1), optional
## @return The matching BiomeData, or fallback_biome if none match
func get_biome(elevation: float, moisture: float, temperature: float = 0.5) -> BiomeData:
	for biome in _sorted_biomes:
		if biome and biome.matches(elevation, moisture, temperature):
			return biome
	
	if fallback_biome:
		return fallback_biome
	
	push_warning("BiomeMap: No matching biome and no fallback set for elevation=%.2f, moisture=%.2f" % [elevation, moisture])
	return null


## Calculate blended biome weights for smooth transitions.
## Returns Color where each channel represents a splatmap layer weight.
## Uses softmax-style normalization across all matching biomes.
## @param elevation Normalized terrain height (0-1)
## @param moisture Normalized moisture value (0-1)
## @return Color with RGBA weights (each channel 0-1, sum = 1)
func get_biome_weights(elevation: float, moisture: float) -> Color:
	var weights := [0.0, 0.0, 0.0, 0.0]
	var total_strength := 0.0
	
	# Accumulate match strength per splatmap channel
	for biome in _sorted_biomes:
		if not biome:
			continue
		
		var strength := biome.get_match_strength(elevation, moisture)
		if strength > 0.0:
			var channel := clampi(biome.splatmap_channel, 0, 3)
			weights[channel] += strength
			total_strength += strength
	
	# Handle fallback if no biomes matched
	if total_strength <= 0.0 and fallback_biome:
		var channel := clampi(fallback_biome.splatmap_channel, 0, 3)
		weights[channel] = 1.0
		total_strength = 1.0
	
	# Normalize weights so they sum to 1
	if total_strength > 0.0:
		for i in range(4):
			weights[i] /= total_strength
	else:
		# Ultimate fallback: 100% grass (channel 0)
		weights[0] = 1.0
	
	return Color(weights[0], weights[1], weights[2], weights[3])


## Get all biomes that match the given conditions (for blending).
## @param elevation Normalized terrain height (0-1)
## @param moisture Normalized moisture value (0-1)
## @return Array of matching BiomeData with their strengths
func get_matching_biomes(elevation: float, moisture: float) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	
	for biome in _sorted_biomes:
		if not biome:
			continue
		
		var strength := biome.get_match_strength(elevation, moisture)
		if strength > 0.0:
			matches.append({
				"biome": biome,
				"strength": strength
			})
	
	return matches
