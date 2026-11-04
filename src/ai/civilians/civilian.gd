class_name Civilian
extends NpcCharacter
## Personaje civil con quien se puede hablar (E): peatones que caminan entre
## puntos de la acera, el vendedor de granizados y los amigos de Sebastián.
## Si tiene puntos de paseo, camina entre ellos; si no, se queda en su sitio.
## Al hablarle se detiene y mira al jugador unos segundos.

const TALK_PAUSE := 3.5

var wander_points: PackedVector3Array = []
var walk_speed := 1.3
var lines: PackedStringArray = []
var interactable: Interactable
## Si se asigna, reemplaza la conversación normal (vendedor, amigos).
var on_talk: Callable

var _wait := 0.0
var _talk_timer := 0.0
var _line := 0
var _target := Vector3.INF
var _home := Vector3.ZERO
var _home_yaw := 0.0


func _ready() -> void:
	super()
	add_to_group("civilian")
	interactable = Interactable.new("Hablar con %s" % display_name, 1.8)
	interactable.action = _talk
	add_child(interactable)
	_home = global_position
	_home_yaw = facing_yaw
	_wait = randf_range(0.0, 2.0)


func _talk(player: PlayerController) -> void:
	_talk_timer = TALK_PAUSE
	stop()
	face(player.global_position)
	if on_talk.is_valid():
		on_talk.call(player)
		return
	if lines.is_empty():
		return
	EventBus.notify.emit("%s: «%s»" % [display_name, lines[_line % lines.size()]])
	_line += 1


func think(delta: float) -> void:
	if _talk_timer > 0.0:
		_talk_timer -= delta
		move_speed = 0.0
		return
	if wander_points.is_empty():
		move_speed = 0.0
		_look_target = global_position + Vector3(-sin(_home_yaw), 0, -cos(_home_yaw))
		return
	_look_target = Vector3.INF
	if _wait > 0.0:
		_wait -= delta
		move_speed = 0.0
		return
	if _target == Vector3.INF:
		_target = wander_points[randi() % wander_points.size()]
	move_speed = walk_speed
	go_to(_target)
	if arrived():
		_target = Vector3.INF
		_wait = randf_range(1.5, 5.0)
