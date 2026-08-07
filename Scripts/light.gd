extends Node3D

# ── LampLighting.gd ────────────────────────────────────────────────────────
# Attach to the Node3D that contains your lamp mesh and DirectionalLight3D.
# Creates a warm internal glow inside the lamp (OmniLight3D + emissive
# material) and tunes the DirectionalLight3D for a moody ambient look.
# ─────────────────────────────────────────────────────────────────────────────

@export var lamp_mesh_path: NodePath          # drag "lamp_003" here in the inspector
@export var directional_light_path: NodePath  # drag "DirectionalLight3D" here

@export_category("Internal Glow")
@export var glow_surface_index: int  = 0        # which surface is the shade (not the rod)
@export var enable_shade_emission: bool = false # OFF by default — this is what makes the shade look "neon"; the spotlight cone does the actual lighting
@export var glow_color: Color        = Color(1.0, 0.75, 0.4)   # warm amber
@export var glow_energy: float       = 8.0
@export var glow_range: float        = 9.0
@export var spot_angle_deg: float    = 75.0     # wider cone = light covers a bigger area
@export var spot_attenuation: float  = 1.0      # lower = softer, more gradual falloff at the edge
@export var emission_multiplier: float = 3.0    # only matters if enable_shade_emission is true
@export var auto_enable_glow: bool   = true     # turns on Glow in the scene's WorldEnvironment
@export var enable_volumetric_beam: bool = false # OFF — this was the "nuclear bomb" haze. The beam mesh below handles the visible cone instead.
@export var darken_environment: bool = true      # dims ambient so the lamp reads as the main light source
@export var ambient_light_level: float = 0.06    # small amount of visibility outside the beam — 0.0 = pitch black
@export var enable_beam_mesh: bool   = true     # adds an actual visible cone mesh under the light
@export var beam_alpha: float        = 0.14     # how visible the beam cone looks — keep low, it stacks toward the center
@export var enable_flicker: bool     = true
@export var flicker_strength: float  = 0.15   # 0 = steady, higher = more flicker
@export var flicker_speed: float     = 6.0

@export_category("Ambient / Directional")
@export var sun_color: Color   = Color(1.0, 0.95, 0.85)  # neutral warm white, won't tint walls
@export var sun_energy: float  = 0.3
@export var sun_angle_deg: Vector3 = Vector3(-35, 45, 0)

var _lamp_mesh: MeshInstance3D    = null
var _sun: DirectionalLight3D      = null
var _inner_light: SpotLight3D     = null
var _time: float                  = 0.0


func _ready() -> void:
	_lamp_mesh = get_node_or_null(lamp_mesh_path) as MeshInstance3D
	_sun       = get_node_or_null(directional_light_path) as DirectionalLight3D

	_setup_directional_light()
	_setup_inner_glow()
	if auto_enable_glow:
		_enable_scene_glow()


func _process(delta: float) -> void:
	if not enable_flicker or _inner_light == null:
		return

	_time += delta * flicker_speed
	var flicker := sin(_time) * 0.6 + sin(_time * 2.7) * 0.4
	_inner_light.light_energy = glow_energy + flicker * flicker_strength * glow_energy


func _setup_directional_light() -> void:
	if _sun == null:
		push_warning("LampLighting: no DirectionalLight3D assigned")
		return

	_sun.light_color  = sun_color
	_sun.light_energy = sun_energy
	_sun.shadow_enabled = true
	_sun.rotation_degrees = sun_angle_deg


