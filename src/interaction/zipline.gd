class_name Zipline
extends Node3D
## Tirolesa: un cable entre dos puntos. Con Interactuar en la salida, Sebastián
## se cuelga de la roldana y baja deslizándose (estado "Zipline" del jugador).
## Saltar en el aire lo suelta antes. `enabled = false` la deja bloqueada.
##
## Los puntos `start` y `end` son los pies del jugador al subir y al bajar; el
## cable va HANG metros más arriba.

signal ridden(player: PlayerController)
signal arrived(player: PlayerController)

const HANG := 2.15
const SPEED := 13.0

var start := Vector3.ZERO
var end := Vector3.ZERO
var enabled := true:
	set(value):
		enabled = value
		if interactable != null:
			interactable.enabled = value
var interactable: Interactable
var rides := 0


func _init(from: Vector3, to: Vector3) -> void:
	start = from
	end = to
	name = "Tirolesa"


func _ready() -> void:
	add_to_group("zipline")
	var a := start + Vector3.UP * HANG
	var b := end + Vector3.UP * HANG
	var cable := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	cable.mesh = mesh
	cable.material_override = MaterialLibrary.get_material("zip_cable")
	cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# El cilindro va en Y: se orienta de a hacia b.
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	cable.basis = Basis(side, dir, side.cross(dir))
	cable.position = (a + b) * 0.5
	add_child(cable)
	interactable = Interactable.new("Bajar por la tirolesa", 1.3)
	interactable.position = start
	interactable.action = ride
	add_child(interactable)
	interactable.enabled = enabled


func ride(player: PlayerController) -> void:
	if not enabled or player.state_machine.current_name == &"Zipline":
		return
	rides += 1
	player.state_machine.change_state(&"Zipline", {"from": start, "to": end, "speed": SPEED, "line": self})
	AudioManager.sfx("zip_start")
	ridden.emit(player)


## Punto del cable (en los pies) a una fracción t del recorrido.
func point_at(t: float) -> Vector3:
	return start.lerp(end, clampf(t, 0.0, 1.0))
