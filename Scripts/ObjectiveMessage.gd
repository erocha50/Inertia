extends CanvasLayer

@onready var label: Label = $Panel/MessageLabel

var fade_tween: Tween

func _ready() -> void:
	visible = false
	label.modulate.a = 0.0

func show_message(text: String, duration: float = 3.0) -> void:
	label.text = text
	visible = true

	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(label, "modulate:a", 1.0, 0.3)
	fade_tween.tween_interval(duration)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	fade_tween.tween_callback(func(): visible = false)
