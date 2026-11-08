class_name PoliceOfficer
extends NpcCharacter
## Policía a pie (ficticia, sin violencia: si te alcanza, te "atrapa" y vuelves
## a empezar desde donde están tus amigos).
##
## Estados:
##   PATROL      recorre su ruta caminando.
##   SUSPICIOUS  vio algo: se detiene, mira y se acerca despacio mientras sube la alerta.
##   CHASE       te persigue corriendo; si te pierde de vista va a donde te vio por última vez.
##   SEARCH      revisa la zona donde te perdió durante unos segundos.
##   RETURN      vuelve al punto más cercano de su ruta.
##
## Percepción: cono de visión de 110° con línea de vista (los edificios y los
## carros tapan), alcance menor si vas agachado y mayor si corres. Si corres
## cerca, te oye aunque estés detrás. Escondido en un matorral no te ve.

enum State { PATROL, SUSPICIOUS, CHASE, SEARCH, RETURN }

const STATE_NAMES := ["Patrulla", "Sospecha", "Persecución", "Búsqueda", "Regreso"]

const PATROL_SPEED := 1.5
const APPROACH_SPEED := 1.9
const SEARCH_SPEED := 2.8
const CHASE_SPEED := 5.2          ## Un poco menos que correr (5,8): se escapa corriendo, pero la resistencia se acaba.

const VIEW_RANGE := 17.0
const VIEW_FOV := deg_to_rad(110.0)
const CLOSE_SENSE := 1.6          ## Tan cerca, te nota aunque estés detrás.
const HEAR_RANGE := 6.0           ## Te oye correr a esta distancia.
const CROUCH_RANGE_MULT := 0.5
const RUN_RANGE_MULT := 1.2
const EYE_HEIGHT := 1.6

const ALERT_DECAY := 0.3          ## Por segundo, sin verte.
const LOSE_TIME := 1.6            ## Segundos sin verte antes de dejar de perseguir a ciegas.
const SEARCH_TIME := 9.0
const CATCH_DISTANCE := 1.25
const RADIO_RANGE := 35.0

var state: State = State.PATROL
var route: PackedVector3Array = []
var route_index := 0
var alert := 0.0                  ## 0..1. Al llegar a 1 empieza la persecución.
var last_known := Vector3.ZERO
var active := true                ## false: no piensa ni percibe (pruebas, pantallas).
var sees_player := false
## Alcance de la vista (los vigilantes de la bodega ven un poco menos de noche).
var view_range := VIEW_RANGE

var _player: PlayerController
var _lost_timer := 0.0
var _search_timer := 0.0
var _search_point := Vector3.INF
var _look_phase := 0.0
var _indicator: Label3D
var _home: Vector3
var _ray := PhysicsRayQueryParameters3D.new()


func _init() -> void:
	super({
		"skin": Color(0.62, 0.45, 0.34), "shirt": Color(0.2, 0.32, 0.22), "pants": Color(0.16, 0.24, 0.17),
		"shoes": Color(0.05, 0.05, 0.05), "shoe_accent": Color(0.05, 0.05, 0.05),
		"cap": Color(0.14, 0.22, 0.15), "vest": Color(0.75, 0.95, 0.15),
	})


func _ready() -> void:
	super()
	add_to_group("police")
	display_name = "Policía"
	_indicator = Label3D.new()
	_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_indicator.no_depth_test = true
	_indicator.font_size = 96
	_indicator.pixel_size = 0.006
	_indicator.outline_size = 18
	_indicator.position = Vector3(0, 2.25, 0)
	_indicator.visible = false
	add_child(_indicator)
	_ray.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.VEHICLES
	_ray.exclude = [get_rid()]
	_home = global_position


func setup(patrol_route: PackedVector3Array) -> void:
	route = patrol_route
	route_index = 0
	EventBus.police_radio.connect(_on_radio)
	EventBus.noise.connect(_on_noise)


