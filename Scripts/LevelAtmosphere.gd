extends WorldEnvironment

# Attach to your level's WorldEnvironment node.
# Simple version — no SDFGI, no SSIL. Just:
#   1. A dim ambient floor so nothing goes pure black
#   2. SSAO for contact shadows in corners (cheap, big visual payoff)
#   3. Restrained glow, only for genuinely bright things
#   4. Filmic tonemap + slight desaturation for mood
# This is cheaper to run and much easier to reason about than the
# SDFGI version, at the cost of walls not "bouncing" colored light
# off each other — direct lamp light + flat ambient fill instead.

@export var apply_in_editor: bool = true

func _ready() -> void:
	if Engine.is_editor_hint() and not apply_in_editor:
		return
	_build_environment()

func _build_environment() -> void:
	var env := Environment.new()

	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.07)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.16, 0.2)
	env.ambient_light_energy = 1.1

	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5

	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.6   # high on purpose — only real bright lights should bloom
	env.glow_hdr_scale = 1.5

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.9

	environment = env
