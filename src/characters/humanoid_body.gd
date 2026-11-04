class_name HumanoidBody
extends Node3D
## Cuerpo humano hecho con primitivas, compartido por Sebastián, la policía,
## los amigos, el vendedor y los peatones. Cada uno cambia la paleta y los
## accesorios (gorra, chaleco, mochila, pulsera) y las proporciones.
##
## Articulaciones: cadera → muslo → rodilla → pierna; hombro → brazo → codo →
## antebrazo. animate() mueve el ciclo de caminar/correr, el agacharse y la
## inclinación. Mira hacia -Z (el dueño gira este nodo con rotation.y).
## Es provisional: el modelo animado definitivo llega en la Fase 3.

## Paleta y opciones. Las claves que falten usan DEFAULTS.
var look: Dictionary = {}

const DEFAULTS := {
	"skin": Color(0.72, 0.52, 0.4),
	"hair": Color(0.09, 0.07, 0.06),
	"shirt": Color(0.5, 0.5, 0.55),
	"sleeves": true,           ## Mangas largas del color de la camisa.
	"pants": Color(0.2, 0.3, 0.5),
	"shoes": Color(0.93, 0.93, 0.92),
	"shoe_accent": Color(0.3, 0.3, 0.3),
	"height": 1.0,             ## Escala vertical (Diaz es más alto).
	"girth": 1.0,              ## Escala del torso (Gordo es más ancho).
	"hair_style": "short",     ## short, long, bald
	"cap": null,               ## Color de la gorra o null.
	"vest": null,              ## Color del chaleco reflectivo o null.
	"backpack": null,          ## Color de la mochila o null.
	"bracelet": false,
	"belt": Color(0.1, 0.08, 0.07),
}

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _phase := 0.0
var _stride := 0.0
var _crouch := 0.0
var _lean := 0.0
var _materials: Dictionary = {}


func _init(options: Dictionary = {}) -> void:
	look = DEFAULTS.duplicate()
	look.merge(options, true)


func _ready() -> void:
	var h: float = look["height"]
	var g: float = look["girth"]
	scale = Vector3(1.0, h, 1.0)
	_hips = _pivot(self, Vector3(0, 0.92, 0))
	_part(_hips, _box(Vector3(0.32 * g, 0.16, 0.2 * g)), Vector3(0, 0.0, 0), "pants")
	_part(_hips, _box(Vector3(0.33 * g, 0.05, 0.21 * g)), Vector3(0, 0.07, 0), "belt")
	for side: float in [-1.0, 1.0]:
		var thigh := _pivot(_hips, Vector3(side * 0.1 * g, -0.04, 0))
		_part(thigh, _capsule(0.08, 0.48), Vector3(0, -0.22, 0), "pants")
		var knee := _pivot(thigh, Vector3(0, -0.43, 0))
		_part(knee, _capsule(0.068, 0.46), Vector3(0, -0.2, 0), "pants")
		_part(knee, _box(Vector3(0.12, 0.09, 0.27)), Vector3(0, -0.42, -0.04), "shoes")
		_part(knee, _sphere(0.062), Vector3(0, -0.41, -0.15), "shoes")
		_part(knee, _box(Vector3(0.125, 0.03, 0.22)), Vector3(0, -0.385, -0.03), "shoe_accent")
		_thighs.append(thigh)
		_knees.append(knee)
	_torso = _pivot(_hips, Vector3(0, 0.06, 0))
	var chest := _part(_torso, _capsule(0.17, 0.6), Vector3(0, 0.27, 0), "shirt")
	chest.scale = Vector3(1.12 * g, 1.0, 0.72 * g)
	if look["vest"] != null:
		var vest := _part(_torso, _capsule(0.175, 0.44), Vector3(0, 0.3, 0), "vest")
		vest.scale = Vector3(1.16 * g, 1.0, 0.78 * g)
		_part(_torso, _box(Vector3(0.36 * g, 0.035, 0.27 * g)), Vector3(0, 0.27, 0), "stripe")
	if look["backpack"] != null:
		_part(_torso, _box(Vector3(0.3, 0.38, 0.14)), Vector3(0, 0.33, 0.13 * g + 0.06), "backpack")
		for side: float in [-1.0, 1.0]:
			_part(_torso, _box(Vector3(0.04, 0.4, 0.3 * g)), Vector3(side * 0.11, 0.38, 0.0), "backpack")
	_part(_torso, _cylinder(0.05, 0.1), Vector3(0, 0.6, 0), "skin")  # cuello
	_head = _pivot(_torso, Vector3(0, 0.72, 0))
	var skull := _part(_head, _sphere(0.115), Vector3.ZERO, "skin")
	skull.scale = Vector3(0.95, 1.08, 1.0)
	for side: float in [-1.0, 1.0]:
		_part(_head, _sphere(0.018), Vector3(side * 0.04, 0.02, -0.103), "eyes")
		_part(_head, _sphere(0.025), Vector3(side * 0.112, 0.0, 0.0), "skin")   # orejas
	_part(_head, _box(Vector3(0.03, 0.04, 0.04)), Vector3(0, -0.015, -0.115), "skin")  # nariz
	match String(look["hair_style"]):
		"short":
			var hair := _part(_head, _hemisphere(0.122), Vector3(0, 0.015, 0.008), "hair")
			hair.scale = Vector3(0.98, 1.0, 1.04)
		"long":
			var hair2 := _part(_head, _hemisphere(0.126), Vector3(0, 0.012, 0.01), "hair")
			hair2.scale = Vector3(1.0, 1.05, 1.06)
			_part(_head, _box(Vector3(0.2, 0.2, 0.08)), Vector3(0, -0.08, 0.07), "hair")
	if look["cap"] != null:
		var cap := _part(_head, _hemisphere(0.128), Vector3(0, 0.03, 0.0), "cap")
		cap.scale = Vector3(1.0, 0.8, 1.04)
		_part(_head, _box(Vector3(0.18, 0.02, 0.1)), Vector3(0, 0.035, -0.15), "cap")
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(_torso, Vector3(side * 0.225 * g, 0.5, 0))
		_part(arm, _sphere(0.065), Vector3.ZERO, "shirt")
		_part(arm, _capsule(0.055, 0.32), Vector3(0, -0.14, 0), "shirt")
		var elbow := _pivot(arm, Vector3(0, -0.29, 0))
		_part(elbow, _capsule(0.048, 0.28), Vector3(0, -0.12, 0), "shirt" if look["sleeves"] else "skin")
		_part(elbow, _sphere(0.048), Vector3(0, -0.29, 0), "skin")
		if look["bracelet"] and side > 0.0:
			_part(elbow, _cylinder(0.054, 0.03), Vector3(0, -0.23, 0), "bracelet")
		_arms.append(arm)
		_elbows.append(elbow)
		arm.rotation.z = side * 0.06


