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
