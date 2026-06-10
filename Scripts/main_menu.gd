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
	# Safely get node references with null checks
	var title: Label = get_node_or_null("TitleContainer/Title")
	var subtitle: Label = get_node_or_null("TitleContainer/Subtitle")
	var play_btn: Button = get_node_or_null("MenuContainer/PlayButton")
	var settings_btn: Button = get_node_or_null("MenuContainer/SettingsButton")
	var quit_btn: Button = get_node_or_null("MenuContainer/QuitButton")
	var status_text: Label = get_node_or_null("StatusContainer/StatusText")
	var version_text: Label = get_node_or_null("VersionContainer/VersionText")
	
	# Apply title font
	if title and font_config.get_title_font():
		title.add_theme_font_override("font", font_config.get_title_font())
		title.add_theme_font_size_override("font_size", font_config.title_font_size)
	
	# Apply subtitle font
	if subtitle and font_config.get_subtitle_font():
		subtitle.add_theme_font_override("font", font_config.get_subtitle_font())
		subtitle.add_theme_font_size_override("font_size", font_config.subtitle_font_size)
	
	# Apply button fonts
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
	
	# Apply status font (optional)
	if status_text and font_config.get_status_font():
		status_text.add_theme_font_override("font", font_config.get_status_font())
		status_text.add_theme_font_size_override("font_size", font_config.status_font_size)
	
	# Apply version font (optional - this node may not exist)
	if version_text and font_config.get_version_font():
		version_text.add_theme_font_override("font", font_config.get_version_font())
		version_text.add_theme_font_size_override("font_size", font_config.version_font_size)

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://maps/test_play_world.tscn")

func _on_settings_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/settings.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
