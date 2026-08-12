extends CanvasLayer

# AUTOLOAD SINGLETON — register in Project Settings > Autoload.
# Full-screen post-process: god rays (radial light shafts), split-
# tone color grading, vignette, and film grain. Pure post-process —
# doesn't touch your WorldEnvironment/GI settings at all.

@export_category("God Rays")
@export var godray_screen_pos: Vector2 = Vector2(0.5, 0.12)  # roughly where your ceiling lamps converge toward in the frame
@export var godray_density: float = 0.5
@export var godray_decay: float = 0.94
@export var godray_exposure: float = 0.25
@export var godray_weight: float = 0.4
@export var godray_tint: Color = Color(1.0, 0.85, 0.6)   # golden bias applied to rays regardless of source color
@export var godray_tint_strength: float = 0.5
@export var godray_shimmer_strength: float = 0.04         # subtle flicker so rays aren't perfectly static

@export_category("Dust Motes")
@export var dust_strength: float = 0.15
@export var dust_density: float = 40.0
@export var dust_drift_speed: float = 0.04

@export_category("Color Grade")
@export var shadow_tint: Color = Color(0.55, 0.65, 0.8)   # cool
@export var highlight_tint: Color = Color(1.0, 0.85, 0.65) # warm
@export var split_tone_strength: float = 0.25

@export_category("Vignette / Grain")
@export var vignette_strength: float = 0.3
@export var vignette_softness: float = 0.65
@export var grain_strength: float = 0.02
@export var contrast: float = 1.06
@export var saturation: float = 0.95

var rect: ColorRect
var mat: ShaderMaterial

const SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform vec2 godray_screen_pos = vec2(0.5, 0.12);
uniform float godray_density = 0.5;
uniform float godray_decay = 0.94;
uniform float godray_exposure = 0.25;
uniform float godray_weight = 0.4;
uniform vec4 godray_tint : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float godray_tint_strength = 0.5;
uniform float godray_shimmer_strength = 0.04;

uniform float dust_strength = 0.15;
uniform float dust_density = 40.0;
uniform float dust_drift_speed = 0.04;

uniform vec4 shadow_tint : source_color = vec4(0.55, 0.65, 0.8, 1.0);
uniform vec4 highlight_tint : source_color = vec4(1.0, 0.85, 0.65, 1.0);
uniform float split_tone_strength = 0.25;

uniform float vignette_strength = 0.3;
uniform float vignette_softness = 0.65;
uniform float grain_strength = 0.02;
uniform float contrast = 1.06;
uniform float saturation = 0.95;

const int GODRAY_SAMPLES = 24;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float dust_motes(vec2 uv, float t) {
	vec2 grid_uv = uv * dust_density;
	grid_uv.y += t * dust_drift_speed * dust_density;
	vec2 cell = floor(grid_uv);
	vec2 f = fract(grid_uv);

	float h = rand(cell);
	if (h < 0.85) {
		return 0.0; // most cells have no mote — keeps it sparse
	}

	vec2 center = vec2(rand(cell + 1.1), rand(cell + 3.7));
	float d = distance(f, center);
	float twinkle = sin(t * 2.0 + h * 30.0) * 0.5 + 0.5;
	return smoothstep(0.12, 0.0, d) * twinkle;
}

void fragment() {
	vec3 base = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;

	// --- God rays: radial blur pulling bright pixels toward the
	// screen, streaking away from godray_screen_pos ---
	vec2 uv = SCREEN_UV;
	vec2 delta = (uv - godray_screen_pos) * (godray_density / float(GODRAY_SAMPLES));
	vec2 sample_uv = uv;
	float decay = 1.0;
	vec3 rays = vec3(0.0);

	for (int i = 0; i < GODRAY_SAMPLES; i++) {
		sample_uv -= delta;
		vec3 samp = textureLod(screen_tex, sample_uv, 0.0).rgb;
		// only bright pixels (the lamps) contribute meaningfully
		float brightness = max(samp.r, max(samp.g, samp.b));
		samp *= smoothstep(0.5, 1.2, brightness);
		rays += samp * decay * godray_weight;
		decay *= godray_decay;
	}

	// Bias toward a consistent gold color instead of just whatever
	// was behind them — makes them read as "light shafts" even
	// over non-warm backgrounds (like your UI screens)
	float ray_brightness = max(rays.r, max(rays.g, rays.b));
	rays = mix(rays, godray_tint.rgb * ray_brightness, godray_tint_strength);

	// Subtle shimmer so the rays aren't perfectly static every frame
	float shimmer = 1.0 + sin(TIME * 3.0) * godray_shimmer_strength + sin(TIME * 7.3) * godray_shimmer_strength * 0.5;
	rays *= godray_exposure * shimmer;

	vec3 col = base + rays;

	// --- Dust motes drifting through the light ---
	float motes = dust_motes(SCREEN_UV, TIME) * dust_strength;
	col += vec3(1.0, 0.95, 0.85) * motes;

	// --- Split-tone grading: cool shadows, warm highlights ---
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 shadows = mix(vec3(1.0), shadow_tint.rgb, split_tone_strength) * (1.0 - luma);
	vec3 highlights = mix(vec3(1.0), highlight_tint.rgb, split_tone_strength) * luma;
	col *= clamp(shadows + highlights, 0.0, 2.0);

	// --- Contrast / saturation ---
	col = (col - 0.5) * contrast + 0.5;
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(gray), col, saturation);

	// --- Grain ---
	float noise = (rand(SCREEN_UV * vec2(1920.0, 1080.0) + vec2(TIME * 60.0)) - 0.5) * grain_strength;
	col += noise;

	// --- Vignette ---
	vec2 vuv = SCREEN_UV - 0.5;
	float vig = smoothstep(0.75, vignette_softness, length(vuv));
	col *= mix(1.0, 1.0 - vignette_strength, vig);

	COLOR = vec4(col, 1.0);
}
"""

func _ready() -> void:
	layer = 90

	rect = ColorRect.new()
	rect.name = "PostProcessRect"
	rect.color = Color(1, 1, 1, 1)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = SHADER_CODE
	mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("godray_screen_pos", godray_screen_pos)
	mat.set_shader_parameter("godray_density", godray_density)
	mat.set_shader_parameter("godray_decay", godray_decay)
	mat.set_shader_parameter("godray_exposure", godray_exposure)
	mat.set_shader_parameter("godray_weight", godray_weight)
	mat.set_shader_parameter("godray_tint", godray_tint)
	mat.set_shader_parameter("godray_tint_strength", godray_tint_strength)
	mat.set_shader_parameter("godray_shimmer_strength", godray_shimmer_strength)
	mat.set_shader_parameter("dust_strength", dust_strength)
	mat.set_shader_parameter("dust_density", dust_density)
	mat.set_shader_parameter("dust_drift_speed", dust_drift_speed)
	mat.set_shader_parameter("shadow_tint", shadow_tint)
	mat.set_shader_parameter("highlight_tint", highlight_tint)
	mat.set_shader_parameter("split_tone_strength", split_tone_strength)
	mat.set_shader_parameter("vignette_strength", vignette_strength)
	mat.set_shader_parameter("vignette_softness", vignette_softness)
	mat.set_shader_parameter("grain_strength", grain_strength)
	mat.set_shader_parameter("contrast", contrast)
	mat.set_shader_parameter("saturation", saturation)

	rect.material = mat
	add_child(rect)
