extends Node3D

# ── heat_trail.gd ─────────────────────────────────────────────────────────────
# Attach to HeatTrail (Node3D) scene root.
# Required children (by name):
#   Particles     (CPUParticles3D)
#   CollectArea   (Area3D)
#     CollisionShape3D  (SphereShape3D)
#   GlowMesh      (MeshInstance3D)
# ─────────────────────────────────────────────────────────────────────────────

@export var stored_heat: float       = 0.0
@export var heat_refund_ratio: float = 0.85
@export var lifetime: float          = 60.0
@export var pulse_speed: float       = 2.2
@export var pulse_scale_min: float   = 0.85
@export var pulse_scale_max: float   = 1.15
@export var colour_cold: Color       = Color(1.0, 0.55, 0.1, 1.0)
@export var colour_hot: Color        = Color(1.0, 0.05, 0.0, 1.0)

@onready var _particles:    CPUParticles3D = $Particles
@onready var _collect_area: Area3D         = $CollectArea
@onready var _glow_mesh:    MeshInstance3D = $GlowMesh

var _lifetime_timer: float   = 0.0
var _pulse_t: float          = 0.0
var _collected: bool         = false
var _mat: StandardMaterial3D = null


func _ready() -> void:
	_build_material()
	_build_particles()
	_ensure_collision()
	_collect_area.body_entered.connect(_on_body_entered)
	_lifetime_timer = lifetime


func _build_material() -> void:
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled           = true
	_mat.emission                   = colour_cold
	_mat.emission_energy_multiplier = 2.0
	_mat.albedo_color               = Color(0.05, 0.02, 0.0)

	if _glow_mesh.mesh == null:
		var s      := SphereMesh.new()
		s.radius   = 0.35
		s.height   = 0.7
		_glow_mesh.mesh = s

	_glow_mesh.set_surface_override_material(0, _mat)


func _build_particles() -> void:
	_particles.emitting              = false
	_particles.amount                = 30
	_particles.lifetime              = 1.5
	_particles.explosiveness         = 0.0
	_particles.randomness            = 0.6
	_particles.emission_shape        = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius= 0.25
	_particles.gravity               = Vector3(0, 1.0, 0)
	_particles.initial_velocity_min  = 0.4
	_particles.initial_velocity_max  = 1.2
	_particles.scale_amount_min      = 0.08
	_particles.scale_amount_max      = 0.25
	_particles.color                 = colour_cold


func _ensure_collision() -> void:
	if _collect_area.get_node_or_null("CollisionShape3D") != null:
		return
	var cs    := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 3.5
	cs.shape     = shape
	_collect_area.add_child(cs)


func _process(delta: float) -> void:
	if _collected:
		return

	if lifetime > 0.0:
		_lifetime_timer -= delta
		if _lifetime_timer <= 0.0:
			_decay_away()
			return

	_pulse_t += delta * pulse_speed
	var s := lerpf(pulse_scale_min, pulse_scale_max, sin(_pulse_t) * 0.5 + 0.5)
	_glow_mesh.scale = Vector3(s, s, s)

	if lifetime > 0.0 and _mat:
		var urgency := 1.0 - clampf(_lifetime_timer / lifetime, 0.0, 1.0)
		var tint    := colour_cold.lerp(colour_hot, urgency)
		_particles.color = tint
		_mat.emission    = tint


func spawn_at(world_position: Vector3, heat_amount: float) -> void:
	global_position = world_position
	stored_heat     = heat_amount
	_apply_heat_visuals()
	_particles.emitting = true


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	HeatManager.restore_heat(stored_heat * heat_refund_ratio)
	_particles.emitting = false
	_particles.one_shot = true
	_particles.restart()
	await get_tree().create_timer(0.6).timeout
	queue_free()


func _decay_away() -> void:
	_collected = true
	_particles.emitting = false
	var tw := create_tween()
	tw.tween_property(_glow_mesh, "scale", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(0.6).timeout
	queue_free()


func _apply_heat_visuals() -> void:
	if _mat == null:
		return
	var t    := clampf(stored_heat / maxf(HeatManager.max_heat, 1.0), 0.0, 1.0)
	var tint := colour_cold.lerp(colour_hot, t)
	_particles.color                    = tint
	_mat.emission                       = tint
	_mat.emission_energy_multiplier     = lerpf(0.8, 3.0, t)
