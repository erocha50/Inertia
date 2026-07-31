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
uniform float warp_speed : hint_range(0.1, 5.0) = 1.4;

const int STAR_COUNT = 70;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.0;

	vec3 col = vec3(0.0);
	float t = TIME * warp_speed;

	for (int i = 0; i < STAR_COUNT; i++) {
		float fi = float(i);
		float angle = hash(fi) * 6.2831853;
		float speed_mult = 0.5 + hash(fi + 13.7) * 1.5;
		vec2 dir = vec2(cos(angle), sin(angle));

		// Outward travel distance, looping and easing so stars
		// accelerate as they head toward the edge of the screen.
		float dist = fract(t * speed_mult * 0.35 + hash(fi + 3.1));
		dist = dist * dist;
		float star_radius = dist * 0.9;

		vec2 star_pos = dir * star_radius;
		float tail_length = 0.03 + progress * 0.22 * speed_mult;
		vec2 tail_start = star_pos - dir * tail_length;

		// Distance from this pixel to the star's line segment
		vec2 pa = uv - tail_start;
		vec2 ba = star_pos - tail_start;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
		float d = length(pa - ba * h);

		float brightness = smoothstep(0.005, 0.0, d) * progress;
		col += vec3(0.7, 0.85, 1.0) * brightness;
	}

	float glow = max(col.r, max(col.g, col.b));
	float bg_fade = progress * 0.9;

	COLOR = vec4(col, clamp(bg_fade + glow, 0.0, 1.0));
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
