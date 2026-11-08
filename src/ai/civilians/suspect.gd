class_name Suspect
extends Civilian
## Persona de la plaza en el capítulo 2. Una de ellas es el ladrón del sobre
## de la natillera (chaqueta verde y morral naranja); las demás comparten solo
## un detalle con lo que dijo la testigo.
##
## El ladrón, una vez señalado, camina hasta su escondite por una ruta fija.
## Cada tanto se detiene y mira hacia atrás (LOOK_BACK): si te ve en ese
## momento, se da cuenta de que lo siguen. En el escondite deja el sobre en una
## caneca y la vigila (GUARD); un ruido cercano (una lata) lo hace ir a mirar
## (INVESTIGATE). Cuando le quitan el sobre, sale corriendo (FLEE).
##
## Este nodo solo dice si ve al jugador (sees_player); qué pasa entonces lo
## decide RoboPlazaMission.

signal reached_hideout
signal noise_heard(position: Vector3)

enum Mode { IDLE, WALK, LOOK_BACK, GUARD, INVESTIGATE, FLEE }

const WALK_SPEED := 1.7
const LOOK_EVERY := Vector2(6.0, 10.0)
const LOOK_TIME := 2.6
const SIGHT := 14.0
const GUARD_SIGHT := 10.0
const FOV := deg_to_rad(120.0)
const INVESTIGATE_TIME := 7.0
const EYE_HEIGHT := 1.55

var is_thief := false
var mode: Mode = Mode.IDLE
var path: PackedVector3Array = []
var path_index := 0
var guard_point := Vector3.ZERO
var sees_player := false

var _timer := 0.0
var _noise_point := Vector3.INF
var _look_phase := 0.0
var _player: PlayerController
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	super()
	add_to_group("suspect")
	_ray.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.VEHICLES
	_ray.exclude = [get_rid()]
	EventBus.noise.connect(_on_noise)


## Empieza a caminar hacia el escondite.
func start_walk(route: PackedVector3Array) -> void:
	path = route
	path_index = 0
	guard_point = route[route.size() - 1]
	interactable.enabled = false
	_set_mode(Mode.WALK)


## Vuelve a poner al ladrón al principio de la ruta (al reintentar el seguimiento).
func restart_walk() -> void:
	if path.is_empty():
		return
	place(path[0])
	path_index = 0
	_set_mode(Mode.WALK)


## Lo pone directo en su escondite (al cargar una partida).
func place_at_hideout() -> void:
	place(guard_point if guard_point != Vector3.ZERO else path[path.size() - 1])
	path_index = path.size()
	_set_mode(Mode.GUARD)


func flee(to: Vector3) -> void:
	running = true
	go_to(to)
	_set_mode(Mode.FLEE)


func think(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	match mode:
		Mode.IDLE:
			sees_player = false
			super(delta)
		Mode.WALK:
			_walk(delta)
		Mode.LOOK_BACK:
			_look_back(delta)
		Mode.GUARD:
			_guard(delta)
		Mode.INVESTIGATE:
			_investigate(delta)
		Mode.FLEE:
			sees_player = false
			move_speed = 4.5
			if arrived():
				visible = false
				move_speed = 0.0


func _walk(delta: float) -> void:
	sees_player = false
	running = false
	move_speed = WALK_SPEED
	_look_target = Vector3.INF
	if path_index >= path.size():
		_set_mode(Mode.GUARD)
		reached_hideout.emit()
		return
	go_to(path[path_index])
	if arrived():
		path_index += 1
	_timer -= delta
	if _timer <= 0.0 and path_index > 0 and path_index < path.size():
		_set_mode(Mode.LOOK_BACK)


func _look_back(delta: float) -> void:
	move_speed = 0.0
	stop()
	# Mira hacia atrás, por donde venía.
	var back := path[maxi(0, path_index - 1)]
	if global_position.distance_to(back) < 2.0:
		back = path[maxi(0, path_index - 2)]
	face(back)
	sees_player = can_see_player(SIGHT)
	_timer -= delta
	if _timer <= 0.0:
		_set_mode(Mode.WALK)


func _guard(delta: float) -> void:
	move_speed = WALK_SPEED
	if global_position.distance_to(guard_point) > 1.0:
		go_to(guard_point)
		sees_player = false
		return
	move_speed = 0.0
	_look_phase += delta * 0.7
	# Mira de un lado a otro del patio.
	face(global_position + Vector3(sin(_look_phase), 0, cos(_look_phase) * 0.6 + 0.4))
	sees_player = can_see_player(GUARD_SIGHT)


func _investigate(delta: float) -> void:
	sees_player = false
	move_speed = 1.5
	go_to(_noise_point)
	if arrived():
		move_speed = 0.0
		_timer -= delta
		_look_phase += delta * 2.0
		visual.look_around(sin(_look_phase) * 0.8)
		if _timer <= 0.0:
			visual.look_around(0.0)
			_set_mode(Mode.GUARD)


func _on_noise(pos: Vector3, radius: float, _source: String) -> void:
	if not is_thief or not is_inside_tree() or mode != Mode.GUARD:
		return
	if global_position.distance_to(pos) > radius:
		return
	_noise_point = pos
	noise_heard.emit(pos)
	_set_mode(Mode.INVESTIGATE)


func can_see_player(reach: float) -> bool:
	if _player == null or _player.is_hidden():
		return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target := _player.global_position + Vector3.UP * (0.7 if _player.crouching else 1.3)
	var to := target - eye
	var r := reach * PlayerProfile.visibility_mult() * (0.55 if _player.crouching else 1.0)
	if to.length() > r:
		return false
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > 0.5 and forward().angle_to(flat.normalized()) > FOV * 0.5:
		return false
	_ray.from = eye
	_ray.to = target
	return get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


func _set_mode(m: Mode) -> void:
	mode = m
	match m:
		Mode.WALK:
			_timer = randf_range(LOOK_EVERY.x, LOOK_EVERY.y)
		Mode.LOOK_BACK:
			_timer = LOOK_TIME
		Mode.INVESTIGATE:
			_timer = INVESTIGATE_TIME
