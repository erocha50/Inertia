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
@export var glow_color: Color        = Color(1.0, 0.75, 0.4)   # warm amber
@export var glow_energy: float       = 4.0
@export var glow_range: float        = 4.0
@export var spot_angle_deg: float    = 45.0     # cone width
@export var spot_attenuation: float  = 2.0      # edge falloff softness
@export var emission_multiplier: float = 0.6    # keep low or the shade looks flat/unlit
@export var enable_flicker: bool     = true
@export var flicker_strength: float  = 0.15   # 0 = steady, higher = more flicker
@export var flicker_speed: float     = 6.0

@export_category("Ambient / Directional")
@export var sun_color: Color   = Color(0.85, 0.75, 0.95)  # cool moody tone
@export var sun_energy: float  = 0.6
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

	# Emissive material on ONLY the shade surface — keeps the rod (or any
	# other surface) looking normal instead of everything glowing flat.
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
	_inner_light.position = Vector3(0, -0.1, 0)  # nudge in the inspector if bulb isn't centered
	_inner_light.rotation_degrees = Vector3(-90, 0, 0)  # point straight down
