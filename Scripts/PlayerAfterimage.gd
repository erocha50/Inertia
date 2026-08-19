extends Node

# AUTOLOAD SINGLETON — register in Project Settings > Autoload.
# Freezes translucent copies of the player's CURRENT pose and fades
# them out — the "leaves a frame behind" trail effect. Frames ONLY
# spawn as a burst when the player dashes (dash_attack_performed or
# dash_performed) — there is no continuous/always-on trail. Frame
# SIZE still scales with flat speed at the moment each frame is
# spawned, so a fast dash produces bigger frames than a slow one.
#
# Reads the player via the same "player" group convention used
# elsewhere in this project. No changes needed to the player
# controller script — this only duplicates and reads it.

@export_category("Frame Size")
@export var speed_for_min_scale: float = 4.0   # flat speed at/below which frames spawn at their smallest
@export var speed_for_max_scale: float = 40.0  # flat speed at/above which frames reach full size — matches player's speed_max
@export_range(0.05, 1.0) var min_frame_scale: float = 0.3   # size multiplier at low speed
@export_range(0.5, 2.0) var max_frame_scale: float = 1.0    # size multiplier at high speed (1.0 = player's actual size)

@export var ghost_lifetime: float = 0.4       # seconds each frame takes to fade out

@export_category("Dash Burst")
@export var burst_on_dash: bool = true         # spawn a guaranteed handful of frames when dash/dash_attack fires, regardless of current speed threshold
@export var burst_frame_count: int = 4
@export var burst_frame_interval: float = 0.04

@export_category("Look")
@export var tint_color: Color = Color(0.35, 0.55, 1.0)
@export_range(0.0, 1.0) var base_opacity: float = 0.6      # starting transparency of each frame
@export_range(0.0, 1.0) var metallic_amount: float = 0.7    # mirror-like reflectivity
@export_range(0.0, 1.0) var roughness_amount: float = 0.15  # low = glossy, high = matte
@export var rim_strength: float = 1.1

var player: Node3D = null
var _ghost_shader: Shader


func _ready() -> void:
	var shader := load("res://shaders/PlayerGhost.gdshader")
	if shader:
		_ghost_shader = shader
	else:
		# Fallback if the shader file isn't in the expected path yet —
		# builds it from embedded code so this still works standalone.
		_ghost_shader = Shader.new()
		_ghost_shader.code = _embedded_shader_code()


func _process(_delta: float) -> void:
	# No continuous trail anymore — this just keeps the player reference
	# fresh and (re)connects the dash signals whenever a new player
	# instance shows up (e.g. after a respawn/scene change). All frame
	# spawning now happens exclusively through _on_dash_burst().
	if not is_instance_valid(player):
		player = null
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0] is Node3D:
			player = players[0]
			_connect_dash_signals()


func _flat_speed() -> float:
	if player is CharacterBody3D:
		var vel: Vector3 = (player as CharacterBody3D).velocity
		return Vector2(vel.x, vel.z).length()
	return 0.0


func _connect_dash_signals() -> void:
	if not burst_on_dash or player == null:
		return
	# Just connecting to signals the player already exposes — no
	# changes to player_controller.gd needed.
	if player.has_signal("dash_attack_performed") and not player.dash_attack_performed.is_connected(_on_dash_burst):
		player.dash_attack_performed.connect(_on_dash_burst)
	if player.has_signal("dash_performed") and not player.dash_performed.is_connected(_on_dash_burst):
		player.dash_performed.connect(_on_dash_burst)


func _on_dash_burst() -> void:
	for i in range(burst_frame_count):
		get_tree().create_timer(i * burst_frame_interval).timeout.connect(_spawn_ghost_frame)


