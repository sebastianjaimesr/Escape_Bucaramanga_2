class_name PoliceLights
extends Node3D
## Barra de luces de la patrulla: alterna rojo y azul. En Medio y Alto también
## ilumina el entorno con una luz puntual (en Bajo solo brillan las lámparas).

const PERIOD := 0.28

var _left: MeshInstance3D
var _right: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0
var _phase := false


func _ready() -> void:
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.12, 0.3)
	base.mesh = bm
	base.material_override = MaterialLibrary.get_material("rail")
	add_child(base)
	_left = _lamp(Vector3(-0.35, 0.1, 0))
	_right = _lamp(Vector3(0.35, 0.1, 0))
	if Settings.quality_profile() != "bajo":
		_light = OmniLight3D.new()
		_light.position = Vector3(0, 0.4, 0)
		_light.omni_range = 7.0
		_light.light_energy = 2.0
		_light.shadow_enabled = false
		add_child(_light)
	_apply()


func _lamp(pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.45, 0.14, 0.26)
	mi.mesh = m
	mi.position = pos
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if _t >= PERIOD:
		_t = 0.0
		_phase = not _phase
		_apply()


func _apply() -> void:
	_left.material_override = MaterialLibrary.get_material("light_red" if _phase else "light_off")
	_right.material_override = MaterialLibrary.get_material("light_off" if _phase else "light_blue")
	if _light != null:
		_light.light_color = Color(1, 0.15, 0.1) if _phase else Color(0.2, 0.35, 1.0)
