extends Control
class_name GridBackground

var grid_spacing: int = 80
var line_color: Color = Color(0, 1, 1, 0.15)
var line_width: float = 1.0
var animate_offset: bool = true
var animation_speed: float = 20.0
var offset_x: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if animate_offset:
		offset_x += animation_speed * delta
		if offset_x >= grid_spacing:
			offset_x -= grid_spacing
		queue_redraw()

func _draw() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	
	# Draw vertical lines
	var x: float = -offset_x
	while x < screen_size.x:
		draw_line(Vector2(x, 0), Vector2(x, screen_size.y), line_color, line_width)
		x += grid_spacing
	
	# Draw horizontal lines
	var y: float = 0.0
	while y < screen_size.y:
		draw_line(Vector2(0, y), Vector2(screen_size.x, y), line_color, line_width)
		y += grid_spacing
