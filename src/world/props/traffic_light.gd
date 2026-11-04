class_name TrafficLight
extends Node3D
## Semáforo decorativo con ciclo real (verde, amarillo, rojo). Los dos ejes del
## cruce ("ns" y "ew") están sincronizados con el reloj del juego: cuando uno
## está en verde, el otro está en rojo.

const GREEN_TIME := 8.0
const YELLOW_TIME := 2.0
const CYCLE := (GREEN_TIME + YELLOW_TIME) * 2.0

var axis := "ns"
var _lamps: Dictionary = {}
var _state := ""
var _time := 0.0


func _ready() -> void:
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.09
	pm.height = 3.2
	pole.mesh = pm
	pole.position.y = 1.6
	pole.material_override = MaterialLibrary.get_material("rail")
	add_child(pole)
	var housing := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.36, 1.0, 0.3)
	housing.mesh = hm
	housing.position = Vector3(0, 3.4, 0)
	housing.material_override = MaterialLibrary.get_material("rail")
	add_child(housing)
	var i := 0
	for color: String in ["red", "yellow", "green"]:
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.22
		sm.radial_segments = 10
		sm.rings = 5
		lamp.mesh = sm
		lamp.position = Vector3(0, 3.72 - i * 0.31, -0.13)
		add_child(lamp)
		_lamps[color] = lamp
		i += 1
	_update(true)


func _process(delta: float) -> void:
	_time += delta
	_update(false)


func current_state() -> String:
	var t := fmod(_time + (0.0 if axis == "ns" else GREEN_TIME + YELLOW_TIME), CYCLE)
	if t < GREEN_TIME:
		return "green"
	if t < GREEN_TIME + YELLOW_TIME:
		return "yellow"
	return "red"


func _update(force: bool) -> void:
	var s := current_state()
	if s == _state and not force:
		return
	_state = s
	for color: String in _lamps:
		var on := color == s
		(_lamps[color] as MeshInstance3D).material_override = MaterialLibrary.get_material(
				"light_" + color if on else "light_off")
