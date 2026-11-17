class_name StrayDog
extends Node3D
## Firulais, el perro de Doña Carmen (misión secundaria «¿Dónde está
## Firulais?»). Hecho con primitivas: cuerpo, cabeza, orejas, cola y cuatro
## patas que se mueven al caminar. Espera en el bosque moviendo la cola; al
## llamarlo (Interactuar) sigue al jugador a un par de metros, y al llegar
## donde su dueña se sienta a su lado. No tiene colisión (no estorba).

signal called

const FOLLOW_DISTANCE := 1.8
const MAX_SPEED := 7.5

var interactable: Interactable
## "waiting", "following" o "home".
var mode := "waiting"
var target: Node3D
var home := Vector3.ZERO
var _legs: Array[Node3D] = []
var _tail: Node3D
var _t := 0.0
var _speed := 0.0


func _ready() -> void:
	name = "Firulais"
	add_to_group("dog")
	var fur := MaterialLibrary.get_material("dog_fur")
	var dark := MaterialLibrary.get_material("bark")
	var body := _mesh(_box(Vector3(0.28, 0.26, 0.62)), Vector3(0, 0.46, 0), fur)
	body.name = "Cuerpo"
	_mesh(_box(Vector3(0.24, 0.22, 0.26)), Vector3(0, 0.66, -0.4), fur)
	_mesh(_box(Vector3(0.14, 0.11, 0.16)), Vector3(0, 0.62, -0.58), fur)
	_mesh(_sphere(0.035), Vector3(0, 0.65, -0.67), dark)
	for s: float in [-1.0, 1.0]:
		var ear := _mesh(_box(Vector3(0.06, 0.14, 0.08)), Vector3(s * 0.1, 0.8, -0.37), dark)
		ear.rotation.z = s * 0.35
		_mesh(_sphere(0.022), Vector3(s * 0.06, 0.7, -0.53), MaterialLibrary.get_material("rail"))
	for p: Vector3 in [Vector3(-0.1, 0.33, -0.22), Vector3(0.1, 0.33, -0.22), Vector3(-0.1, 0.33, 0.22), Vector3(0.1, 0.33, 0.22)]:
		var pivot := Node3D.new()
		pivot.position = p
		add_child(pivot)
		var leg := MeshInstance3D.new()
		leg.mesh = _box(Vector3(0.07, 0.33, 0.07))
		leg.position = Vector3(0, -0.165, 0)
		leg.material_override = fur
		pivot.add_child(leg)
		_legs.append(pivot)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.55, 0.3)
	add_child(_tail)
	var tail := MeshInstance3D.new()
	tail.mesh = _box(Vector3(0.05, 0.05, 0.28))
	tail.position = Vector3(0, 0.06, 0.12)
	tail.rotation.x = -0.5
	tail.material_override = fur
	_tail.add_child(tail)
	interactable = Interactable.new("Llamar a Firulais", 1.6)
	interactable.position.y = 0.5
	interactable.action = func(_p: PlayerController) -> void: called.emit()
	add_child(interactable)


func follow(node: Node3D) -> void:
	target = node
	mode = "following"
	interactable.enabled = false


func sit_at(pos: Vector3) -> void:
	mode = "home"
	home = pos
	target = null


func _process(delta: float) -> void:
	_t += delta
	var goal := global_position
	if mode == "following" and target != null:
		var to := target.global_position - global_position
		to.y = 0.0
		# Si se queda muy atrás (tirolesa, techos, atajos), aparece detrás del jugador.
		if to.length() > 25.0:
			global_position = target.global_position - target.global_basis.z * -FOLLOW_DISTANCE
			to = target.global_position - global_position
			to.y = 0.0
		if to.length() > FOLLOW_DISTANCE:
			goal = target.global_position - to.normalized() * FOLLOW_DISTANCE
	elif mode == "home":
		goal = home
	var flat := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	var want := clampf(flat.length() * 3.0, 0.0, MAX_SPEED)
	_speed = move_toward(_speed, want, 14.0 * delta)
	if flat.length() > 0.05 and _speed > 0.05:
		var step := flat.normalized() * minf(_speed * delta, flat.length())
		global_position += step
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), clampf(10.0 * delta, 0.0, 1.0))
	# Siempre en el suelo del parque (no sube a techos ni bancas).
	global_position.y = PrototypeBlockBuilder.CURB_HEIGHT
	var swing := sin(_t * 14.0) * 0.6 * clampf(_speed / 3.0, 0.0, 1.0)
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 3 == 0 else -1.0)
	_tail.rotation.y = sin(_t * (16.0 if mode != "waiting" or _speed < 0.1 else 8.0)) * 0.6


func _mesh(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 4
	return m
