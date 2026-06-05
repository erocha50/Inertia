extends Node3D

# ── heat_trail.gd ─────────────────────────────────────────────────────────────
# Builds all visuals in code — no material or particle setup needed in editor.
# Scene structure needed:
#   HeatTrail (Node3D)      ← this script
#   ├── Particles (CPUParticles3D)
#   ├── CollectArea (Area3D)
#   │   └── CollisionShape3D  ← SphereShape3D
#   └── GlowMesh (MeshInstance3D)
# ─────────────────────────────────────────────────────────────────────────────

@export var stored_heat: float      = 0.0
@export var heat_refund_ratio: float = 0.85
@export var lifetime: float          = 60.0
@export var pulse_speed: float       = 2.2
@export var pulse_scale_min: float   = 0.85
@export var pulse_scale_max: float   = 1.15
@export var colour_cold: Color       = Color(1.0, 0.55, 0.1, 1.0)
@export var colour_hot:  Color       = Color(1.0, 0.05, 0.0, 1.0)

@onready var _particles:    CPUParticles3D = $Particles
@onready var _collect_area: Area3D         = $CollectArea
@onready var _glow_mesh:    MeshInstance3D = $GlowMesh

var _lifetime_timer: float   = 0.0
var _pulse_t: float          = 0.0
var _collected: bool         = false
var _mat: StandardMaterial3D = null


func _ready() -> void:
	_setup_glow_material()
	_setup_particles()
	_setup_collision()
	_collect_area.body_entered.connect(_on_collect_area_body_entered)
	_lifetime_timer = lifetime


func _setup_glow_material() -> void:
	# Always create a fresh emissive material in code
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled          = true
	_mat.emission                  = colour_cold
	_mat.emission_energy_multiplier = 2.0
	_mat.albedo_color              = Color(0, 0, 0, 1)

	# Make sure GlowMesh has a sphere mesh
	if _glow_mesh.mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		_glow_mesh.mesh = sphere

	_glow_mesh.set_surface_override_material(0, _mat)


func _setup_particles() -> void:
	_particles.emitting        = false
	_particles.amount          = 24
	_particles.lifetime        = 1.2
	_particles.explosiveness   = 0.0
	_particles.randomness      = 0.5
	_particles.emission_shape  = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 0.2
	_particles.gravity         = Vector3(0, 1.5, 0)
	_particles.initial_velocity_min = 0.5
	_particles.initial_velocity_max = 1.5
	_particles.scale_amount_min = 0.1
	_particles.scale_amount_max = 0.3
	_particles.color           = colour_cold


func _setup_collision() -> void:
	# Make sure CollectArea has a collision shape
	var existing := _collect_area.get_node_or_null("CollisionShape3D")
	if existing == null:
		var shape_node := CollisionShape3D.new()
		var sphere     := SphereShape3D.new()
		sphere.radius  = 3.5
		shape_node.shape = sphere
		_collect_area.add_child(shape_node)


func _process(delta: float) -> void:
	if _collected:
		return

	# Lifetime decay
	if lifetime > 0.0:
		_lifetime_timer -= delta
		if _lifetime_timer <= 0.0:
			_decay_away()
			return

	# Glow pulse
	_pulse_t += delta * pulse_speed
	var s := lerpf(pulse_scale_min, pulse_scale_max, sin(_pulse_t) * 0.5 + 0.5)
	_glow_mesh.scale = Vector3(s, s, s)

	# Colour flicker toward hot as lifetime runs out
	if lifetime > 0.0:
		var urgency := 1.0 - clampf(_lifetime_timer / lifetime, 0.0, 1.0)
		var tint    := colour_cold.lerp(colour_hot, urgency)
		_particles.color  = tint
		_mat.emission     = tint


# ── Public API ────────────────────────────────────────────────────────────────

func spawn_at(world_position: Vector3, heat_amount: float) -> void:
	print("HeatTrail: spawn_at called with position: ", world_position, " heat: ", heat_amount)
	global_position = world_position
	stored_heat     = heat_amount
	_apply_heat_visuals()
	_particles.emitting = true
	print("HeatTrail: global_position set to: ", global_position)


# ── Collection ────────────────────────────────────────────────────────────────

func _on_collect_area_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return

	_collected = true

	HeatManager.restore_heat(stored_heat * heat_refund_ratio)

	if _particles:
		_particles.emitting = false
		_particles.one_shot = true
		_particles.restart()

	await get_tree().create_timer(0.6).timeout
	queue_free()


# ── Natural decay ─────────────────────────────────────────────────────────────

func _decay_away() -> void:
	_collected = true
	_particles.emitting = false

	var tween := create_tween()
	tween.tween_property(_glow_mesh, "scale", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_QUAD)

	await get_tree().create_timer(0.6).timeout
	queue_free()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _apply_heat_visuals() -> void:
	var t    := clampf(stored_heat / maxf(HeatManager.max_heat, 1.0), 0.0, 1.0)
	var tint := colour_cold.lerp(colour_hot, t)

	_particles.color                    = tint
	_mat.emission                       = tint
	_mat.emission_enabled               = true
	_mat.emission_energy_multiplier     = lerpf(0.8, 3.0, t)
