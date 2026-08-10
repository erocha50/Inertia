extends Node3D

# ── LampLighting.gd (simple version) ────────────────────────────────────────
# Attach to the Node3D that contains your lamp mesh.
# Creates ONE SpotLight3D pointed straight down. That's it.
# ─────────────────────────────────────────────────────────────────────────────

@export var lamp_mesh_path: NodePath   # drag "lamp_003" here in the inspector

@export var light_color: Color   = Color(1.0, 0.8, 0.5)  # warm white
@export var light_energy: float  = 35.0
@export var light_range: float   = 40.0
@export var cone_angle_deg: float = 65.0   # how wide the cone spreads
@export var cone_softness: float  = 2.0    # lower = harder edge, higher = softer edge

@export_category("Flicker")
@export var enable_flicker: bool     = true
@export var flicker_strength: float  = 0.15   # 0 = perfectly steady, higher = more dramatic flicker
@export var flicker_speed: float     = 6.0

var _lamp_mesh: Node3D = null
var _light: SpotLight3D = null
var _time: float = 0.0


func _ready() -> void:
	_lamp_mesh = get_node_or_null(lamp_mesh_path) as Node3D
	if _lamp_mesh == null:
		push_warning("LampLighting: lamp_mesh_path is not set or invalid.")
		return

	_light = SpotLight3D.new()
	_light.light_color      = light_color
	_light.light_energy     = light_energy
	_light.spot_range       = light_range
	_light.spot_angle       = cone_angle_deg
	_light.spot_attenuation = cone_softness
	_light.shadow_enabled   = true

	add_child(_light)
	_light.top_level = true  # ignore any rotation on parent nodes — always points where we tell it to
	_light.global_position = _lamp_mesh.global_position
	_light.look_at(_light.global_position + Vector3.DOWN, Vector3.FORWARD)

	print("LampLighting: light created at ", _light.global_position, " energy=", _light.light_energy, " range=", _light.spot_range, " angle=", _light.spot_angle)


func _process(delta: float) -> void:
	if not enable_flicker or _light == null:
		return

	_time += delta * flicker_speed
	# Two overlapping sine waves so it doesn't feel like a robotic pulse
	var flicker := sin(_time) * 0.6 + sin(_time * 2.7) * 0.4
	_light.light_energy = light_energy + flicker * flicker_strength * light_energy
