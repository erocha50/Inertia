extends Area3D

# ── Checkpoint.gd ─────────────────────────────────────────────────────────────
# Attach to an Area3D node placed in your levels.
#
# Suggested scene structure:
#   Checkpoint (Area3D)                 ← this script
#   ├── CollisionShape3D                ← shape the player walks through
#   ├── CheckpointMesh (MeshInstance3D) ← visual marker (optional)
#   └── ActivateParticles (CPUParticles3D) ← burst on activation (optional)
#
# Behaviour:
#   • First time the player walks through → registers position with
#     DeathRespawnManager and plays an activation effect.
#   • Can only activate once (set repeatable = true to allow re-triggering).
#   • Emits checkpoint_activated so UI / audio can react.
# ─────────────────────────────────────────────────────────────────────────────

signal checkpoint_activated(position: Vector3)

## If true, re-activates every time the player passes through.
## Useful if you want checkpoints to also refill heat each pass.
@export var repeatable: bool = false

## Optional heat bonus given to the player on activation
@export var heat_bonus: float = 0.0

## Visual colour shift when activated (tints CheckpointMesh emissive, if present)
@export var inactive_colour: Color = Color(0.3, 0.3, 1.0)   # cool blue
@export var active_colour:   Color = Color(1.0, 0.6, 0.1)   # warm orange

@onready var _mesh:      MeshInstance3D  = get_node_or_null("CheckpointMesh")
@onready var _particles: CPUParticles3D  = get_node_or_null("ActivateParticles")

var _activated: bool = false
var _mat: StandardMaterial3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Set up material for colour feedback
	if _mesh and _mesh.get_surface_override_material(0):
		_mat = _mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
		_mesh.set_surface_override_material(0, _mat)
		_set_colour(inactive_colour)


# ── Activation ────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _activated and not repeatable:
		return

	_activate()


func _activate() -> void:
	_activated = true

	# Register with the respawn manager
	DeathRespawnManager.register_checkpoint(global_position)

	# Optional heat bonus
	if heat_bonus > 0.0:
		HeatManager.add_heat(heat_bonus)

	# Visual feedback
	_set_colour(active_colour)

	if _particles:
		_particles.emitting  = false
		_particles.one_shot  = true
		_particles.restart()

	checkpoint_activated.emit(global_position)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_colour(c: Color) -> void:
	if _mat == null:
		return
	_mat.emission         = c
	_mat.emission_enabled = true


## Call this from a level reset to un-activate the checkpoint
func reset() -> void:
	_activated = false
	_set_colour(inactive_colour)
