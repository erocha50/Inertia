extends Control

@export var font_config: FontConfig

# Scroll speed in UV units per second (tweak to taste)
@export var scroll_speed: float = 0.015

var _bg: TextureRect
var _scroll_shader: ShaderMaterial

const SCROLL_SHADER_CODE = """
shader_type canvas_item;

uniform float offset_x : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x + offset_x);
	COLOR = texture(TEXTURE, uv);
}
"""

func _ready() -> void:
	_setup_background()

	if font_config == null:
		font_config = load("res://Resources/font_config.tres") as FontConfig
	if font_config == null:
		font_config = FontConfig.new()
		print("⚠ FontConfig resource not found, created new instance")

	_apply_fonts()

func _setup_background() -> void:
	_bg = get_node_or_null("Background")
	if _bg == null:
		push_warning("main_menu: No TextureRect named 'Background' found.")
		return

	# Make it fill the whole screen
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# Build and assign the scroll shader
	var shader = Shader.new()
	shader.code = SCROLL_SHADER_CODE
	_scroll_shader = ShaderMaterial.new()
	_scroll_shader.shader = shader
	_scroll_shader.set_shader_parameter("offset_x", 0.0)
	_bg.material = _scroll_shader

func _process(delta: float) -> void:
	if _scroll_shader == null:
		return
	var current: float = _scroll_shader.get_shader_parameter("offset_x")
	# fract keeps it in 0-1 so it loops seamlessly
	_scroll_shader.set_shader_parameter("offset_x", fmod(current + scroll_speed * delta, 1.0))

func _apply_fonts() -> void:
	var title: Label = get_node_or_null("TitleContainer/Title")
	var subtitle: Label = get_node_or_null("TitleContainer/Subtitle")
	var play_btn: Button = get_node_or_null("MenuContainer/PlayButton")
	var settings_btn: Button = get_node_or_null("MenuContainer/SettingsButton")
	var quit_btn: Button = get_node_or_null("MenuContainer/QuitButton")
	var status_text: Label = get_node_or_null("StatusContainer/StatusText")
	var version_text: Label = get_node_or_null("VersionContainer/VersionText")

	if title and font_config.get_title_font():
		title.add_theme_font_override("font", font_config.get_title_font())
		title.add_theme_font_size_override("font_size", font_config.title_font_size)

	if subtitle and font_config.get_subtitle_font():
		subtitle.add_theme_font_override("font", font_config.get_subtitle_font())
		subtitle.add_theme_font_size_override("font_size", font_config.subtitle_font_size)

	if font_config.get_button_font():
		if play_btn:
			play_btn.add_theme_font_override("font", font_config.get_button_font())
			play_btn.add_theme_font_size_override("font_size", font_config.button_font_size)
		if settings_btn:
			settings_btn.add_theme_font_override("font", font_config.get_button_font())
			settings_btn.add_theme_font_size_override("font_size", font_config.button_font_size)
		if quit_btn:
			quit_btn.add_theme_font_override("font", font_config.get_button_font())
			quit_btn.add_theme_font_size_override("font_size", font_config.button_font_size)

	if status_text and font_config.get_status_font():
		status_text.add_theme_font_override("font", font_config.get_status_font())
		status_text.add_theme_font_size_override("font_size", font_config.status_font_size)

	if version_text and font_config.get_version_font():
		version_text.add_theme_font_override("font", font_config.get_version_font())
		version_text.add_theme_font_size_override("font_size", font_config.version_font_size)

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://maps/test_play_world.tscn")

func _on_settings_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/settings.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
