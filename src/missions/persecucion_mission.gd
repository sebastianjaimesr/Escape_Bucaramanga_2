class_name PersecucionMission
extends Mission
## Capítulo 4 · «Persecución urbana» (de noche, con lluvia).
##
## Alguien de la red avisó a la policía y empiezas con la búsqueda en nivel 3.
##   1. Llegar al túnel de la plaza, donde espera Diaz (punto de control).
##   2. Perder a la policía: la búsqueda tiene que bajar a Tranquilo.
##   3. Recoger la mochila que dejó Gordo en el callejón del sureste: trae un
##      impermeable (disfraz, baja dos niveles). Al salir, una patrulla te ve.
##   4. Llegar al refugio con tus amigos con la búsqueda en Tranquilo o Sospecha.

const START := Vector3(30.0, 0.15, -6.2)
const BACKPACK := Vector3(12.5, 0.15, 20.1)
const ROUTES := [
	[Vector3(42, 0.15, -6.0), Vector3(10, 0.15, -6.0), Vector3(10, 0.15, 6.0), Vector3(42, 0.15, 6.0)],
	[Vector3(6.0, 0.15, -44), Vector3(6.0, 0.15, -10), Vector3(-6.0, 0.15, -10), Vector3(-6.0, 0.15, -44)],
	[Vector3(-10, 0.15, 30), Vector3(-10, 0.15, 46), Vector3(-32, 0.15, 46), Vector3(-34, 0.15, 30)],
	[Vector3(6.2, 0.15, 12), Vector3(6.2, 0.15, 50), Vector3(-6.2, 0.15, 50), Vector3(-6.2, 0.15, 12)],
	[Vector3(-12, 0.15, -6.2), Vector3(-50, 0.15, -6.2), Vector3(-50, 0.15, 6.2), Vector3(-12, 0.15, 6.2)],
]

var tunnel_beacon: Beacon
var backpack_beacon: Beacon
var refuge_beacon: Beacon
var _alarm_started := false


func _init(w: PrototypeWorld) -> void:
	super(w)
	name = "PersecucionMission"
	chapter_id = "persecucion"
	max_lives = int(Chapters.get_chapter(chapter_id).get("lives", 3))
	lives = max_lives
	routes = ROUTES


func _ready() -> void:
	super()
	if not GameSession.continue_saved:
		respawn_point = START
		respawn_yaw = PI * 0.5
		world.player.teleport(START, respawn_yaw)
		world.camera_rig.yaw = respawn_yaw
		world.camera_rig.snap()


func step_list() -> Array:
	return ChapterStory.steps(chapter_id)


func idle_objective() -> String:
	return "Llega al refugio"


func _setup() -> void:
	tunnel_beacon = _beacon("Diaz", points.get("tunnel_inside", Vector3(-27, 0.15, 37)), _on_tunnel, 1.6)
	backpack_beacon = _beacon("Mochila de Gordo", BACKPACK, _on_backpack, 1.4)
	refuge_beacon = _beacon("Refugio", points["meeting_point"], _on_refuge, 3.0)
	_spawn_friends(_talk_to_friends, "Hablar con tus amigos")
	var diaz := Civilian.new(Chapters.FRIENDS[1][1])
	diaz.display_name = "Diaz"
	diaz.position = points.get("tunnel_inside", Vector3(-27, 0.15, 37)) + Vector3(-1.8, 0, 0)
	diaz.lines = PackedStringArray(["Diaz: «Aquí abajo no nos ven. Espere a que se calmen.»"])
	world.add_child(diaz)
	_update_beacons()


func _tick(_delta: float) -> void:
	# Al terminar el tiempo de gracia, la policía ya sabe dónde estás.
	if not _alarm_started and officers.size() > 0 and officers[0].active:
		_alarm_started = true
		if not is_done("tunel"):
			EventBus.notify.emit("Radio: «Sospechoso con una mochila en la calle oriental. Todas las unidades.»")
			wanted.set_level(3)
			for o in officers:
				o.investigate(world.player.global_position)
	if is_done("tunel") and not is_done("perder") and wanted.level == 0:
		EventBus.notify.emit("Los perdiste. Ahora ve por la mochila que te dejó Gordo.")
		_complete("perder")
		_update_beacons()
	if refuge_beacon.active and wanted.level <= 1 and refuge_beacon.has_player():
		_on_refuge(world.player)


func _on_tunnel(_p: PlayerController) -> void:
	if is_done("tunel") or finished:
		return
	EventBus.notify.emit("Diaz: «¡Por aquí! Quédese agachado hasta que dejen de buscarlo.»")
	_complete("tunel")
	_update_beacons()


func _on_backpack(_p: PlayerController) -> void:
	if is_done("mochila") or not is_done("perder") or finished:
		return
	_give("impermeable")
	EventBus.notify.emit("La mochila de Gordo: un impermeable amarillo. Pulsa Q o úsalo desde el inventario.")
	_complete("mochila")
	# Al salir del callejón te ve una patrulla.
	wanted.report(maxf(0.0, WantedSystem.level_heat(2) + 15.0 - wanted.heat), world.player.global_position)
	_update_beacons()


func _on_refuge(_p: PlayerController) -> void:
	if finished or not is_done("mochila"):
		return
	if wanted.level > 1:
		EventBus.notify.emit("Gordo: «¡No los traiga hasta acá! Piérdalos o póngase el impermeable.»")
		return
	EventBus.notify.emit("Gordo: «¡Llegó! Ahora sí, a ver quién es ese tal A. Pabón… y quién es El Búho.»")
	_complete("refugio")
	_win()


func _talk_to_friends(_p: PlayerController) -> void:
	if is_done("mochila"):
		_on_refuge(world.player)
		return
	EventBus.notify.emit("Buitrago: «¡Usted no debería estar aquí todavía! Primero pierda a la policía.»")


func _update_beacons() -> void:
	tunnel_beacon.active = not is_done("tunel")
	backpack_beacon.active = is_done("perder") and not is_done("mochila")
	refuge_beacon.active = is_done("mochila") and not is_done("refugio")


func _after_respawn() -> void:
	# Después de que te atrapan, la búsqueda se reinicia, pero no del todo.
	if not is_done("perder"):
		_alarm_started = false


func apply_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	super(data)
	if is_done("tunel"):
		_alarm_started = true
	_update_beacons()
