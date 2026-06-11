extends Node3D

# ── EnemyHealthBar.gd ─────────────────────────────────────────────────────────
# Attach as a child of any enemy node.
# Builds a flat billboard health bar in code — no scene setup needed.
#
# Usage:
#   Call show_damage(current_hp, max_hp) whenever the enemy takes damage.
#   The bar fades out after a few seconds if not damaged again.
# ─────────────────────────────────────────────────────────────────────────────

## How high above the enemy origin the bar floats
@export var height_offset: float       = 2.2
## How long the bar stays visible after last damage
@export var fade_delay: float          = 2.5
## How far the player must be for the bar to show (metres)
@export var max_visible_distance: float = 12.0
## Bar size in world units
@export var bar_width: float           = 1.0
@export var bar_height: float          = 0.08

const COLOR_BG      := Color(0.08, 0.08, 0.08, 0.85)
const COLOR_FULL    := Color(0.18, 0.85, 0.38, 1.0)   # green
const COLOR_MID     := Color(0.95, 0.75, 0.10, 1.0)   # yellow
const COLOR_LOW     := Color(0.90, 0.18, 0.12, 1.0)   # red
const COLOR_DEAD    := Color(0.30, 0.30, 0.30, 1.0)

var _bg:        MeshInstance3D = null
var _fill:      MeshInstance3D = null
var _bg_mat:    StandardMaterial3D = null
var _fill_mat:  StandardMaterial3D = null

var _fade_timer:  float = 0.0
var _visible_bar: bool  = false
var _hp_ratio:    float = 1.0
var _player:      Node3D = null


func _ready() -> void:
	position = Vector3(0, height_offset, 0)
	_build_bar()
	_set_bar_visible(false)
	call_deferred("_find_player")


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]


func _process(delta: float) -> void:
	if not _visible_bar:
		return

	# Billboard — always face the camera/player
	if _player:
		var to_player := _player.global_position - global_position
		to_player.y   = 0.0
		if to_player.length_squared() > 0.01:
			look_at(global_position - to_player, Vector3.UP)

		# Hide if player too far
		var dist := global_position.distance_to(_player.global_position)
		if dist > max_visible_distance:
			_set_bar_visible(false)
			return

	# Fade out after delay
	_fade_timer -= delta
	if _fade_timer <= 0.0:
		_set_bar_visible(false)


# ── Public API ────────────────────────────────────────────────────────────────

## Call this whenever the enemy takes damage
func show_damage(current_hp: float, max_hp: float) -> void:
	if _player == null:
		_find_player()

	# Distance check before showing
	if _player:
		var dist: float = (get_parent() as Node3D).global_position.distance_to(_player.global_position)
		if dist > max_visible_distance:
			return

	_hp_ratio = clampf(current_hp / maxf(max_hp, 1.0), 0.0, 1.0)
	_update_fill()
	_set_bar_visible(true)
	_fade_timer = fade_delay


## Call this when the enemy dies
func show_dead() -> void:
	_hp_ratio = 0.0
	if _fill_mat:
		_fill_mat.albedo_color = COLOR_DEAD
	if _fill:
		_fill.scale.x = 0.01
	_set_bar_visible(true)
	_fade_timer = 1.0


## Call this on respawn to reset
func reset() -> void:
	_hp_ratio = 1.0
	_set_bar_visible(false)
	_fade_timer = 0.0


# ── Internal ──────────────────────────────────────────────────────────────────

func _build_bar() -> void:
	# Background
	_bg     = MeshInstance3D.new()
	var bq  := QuadMesh.new()
	bq.size = Vector2(bar_width + 0.06, bar_height + 0.04)
	_bg.mesh = bq
	_bg_mat  = StandardMaterial3D.new()
	_bg_mat.albedo_color     = COLOR_BG
	_bg_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bg_mat.billboard_mode   = BaseMaterial3D.BILLBOARD_ENABLED
	_bg_mat.no_depth_test    = true
	_bg.set_surface_override_material(0, _bg_mat)
	add_child(_bg)

	# Fill bar
	_fill     = MeshInstance3D.new()
	var fq    := QuadMesh.new()
	fq.size   = Vector2(bar_width, bar_height)
	_fill.mesh = fq
	_fill_mat  = StandardMaterial3D.new()
	_fill_mat.albedo_color   = COLOR_FULL
	_fill_mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fill_mat.no_depth_test  = true
	# Slight z offset so fill renders in front of bg
	_fill.position.z = 0.002
	_fill.set_surface_override_material(0, _fill_mat)
	add_child(_fill)


func _update_fill() -> void:
	if _fill == null or _fill_mat == null:
		return

	# Scale fill quad on X axis — pivot from left side
	_fill.scale.x  = maxf(_hp_ratio, 0.01)
	# Offset so bar shrinks from right, not centre
	_fill.position.x = bar_width * (_hp_ratio - 1.0) * 0.5

	# Colour shifts green → yellow → red
	var c: Color
	if _hp_ratio > 0.5:
		c = COLOR_FULL.lerp(COLOR_MID, (1.0 - _hp_ratio) * 2.0)
	else:
		c = COLOR_MID.lerp(COLOR_LOW, (0.5 - _hp_ratio) * 2.0)
	_fill_mat.albedo_color = c


func _set_bar_visible(v: bool) -> void:
	_visible_bar = v
	if _bg:   _bg.visible   = v
	if _fill: _fill.visible = v
