extends Button
class_name CyberpunkButton

@export var button_color: Color = Color.CYAN
@export var border_width: float = 2.0

var glow_amount: float = 0.0
var default_glow: float = 0.3
var hover_glow: float = 1.0
var target_glow: float = 0.3

func _ready() -> void:
	flat = true
	custom_minimum_size = Vector2(300, 60)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _process(_delta: float) -> void:
	glow_amount = lerp(glow_amount, target_glow, 0.1)
	queue_redraw()

func _on_mouse_entered() -> void:
	target_glow = hover_glow

func _on_mouse_exited() -> void:
	target_glow = default_glow

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	
	# Draw border
	var border_color: Color = button_color
	border_color.a = 0.7 + glow_amount * 0.3
	
	# Outer border
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), border_color, border_width)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), border_color, border_width)
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, border_color, border_width)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, border_color, border_width)
	
	# Inner glow lines
	if glow_amount > 0.1:
		var glow_color: Color = button_color
		glow_color.a = glow_amount * 0.5
		var inner_y: float = border_width + 1
		draw_line(Vector2(inner_y, inner_y), Vector2(rect.end.x - inner_y, inner_y), glow_color, 1.0)
		draw_line(Vector2(inner_y, rect.end.y - inner_y), Vector2(rect.end.x - inner_y, rect.end.y - inner_y), glow_color, 1.0)
