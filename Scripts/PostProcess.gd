extends CanvasLayer

# AUTOLOAD SINGLETON — register in Project Settings > Autoload.
# Full-screen post-process: speed-reactive zoom/motion blur +
# chromatic aberration (ramps up with player velocity, peaks during
# a dash), split-tone color grading, vignette, film grain, dust
# motes. Reads the player's built-in `velocity` off whatever
# CharacterBody3D is in the "player" group — no changes needed to
# the player controller script itself.

@export_category("Speed Blur")
@export var max_reference_speed: float = 18.0   # velocity (units/sec) at which blur reaches full strength — IMPORTANT: set this close to your actual dash top speed, or the effect will be maxed out during normal movement
@export var speed_curve_power: float = 3.0       # higher = stays subtle longer, only kicks in near true max speed
@export var effect_intensity: float = 0.35       # master dial, 0-1 — turn this down first if it's still too much
@export var blur_samples: int = 10
@export var blur_strength: float = 0          # reduced — was way too strong
@export var zoom_strength: float = 0         # reduced
@export var chromatic_strength: float = 0  # reduced
@export var speed_smoothing: float = 6.0          # higher = snappier response to speed changes

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
var player: CharacterBody3D = null
var _current_speed_factor: float = 0.0

const SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float speed_factor = 0.0;
uniform int blur_samples = 10;
uniform float blur_strength = 0.35;
uniform float zoom_strength = 0.04;
uniform float chromatic_strength = 0.006;

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
		return 0.0;
	}

	vec2 center = vec2(rand(cell + 1.1), rand(cell + 3.7));
	float d = distance(f, center);
	float twinkle = sin(t * 2.0 + h * 30.0) * 0.5 + 0.5;
	return smoothstep(0.12, 0.0, d) * twinkle;
}

void fragment() {
	vec2 screen_center = vec2(0.5, 0.5);

	// Subtle zoom-in toward center, scaling with speed — tunnel-
	// vision feel, mimics an FOV kick without touching the camera
	vec2 zoomed_uv = screen_center + (SCREEN_UV - screen_center) * (1.0 - zoom_strength * speed_factor);
	vec2 dir = zoomed_uv - screen_center;

	// Radial blur: samples pull progressively toward center,
	// strength scales with speed
	vec3 col = vec3(0.0);
	float samples_f = float(blur_samples);
	for (int i = 0; i < blur_samples; i++) {
		float t = float(i) / max(samples_f - 1.0, 1.0);
		vec2 sample_uv = zoomed_uv - dir * blur_strength * speed_factor * t;
		col += textureLod(screen_tex, sample_uv, 0.0).rgb;
	}
	col /= samples_f;

	// Chromatic aberration along the same radial direction, only
	// kicks in noticeably at higher speed
	float ca = chromatic_strength * speed_factor;
	float r = textureLod(screen_tex, zoomed_uv - dir * ca, 0.0).r;
	float b = textureLod(screen_tex, zoomed_uv + dir * ca, 0.0).b;
	col.r = mix(col.r, r, speed_factor);
	col.b = mix(col.b, b, speed_factor);

	// --- Dust motes ---
	float motes = dust_motes(SCREEN_UV, TIME) * dust_strength;
	col += vec3(1.0, 0.95, 0.85) * motes;

	// --- Split-tone grading ---
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
	mat.set_shader_parameter("speed_factor", 0.0)
	mat.set_shader_parameter("blur_samples", blur_samples)
	mat.set_shader_parameter("blur_strength", blur_strength)
	mat.set_shader_parameter("zoom_strength", zoom_strength)
	mat.set_shader_parameter("chromatic_strength", chromatic_strength)
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


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = null
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0] is CharacterBody3D:
			player = players[0]

	var target_factor := 0.0
	if player != null:
		var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
		target_factor = clamp(horizontal_speed / max_reference_speed, 0.0, 1.0)

	_current_speed_factor = lerp(_current_speed_factor, target_factor, clamp(delta * speed_smoothing, 0.0, 1.0))
	mat.set_shader_parameter("speed_factor", _current_speed_factor)
