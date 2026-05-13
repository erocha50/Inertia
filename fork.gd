extends Area3D

@export var speed: float = 18.0
@export var damage: float = 12.0
@export var lifetime: float = 3.0

var direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var t = get_tree().create_timer(lifetime)
	t.timeout.connect(queue_free)

func launch(dir: Vector3) -> void:
	direction = dir.normalized()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	# Rotate to face travel direction (visual polish)
	if direction.length() > 0.01:
		rotation.y = atan2(direction.x, direction.z)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
