class_name Snatcher
extends NpcCharacter
## El raponero del evento «¡Raponazo!»: sale corriendo por una ruta fija con el
## bolso. Corre un poco más despacio que Sebastián corriendo, así que se le
## alcanza si no se le pierde de vista. Si lo alcanzas, suelta el bolso
## (`caught`); si llega al final de la ruta, se pierde (`escaped`).

signal caught
signal escaped

const SPEED := 4.9
const CATCH_DISTANCE := 1.6

var route: PackedVector3Array = []
var player: Node3D
var done := false
var _i := 0


func _init() -> void:
	super({"skin": Color(0.62, 0.45, 0.33), "shirt": Color(0.2, 0.2, 0.22), "pants": Color(0.12, 0.14, 0.2),
			"cap": Color(0.15, 0.15, 0.15), "hair_style": "short"})
	display_name = "el raponero"


func think(_delta: float) -> void:
	if done:
		move_speed = 0.0
		return
	if player != null and global_position.distance_to(player.global_position) < CATCH_DISTANCE:
		done = true
		stop()
		caught.emit()
		return
	if _i >= route.size():
		done = true
		stop()
		escaped.emit()
		return
	running = true
	move_speed = SPEED
	go_to(route[_i])
	if arrived():
		_i += 1
