shader_type spatial;

// ============================================
// TERRAIN TRIPLANAR SPLATMAP SHADER
// ============================================
// Blends up to 4 terrain textures using triplanar projection
// Supports height-based snow and slope-based rock blending
// Compatible with AmbientCG PBR material sets
// Falls back to procedural colors if no textures assigned

// ============================================
// GRASS MATERIAL (Channel R)
// ============================================
group_uniforms grass_material;
uniform sampler2D texture_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_grass_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_grass_ao : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 color_grass : source_color = vec3(0.28, 0.45, 0.18);
uniform bool grass_has_textures = false;

// ============================================
// ROCK MATERIAL (Channel G)
// ============================================
group_uniforms rock_material;
uniform sampler2D texture_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_rock_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_rock_ao : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 color_rock : source_color = vec3(0.4, 0.38, 0.35);
uniform bool rock_has_textures = false;

// ============================================
// SAND MATERIAL (Channel B)
// ============================================
group_uniforms sand_material;
uniform sampler2D texture_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_sand_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_sand_ao : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 color_sand : source_color = vec3(0.76, 0.7, 0.5);
uniform bool sand_has_textures = false;

// ============================================
// SNOW MATERIAL (Channel A)
// ============================================
group_uniforms snow_material;
uniform sampler2D texture_snow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_snow_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_snow_ao : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 color_snow : source_color = vec3(0.95, 0.97, 1.0);
uniform bool snow_has_textures = false;

// ============================================
// SPLATMAP & BLENDING
// ============================================
group_uniforms blending;
uniform sampler2D splatmap : filter_linear;
uniform bool use_splatmap = false;
uniform float texture_scale : hint_range(0.001, 1.0) = 0.05;
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;

// ============================================
// HEIGHT-BASED SNOW
// ============================================
group_uniforms snow_settings;
uniform float snow_height : hint_range(0.0, 200.0) = 35.0;
uniform float snow_blend_range : hint_range(1.0, 50.0) = 8.0;
uniform float snow_slope_threshold : hint_range(0.0, 1.0) = 0.7;

// ============================================
// SLOPE-BASED ROCK
// ============================================
group_uniforms rock_settings;
uniform float rock_slope_start : hint_range(0.0, 1.0) = 0.4;
uniform float rock_slope_end : hint_range(0.0, 1.0) = 0.7;

// ============================================
// MATERIAL PROPERTIES
// ============================================
group_uniforms material_properties;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.1;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 triplanar_sample(sampler2D tex, vec3 pos, vec3 normal) {
	vec3 blend = abs(normal);
	blend = pow(blend, vec3(triplanar_sharpness));
	blend /= (blend.x + blend.y + blend.z + 0.0001);
	vec4 x_sample = texture(tex, pos.zy * texture_scale);
	vec4 y_sample = texture(tex, pos.xz * texture_scale);
	vec4 z_sample = texture(tex, pos.xy * texture_scale);
	return x_sample * blend.x + y_sample * blend.y + z_sample * blend.z;
}

vec3 triplanar_normal(sampler2D tex, vec3 pos, vec3 normal) {
	vec3 blend = abs(normal);
	blend = pow(blend, vec3(triplanar_sharpness));
	blend /= (blend.x + blend.y + blend.z + 0.0001);
	vec3 x_normal = texture(tex, pos.zy * texture_scale).rgb * 2.0 - 1.0;
	vec3 y_normal = texture(tex, pos.xz * texture_scale).rgb * 2.0 - 1.0;
	vec3 z_normal = texture(tex, pos.xy * texture_scale).rgb * 2.0 - 1.0;
	return normalize(x_normal * blend.x + y_normal * blend.y + z_normal * blend.z);
}

float triplanar_single(sampler2D tex, vec3 pos, vec3 normal) {
	vec3 blend = abs(normal);
	blend = pow(blend, vec3(triplanar_sharpness));
	blend /= (blend.x + blend.y + blend.z + 0.0001);
	float x_sample = texture(tex, pos.zy * texture_scale).r;
	float y_sample = texture(tex, pos.xz * texture_scale).r;
	float z_sample = texture(tex, pos.xy * texture_scale).r;
	return x_sample * blend.x + y_sample * blend.y + z_sample * blend.z;
}

