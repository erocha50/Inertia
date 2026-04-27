class_name FoodItem
extends Area3D

@export var item_name: String = "Food"
@export var is_rare: bool = false
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.1

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
	# Create smooth bobbing motion using sine wave
	time_elapsed += delta
	var bob_offset: float = sin(time_elapsed * bob_speed * TAU) * bob_height
	position.y = animation_start_position.y + bob_offset


func _initialize_food() -> void:
	# Color the mesh based on item type/rarity
	var color: Color = Color.YELLOW
	if is_rare:
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
	
	# Emit the signal for the player to consume the food
	GameEvents.player_consumed_food.emit(item_name)
	
	# Remove the food item from the scene
	queue_free()
