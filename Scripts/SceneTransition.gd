extends CanvasLayer

# AUTOLOAD SINGLETON — register this in Project Settings > Autoload
# so it exists globally and persists across scene changes.
# Any script can then just call:
#     SceneTransition.transition_to_scene("res://scenes/next_level.tscn")

var overlay: ColorRect
var loading_label: Label
var warp_material: ShaderMaterial
var is_transitioning: bool = false

const WARP_SHADER_CODE := """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float warp_speed : hint_range(0.5, 10.0) = 4.0;
uniform int streak_count : hint_range(20, 300) = 140;

float rand(float seed) {
	return fract(sin(seed * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = (UV - vec2(0.5)) * vec2(1.0, SCREEN_PIXEL_SIZE.x > 0.0 ? 1.0 : 1.0);
	float angle = atan(uv.y, uv.x);
	float radius = length(uv) * 2.0;

	float streak_id = floor((angle / (2.0 * 3.14159265)) * float(streak_count));
	float rnd = rand(streak_id);
	float speed_mult = 0.4 + rnd * 1.6;

	float pos = fract(radius - TIME * warp_speed * speed_mult * progress - rnd);
	float streak = smoothstep(0.0, 0.015, pos) - smoothstep(0.015, 0.06, pos);

	float brightness = streak * radius * progress * 2.0;
	vec3 streak_color = mix(vec3(0.5, 0.7, 1.0), vec3(0.9, 0.95, 1.0), rnd);

	vec3 col = streak_color * brightness;
	float bg_fade = progress * 0.85;

	float vignette = smoothstep(1.5, 0.1, radius);
	float alpha = clamp(bg_fade + brightness, 0.0, 1.0) * vignette + bg_fade;

	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
"""

func _ready() -> void:
	layer = 100  # draw on top of everything, including other UI

	overlay = ColorRect.new()
	overlay.name = "WarpOverlay"
	overlay.color = Color(0, 0, 0, 1)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = WARP_SHADER_CODE
	warp_material = ShaderMaterial.new()
	warp_material.shader = shader
	warp_material.set_shader_parameter("progress", 0.0)
	overlay.material = warp_material

	add_child(overlay)

	loading_label = Label.new()
	loading_label.text = "LOADING..."
	loading_label.anchors_preset = Control.PRESET_CENTER
	loading_label.anchor_left = 0.5
	loading_label.anchor_right = 0.5
	loading_label.anchor_top = 0.5
	loading_label.anchor_bottom = 0.5
	loading_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loading_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.0))
	loading_label.add_theme_font_size_override("font_size", 28)
	loading_label.add_theme_constant_override("outline_size", 4)
	loading_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_child(loading_label)

	overlay.visible = false
	loading_label.visible = false


func transition_to_scene(scene_path: String, warp_in_time: float = 1.1, hold_time: float = 0.6, warp_out_time: float = 0.9) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	overlay.visible = true
	loading_label.visible = true
	overlay.color.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)

	# Accelerate into warp: streaks build up, label fades in
	tween.set_parallel(true)
	tween.tween_property(warp_material, "shader_parameter/progress", 1.0, warp_in_time)
	tween.tween_property(loading_label, "theme_override_colors/font_color:a", 1.0, warp_in_time * 0.6)
	tween.chain()

	tween.tween_interval(hold_time)

	# Load the new scene while the screen is fully covered
	tween.tween_callback(func():
		get_tree().change_scene_to_file(scene_path)
	)

	tween.tween_interval(0.1)  # let the new scene finish entering the tree

	# Decelerate out of warp, fade label, reveal new scene
	tween.set_parallel(true)
	tween.tween_property(warp_material, "shader_parameter/progress", 0.0, warp_out_time)
	tween.tween_property(loading_label, "theme_override_colors/font_color:a", 0.0, warp_out_time * 0.5)
	tween.chain()

	tween.tween_callback(func():
		overlay.visible = false
		loading_label.visible = false
		is_transitioning = false
	)
