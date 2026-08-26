extends Node

# List every bus you want easy control over here (must match your Audio Bus Layout exactly)
@export var managed_buses: Array[String] = ["Master"]

const SAVE_PATH: String = "user://audio_settings.cfg"

signal volume_changed(bus_name: String, linear_value: float)

var _bus_indices: Dictionary = {}


func _ready() -> void:
	for bus_name in managed_buses:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index == -1:
			push_warning("AudioManager: No audio bus named '%s' found." % bus_name)
			continue
		_bus_indices[bus_name] = index

	_load_settings()


func set_volume(bus_name: String, linear_value: float) -> void:
	if not _bus_indices.has(bus_name):
		push_warning("AudioManager: '%s' is not a managed bus." % bus_name)
		return

	linear_value = clampf(linear_value, 0.0, 1.0)
	var index: int = _bus_indices[bus_name]

	AudioServer.set_bus_volume_db(index, linear_to_db(linear_value))
	AudioServer.set_bus_mute(index, linear_value <= 0.0)

	volume_changed.emit(bus_name, linear_value)
	_save_settings()


func get_volume(bus_name: String) -> float:
	if not _bus_indices.has(bus_name):
		push_warning("AudioManager: '%s' is not a managed bus." % bus_name)
		return 0.0

	var index: int = _bus_indices[bus_name]
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	for bus_name in _bus_indices.keys():
		config.set_value("audio", bus_name, get_volume(bus_name))
	config.save(SAVE_PATH)


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SAVE_PATH)
	if err != OK:
		return  # No save file yet — keep default bus volumes

	for bus_name in _bus_indices.keys():
		var saved_value: float = config.get_value("audio", bus_name, get_volume(bus_name))
		set_volume(bus_name, saved_value)
