extends FogVolume

# Attach this to a FogVolume node, placed somewhere central in
# your level (e.g. as a sibling of WorldEnvironment). This adds
# a denser, textured fog patch on top of the base environment fog,
# and slowly drifts it to sell "wind blowing the fog through."

@export var wind_direction: Vector3 = Vector3(1, 0, 0.4)
@export var wind_speed: float = 0.8
@export var patch_size: Vector3 = Vector3(60, 15, 60)

var _start_position: Vector3
var _wind_dir_normalized: Vector3

func _ready() -> void:
	_build_fog_material()
	size = patch_size
	shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_start_position = position
	_wind_dir_normalized = wind_direction.normalized()

func _process(delta: float) -> void:
	# Drift the whole volume, then wrap it back so the motion
	# loops seamlessly instead of the fog patch drifting away
	# from your level forever.
	position += _wind_dir_normalized * wind_speed * delta

	var offset := position - _start_position
	var wrap_range := patch_size.x * 0.5

	if offset.length() > wrap_range:
		position = _start_position

func _build_fog_material() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.06

	var noise_tex := NoiseTexture3D.new()
	noise_tex.noise = noise
	noise_tex.width = 64
	noise_tex.height = 64
	noise_tex.depth = 64

	var fog_mat := FogMaterial.new()
	fog_mat.density = 3.0
	fog_mat.albedo = Color(0.6, 0.63, 0.66)
	fog_mat.emission = Color(0.5, 0.52, 0.55)
	fog_mat.height_falloff = 0.4
	fog_mat.edge_fade = 0.4
	fog_mat.density_texture = noise_tex

	material = fog_mat
