extends Control

@export var font_config: FontConfig

func _ready() -> void:
	# Load font config resource
	if font_config == null:
		font_config = load("res://Resources/font_config.tres") as FontConfig
	
	# Fallback to creating a new one if loading fails
	if font_config == null:
		font_config = FontConfig.new()
		print("⚠ FontConfig resource not found, created new instance")
	
	# Apply fonts to UI elements
	_apply_fonts()

func _apply_fonts() -> void:
	var title: Label = $TitleContainer/Title
	var subtitle: Label = $TitleContainer/Subtitle
	var play_btn: Button = $MenuContainer/PlayButton
	var settings_btn: Button = $MenuContainer/SettingsButton
	var quit_btn: Button = $MenuContainer/QuitButton
	var status_text: Label = $StatusContainer/StatusText
	var version_text: Label = $VersionContainer/VersionText
	
	# Apply title font
	if font_config.get_title_font():
		title.add_theme_font_override("font", font_config.get_title_font())
		title.add_theme_font_size_override("font_size", font_config.title_font_size)
	
	# Apply subtitle font
	if font_config.get_subtitle_font():
		subtitle.add_theme_font_override("font", font_config.get_subtitle_font())
		subtitle.add_theme_font_size_override("font_size", font_config.subtitle_font_size)
	
	# Apply button fonts
	if font_config.get_button_font():
		play_btn.add_theme_font_override("font", font_config.get_button_font())
		play_btn.add_theme_font_size_override("font_size", font_config.button_font_size)
		settings_btn.add_theme_font_override("font", font_config.get_button_font())
		settings_btn.add_theme_font_size_override("font_size", font_config.button_font_size)
		quit_btn.add_theme_font_override("font", font_config.get_button_font())
		quit_btn.add_theme_font_size_override("font_size", font_config.button_font_size)
	
	# Apply status font
	if font_config.get_status_font():
		status_text.add_theme_font_override("font", font_config.get_status_font())
		status_text.add_theme_font_size_override("font_size", font_config.status_font_size)
	
	# Apply version font
	if font_config.get_version_font():
		version_text.add_theme_font_override("font", font_config.get_version_font())
		version_text.add_theme_font_size_override("font_size", font_config.version_font_size)

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://maps/test_world.tscn")

func _on_settings_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/settings.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