## Vuelve al estado inicial en su ruta (tras atrapar al jugador).
func reset_to(pos: Vector3) -> void:
	place(pos)
	route_index = 0
	alert = 0.0
	sees_player = false
	_set_state(State.PATROL)


func think(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if not active or _player == null:
		move_speed = 0.0
		_indicator.visible = false
		return
	sees_player = can_see_player()
	if sees_player:
		last_known = _player.global_position
	match state:
		State.PATROL:
			_patrol(delta)
		State.SUSPICIOUS:
			_suspicious(delta)
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		State.RETURN:
			_return(delta)
	_update_indicator()


# ---------------------------------------------------------------------------
# Percepción
# ---------------------------------------------------------------------------
func can_see_player() -> bool:
	if _player == null or _player.is_hidden():
		return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target := _player.global_position + Vector3.UP * (0.7 if _player.crouching else 1.3)
	var to := target - eye
	var dist := to.length()
	var player_running := _player.is_running()
	var reach := view_range * PlayerProfile.visibility_mult()
	if _player.crouching:
		reach *= CROUCH_RANGE_MULT
	elif player_running:
		reach *= RUN_RANGE_MULT
	if dist > reach:
		return false
	var flat := Vector3(to.x, 0.0, to.z)
	var in_cone := flat.length() < 0.01 or view_direction().angle_to(flat.normalized()) <= VIEW_FOV * 0.5
	var heard := player_running and dist < HEAR_RANGE * PlayerProfile.noise_mult()
	if not in_cone and not heard and dist > CLOSE_SENSE:
		return false
	_ray.from = eye
	_ray.to = target
	return get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


## Hacia dónde mira: si ya sospecha o persigue, no te quita los ojos de encima
## (mira a donde te vio por última vez aunque camine rodeando algo).
func view_direction() -> Vector3:
	if state in [State.SUSPICIOUS, State.CHASE]:
		var to := Vector3(last_known.x - global_position.x, 0.0, last_known.z - global_position.z)
		if to.length() > 0.3:
			return to.normalized()
	return forward()


## Cuánto sube la alerta por segundo al verte: más rápido cuanto más cerca.
func _alert_rate() -> float:
	var dist := global_position.distance_to(_player.global_position)
	return lerpf(3.0, 0.7, clampf(dist / VIEW_RANGE, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------
func _patrol(delta: float) -> void:
	running = false
	move_speed = PATROL_SPEED
	if sees_player:
		alert = minf(1.0, alert + _alert_rate() * delta)
		_set_state(State.SUSPICIOUS)
		return
	alert = maxf(0.0, alert - ALERT_DECAY * delta)
	if route.is_empty():
		go_to(_home)
		return
	go_to(route[route_index])
	if arrived():
		route_index = (route_index + 1) % route.size()
		go_to(route[route_index])


func _suspicious(delta: float) -> void:
	running = false
	face(last_known)
	if sees_player:
		alert = minf(1.0, alert + _alert_rate() * delta)
	else:
		alert = maxf(0.0, alert - ALERT_DECAY * delta)
	if alert >= 1.0:
		_start_chase()
		return
	if alert <= 0.0:
		_set_state(State.RETURN)
		return
	# Con media alerta se acerca a mirar; con poca, solo se queda mirando.
	if alert > 0.5:
		move_speed = APPROACH_SPEED
		go_to(last_known)
	else:
		move_speed = 0.0


func _chase(delta: float) -> void:
	running = true
	move_speed = CHASE_SPEED
	alert = 1.0
	go_to(last_known)
	if sees_player:
		_lost_timer = 0.0
		var d := global_position.distance_to(_player.global_position)
		if d < CATCH_DISTANCE:
			active = false
			EventBus.player_caught.emit(self)
			return
	else:
		_lost_timer += delta
		# Llegó a donde te vio por última vez (o no puede llegar): a buscar.
		if (_lost_timer > LOSE_TIME and arrived()) or _lost_timer > LOSE_TIME + 6.0:
			_set_state(State.SEARCH)


func _search(delta: float) -> void:
	running = false
	_search_timer -= delta
	if sees_player:
		alert = minf(1.0, alert + _alert_rate() * 1.5 * delta)
		if alert >= 1.0:
			_start_chase()
			return
	if _search_timer <= 0.0:
		_set_state(State.RETURN)
		return
	move_speed = SEARCH_SPEED
	if _search_point == Vector3.INF or arrived():
		_search_point = _random_point_near(last_known, 7.0)
		go_to(_search_point)
	_look_phase += delta * 2.5
	visual.look_around(sin(_look_phase) * 0.8)


func _return(delta: float) -> void:
	running = false
	move_speed = PATROL_SPEED
	if sees_player:
		alert = minf(1.0, alert + _alert_rate() * delta)
		_set_state(State.SUSPICIOUS)
		return
	alert = maxf(0.0, alert - ALERT_DECAY * delta)
	if route.is_empty():
		go_to(_home)
		if arrived():
			_set_state(State.PATROL)
		return
	route_index = _nearest_route_index()
	go_to(route[route_index])
	if arrived():
		_set_state(State.PATROL)


func _start_chase() -> void:
	_lost_timer = 0.0
	_set_state(State.CHASE)
	EventBus.police_radio.emit(last_known, self)


## Otro policía avisó por radio: si está cerca y tranquilo, va a buscar.
func _on_radio(pos: Vector3, from: Node) -> void:
	if from == self or not active or state == State.CHASE:
		return
	if global_position.distance_to(pos) > RADIO_RANGE:
		return
	last_known = pos
	alert = maxf(alert, 0.6)
	_set_state(State.SEARCH)


## Va a revisar un punto (un ruido, un aviso). No interrumpe una persecución.
func investigate(pos: Vector3) -> void:
	if state == State.CHASE:
		return
	last_known = pos
	alert = maxf(alert, 0.5)
	_set_state(State.SEARCH)
	_search_point = pos
	go_to(pos)


## Te perdió de vista (por ejemplo, al cambiarte de chaqueta): deja de perseguir y busca.
func lose_track() -> void:
	if state == State.CHASE:
		_set_state(State.SEARCH)


## Oyó un ruido (una lata, una alarma): si está cerca y no te persigue, va a mirar.
func _on_noise(pos: Vector3, radius: float, source: String) -> void:
	if not active or state == State.CHASE or not is_inside_tree():
		return
	if global_position.distance_to(pos) > radius:
		return
	investigate(pos)
	if source == "lata":
		PlayerProfile.unlock_achievement("distraccion")


func _set_state(s: State) -> void:
	state = s
	match s:
		State.SEARCH:
			_search_timer = SEARCH_TIME
			_search_point = Vector3.INF
			alert = maxf(alert, 0.5)
		State.PATROL, State.RETURN:
			visual.look_around(0.0)
			_look_target = Vector3.INF


func _nearest_route_index() -> int:
	var best := 0
	var best_d := INF
	for i in route.size():
		var d := global_position.distance_squared_to(route[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _random_point_near(center: Vector3, radius: float) -> Vector3:
	var p := center + Vector3(randf_range(-radius, radius), 0.0, randf_range(-radius, radius))
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return p
	return NavigationServer3D.map_get_closest_point(map, p)


func _update_indicator() -> void:
	match state:
		State.CHASE:
			_indicator.visible = true
			_indicator.text = "!"
			_indicator.modulate = Color(1.0, 0.2, 0.15)
		State.SUSPICIOUS, State.SEARCH:
			_indicator.visible = true
			_indicator.text = "?"
			_indicator.modulate = Color(1.0, 0.85, 0.2, clampf(0.35 + alert, 0.0, 1.0))
		_:
			_indicator.visible = false


func state_name() -> String:
	return STATE_NAMES[state]
