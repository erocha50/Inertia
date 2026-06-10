extends Resource
class_name FontConfig

@export var title_font_path: String = "res://fonts/BebasNeue-Regular.ttf"
@export var title_font_size: int = 72
@export var subtitle_font_path: String = "res://fonts/BebasNeue-Regular.ttf"
@export var subtitle_font_size: int = 16
@export var button_font_path: String = "res://fonts/BebasNeue-Regular.ttf"
@export var button_font_size: int = 24
@export var status_font_path: String = "res://fonts/BebasNeue-Regular.ttf"
@export var status_font_size: int = 14
@export var version_font_path: String = "res://fonts/BebasNeue-Regular.ttf"
@export var version_font_size: int = 10

# Cached fonts to avoid reloading
var _title_font_cache: Font
var _subtitle_font_cache: Font
var _button_font_cache: Font
var _status_font_cache: Font
var _version_font_cache: Font

func get_title_font() -> Font:
	if _title_font_cache == null:
		_title_font_cache = _load_font(title_font_path)
	return _title_font_cache

func get_subtitle_font() -> Font:
	if _subtitle_font_cache == null:
		_subtitle_font_cache = _load_font(subtitle_font_path)
	return _subtitle_font_cache

func get_button_font() -> Font:
	if _button_font_cache == null:
		_button_font_cache = _load_font(button_font_path)
	return _button_font_cache

func get_status_font() -> Font:
	if _status_font_cache == null:
		_status_font_cache = _load_font(status_font_path)
	return _status_font_cache

func get_version_font() -> Font:
	if _version_font_cache == null:
		_version_font_cache = _load_font(version_font_path)
	return _version_font_cache

func _load_font(path: String) -> Font:
	if path.is_empty():
		return null
	var font: Font = load(path)
	if font == null:
		push_error("Failed to load font: %s" % path)
		return null
	return font
