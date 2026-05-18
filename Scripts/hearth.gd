class_name Hearth
extends StaticBody3D

## Hearth — Rest Point
## On interact: restores heat, saves game, resets nearby enemies, gives +2 heat_floor_bonus.
## Max 6 hearths × +2 = +12 heat_floor_bonus total.

signal hearth_activated(hearth_id: String)

@export_group("Hearth Identity")
@export var hearth_id: String = "hearth_01"          # Unique ID — set per instance in editor
@export var heat_restore_amount: float = 100.0        # How much heat to restore (set to your max)
@export var heat_floor_bonus: float = 2.0             # Added to minimum heat floor on first activation

@export_group("Nodes")
@export var interact_area_path: NodePath = ^"InteractArea"
@export var activated_mesh_path: NodePath = ^"ActivatedMesh"
@export var particles_path: NodePath = ^"CPUParticles3D"

# Internal
var _activated: bool = false
var _player_inside: bool = false
var _interact_area: Area3D
var _activated_mesh: MeshInstance3D
var _particles: CPUParticles3D


func _ready() -> void:
	_interact_area = get_node(interact_area_path)
	_activated_mesh = get_node_or_null(activated_mesh_path)
	_particles = get_node_or_null(particles_path)

	_interact_area.body_entered.connect(_on_interact_area_body_entered)
	_interact_area.body_exited.connect(_on_interact_area_body_exited)

	# Particles run always — they represent the fire existing
	if _particles:
		_particles.emitting = true

	# ActivatedMesh starts hidden; shown after first rest
	if _activated_mesh:
		_activated_mesh.visible = false

	# Restore activated state if already visited this save
	if hearth_id in SaveManager.save_data['hearths_activated']:
		_set_activated_visual(true)
		_activated = true


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_just_pressed("interact"):
		_do_rest()


# ── Rest Logic ───────────────────────────────────────────────────────────────

func _do_rest() -> void:
	var player := _get_player()
	if player == null:
		return

	# 1. Restore heat
	if player.has_method("restore_heat"):
		player.restore_heat(heat_restore_amount)

	# 2. First-time activation bonus
	if not _activated:
		_activated = true
		_set_activated_visual(true)
		# Permanently raise the heat floor (capped in HeatManager)
		if HeatManager.has_method("add_heat_floor_bonus"):
			HeatManager.add_heat_floor_bonus(heat_floor_bonus)
		SaveManager.activate_hearth(hearth_id)

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


func _get_player() -> Player:
	# Grab whichever Player body is inside the area
	for body in _interact_area.get_overlapping_bodies():
		if body is Player:
			return body
	return null


# ── Area Signals ─────────────────────────────────────────────────────────────

func _on_interact_area_body_entered(body: Node3D) -> void:
	if body is Player:
		_player_inside = true

func _on_interact_area_body_exited(body: Node3D) -> void:
	if body is Player:
		_player_inside = false
