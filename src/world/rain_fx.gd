class_name RainFx
extends Node3D
## Lluvia: gotas (partículas alargadas) en una caja alrededor del jugador, que
## lo sigue. Con «Reducir movimiento» hay menos gotas. Suena el ambiente de
## lluvia mientras exista.

const AREA := Vector3(36.0, 1.0, 36.0)
const HEIGHT := 14.0

var _particles: CPUParticles3D
var _player: Node3D


func _ready() -> void:
	_particles = CPUParticles3D.new()
	_particles.amount = 500 if bool(Settings.get_value("interface", "reduce_motion")) else 1400
	_particles.lifetime = 1.0
	_particles.preprocess = 1.0
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = AREA * 0.5
	_particles.direction = Vector3(0.08, -1.0, 0.0)
	_particles.spread = 2.0
	_particles.gravity = Vector3(0, -9.8, 0)
	_particles.initial_velocity_min = 14.0
	_particles.initial_velocity_max = 18.0
	_particles.local_coords = false
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.82, 0.95, 0.35)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = mat
	_particles.mesh = drop
	_particles.position.y = HEIGHT
	add_child(_particles)
	AudioManager.set_rain(true)


func _exit_tree() -> void:
	AudioManager.set_rain(false)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	global_position = Vector3(_player.global_position.x, 0.0, _player.global_position.z)