func _setup_inner_glow() -> void:
	if _lamp_mesh == null:
		push_warning("LampLighting: no lamp mesh assigned")
		return

	# Emissive material on ONLY the shade surface — OFF by default, since
	# this is what causes the flat "neon ring" look. Turn it on only if
	# you want a subtle self-lit bulb look in ADDITION to the spotlight.
	if enable_shade_emission:
		var existing := _lamp_mesh.get_active_material(glow_surface_index)
		var mat: StandardMaterial3D
		if existing and existing is StandardMaterial3D:
			mat = (existing as StandardMaterial3D).duplicate()
		else:
			mat = StandardMaterial3D.new()

		mat.emission_enabled = true
		mat.emission         = glow_color
		mat.emission_energy_multiplier = emission_multiplier
		# Follow the existing texture/shading pattern instead of a flat
		# solid color, if the material has an albedo texture.
		if mat.albedo_texture != null:
			mat.emission_texture = mat.albedo_texture

		_lamp_mesh.set_surface_override_material(glow_surface_index, mat)

	# Actual light source sitting inside the lamp shade, aimed straight
	# down so it behaves like a real hanging lamp instead of a glowing orb.
	_inner_light = SpotLight3D.new()
	_inner_light.light_color   = glow_color
	_inner_light.light_energy  = glow_energy
	_inner_light.spot_range    = glow_range
	_inner_light.spot_angle    = spot_angle_deg
	_inner_light.spot_attenuation = spot_attenuation
	_inner_light.shadow_enabled = true
	_lamp_mesh.add_child(_inner_light)
	_inner_light.top_level = true  # ignore the lamp mesh's own rotation entirely
	_inner_light.global_position = _lamp_mesh.global_position + Vector3(0, -0.1, 0)
	_inner_light.look_at(_inner_light.global_position + Vector3.DOWN, Vector3.FORWARD)

	if enable_beam_mesh:
		_create_beam_mesh()


func _create_beam_mesh() -> void:
	var half_angle_rad := deg_to_rad(spot_angle_deg * 0.5)
	var bottom_radius := glow_range * tan(half_angle_rad)

	var cone := CylinderMesh.new()
	cone.top_radius    = 0.0          # apex at the light — makes it a true cone, not a cylinder
	cone.bottom_radius = bottom_radius
	cone.height         = glow_range
	cone.radial_segments = 32

	var mat := StandardMaterial3D.new()
	mat.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode         = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode          = BaseMaterial3D.CULL_BACK  # standard culling — prevents whiteout when camera is near/inside the cone
	mat.albedo_color       = Color(glow_color.r, glow_color.g, glow_color.b, beam_alpha)
	mat.no_depth_test      = false

	var beam := MeshInstance3D.new()
	beam.mesh = cone
	beam.material_override = mat
	beam.top_level = true

	get_tree().root.add_child(beam)
	# Cone apex sits at the light; mesh is centered, so shift the mesh
	# down by half its height so the apex lines up with the light itself.
	beam.global_position = _inner_light.global_position - Vector3(0, glow_range * 0.5, 0)


func _enable_scene_glow() -> void:
	var world_env := _find_world_environment(get_tree().root)

	if world_env == null:
		push_warning("LampLighting: no WorldEnvironment found in the scene. Add one and enable Glow in its Environment resource — without it, emission just looks like a flat brighter color instead of an actual glow.")
		return

	var env := world_env.environment
	if env == null:
		env = Environment.new()
		world_env.environment = env

	env.glow_enabled = true
	if env.glow_intensity < 0.4:
		env.glow_intensity = 0.8
	if env.glow_strength < 0.8:
		env.glow_strength = 1.2

	env.volumetric_fog_enabled = false  # explicitly off — this was causing the blown-out haze

	if darken_environment:
		env.ambient_light_energy = ambient_light_level

	if enable_volumetric_beam:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.015          # too high = uniform haze, not a beam
		env.volumetric_fog_albedo  = glow_color
		env.volumetric_fog_ambient_inject = 0.0     # stop ambient light from filling the fog everywhere
		env.volumetric_fog_anisotropy = 0.6         # forward-scatters light so the shaft reads clearly
		env.volumetric_fog_emission_energy = 0.3
		_inner_light.light_volumetric_fog_energy = 3.0  # how strongly THIS light defines the beam


func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var found := _find_world_environment(child)
		if found:
			return found
	return null
