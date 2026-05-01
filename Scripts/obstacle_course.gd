class_name ObstacleCourse
extends Node3D

## Creates a test obstacle course with ramps, turns, and obstacles

@export_group("Ramp Settings")
@export var ramp_length: float = 8.0
@export var ramp_height: float = 4.0
@export var ramp_width: float = 6.0

@export_group("Wall Settings")
@export var wall_height: float = 4.0
@export var wall_thickness: float = 1.0

@export_group("Pillar Settings")
@export var pillar_radius: float = 2.0
@export var pillar_height: float = 8.0

# Materials
var _ramp_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _pillar_mat: StandardMaterial3D

func _ready() -> void:
	_setup_materials()
	_build_course()

func _setup_materials() -> void:
	_ramp_mat = StandardMaterial3D.new()
	_ramp_mat.albedo_color = Color(0.3, 0.7, 0.9, 1.0)  # Light blue
	_ramp_mat.metallic = 0.3
	_ramp_mat.roughness = 0.4
	
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.9, 0.3, 0.3, 1.0)  # Red
	_wall_mat.metallic = 0.2
	_wall_mat.roughness = 0.5
	
	_pillar_mat = StandardMaterial3D.new()
	_pillar_mat.albedo_color = Color(0.9, 0.9, 0.3, 1.0)  # Yellow
	_pillar_mat.metallic = 0.4
	_pillar_mat.roughness = 0.3

func _build_course() -> void:
	# Starting platform with some pillars for weaving
	_create_pillar_at(Vector3(-15, 4, 10))
	_create_pillar_at(Vector3(-15, 4, -10))
	
	# First ramp going up
	var ramp1 = _create_ramp(Vector3(0, 0, 0), Vector3(0, 0, 1), ramp_length, ramp_height)
	add_child(ramp1)
	
	# Platform after first ramp
	_create_platform(Vector3(ramp_length * 0.5, ramp_height, 0), ramp_length, ramp_width)
	
	# Second ramp going up (steeper)
	var ramp2 = _create_ramp(Vector3(ramp_length, ramp_height, 0), Vector3(0, 0, 1), ramp_length * 0.7, ramp_height * 1.5)
	add_child(ramp2)
	
	# Elevated platform with pillars for slalom
	_create_platform(Vector3(ramp_length + ramp_length * 0.35, ramp_height * 2.5, 0), ramp_length * 0.7, ramp_width * 1.5)
	_create_pillar_at(Vector3(ramp_length + ramp_length * 0.35, 6, -6))
	_create_pillar_at(Vector3(ramp_length + ramp_length * 0.35, 6, 6))
	_create_pillar_at(Vector3(ramp_length + ramp_length * 0.35 + 8, 6, 0))
	
	# Turn platform with walls (90 degree turn)
	_create_platform(Vector3(ramp_length * 2 + 4, ramp_height * 2.5, 0), 10, 10)
	_create_wall(Vector3(ramp_length * 2 + 4, wall_height * 0.5, -10), Vector3(0, 0, 1), 10, wall_height)
	_create_wall(Vector3(ramp_length * 2 + 4, wall_height * 0.5, 10), Vector3(0, 0, 1), 10, wall_height)
	
	# Descending ramp
	var ramp3 = _create_ramp(Vector3(ramp_length * 2 + 4, ramp_height * 2.5, 10), Vector3(0, 0, 1), ramp_length, -ramp_height * 1.5)
	add_child(ramp3)
	
	# Lower platform with tight obstacles
	_create_platform(Vector3(ramp_length * 2 + 4, ramp_height, 30), 20, 8)
	_create_pillar_at(Vector3(ramp_length * 2 + 4, 4, 25))
	_create_pillar_at(Vector3(ramp_length * 2 + 4, 4, 35))
	_create_pillar_at(Vector3(ramp_length * 2 + 14, 4, 30))
	
	# Curved section - walls creating a channel
	_create_wall(Vector3(ramp_length * 2 + 4, wall_height * 0.5, 40), Vector3(0, 0, 1), 20, wall_height)
	_create_wall(Vector3(ramp_length * 2 + 4 + 20, wall_height * 0.5, 40), Vector3(0, 0, 1), 20, wall_height)
	_create_wall(Vector3(ramp_length * 2 + 4, wall_height * 0.5, 45), Vector3(0, 0, 1), 20, wall_height)
	_create_wall(Vector3(ramp_length * 2 + 4 + 20, wall_height * 0.5, 45), Vector3(0, 0, 1), 20, wall_height)
	
	# Gap jump section
	_create_platform(Vector3(ramp_length * 2 + 4 + 20, ramp_height, 50), 10, 8)
	
	# Final platform
	_create_platform(Vector3(ramp_length * 2 + 4 + 20, ramp_height, 70), 15, 15)
	_create_pillar_at(Vector3(ramp_length * 2 + 4 + 20, 4, 65))
	_create_pillar_at(Vector3(ramp_length * 2 + 4 + 20, 4, 75))
	_create_pillar_at(Vector3(ramp_length * 2 + 4 + 20 + 5, 4, 70))

