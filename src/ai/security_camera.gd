class_name SecurityCamera
extends Node3D
## Cámara de seguridad en una pared: gira de un lado a otro y muestra su cono
## de visión en rojo. Si te ve (con línea de vista, sin estar escondido) durante
## DETECT_TIME seguidos, da la alarma: sube el nivel de búsqueda y avisa por
## radio dónde estás. Después descansa COOLDOWN segundos.
##
## Se coloca mirando hacia -Z local (yaw = hacia dónde apunta en el centro del barrido).

signal alarm(position: Vector3)

const RANGE := 13.0
const FOV := deg_to_rad(54.0)
const PITCH := deg_to_rad(-28.0)
const SWEEP := deg_to_rad(50.0)
const SWEEP_SPEED := 0.45
const DETECT_TIME := 1.1
const COOLDOWN := 8.0
const ALARM_HEAT := 45.0

var active := true
var detect := 0.0                 ## 0..1: cuánto le falta para dar la alarma.
var sees_player := false
var wanted: WantedSystem
var _head: Node3D
var _cone: MeshInstance3D
var _led: MeshInstance3D
var _phase := 0.0
var _cooldown := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _player: PlayerController


func _ready() -> void:
	add_to_group("security_camera")
	_phase = randf() * TAU
	var mount := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.12, 0.3, 0.12)
	mount.mesh = mb
	mount.material_override = MaterialLibrary.get_material("camera_body")
	add_child(mount)
	_head = Node3D.new()
	_head.position = Vector3(0, -0.12, -0.12)
	add_child(_head)
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.22, 0.2, 0.42)
	body.mesh = bb
	body.material_override = MaterialLibrary.get_material("camera_body")
	body.position.z = -0.2
	_head.add_child(body)
	_led = MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.035
	lm.height = 0.07
	_led.mesh = lm
	_led.material_override = MaterialLibrary.get_material("light_red")
	_led.position = Vector3(0.06, 0.07, -0.42)
	_head.add_child(_led)
	# Cono de visión: un cilindro con punta, abierto, apuntando hacia -Z.
	_cone = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = tan(FOV * 0.5) * RANGE
	cm.height = RANGE
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 20
	_cone.mesh = cm
	_cone.material_override = MaterialLibrary.get_material("camera_cone")
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.rotation.x = -PI * 0.5
	_cone.position.z = -RANGE * 0.5
	var cone_pivot := Node3D.new()
	cone_pivot.position.z = -0.4
	cone_pivot.add_child(_cone)
	_head.add_child(cone_pivot)
	_ray.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.VEHICLES
	_update_head()


func _physics_process(delta: float) -> void:
	if not active:
		sees_player = false
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if _player == null:
			return
	_cooldown = maxf(0.0, _cooldown - delta)
	sees_player = can_see_player()
	if sees_player and _cooldown <= 0.0:
		detect = minf(1.0, detect + delta / DETECT_TIME)
		if detect >= 1.0:
			_raise_alarm()
	else:
		detect = maxf(0.0, detect - delta * 0.6)
		# Mientras te mira, deja de girar (te sigue con la vista).
		_phase += delta * SWEEP_SPEED
	_update_head()
	_led.visible = detect > 0.0 or int(Time.get_ticks_msec() / 500) % 2 == 0


func _update_head() -> void:
	if _head == null:
		return
	_head.rotation = Vector3(PITCH, sin(_phase) * SWEEP, 0)


## Dirección hacia donde apunta el centro del cono, en coordenadas del mundo.
func look_direction() -> Vector3:
	return -_head.global_transform.basis.z


func can_see_player() -> bool:
	if _player == null or _player.is_hidden():
		return false
	var eye := _head.global_position
	var target := _player.global_position + Vector3.UP * (0.7 if _player.crouching else 1.2)
	var to := target - eye
	var reach := RANGE * PlayerProfile.visibility_mult()
	if to.length() > reach:
		return false
	if look_direction().angle_to(to.normalized()) > FOV * 0.5:
		return false
	_ray.from = eye
	_ray.to = target
	return get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


func _raise_alarm() -> void:
	detect = 0.0
	_cooldown = COOLDOWN
	var at := _player.global_position
	if wanted != null:
		wanted.report(ALARM_HEAT, at)
	EventBus.noise.emit(at, 30.0, "alarma")
	EventBus.notify.emit("¡Una cámara te grabó! Suena la alarma.")
	AudioManager.sfx("alarm")
	alarm.emit(at)