void fragment() {
	float slope = 1.0 - abs(world_normal.y);
	vec4 splat;
	
	if (use_splatmap) {
		splat = texture(splatmap, UV);
	} else {
		splat = vec4(1.0, 0.0, 0.0, 0.0);
		float rock_factor = smoothstep(rock_slope_start, rock_slope_end, slope);
		splat.r = mix(splat.r, 0.0, rock_factor);
		splat.g = rock_factor;
	}
	
	float snow_factor = smoothstep(snow_height - snow_blend_range, snow_height + snow_blend_range, world_position.y);
	snow_factor *= smoothstep(snow_slope_threshold, snow_slope_threshold - 0.2, slope);
	splat.r = mix(splat.r, 0.0, snow_factor);
	splat.g = mix(splat.g, 0.0, snow_factor);
	splat.b = mix(splat.b, 0.0, snow_factor);
	splat.a = mix(splat.a, 1.0, snow_factor);
	
	float total = splat.r + splat.g + splat.b + splat.a;
	if (total > 0.001) { splat /= total; } else { splat = vec4(1.0, 0.0, 0.0, 0.0); }
	
	// ALBEDO
	vec3 final_color = vec3(0.0);
	if (splat.r > 0.001) {
		final_color += (grass_has_textures ? triplanar_sample(texture_grass, world_position, world_normal).rgb : color_grass) * splat.r;
	}
	if (splat.g > 0.001) {
		final_color += (rock_has_textures ? triplanar_sample(texture_rock, world_position, world_normal).rgb : color_rock) * splat.g;
	}
	if (splat.b > 0.001) {
		final_color += (sand_has_textures ? triplanar_sample(texture_sand, world_position, world_normal).rgb : color_sand) * splat.b;
	}
	if (splat.a > 0.001) {
		final_color += (snow_has_textures ? triplanar_sample(texture_snow, world_position, world_normal).rgb : color_snow) * splat.a;
	}
	ALBEDO = final_color;
	
	// NORMAL MAPS
	vec3 blended_normal = vec3(0.0, 0.0, 1.0);
	bool any_normals = false;
	if (grass_has_textures && splat.r > 0.001) { blended_normal += triplanar_normal(texture_grass_normal, world_position, world_normal) * splat.r; any_normals = true; }
	if (rock_has_textures && splat.g > 0.001) { blended_normal += triplanar_normal(texture_rock_normal, world_position, world_normal) * splat.g; any_normals = true; }
	if (sand_has_textures && splat.b > 0.001) { blended_normal += triplanar_normal(texture_sand_normal, world_position, world_normal) * splat.b; any_normals = true; }
	if (snow_has_textures && splat.a > 0.001) { blended_normal += triplanar_normal(texture_snow_normal, world_position, world_normal) * splat.a; any_normals = true; }
	if (any_normals) { blended_normal = normalize(blended_normal); blended_normal.xy *= normal_strength; NORMAL_MAP = blended_normal * 0.5 + 0.5; }
	
	// ROUGHNESS
	float final_roughness = 0.0;
	final_roughness += (grass_has_textures ? triplanar_single(texture_grass_roughness, world_position, world_normal) : roughness_base) * splat.r;
	final_roughness += (rock_has_textures ? triplanar_single(texture_rock_roughness, world_position, world_normal) : 0.95) * splat.g;
	final_roughness += (sand_has_textures ? triplanar_single(texture_sand_roughness, world_position, world_normal) : 0.9) * splat.b;
	final_roughness += (snow_has_textures ? triplanar_single(texture_snow_roughness, world_position, world_normal) : 0.7) * splat.a;
	ROUGHNESS = final_roughness + slope * roughness_variation;
	
	// AMBIENT OCCLUSION
	float final_ao = 1.0;
	bool any_ao = false;
	if (grass_has_textures && splat.r > 0.001) { final_ao *= mix(1.0, triplanar_single(texture_grass_ao, world_position, world_normal), splat.r); any_ao = true; }
	if (rock_has_textures && splat.g > 0.001) { final_ao *= mix(1.0, triplanar_single(texture_rock_ao, world_position, world_normal), splat.g); any_ao = true; }
	if (sand_has_textures && splat.b > 0.001) { final_ao *= mix(1.0, triplanar_single(texture_sand_ao, world_position, world_normal), splat.b); any_ao = true; }
	if (snow_has_textures && splat.a > 0.001) { final_ao *= mix(1.0, triplanar_single(texture_snow_ao, world_position, world_normal), splat.a); any_ao = true; }
	if (any_ao) { AO = mix(1.0, final_ao, ao_strength); AO_LIGHT_AFFECT = 0.5; }
}
