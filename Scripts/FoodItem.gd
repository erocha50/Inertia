class_name FoodItem
extends Area3D

@export var item_name: String = "Food"
@export var is_rare: bool = false
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.1

## Assign a FoodItemData resource to drive what this item does
@export var data: FoodItemData

## Fallback heat amount if no FoodItemData is assigned
@export var fallback_heat_amount: float = 15.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var player: Node3D
var animation_start_position: Vector3
var time_elapsed: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	animation_start_position = position
	_initialize_food()


func _process(delta: float) -> void:
	time_elapsed += delta
	var bob_offset: float = sin(time_elapsed * bob_speed * TAU) * bob_height
	position.y = animation_start_position.y + bob_offset


func _initialize_food() -> void:
	var color: Color = Color.YELLOW
	if data and data.is_rare:
		color = Color.MAGENTA
	elif is_rare:
		color = Color.MAGENTA
	_set_mesh_color(color)


func _set_mesh_color(color: Color) -> void:
	if mesh_instance:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		mesh_instance.set_surface_override_material(0, material)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body
		_consume_food()


func _consume_food() -> void:
	if not player:
		return

	var consumed_name: String = item_name

	if data:
		consumed_name = data.item_name

		# ── Instant heat effects ─────────────────────────────────────────────
		if data.fills_heat_to_max:
			HeatManager.set_heat(HeatManager.max_heat)
		elif data.heat_per_hit_bonus > 0.0 and data.duration <= 0.0:
			# Only apply instantly if it's NOT a timed buff
			HeatManager.add_heat(data.heat_per_hit_bonus)

		# ── Instant healing ───────────────────────────────────────────────────
		if data.heal_amount > 0.0:
			HealthManager.heal(data.heal_amount)

		# ── Speed burst ────────────────────────────────────────────────────────
		if data.triggers_speed_burst:
			_trigger_speed_burst()

		# ── Timed buffs (momentum ceiling, heat-per-hit, sprint damage, turning) ─
		if data.duration > 0.0:
			FoodBuffManager.apply_food_buff(data)

	else:
		# No data assigned — flat heat boost fallback
		HeatManager.add_heat(fallback_heat_amount)

	GameEvents.player_consumed_food.emit(consumed_name)
	queue_free()


func _trigger_speed_burst() -> void:
	# Give the player a quick burst of heat — speed scales with heat,
	# so this gives an immediate momentum kick
	HeatManager.add_heat(20.0)
