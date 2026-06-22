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

	# Billboard is handled by material billboard_mode — just check distance
	if _player:
		var dist := global_position.distance_to(_player.global_position)
		if dist > max_visible_distance:
			_set_bar_visible(false)
			return

	# Fade out after delay with smooth transparency
	_fade_timer -= delta
	if _fade_timer <= 0.0:
		_set_bar_visible(false)
	elif _fade_timer < 0.5:  # Fade out last 0.5 seconds
		var fade_alpha: float = _fade_timer / 0.5
		if _bg_mat:
			var bg_color := COLOR_BG
			bg_color.a = 0.85 * fade_alpha
			_bg_mat.albedo_color = bg_color
			_bg_mat.emission = bg_color
		if _fill_mat:
			var fill_color := _fill_mat.albedo_color
			fill_color.a = fill_color.a * fade_alpha
			_fill_mat.albedo_color = fill_color
			_fill_mat.emission = fill_color


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
		_fill_mat.emission = COLOR_DEAD
	if _fill:
		_fill.scale.x = 0.01
	_set_bar_visible(true)
	_fade_timer = 1.0


## Call this on respawn to reset
func reset() -> void:
	_hp_ratio = 1.0
	_set_bar_visible(false)
	_fade_timer = 0.0
	# Restore original colors
	if _bg_mat:
		_bg_mat.albedo_color = COLOR_BG
		_bg_mat.emission = COLOR_BG
	if _fill_mat:
		_fill_mat.albedo_color = COLOR_FULL
		_fill_mat.emission = COLOR_FULL
		_fill.scale.x = 1.0
		_fill.position.x = 0.0


# ── Internal ──────────────────────────────────────────────────────────────────

func _build_bar() -> void:
	# Background - clean flat border look (no shading artifacts)
	_bg     = MeshInstance3D.new()
	var bq  := QuadMesh.new()
	bq.size = Vector2(bar_width + 0.04, bar_height + 0.02)
	_bg.mesh = bq
	_bg_mat  = StandardMaterial3D.new()
	_bg_mat.albedo_color     = COLOR_BG
	_bg_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bg_mat.billboard_mode   = BaseMaterial3D.BILLBOARD_ENABLED
	_bg_mat.no_depth_test    = true
	_bg_mat.disable_receive_shadows = true
	_bg_mat.emission_enabled = true
	_bg_mat.emission = COLOR_BG
	_bg_mat.emission_energy_multiplier = 2.0
	_bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bg.set_surface_override_material(0, _bg_mat)
	add_child(_bg)

	# Fill bar - scales from left to right (flat, no shading)
	_fill     = MeshInstance3D.new()
	var fq    := QuadMesh.new()
	fq.size   = Vector2(bar_width, bar_height)
	_fill.mesh = fq
	_fill_mat  = StandardMaterial3D.new()
	_fill_mat.albedo_color   = COLOR_FULL
	_fill_mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fill_mat.no_depth_test  = true
	_fill_mat.disable_receive_shadows = true
	_fill_mat.emission_enabled = true
	_fill_mat.emission = COLOR_FULL
	_fill_mat.emission_energy_multiplier = 2.0
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Position fill so it scales from the left edge
	_fill.position.z = 0.001
	_fill.set_surface_override_material(0, _fill_mat)
	add_child(_fill)


func _update_fill() -> void:
	if _fill == null or _fill_mat == null:
		return

	# Scale from left edge by adjusting position and scale together
	var new_scale_x: float = maxf(_hp_ratio, 0.01)
	_fill.scale.x = new_scale_x
	
	# Move left edge to match bar_width offset for proper alignment
	_fill.position.x = -(bar_width * 0.5) + (bar_width * _hp_ratio * 0.5)

	# Colour shifts green → yellow → red with smooth transitions
	var c: Color
	if _hp_ratio > 0.5:
		c = COLOR_FULL.lerp(COLOR_MID, 1.0 - (_hp_ratio - 0.5) * 2.0)
	else:
		c = COLOR_MID.lerp(COLOR_LOW, 1.0 - _hp_ratio * 2.0)
	_fill_mat.albedo_color = c
	_fill_mat.emission = c  # Keep emission synchronized with color


func _set_bar_visible(v: bool) -> void:
	_visible_bar = v
	if _bg:   _bg.visible   = v
	if _fill: _fill.visible = v
