shader_type spatial;
render_mode cull_back, unshaded;

// Cel-shaded material with clear, distinct shadows and light bands
// Creates classic comic book/anime style shading with hard shadow edges

uniform sampler2D albedo_texture : source_color;
uniform vec3 albedo_color : source_color = vec3(1.0);

// Cel shading parameters
uniform int cel_bands : hint_range(2, 8) = 3;
uniform float shadow_darkness : hint_range(0.0, 0.5) = 0.2;
uniform float shadow_threshold : hint_range(-0.3, 0.3) = 0.0;
uniform float light_falloff_distance : hint_range(1.0, 500.0) = 150.0;
uniform float ambient_multiplier : hint_range(0.0, 2.0) = 0.8;

void vertex() {
	// Standard vertex processing
}

void fragment() {
	// Sample albedo texture
	vec3 albedo = texture(albedo_texture, UV).rgb * albedo_color;
	
	// Calculate ambient light contribution
	vec3 ambient_light = vec3(1.0) * ambient_multiplier;
	
	// Initialize with ambient
	vec3 final_color = albedo * ambient_light;
	
	ALBEDO = final_color;
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
}

void light() {
	// Get the normal
	vec3 normal = normalize(NORMAL);
	
	// Light direction from the light node
	vec3 light_dir = normalize(LIGHT);
	
	// Calculate raw diffuse
	float raw_diffuse = dot(normal, light_dir);
	
	// Hard shadow cutoff - determines if pixel is in shadow or light
	float is_lit = step(shadow_threshold, raw_diffuse);
	
	// For lit areas, quantize to cel bands
	float cel_value = max(raw_diffuse, 0.0);
	cel_value = floor(cel_value * float(cel_bands)) / float(cel_bands);
	
	// Determine final color: shadow color or cel-banded lit color
	vec3 lit_color = ALBEDO * cel_value;
	vec3 shadow_color = ALBEDO * shadow_darkness;
	vec3 final_shading = mix(shadow_color, lit_color, is_lit);
	
	// Distance attenuation is already handled by LIGHT_ENERGY and light distance
	// The falloff_distance uniform is kept for API compatibility
	
	// Apply light color with cel shading and attenuation (includes distance falloff)
	vec3 light_contribution = LIGHT_COLOR * final_shading * ATTENUATION;
	
	// Add to diffuse light
	DIFFUSE_LIGHT += light_contribution;
}
