extends CanvasLayer

# ── RespawnScreen.gd ──────────────────────────────────────────────────────────
# Attach to a CanvasLayer node in your main scene (or a dedicated UI scene).
#
# Suggested scene structure:
#   RespawnScreen (CanvasLayer)         ← this script
#   └── Panel (Panel)
#       ├── DeathLabel (Label)          ← "YOU DIED" or flavour text
#       ├── HeatLabel (Label)           ← "Heat lost: XX"
#       ├── CountdownBar (ProgressBar)  ← shows death timer ticking down (optional)
#       └── RespawnButton (Button)      ← "Run Again"
# ─────────────────────────────────────────────────────────────────────────────

@export var death_messages: Array[String] = [
	"HEAT LOST",
	"MOMENTUM ZERO",
	"COLD",
	"TRAIL LEFT BEHIND",
]

@onready var _panel:         Control      = $Panel
@onready var _death_label:   Label        = $Panel/DeathLabel
@onready var _heat_label:    Label        = $Panel/HeatLabel
@onready var _countdown_bar: ProgressBar  = $Panel/CountdownBar
@onready var _respawn_btn:   Button       = $Panel/RespawnButton

var _heat_at_death: float = 0.0


func _ready() -> void:
	hide()
	_panel.hide()

	_respawn_btn.pressed.connect(_on_respawn_pressed)
	call_deferred("_connect_signals")

func _connect_signals() -> void:
	DeathRespawnManager.death_timer_changed.connect(_on_death_timer_changed)
	DeathRespawnManager.player_died.connect(_on_player_died)


# ── Public API ────────────────────────────────────────────────────────────────

func show_screen() -> void:
	_heat_at_death = HeatManager.heat_value

	# Pick a random death message
	var msg: String = death_messages[randi() % death_messages.size()]
	_death_label.text = msg

	_heat_label.text = "Heat trail value: %.0f" % _heat_at_death

	if _countdown_bar:
		_countdown_bar.max_value = DeathRespawnManager.heat_zero_death_delay
		_countdown_bar.value     = 0.0

	_respawn_btn.disabled = false

	show()
	_panel.show()

	# Optional: capture mouse so the button is clickable
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func hide_screen() -> void:
	hide()
	_panel.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_player_died(_death_pos: Vector3) -> void:
	# Already handled by DeathRespawnManager calling show_screen(),
	# but you can add camera shake / SFX calls here if you want.
	pass


func _on_death_timer_changed(seconds_remaining: float) -> void:
	if _countdown_bar and is_visible():
		# Bar fills as the timer runs down toward death
		var elapsed: float = DeathRespawnManager.heat_zero_death_delay - seconds_remaining
		_countdown_bar.value = elapsed


func _on_respawn_pressed() -> void:
	_respawn_btn.disabled = true   # prevent double-press
	DeathRespawnManager.do_respawn()
