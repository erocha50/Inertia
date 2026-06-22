# autoloads/SaveManager.gd
extends Node

const SAVE_PATH = 'user://save.json'

var save_data: Dictionary = {
	'hearths_activated': [],
	'knife_shards': [],
	'current_area': 'Foyer',
	'player_health': 100.0,
}

func save() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print('[SaveManager] Game saved.')
	else:
		push_error('[SaveManager] Could not open save file for writing.')

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print('[SaveManager] No save file found. Starting fresh.')
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			save_data = parsed
			return true
	push_error('[SaveManager] Failed to load save file.')
	return false

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		save_data = {
			'hearths_activated': [],
			'knife_shards': [],
			'current_area': 'Foyer',
			'player_health': 100.0,
		}

func activate_hearth(hearth_id: String) -> void:
	if hearth_id not in save_data['hearths_activated']:
		save_data['hearths_activated'].append(hearth_id)
	save()

func add_shard(shard_name: String) -> void:
	if shard_name not in save_data['knife_shards']:
		save_data['knife_shards'].append(shard_name)
	save()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
