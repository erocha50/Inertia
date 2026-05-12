extends Control

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://maps/test_world.tscn")

func _on_settings_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/settings.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