func _spawn_ghost_frame() -> void:
	# Duplicate the ENTIRE player node — flags = 0 is important here:
	# it forces Godot to copy each node's CURRENT live property
	# values (current animation, current frame, current bone poses,
	# current transform) rather than re-instantiating from the
	# saved .tscn file, which would reset everything to whatever
	# state the scene was saved in (idle, bind pose, etc). It also
	# means no script or group membership gets copied onto the
	# ghost — which is what we want, since we don't want it showing
	# up in the "player" group and confusing other systems.
	var ghost := player.duplicate(0)
	if ghost == null:
		return

	# Extra safety net: strip scripts BEFORE adding to the tree, in
	# case anything still ends up with one attached. If a script's
	# _ready() fires on the ghost before this runs, it could reset
	# state (e.g. an animation controller forcing "idle") before we
	# get a chance to remove it.
	var materials: Array[ShaderMaterial] = []
	var sprites: Array[SpriteBase3D] = []
	_sanitize_and_collect(ghost, materials, sprites)

	if materials.is_empty() and sprites.is_empty():
		ghost.queue_free()
		return

	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = player.global_transform

	# Frame size follows current speed — small at a crawl, full size at
	# speed_for_max_scale and above. Re-read live speed here (rather than
	# passing it in once) since the dash burst frames fire on delayed
	# callbacks, and speed can shift between the first and last frame.
	var t := clampf(inverse_lerp(speed_for_min_scale, speed_for_max_scale, _flat_speed()), 0.0, 1.0)
	var frame_scale := lerpf(min_frame_scale, max_frame_scale, t)
	ghost.scale *= frame_scale

	for s in sprites:
		s.modulate = Color(tint_color.r, tint_color.g, tint_color.b, base_opacity)
		if s is AnimatedSprite3D:
			# Freeze on the exact captured frame — setting speed_scale
			# to 0 halts playback without resetting frame/animation
			# the way calling stop() would.
			(s as AnimatedSprite3D).speed_scale = 0.0

	var tween := create_tween()
	tween.tween_method(
		func(alpha: float):
			for m in materials:
				m.set_shader_parameter("ghost_alpha", alpha)
			for s in sprites:
				s.modulate.a = base_opacity * alpha,
		1.0, 0.0, ghost_lifetime
	)
	tween.tween_callback(ghost.queue_free)


func _sanitize_and_collect(node: Node, materials: Array[ShaderMaterial], sprites: Array[SpriteBase3D]) -> void:
	# Strip anything that would make the duplicate act like a real
	# player (movement script, physics collision, a second camera)
	# and apply the ghost look to every mesh surface or sprite we find.
	if node.get_script() != null:
		node.set_script(null)

	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0

	if node is Camera3D or node is AudioListener3D:
		node.queue_free()
		return  # don't recurse into a node we're removing

	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var surf_count: int = max(mesh_inst.mesh.get_surface_count() if mesh_inst.mesh else 1, 1)
		for i in range(surf_count):
			var mat := ShaderMaterial.new()
			mat.shader = _ghost_shader
			mat.set_shader_parameter("tint_color", tint_color)
			mat.set_shader_parameter("base_opacity", base_opacity)
			mat.set_shader_parameter("ghost_alpha", 1.0)
			mat.set_shader_parameter("metallic_amount", metallic_amount)
			mat.set_shader_parameter("roughness_amount", roughness_amount)
			mat.set_shader_parameter("rim_strength", rim_strength)
			mesh_inst.set_surface_override_material(i, mat)
			materials.append(mat)

	elif node is SpriteBase3D:
		# Covers Sprite3D and AnimatedSprite3D. Uses the built-in
		# modulate property — tints color and controls transparency
		# directly, while keeping the sprite's actual texture/shape
		# and current animation frame intact.
		sprites.append(node as SpriteBase3D)

	for child in node.get_children():
		_sanitize_and_collect(child, materials, sprites)


func _embedded_shader_code() -> String:
	return """
shader_type spatial;
render_mode blend_mix, cull_back;

uniform vec4 tint_color : source_color = vec4(0.35, 0.55, 1.0, 1.0);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.6;
uniform float ghost_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.7;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.15;
uniform float rim_strength : hint_range(0.0, 3.0) = 1.1;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

varying vec3 world_normal;
varying vec3 world_view;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_view = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz - (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float rim = 1.0 - clamp(dot(normalize(world_normal), normalize(world_view)), 0.0, 1.0);
	rim = pow(rim, rim_power) * rim_strength;

	ALBEDO = tint_color.rgb;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	EMISSION = tint_color.rgb * rim * 0.6;
	ALPHA = base_opacity * ghost_alpha;
}
"""
