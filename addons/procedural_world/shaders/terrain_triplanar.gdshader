shader_type spatial;

// ============================================
// TERRAIN TRIPLANAR SPLATMAP SHADER
// ============================================
// Blends up to 4 terrain textures using triplanar projection
// Supports height-based snow and slope-based rock blending
// Falls back to procedural colors if no textures assigned

// Terrain textures (albedo) - optional, uses colors if not set
uniform sampler2D texture_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_snow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

// Fallback colors when textures aren't assigned
uniform vec3 color_grass : source_color = vec3(0.28, 0.45, 0.18);
uniform vec3 color_rock : source_color = vec3(0.4, 0.38, 0.35);
uniform vec3 color_sand : source_color = vec3(0.76, 0.7, 0.5);
uniform vec3 color_snow : source_color = vec3(0.95, 0.97, 1.0);

// Whether to use textures (false = use colors only)
uniform bool use_textures = false;

// Splatmap for biome blending (R=grass, G=rock, B=sand, A=snow)
// If not provided, uses procedural blending based on height/slope
uniform sampler2D splatmap : filter_linear;
uniform bool use_splatmap = false;

// Texture tiling
uniform float texture_scale : hint_range(0.001, 1.0) = 0.05;
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;

// Height-based snow
uniform float snow_height : hint_range(0.0, 200.0) = 35.0;
uniform float snow_blend_range : hint_range(1.0, 50.0) = 8.0;
uniform float snow_slope_threshold : hint_range(0.0, 1.0) = 0.7;

// Slope-based rock
uniform float rock_slope_start : hint_range(0.0, 1.0) = 0.4;
uniform float rock_slope_end : hint_range(0.0, 1.0) = 0.7;

// Material properties
uniform float roughness_base : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.1;

// Output from vertex shader
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	// Calculate world-space position and normal
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Triplanar texture sampling
vec4 triplanar_sample(sampler2D tex, vec3 pos, vec3 normal) {
	// Calculate blending weights from normal direction
	vec3 blend = abs(normal);
	blend = pow(blend, vec3(triplanar_sharpness));
	blend /= (blend.x + blend.y + blend.z + 0.0001);
	
	// Sample from each axis plane
	vec4 x_sample = texture(tex, pos.zy * texture_scale);
	vec4 y_sample = texture(tex, pos.xz * texture_scale);
	vec4 z_sample = texture(tex, pos.xy * texture_scale);
	
	// Blend based on normal direction
	return x_sample * blend.x + y_sample * blend.y + z_sample * blend.z;
}

void fragment() {
	// Calculate slope (0 = flat, 1 = vertical)
	float slope = 1.0 - abs(world_normal.y);
	
	// Get splatmap weights or calculate procedurally
	vec4 splat;
	
	if (use_splatmap) {
		splat = texture(splatmap, UV);
	} else {
		// Procedural blending based on height and slope
		splat = vec4(1.0, 0.0, 0.0, 0.0); // Default to grass
		
		// Rock on steep slopes
		float rock_factor = smoothstep(rock_slope_start, rock_slope_end, slope);
		splat.r = mix(splat.r, 0.0, rock_factor);
		splat.g = rock_factor;
		
		// Snow at high elevations (on flat surfaces only)
		float snow_factor = smoothstep(
			snow_height - snow_blend_range,
			snow_height + snow_blend_range,
			world_position.y
		);
		// Reduce snow on slopes
		snow_factor *= smoothstep(snow_slope_threshold, snow_slope_threshold - 0.2, slope);
		
		splat.r = mix(splat.r, 0.0, snow_factor);
		splat.g = mix(splat.g, 0.0, snow_factor);
		splat.a = snow_factor;
	}
	
	// Normalize weights
	float total = splat.r + splat.g + splat.b + splat.a;
	if (total > 0.001) {
		splat /= total;
	} else {
		splat = vec4(1.0, 0.0, 0.0, 0.0); // Fallback to grass
	}
	
	vec3 final_color;
	
	if (use_textures) {
		// Triplanar sample each texture
		vec4 grass = triplanar_sample(texture_grass, world_position, world_normal);
		vec4 rock = triplanar_sample(texture_rock, world_position, world_normal);
		vec4 sand = triplanar_sample(texture_sand, world_position, world_normal);
		vec4 snow = triplanar_sample(texture_snow, world_position, world_normal);
		
		// Blend based on splatmap weights
		final_color = (grass * splat.r + rock * splat.g + sand * splat.b + snow * splat.a).rgb;
	} else {
		// Use solid colors instead of textures
		final_color = color_grass * splat.r + color_rock * splat.g + color_sand * splat.b + color_snow * splat.a;
	}
	
	ALBEDO = final_color;
	
	// Roughness varies by material type
	// Rock is rougher, snow is smoother
	float base_roughness = roughness_base;
	base_roughness = mix(base_roughness, 0.95, splat.g); // Rock
	base_roughness = mix(base_roughness, 0.7, splat.a);  // Snow
	base_roughness = mix(base_roughness, 0.9, splat.b);  // Sand
	
	// Add slight variation based on slope
	ROUGHNESS = base_roughness + slope * roughness_variation;
}
