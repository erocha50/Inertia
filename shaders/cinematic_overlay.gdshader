shader_type canvas_item;
render_mode blend_mix;

// Cinematic overlay shader for atmospheric lighting effects
// Inspired by golden hour and castle fog photography

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_intensity: hint_range(0.0, 1.0) = 0.4;
uniform float vignette_roundness: hint_range(0.0, 1.0) = 0.5;
uniform float color_grade_warmth: hint_range(-1.0, 1.0) = 0.3;
uniform float color_grade_saturation: hint_range(0.0, 2.0) = 1.1;

uniform float depth_fog_intensity: hint_range(0.0, 1.0) = 0.15;
uniform vec3 fog_color = vec3(1.0, 0.9, 0.7);
uniform float chromatic_aberration: hint_range(0.0, 0.05) = 0.0;
uniform float film_grain: hint_range(0.0, 1.0) = 0.05;
uniform float contrast: hint_range(0.5, 2.0) = 1.1;
uniform float brightness: hint_range(0.5, 2.0) = 1.0;

// Hash function for noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Vignette effect
float vignette(vec2 uv) {
	vec2 center = uv - vec2(0.5);
	float dist = length(center * vec2(1.0, 0.6));
	return smoothstep(1.0, vignette_roundness, dist * (1.0 - vignette_intensity));
}

// Simple color grading
vec3 color_grade(vec3 col) {
	// Warmth shift
	col.r += color_grade_warmth * 0.1;
	col.g += color_grade_warmth * 0.05;
	
	// Saturation
	vec3 gray = vec3(dot(col, vec3(0.299, 0.587, 0.114)));
	col = mix(gray, col, color_grade_saturation);
	
	return col;
}

// Depth fog (simulated from screen position)
vec3 apply_depth_fog(vec3 col, vec2 uv) {
	float depth = length(uv - vec2(0.5)) * depth_fog_intensity;
	return mix(col, fog_color, depth);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = texture(SCREEN_TEXTURE, uv).rgb;
	
	// Apply chromatic aberration (subtle)
	if (chromatic_aberration > 0.0) {
		float ca = chromatic_aberration * 0.002;
		float r = texture(SCREEN_TEXTURE, uv + vec2(ca, 0.0)).r;
		float b = texture(SCREEN_TEXTURE, uv - vec2(ca, 0.0)).b;
		col = vec3(r, col.g, b);
	}
	
	// Color grading
	col = color_grade(col);
	
	// Depth fog
	col = apply_depth_fog(col, uv);
	
	// Contrast and brightness
	col = (col - 0.5) * contrast + 0.5;
	col *= brightness;
	
	// Vignette
	col *= vignette(uv);
	
	// Film grain
	if (film_grain > 0.0) {
		float grain = hash(uv * TIME) * film_grain;
		col += grain * 0.1;
	}
	
	// Clamp to avoid oversaturation
	col = clamp(col, vec3(0.0), vec3(1.0));
	
	COLOR = vec4(col, 1.0);
}
