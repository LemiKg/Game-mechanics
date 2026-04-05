@tool
extends Resource
class_name TerrainMaterialSet
## Groups PBR textures for all 4 splatmap channels.
##
## Each channel (R, G, B, A) has albedo, normal, and roughness textures.
## Assign to a BiomeData's terrain_materials property to define
## per-biome terrain appearance.


@export_group("Channel R (Vegetation)")
@export var channel_r_albedo: Texture2D
@export var channel_r_normal: Texture2D
@export var channel_r_roughness: Texture2D

@export_group("Channel G (Rock)")
@export var channel_g_albedo: Texture2D
@export var channel_g_normal: Texture2D
@export var channel_g_roughness: Texture2D

@export_group("Channel B (Ground)")
@export var channel_b_albedo: Texture2D
@export var channel_b_normal: Texture2D
@export var channel_b_roughness: Texture2D

@export_group("Channel A (Snow)")
@export var channel_a_albedo: Texture2D
@export var channel_a_normal: Texture2D
@export var channel_a_roughness: Texture2D


## Apply all textures to a ShaderMaterial instance.
## Uniform names match terrain_triplanar.gdshader: texture_grass, texture_rock, texture_sand, texture_snow.
func apply_to_material(material: ShaderMaterial) -> void:
	if not material:
		return
	# Channel R = Grass
	_set_if_valid(material, "texture_grass", channel_r_albedo)
	_set_if_valid(material, "texture_grass_normal", channel_r_normal)
	_set_if_valid(material, "texture_grass_roughness", channel_r_roughness)
	# Channel G = Rock
	_set_if_valid(material, "texture_rock", channel_g_albedo)
	_set_if_valid(material, "texture_rock_normal", channel_g_normal)
	_set_if_valid(material, "texture_rock_roughness", channel_g_roughness)
	# Channel B = Sand
	_set_if_valid(material, "texture_sand", channel_b_albedo)
	_set_if_valid(material, "texture_sand_normal", channel_b_normal)
	_set_if_valid(material, "texture_sand_roughness", channel_b_roughness)
	# Channel A = Snow
	_set_if_valid(material, "texture_snow", channel_a_albedo)
	_set_if_valid(material, "texture_snow_normal", channel_a_normal)
	_set_if_valid(material, "texture_snow_roughness", channel_a_roughness)


func _set_if_valid(material: ShaderMaterial, uniform: String, texture: Texture2D) -> void:
	if texture:
		material.set_shader_parameter(uniform, texture)
