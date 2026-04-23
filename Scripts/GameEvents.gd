# autoloads/GameEvents.gd
extends Node

# Player events
signal player_died(position: Vector3, heat_stored: float)
signal player_respawned()
signal player_collected_heat_trail()
signal player_equipped_weapon(weapon_data: Resource)
signal player_consumed_food(food_data: Resource)

# World events
signal hearth_activated(hearth_id: String)
signal area_entered(area_name: String)
signal area_exited(area_name: String)

# Boss events
signal boss_phase_changed(phase: int)
signal boss_defeated()

# UI events
signal show_interact_prompt(text: String)
signal hide_interact_prompt()
signal show_item_flash(item_name: String)

# Signal usage helpers (suppresses unused signal warnings)
func _emit_player_died(position: Vector3, heat_stored: float) -> void:
	player_died.emit(position, heat_stored)

func _emit_player_respawned() -> void:
	player_respawned.emit()

func _emit_player_collected_heat_trail() -> void:
	player_collected_heat_trail.emit()

func _emit_player_equipped_weapon(weapon_data: Resource) -> void:
	player_equipped_weapon.emit(weapon_data)

func _emit_player_consumed_food(food_data: Resource) -> void:
	player_consumed_food.emit(food_data)

func _emit_hearth_activated(hearth_id: String) -> void:
	hearth_activated.emit(hearth_id)

func _emit_area_entered(area_name: String) -> void:
	area_entered.emit(area_name)

func _emit_area_exited(area_name: String) -> void:
	area_exited.emit(area_name)

func _emit_boss_phase_changed(phase: int) -> void:
	boss_phase_changed.emit(phase)

func _emit_boss_defeated() -> void:
	boss_defeated.emit()

func _emit_show_interact_prompt(text: String) -> void:
	show_interact_prompt.emit(text)

func _emit_hide_interact_prompt() -> void:
	hide_interact_prompt.emit()

func _emit_show_item_flash(item_name: String) -> void:
	show_item_flash.emit(item_name)
