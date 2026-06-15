class_name Hearth
extends StaticBody3D

## Hearth — Rest Point
## On interact: restores heat, saves game, refills food slots.

signal hearth_activated(hearth_id: String)

@export_group("Hearth Identity")
@export var hearth_id: String = "hearth_01"
@export var heat_restore_amount: float = 100.0

@export_group("Nodes")
@export var interact_area_path: NodePath = ^"InteractArea"
@export var activated_mesh_path: NodePath = ^"ActivatedMesh"
@export var particles_path: NodePath = ^"GPUParticles3D"

# Internal
var _activated: bool = false
var _player_inside: bool = false
var _interact_area: Area3D
var _activated_mesh: MeshInstance3D
var _particles: GPUParticles3D

func _ready() -> void:
	_interact_area = get_node(interact_area_path)
	_activated_mesh = get_node_or_null(activated_mesh_path)
	_particles = get_node_or_null(particles_path)

	_interact_area.body_entered.connect(_on_interact_area_body_entered)
	_interact_area.body_exited.connect(_on_interact_area_body_exited)

	if _particles:
		_particles.emitting = true

	if _activated_mesh:
		_activated_mesh.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not _player_inside:
		return
	if event.keycode == KEY_E and event.pressed and not event.echo:
		_do_rest()

# ── Rest Logic ───────────────────────────────────────────────────────────────

func _do_rest() -> void:
	var player := _get_player()
	if player == null:
		return

	# 1. Restore heat
	if player.has_method("restore_heat"):
		player.restore_heat(heat_restore_amount)

	# 2. Mark as activated and update visual
	if not _activated:
		_activated = true
		_set_activated_visual(true)

	# 3. Refill food slots
	if player.has_method("refill_food_slots"):
		player.refill_food_slots()

	# 4. Reset enemies in current area
	#if EnemyManager.has_method("reset_area_enemies"):
		#EnemyManager.reset_area_enemies(get_tree().current_scene.name)

	# 5. Save
	SaveManager.save()

	# 6. UI flash — emit signal; let your HUD handle the actual flash
	hearth_activated.emit(hearth_id)

	print("Hearth '%s' rested — heat restored, game saved." % hearth_id)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _set_activated_visual(on: bool) -> void:
	if _activated_mesh:
		_activated_mesh.visible = on


func _get_player() -> Node3D:
	for body in _interact_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return body
	return null


# ── Area Signals ─────────────────────────────────────────────────────────────

func _on_interact_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_interact_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
