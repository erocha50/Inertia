class_name PauseMenu extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════════
#  PauseMenu.gd - Pause overlay with Resume/Settings/MainMenu options
# ═══════════════════════════════════════════════════════════════════════════════

const SETTINGS_SCENE: PackedScene = preload("res://Scenes/settings.tscn")

@onready var resume_button: Button = $Control/PausePanel/VBoxContainer/MenuContainer/ResumeButton
@onready var settings_button: Button = $Control/PausePanel/VBoxContainer/MenuContainer/SettingsButton
@onready var main_menu_button: Button = $Control/PausePanel/VBoxContainer/MenuContainer/MainMenuButton
@onready var background_control: Control = $Control
@onready var pause_panel: Control = $Control/PausePanel

var is_paused: bool = false
var font_config: FontConfig = null
var _settings_instance: Control = null

func _ready() -> void:
	# Keep processing even while the SceneTree is paused, so ESC toggling and
	# button input continue to work during the pause.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Load font config for consistent styling
	if font_config == null:
		font_config = load("res://Resources/font_config.tres") as FontConfig
	if font_config == null:
		font_config = FontConfig.new()
		print("⚠ FontConfig resource not found, created new instance")
	
	_apply_fonts()
	
	# Initially hidden
	background_control.visible = false
	background_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if _settings_instance:
			# Settings overlay is open — treat ESC as "close it and resume"
			_on_settings_resume_requested()
		elif not _is_in_main_menu():
			toggle_pause()

func toggle_pause() -> void:
	is_paused = !is_paused
	
	if is_paused:
		_show_pause_menu()
	else:
		_hide_pause_menu()

func _show_pause_menu() -> void:
	background_control.visible = true
	background_control.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()

func _hide_pause_menu() -> void:
	background_control.visible = false
	background_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false
	is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _is_in_main_menu() -> bool:
	# Check if we're in the main_menu.tscn scene by file path
	var scene_file: String = get_tree().current_scene.scene_file_path
	return "main_menu" in scene_file

func _apply_fonts() -> void:
	var title: Label = get_node_or_null("Control/PausePanel/VBoxContainer/Title")
	
	if title and font_config and font_config.get_title_font():
		title.add_theme_font_override("font", font_config.get_title_font())
		title.add_theme_font_size_override("font_size", font_config.title_font_size - 20)
	
	if font_config and font_config.get_button_font():
		if resume_button:
			resume_button.add_theme_font_override("font", font_config.get_button_font())
			resume_button.add_theme_font_size_override("font_size", font_config.button_font_size)
		if settings_button:
			settings_button.add_theme_font_override("font", font_config.get_button_font())
			settings_button.add_theme_font_size_override("font_size", font_config.button_font_size)
		if main_menu_button:
			main_menu_button.add_theme_font_override("font", font_config.get_button_font())
			main_menu_button.add_theme_font_size_override("font_size", font_config.button_font_size)

# ─────────────────────────────────────────────────────────────────────────────
#  Button Callbacks
# ─────────────────────────────────────────────────────────────────────────────

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_settings_pressed() -> void:
	# Show settings as an overlay INSTEAD of swapping scenes — the game stays
	# paused and alive underneath, so Resume can actually take you back to it.
	pause_panel.visible = false

	_settings_instance = SETTINGS_SCENE.instantiate()
	_settings_instance.show_resume_button = true
	_settings_instance.resume_requested.connect(_on_settings_resume_requested)
	background_control.add_child(_settings_instance)

func _on_settings_resume_requested() -> void:
	if _settings_instance:
		_settings_instance.queue_free()
		_settings_instance = null

	pause_panel.visible = true
	toggle_pause()  # is_paused is still true here, so this resumes gameplay

func _on_main_menu_pressed() -> void:
	_hide_pause_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
