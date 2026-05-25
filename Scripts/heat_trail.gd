extends Node3D

# ── HeatTrail.gd ──────────────────────────────────────────────────────────────
# Attach to: scenes/items/HeatTrail.tscn  (Root Node3D)
#
# Scene structure expected:
#   HeatTrail (Node3D)          ← this script
#   ├── Particles (CPUParticles3D)
#   ├── CollectArea (Area3D)
#   │   └── CollectShape (CollisionShape3D)  ← SphereShape3D, generous radius
#   └── GlowMesh (MeshInstance3D)            ← flat sphere, emissive material
#
# How it works:
#   1. Player dies → something calls HeatTrail.spawn_at(position, heat_amount)
#      OR the player controller calls PlayerDeathHandler which instances & places this.
#   2. Trail sits at death position, pulsing.
#   3. Player re-enters CollectArea → heat is restored, trail removes itself.
# ─────────────────────────────────────────────────────────────────────────────

## How much heat this trail holds (set via spawn_at or manually before adding to scene)
@export var stored_heat: float = 0.0

## Fraction of stored heat actually returned to player (1.0 = full refund)
@export_range(0.1, 1.0, 0.05) var heat_refund_ratio: float = 0.85

## How long (seconds) before the trail decays on its own. 0 = never.
@export var lifetime: float = 60.0

## Pulse speed of the glow mesh
@export var pulse_speed: float = 2.2
## Pulse scale range (min/max uniform scale of GlowMesh)
@export var pulse_scale_min: float = 0.85
@export var pulse_scale_max: float = 1.15

## Colour tint driven by heat amount (cold → hot)
@export var colour_cold: Color = Color(1.0, 0.55, 0.1, 1.0)   # orange
@export var colour_hot:  Color = Color(1.0, 0.05, 0.0, 1.0)   # deep red

# ── Internal refs ─────────────────────────────────────────────────────────────
@onready var _particles:     CPUParticles3D  = $Particles
@onready var _collect_area:  Area3D          = $CollectArea
@onready var _glow_mesh:     MeshInstance3D  = $GlowMesh

var _lifetime_timer: float = 0.0
var _pulse_t: float        = 0.0
var _collected: bool       = false
var _mat: StandardMaterial3D


func _ready() -> void:
	# Wire up the collect signal
	_collect_area.body_entered.connect(_on_collect_area_body_entered)

	# Grab / duplicate the glow material so we can tint it per-instance
	if _glow_mesh and _glow_mesh.get_surface_override_material(0):
		_mat = _glow_mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
		_glow_mesh.set_surface_override_material(0, _mat)

	_apply_heat_visuals()
	_lifetime_timer = lifetime


func _process(delta: float) -> void:
	if _collected:
		return

	# ── Lifetime decay ────────────────────────────────────────────────────────
	if lifetime > 0.0:
		_lifetime_timer -= delta
		if _lifetime_timer <= 0.0:
			_decay_away()
			return

	# ── Glow pulse ───────────────────────────────────────────────────────────
	_pulse_t += delta * pulse_speed
	var s: float = lerpf(pulse_scale_min, pulse_scale_max, (sin(_pulse_t) * 0.5 + 0.5))
	if _glow_mesh:
		_glow_mesh.scale = Vector3(s, s, s)

	# ── Flicker particle colour toward hot end as lifetime runs out ───────────
	if lifetime > 0.0 and _particles:
		var urgency: float = 1.0 - clampf(_lifetime_timer / lifetime, 0.0, 1.0)
		_particles.color = colour_cold.lerp(colour_hot, urgency)


# ── Public API ────────────────────────────────────────────────────────────────

## Call this after instancing to place the trail and set its heat value.
## e.g.:  var trail = HeatTrailScene.instantiate(); get_tree().root.add_child(trail)
##        trail.spawn_at(player.global_position, HeatManager.heat_value)
func spawn_at(world_position: Vector3, heat_amount: float) -> void:
	global_position = world_position
	stored_heat     = heat_amount
	_apply_heat_visuals()
	if _particles:
		_particles.emitting = true


# ── Collection ────────────────────────────────────────────────────────────────

func _on_collect_area_body_entered(body: Node3D) -> void:
	if _collected:
		return
	# Only the player collects trails
	if not body.is_in_group("player"):
		return

	_collected = true

	var refund: float = stored_heat * heat_refund_ratio
	# Restore heat via HeatManager autoload
	HeatManager.restore_heat(refund)

	# Burst the particles one last time before leaving
	if _particles:
		_particles.emitting  = false
		_particles.one_shot  = true
		_particles.restart()

	# Small delay so the burst plays, then remove
	await get_tree().create_timer(0.6).timeout
	queue_free()


# ── Natural decay (lifetime expired) ─────────────────────────────────────────

func _decay_away() -> void:
	_collected = true   # stop processing

	if _particles:
		_particles.emitting = false

	# Fade out glow mesh
	var tween: Tween = create_tween()
	if _glow_mesh:
		tween.tween_property(_glow_mesh, "scale",
			Vector3(0.0, 0.0, 0.0), 0.5).set_trans(Tween.TRANS_QUAD)

	await get_tree().create_timer(0.6).timeout
	queue_free()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _apply_heat_visuals() -> void:
	# Normalise stored_heat against HeatManager's max (defaults sensibly if unavailable)
	var max_heat: float = 100.0
	if HeatManager:
		max_heat = HeatManager.max_heat

	var t: float = clampf(stored_heat / maxf(max_heat, 1.0), 0.0, 1.0)
	var tint: Color = colour_cold.lerp(colour_hot, t)

	if _particles:
		_particles.color = tint

	if _mat:
		_mat.emission          = tint
		_mat.emission_enabled  = true
		# Scale emission intensity with stored heat
		_mat.emission_energy_multiplier = lerpf(0.8, 3.0, t)