func _create_ramp(pos: Vector3, direction: Vector3, length: float, rise: float) -> StaticBody3D:
	var ramp = StaticBody3D.new()
	ramp.name = "Ramp"
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	
	# Create box mesh for ramp
	var box = BoxMesh.new()
	box.size = Vector3(ramp_width, 0.5, length)
	mesh_instance.mesh = box
	mesh_instance.material_override = _ramp_mat
	
	# Calculate rotation and position
	var angle = atan2(rise, length)
	var rotation_deg = rad_to_deg(angle)
	
	# Rotate around X axis for Z-direction ramp
	var basis = Basis()
	basis = basis.rotated(Vector3.RIGHT, angle)
	
	# Position the mesh at the center of the ramp
	var center_offset = Vector3(0, rise * 0.5, length * 0.5)
	mesh_instance.transform = Transform3D(basis, center_offset)
	
	ramp.add_child(mesh_instance)
	
	# Create collision shape
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	
	# Create a box shape for the ramp collision
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(ramp_width, 0.5, length)
	collision.shape = box_shape
	collision.transform = Transform3D(basis, center_offset)
	
	ramp.add_child(collision)
	
	# Set initial transform
	var initial_transform = Transform3D()
	initial_transform = initial_transform.translated(pos)
	ramp.transform = initial_transform
	
	return ramp

func _create_platform(pos: Vector3, size_x: float, size_z: float) -> StaticBody3D:
	var platform = StaticBody3D.new()
	platform.name = "Platform"
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	
	var box = BoxMesh.new()
	box.size = Vector3(size_x, 0.5, size_z)
	mesh_instance.mesh = box
	mesh_instance.material_override = _ramp_mat
	
	platform.add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(size_x, 0.5, size_z)
	collision.shape = box_shape
	
	platform.add_child(collision)
	
	platform.transform = Transform3D().translated(pos)
	
	add_child(platform)
	return platform

func _create_wall(pos: Vector3, facing: Vector3, length: float, height: float) -> StaticBody3D:
	var wall = StaticBody3D.new()
	wall.name = "Wall"
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	
	var box = BoxMesh.new()
	box.size = Vector3(wall_thickness, height, length)
	mesh_instance.mesh = box
	mesh_instance.material_override = _wall_mat
	
	wall.add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(wall_thickness, height, length)
	collision.shape = box_shape
	
	wall.add_child(collision)
	
	wall.transform = Transform3D().translated(pos)
	
	add_child(wall)
	return wall

func _create_pillar_at(pos: Vector3) -> StaticBody3D:
	var pillar = StaticBody3D.new()
	pillar.name = "Pillar"
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = pillar_radius
	cylinder.bottom_radius = pillar_radius
	cylinder.height = pillar_height
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = _pillar_mat
	
	pillar.add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var cylinder_shape = CylinderShape3D.new()
	cylinder_shape.height = pillar_height
	cylinder_shape.radius = pillar_radius
	collision.shape = cylinder_shape
	
	pillar.add_child(collision)
	
	pillar.transform = Transform3D().translated(Vector3(pos.x, pillar_height * 0.5, pos.z))
	
	add_child(pillar)
	return pillar
