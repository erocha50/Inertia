extends CanvasLayer

# AUTOLOAD SINGLETON — register in Project Settings > Autoload.
# Call from anywhere with:
#     SceneTransition.transition_to_scene("res://scenes/next_level.tscn")

var fade_rect: ColorRect
var particles: GPUParticles2D
var loading_label: Label
var is_transitioning: bool = false

func _ready() -> void:
	layer = 100

	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)

	particles = GPUParticles2D.new()
	particles.name = "WarpParticles"
	particles.amount = 150
	particles.lifetime = 1.0
	particles.explosiveness = 0.0
	particles.one_shot = false
	particles.emitting = false

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 400.0
	mat.initial_velocity_max = 900.0
	mat.scale_min = 1.5
	mat.scale_max = 3.5
	mat.color = Color(0.8, 0.9, 1.0)
	particles.process_material = mat
	add_child(particles)

	loading_label = Label.new()
	loading_label.text = "LOADING..."
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	loading_label.add_theme_font_size_override("font_size", 28)
	loading_label.add_theme_constant_override("outline_size", 4)
	loading_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	loading_label.modulate.a = 0.0
	add_child(loading_label)

	fade_rect.visible = false
	particles.visible = false
	loading_label.visible = false


func transition_to_scene(scene_path: String, fade_time: float = 0.7, hold_time: float = 0.9) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	fade_rect.visible = true
	loading_label.visible = true
	particles.visible = true

	fade_rect.modulate.a = 0.0
	loading_label.modulate.a = 0.0
	particles.position = get_viewport().get_visible_rect().size / 2.0
	particles.emitting = true

	# --- Fade in ---
	var tween_in := create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(fade_rect, "modulate:a", 1.0, fade_time)
	tween_in.tween_property(loading_label, "modulate:a", 1.0, fade_time)
	await tween_in.finished

	# --- Hold on black while the new scene loads ---
	await get_tree().create_timer(hold_time).timeout
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

	# --- Fade out ---
	var tween_out := create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(fade_rect, "modulate:a", 0.0, fade_time)
	tween_out.tween_property(loading_label, "modulate:a", 0.0, fade_time)
	await tween_out.finished

	particles.emitting = false
	fade_rect.visible = false
	loading_label.visible = false
	particles.visible = false
	is_transitioning = false
