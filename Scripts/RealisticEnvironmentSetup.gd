extends WorldEnvironment

# Attach this to your WorldEnvironment node.
# Warm, realistic souls-like lighting — built for GAMEPLAY first.
# Rule of thumb followed here: fog should only ever be visible in
# the distance, never up close. Nothing in this script should make
# nearby geometry harder to read.

@export var apply_in_editor: bool = true

func _ready() -> void:
	if Engine.is_editor_hint() and not apply_in_editor:
		return
	_build_environment()
	_setup_sun()

func _build_environment() -> void:
	var env := Environment.new()

	# --- Sky: warm, late-afternoon overcast — not blue, not gray-cold ---
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.45, 0.42, 0.4)
	sky_material.sky_horizon_color = Color(0.75, 0.62, 0.48)
	sky_material.sky_curve = 0.2
	sky_material.ground_bottom_color = Color(0.22, 0.18, 0.15)
	sky_material.ground_horizon_color = Color(0.55, 0.45, 0.35)
	sky_material.sun_angle_max = 25.0
	sky_material.sun_curve = 0.2

	var sky := Sky.new()
	sky.sky_material = sky_material

	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# --- Ambient light: warm, sky-driven, moderate energy ---
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.ambient_light_sky_contribution = 1.0

	# --- Fog: DISTANCE ONLY. No volumetric fog — that's what was
	# filling the whole room and blocking movement. Regular fog is
	# based on how far the camera ray travels before hitting
	# something, so up close (short rays) it stays basically
	# invisible, and only shows up on long, open sightlines.
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.6, 0.5)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.1
	env.fog_density = 0.0015
	env.fog_aerial_perspective = 0.0   # 0 = fog only affects sky/far distance, never blends over nearby objects
	env.fog_height = 0.0
	env.fog_height_density = 0.0

	env.volumetric_fog_enabled = false

	# --- Tonemap & color grading: warm, filmic, readable ---
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9

	# --- Glow: warm bloom off bright surfaces, kept subtle ---
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1

	# --- SSAO: grounds objects, doesn't affect visibility/readability ---
	env.ssao_enabled = true
	env.ssao_intensity = 1.3

	environment = env

func _setup_sun() -> void:
	var sun: DirectionalLight3D = null
	for child in get_children():
		if child is DirectionalLight3D:
			sun = child
			break

	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "Sun"
		add_child(sun)
		if Engine.is_editor_hint():
			sun.owner = get_tree().edited_scene_root

	# Low, warm, raking light — golden-hour angle
	sun.rotation_degrees = Vector3(-30, -45, 0)

	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.light_energy = 1.4
	sun.light_angular_distance = 0.5   # tighter than before — sharper, more realistic shadow edges

	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
