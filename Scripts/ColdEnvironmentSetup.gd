extends WorldEnvironment

# Attach this to your WorldEnvironment node.
# Builds a cold, overcast, foggy Environment entirely in code.
# You can still tweak the values below to taste, or override
# them from the Inspector after they get applied once (see
# the "apply_in_editor" note below).

@export var apply_in_editor: bool = true

func _ready() -> void:
	if Engine.is_editor_hint() and not apply_in_editor:
		return
	_build_environment()
	_setup_sun()

func _build_environment() -> void:
	var env := Environment.new()

	# --- Sky: overcast, not blue ---
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.42, 0.46, 0.52)
	sky_material.sky_horizon_color = Color(0.55, 0.57, 0.60)
	sky_material.sky_curve = 0.15
	sky_material.ground_bottom_color = Color(0.2, 0.2, 0.22)
	sky_material.ground_horizon_color = Color(0.5, 0.5, 0.52)
	sky_material.sun_angle_max = 30.0
	sky_material.sun_curve = 0.15

	var sky := Sky.new()
	sky.sky_material = sky_material

	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# --- Ambient light: soft, cool, sky-driven, low energy ---
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.ambient_light_sky_contribution = 1.0

	# --- Fog: this is what sells the "cold, heavy air" feel ---
	# --- Fog: distance haze, not a wall right in front of you ---
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.58, 0.62)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.1
	env.fog_density = 0.002        # was 0.015 — much gentler falloff
	env.fog_aerial_perspective = 0.3
	env.fog_height = 0.0
	env.fog_height_density = 0.0

	# --- Volumetric fog: light haze only, not a solid block ---
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008   # was 0.04 — big cut
	env.volumetric_fog_albedo = Color(0.6, 0.62, 0.65)
	env.volumetric_fog_emission = Color(0.5, 0.52, 0.55)
	env.volumetric_fog_emission_energy = 0.15
	env.volumetric_fog_gi_inject = 0.3
	env.volumetric_fog_ambient_inject = 0.15
	env.volumetric_fog_length = 100.0    # was 64 — push the thick part further away
	env.volumetric_fog_detail_spread = 2.0

	# --- Tonemap & color grading: desaturated, filmic, slightly cool ---
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0

	env.adjustment_enabled = true
	env.adjustment_brightness = 0.95
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.75

	# --- Glow: subtle, helps the overcast light feel soft ---
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.2

	# --- SSAO: cheap way to add grounded contact shadows ---
	env.ssao_enabled = true
	env.ssao_intensity = 1.5

	environment = env

func _setup_sun() -> void:
	# Looks for a DirectionalLight3D child of this node first;
	# if you don't have one yet, this creates one for you.
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

	# Low angle, raking light — reads as "cold, low winter sun"
	sun.rotation_degrees = Vector3(-35, -45, 0)

	sun.light_color = Color(0.75, 0.8, 0.88)
	sun.light_energy = 1.2
	sun.light_angular_distance = 1.0  # softer shadow edges, like diffused sun

	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