## speed en m/s, run_speed la velocidad de carrera de ese personaje.
func animate(speed: float, run_speed: float, on_floor: bool, crouching: bool, running: bool, delta: float) -> void:
	if on_floor and speed > 0.1:
		_phase += delta * (4.0 + speed * 1.6)
		_stride = move_toward(_stride, clampf(speed / run_speed, 0.25, 1.0), delta * 6.0)
	else:
		_stride = move_toward(_stride, 0.0, delta * 5.0)
		if speed <= 0.1:
			_phase = lerpf(_phase, roundf(_phase / PI) * PI, clampf(delta * 6.0, 0.0, 1.0))
	var swing := sin(_phase) * 0.75 * _stride
	for i in 2:
		var s := swing if i == 0 else -swing
		if on_floor:
			_thighs[i].rotation.x = s
			# La rodilla se dobla cuando la pierna va hacia atrás.
			_knees[i].rotation.x = -(maxf(0.0, -s) * 1.3 + 0.1 * _stride)
		else:
			_thighs[i].rotation.x = -0.5 if i == 0 else 0.3
			_knees[i].rotation.x = -0.6 if i == 0 else -0.3
		_arms[i].rotation.x = -s * 0.9
		_elbows[i].rotation.x = 0.25 + (0.9 if running else 0.25) * _stride
	# Respiración leve cuando está quieto.
	var breathe := sin(Time.get_ticks_msec() * 0.002) * 0.008
	_crouch = move_toward(_crouch, 1.0 if crouching else 0.0, delta * 6.0)
	_hips.position.y = lerpf(0.92, 0.58, _crouch) + absf(sin(_phase)) * 0.035 * _stride + breathe
	for i in 2:
		_thighs[i].rotation.x += 1.25 * _crouch
		_knees[i].rotation.x += -1.6 * _crouch
	var target_lean := 0.25 if running else (0.08 if speed > 0.1 else 0.0)
	_lean = lerpf(_lean, target_lean + 0.35 * _crouch, clampf(delta * 8.0, 0.0, 1.0))
	_torso.rotation.x = -_lean
	_head.rotation.x = _lean * 0.6


## Gira la cabeza (para mirar alrededor al buscar).
func look_around(amount: float) -> void:
	_head.rotation.y = amount


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _material(key)
	parent.add_child(mi)
	return mi


func _material(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.75
	match key:
		"eyes":
			m.albedo_color = Color(0.05, 0.04, 0.04)
			m.roughness = 0.2
		"stripe":
			m.albedo_color = Color(0.85, 0.85, 0.85)
			m.metallic = 0.6
			m.roughness = 0.3
		"bracelet":
			m.albedo_color = Color(0.85, 0.65, 0.2)
			m.metallic = 0.8
			m.roughness = 0.35
		"skin":
			m.albedo_color = look["skin"]
			m.roughness = 0.6
		"vest":
			m.albedo_color = look["vest"]
			m.emission_enabled = true
			m.emission = look["vest"]
			m.emission_energy_multiplier = 0.15
		_:
			m.albedo_color = look.get(key, Color.MAGENTA)
	_materials[key] = m
	return m


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


static func _hemisphere(r: float) -> SphereMesh:
	var m := _sphere(r)
	m.is_hemisphere = true
	m.height = r
	return m


static func _cylinder(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 12
	return m
