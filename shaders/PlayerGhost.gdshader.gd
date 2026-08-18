extends Node

# AUTOLOAD SINGLETON — register in Project Settings > Autoload.
# While the player moves above min_speed_threshold, periodically
# freezes a translucent copy of their CURRENT pose in place and
# fades it out — the "leaves a frame behind" trail effect.
#
# Reads the player via the same "player" group convention used
# elsewhere in this project. No changes needed to the player
# controller script — this only duplicates and reads it.

@export var min_speed_threshold: float = 8.0
@export var trail_interval: float = 0.06     # seconds between spawned frames while moving fast
@export var ghost_lifetime: float = 0.4       # seconds each frame takes to fade out

@export_category("Look")
@export var tint_color: Color = Color(0.35, 0.55, 1.0)
@export_range(0.0, 1.0) var base_opacity: float = 0.6      # starting transparency of each frame
@export_range(0.0, 1.0) var metallic_amount: float = 0.7    # mirror-like reflectivity
@export_range(0.0, 1.0) var roughness_amount: float = 0.15  # low = glossy, high = matte
@export var rim_strength: float = 1.1

var player: Node3D = null
var _timer: float = 0.0
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


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = null
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0] is Node3D:
			player = players[0]

	if player == null:
		_timer = 0.0
		return

	var speed := Vector2.ZERO
	if player is CharacterBody3D:
		var vel: Vector3 = (player as CharacterBody3D).velocity
		speed = Vector2(vel.x, vel.z)

	if speed.length() >= min_speed_threshold:
		_timer += delta
		if _timer >= trail_interval:
			_timer = 0.0
			_spawn_ghost_frame()
	else:
		_timer = 0.0


func _spawn_ghost_frame() -> void:
	# Duplicate the ENTIRE player node — this is what correctly
	# captures the current animated pose (skeleton bone transforms
	# included), not just a static bind-pose copy.
	var ghost := player.duplicate(Node.DUPLICATE_USE_INSTANTIATION)
	if ghost == null:
		return

	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = player.global_transform

	var materials: Array[ShaderMaterial] = []
	_sanitize_and_collect(ghost, materials)

	if materials.is_empty():
		ghost.queue_free()
		return

	var tween := create_tween()
	tween.tween_method(
		func(alpha: float):
			for m in materials:
				m.set_shader_parameter("ghost_alpha", alpha),
		1.0, 0.0, ghost_lifetime
	)
	tween.tween_callback(ghost.queue_free)


func _sanitize_and_collect(node: Node, materials: Array[ShaderMaterial]) -> void:
	# Strip anything that would make the duplicate act like a real
	# player (movement script, physics collision, a second camera)
	# and apply the ghost material to every mesh surface we find.
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

	for child in node.get_children():
		_sanitize_and_collect(child, materials)


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
