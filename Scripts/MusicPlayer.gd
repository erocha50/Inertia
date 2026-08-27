extends Node

@export var bus_name: String = "Master"

var _player: AudioStreamPlayer
var _current_stream: AudioStream

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicStreamPlayer"
	_player.bus = bus_name
	_player.finished.connect(_on_finished)
	add_child(_player)

func play_track(stream: AudioStream) -> void:
	if stream == null:
		return
	if _current_stream == stream and _player.playing:
		return  # already playing this track — don't restart it
	_current_stream = stream
	_player.stream = stream
	_player.play()

func stop() -> void:
	_player.stop()
	_current_stream = null

func is_playing() -> bool:
	return _player.playing

func _on_finished() -> void:
	# Manual loop — restarts the same track when it ends
	if _current_stream:
		_player.play()
