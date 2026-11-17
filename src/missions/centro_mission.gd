class_name CentroMission
extends Mission
## Capítulo 6 · «La Cigarra» (El Centro, de tarde). Versión 2.0.
##
## Misión principal: el libro de cuentas hablaba de «un amigo en la estación».
## La Cigarra (el vigilante arrepentido de la bodega) escondió la prueba en el
## casillero 27 del Parque de las Cigarras y dejó la clave repartida en tres
## señales: una en el Parque Santander, otra en el García Rovira y otra encima
## del paradero de la 27. Las tres se pueden buscar en cualquier orden. Al
## abrir el casillero llega la patrulla del sargento Ordóñez y hay que llevarle
## la grabación a Lucía al García Rovira.
##
## Además, el Centro tiene misiones secundarias (SideQuests) que entregan
## personajes con «!» sobre la cabeza, un evento inesperado (el raponazo) y
## cinco cigarras pintadas secretas. Todo eso es opcional y queda en el perfil.

const LOCKER_CODE := "4027"
const OBLEAS_SECONDS := 150.0
const LUCIA_LOOK := {"skin": Color(0.78, 0.58, 0.46), "shirt": Color(0.45, 0.18, 0.55), "pants": Color(0.12, 0.12, 0.16),
		"hair_style": "long", "hair": Color(0.2, 0.12, 0.08), "sleeves": true}

var lucia: Civilian
var locker: Interactable
var locker_beacon: Beacon
var finish_beacon: Beacon
var cinematic: CinematicDirector
## Personajes que entregan misiones: id de la misión -> Civilian.
var customers: Array[Civilian] = []
var delivered: Array[int] = []
var photo_beacons: Dictionary = {}   ## lugar -> Beacon
var photos_taken: Array[String] = []
var dog: StrayDog
var secrets: Array[SecretSpot] = []
var snatcher: Snatcher
var victim: Civilian
## Segundos hasta el raponazo (corre después de hablar con Lucía). <0 = ya pasó.
var event_timer := 75.0
var event_state := ""   ## "", "chase", "bag", "done", "escaped"
var obleas_time := 0.0

var _casillero_slips := 0
var _ordonez_called := false


func _init(w: PrototypeWorld) -> void:
	super(w)
	name = "CentroMission"
	chapter_id = "cigarra"
	max_lives = int(Chapters.get_chapter(chapter_id).get("lives", 3))
	lives = max_lives
	quests = QuestTracker.new()
	routes = [
		[Vector3(-9.0, 0.15, -50.0), Vector3(-9.0, 0.15, 50.0)],
		[Vector3(-50.0, 0.15, -6.0), Vector3(50.0, 0.15, -6.0)],
		[Vector3(-44.0, 0.15, -12.0), Vector3(-14.0, 0.15, -12.0), Vector3(-14.0, 0.15, -38.0), Vector3(-44.0, 0.15, -38.0)],
	]


func _ready() -> void:
	super()
	if not GameSession.continue_saved:
		respawn_point = points["spawn"]
		respawn_yaw = points["spawn_yaw"]
		_play_intro.call_deferred()
	_refresh_world()


func step_list() -> Array:
	return ChapterStory.steps(chapter_id)


func idle_objective() -> String:
	return "Lleva la grabación a Lucía"


# ---------------------------------------------------------------------------
# Montaje
# ---------------------------------------------------------------------------
func _setup() -> void:
	cinematic = CinematicDirector.new(world)
	world.add_child(cinematic)
	var statue: Vector3 = points["santander_statue"]
	lucia = _npc(LUCIA_LOOK, "Lucía", statue + Vector3(2.2, 0, 3.4), PI * 0.2, _talk_to_lucia, "Hablar con Lucía")
	friends.append(lucia)
	# Señales de La Cigarra (aparecen al hablar con Lucía).
	var rovira: Vector3 = points["rovira_statue"]
	for spec: Array in [["senal_santander", statue + Vector3(0, 0, -1.8)], ["senal_rovira", rovira + Vector3(4.6, 0, 0.6)],
			["senal_27", points["paradero_roof"]]]:
		var e := EvidencePickup.new(spec[0], item_data(spec[0])["name"])
		e.position = spec[1]
		e.revealed = false
		world.add_child(e)
		evidence.append(e)
	# Casillero 27.
	var lk := Node3D.new()
	lk.name = "Casillero27"
	lk.position = points["lockers"]
	world.add_child(lk)
	locker = Interactable.new("Abrir el casillero 27", 1.6)
	locker.position.y = 0.9
	locker.action = func(_p: PlayerController) -> void: _try_locker()
	lk.add_child(locker)
	locker_beacon = _beacon("Casillero 27", points["lockers"] + Vector3(0, 0, 1.6), func(_p: PlayerController) -> void: pass, 1.2)
	finish_beacon = _beacon("Lucía · García Rovira", points["meeting_point"], func(_p: PlayerController) -> void: _on_finish(), 2.6)
	# Amigos esperando en el García Rovira (con Lucía al final).
	_spawn_friends(func(_p: PlayerController) -> void:
		EventBus.notify.emit("Buitrago: «Nosotros esperamos aquí. Si llega la patrulla de Ordóñez, nos hacemos los turistas.»"))
	_setup_side_quests()
	_setup_secrets()


func _setup_side_quests() -> void:
	givers["obleas"] = _npc({"skin": Color(0.6, 0.42, 0.3), "shirt": Color(0.95, 0.95, 0.93), "pants": Color(0.3, 0.28, 0.25),
			"hair_style": "bald", "cap": Color(0.8, 0.15, 0.12)}, "Don Aníbal", points["obleas"], -PI * 0.5,
			func(_p: PlayerController) -> void: _talk_obleas(), "Hablar con Don Aníbal")
	var sant: Vector3 = points["santander_statue"]
	givers["fotos"] = _npc({"skin": Color(0.82, 0.64, 0.52), "shirt": Color(0.2, 0.55, 0.6), "pants": Color(0.2, 0.2, 0.3),
			"hair_style": "long", "hair": Color(0.35, 0.22, 0.12), "backpack": Color(0.8, 0.5, 0.15)}, "Mariana",
			sant + Vector3(12.0, 0, 11.0), PI * 0.75, func(_p: PlayerController) -> void: _talk_fotos(), "Hablar con Mariana")
	var rov: Vector3 = points["rovira_statue"]
	givers["firulais"] = _npc({"skin": Color(0.7, 0.52, 0.42), "shirt": Color(0.75, 0.35, 0.45), "pants": Color(0.3, 0.25, 0.35),
			"hair_style": "long", "hair": Color(0.75, 0.75, 0.72), "sleeves": true}, "Doña Carmen", rov + Vector3(-6.0, 0, -12.5), 0.0,
			func(_p: PlayerController) -> void: _talk_firulais(), "Hablar con Doña Carmen")
	# Clientes de las obleas (uno por parque).
	var spots := [sant + Vector3(-7.0, 0, 3.0), rov + Vector3(-12.5, 0, -2.0), Vector3(21.0, 0.15, 18.0)]
	var names := ["Don Hernando", "La profe Gladys", "Un trotador"]
	for i in spots.size():
		var c := _npc({"skin": Color(0.55 + i * 0.1, 0.4 + i * 0.06, 0.3), "shirt": [Color(0.4, 0.5, 0.3), Color(0.6, 0.3, 0.2), Color(0.9, 0.5, 0.1)][i],
				"pants": Color(0.25, 0.25, 0.3), "hair_style": ["bald", "long", "short"][i]}, names[i], spots[i], 0.0,
				func(_p: PlayerController) -> void: _talk_customer(i), "Hablar con %s" % names[i])
		customers.append(c)
	# Fotos de Mariana: tres lugares.
	for spec: Array in [["catedral", "Foto: la Catedral"], ["capilla", "Foto: la Capilla"], ["casa_bolivar", "Foto: Casa de Bolívar"]]:
		var place: String = spec[0]
		var b := _beacon(spec[1], points[place], func(_p: PlayerController) -> void: _take_photo(place), 1.6)
		b.active = false
		photo_beacons[place] = b
	# Firulais, en el bosque de las Cigarras.
	dog = StrayDog.new()
	dog.position = Vector3(40.0, 0.15, 26.0)
	world.add_child(dog)
	dog.called.connect(_on_dog_called)


func _setup_secrets() -> void:
	var specs := {
		"cigarra_terraza": [points["roof_a"] + Vector3(0, 0, 2.5), Vector3(0, 0, -1)],
		"cigarra_campanario": [Vector3(-54.0, 0.15, 31.1), Vector3(0, 0, 1)],
		"cigarra_claro": [Vector3(56.5, 0.15, 56.5), Vector3(-1, 0, -1)],
		"cigarra_pasaje": [Vector3(21.6, 0.15, -27.95), Vector3(0, 0, -1)],
		"cigarra_catedral": [Vector3(-19.5, 0.15, -48.2), Vector3(1, 0, 0)],
	}
	for id: String in specs:
		var s := SecretSpot.new(id)
		var d: Vector3 = (specs[id][1] as Vector3).normalized()
		s.position = specs[id][0]
		s.rotation.y = atan2(-d.x, -d.z)
		world.add_child(s)
		secrets.append(s)


# ---------------------------------------------------------------------------
# Cinemáticas
# ---------------------------------------------------------------------------
func _cinematic(shots: Array, on_done: Callable = Callable()) -> void:
	_set_police_active(false)
	cinematic.play(shots, func() -> void:
		if not finished:
			_grace = maxf(_grace, 1.0)
		if on_done.is_valid():
			on_done.call())


func _play_intro() -> void:
	AudioManager.sfx("cinematic")
	var spawn: Vector3 = points["spawn"]
	var cat: Vector3 = points["catedral"]
	_cinematic([
		{"from": Vector3(40.0, 30.0, 50.0), "to": Vector3(20.0, 26.0, 40.0), "look": Vector3(-20.0, 6.0, -10.0),
			"look_to": Vector3(-30.0, 8.0, -30.0), "time": 4.2, "caption": "El Centro de Bucaramanga, 4:30 p. m. Una semana después."},
		{"from": cat + Vector3(-10.0, 4.0, 18.0), "to": cat + Vector3(6.0, 3.0, 16.0), "look": cat + Vector3(0, 8.0, -6.0), "time": 3.6,
			"caption": "Lucía recibió un mensaje firmado por «La Cigarra»: sabe quién es el amigo en la estación."},
		{"from": spawn + Vector3(4.0, 3.0, 5.0), "to": spawn + Vector3(2.0, 2.0, 3.5), "look": spawn + Vector3(0, 1.4, 0),
			"look_to": spawn + Vector3(-3.0, 1.6, -3.0), "time": 2.6, "caption": "Capítulo 6 · La Cigarra"},
	], func() -> void: AudioManager.play_music("explore"))


func _play_finale() -> void:
	var meet: Vector3 = points["meeting_point"]
	var rov: Vector3 = points["rovira_statue"]
	AudioManager.sfx("cinematic")
	_cinematic([
		{"from": meet + Vector3(6.0, 2.2, 6.0), "to": meet + Vector3(-4.0, 2.6, 7.0), "look": meet + Vector3(0, 1.3, 0),
			"time": 3.4, "caption": "Lucía: «Ya está. Con esta grabación, Ordóñez no tiene cómo negarlo.»"},
		{"from": rov + Vector3(14.0, 7.0, 14.0), "to": rov + Vector3(8.0, 12.0, 20.0), "look": rov + Vector3(0, 3.0, 0),
			"time": 3.6, "caption": "Donde empezó la ciudad, termina la mentira del primer día."},
	], _win)


# ---------------------------------------------------------------------------
# Misión principal
# ---------------------------------------------------------------------------
func _talk_to_lucia(_p: PlayerController) -> void:
	if is_done("lucia"):
		var missing := 0
		for e in evidence:
			if not e.collected:
				missing += 1
		EventBus.notify.emit("Lucía: «%s»" % ("Le faltan %d señales. Mire bien los parques y la 27." % missing if missing > 0
				else "¡Ya tiene la clave! El casillero está en el Parque de las Cigarras."))
		return
	for line: String in [
		"Lucía: «Sebas, gracias por venir. Mire este mensaje que me llegó anoche.»",
		"Lucía: «La Cigarra dice que tiene la prueba del ‹amigo en la estación› en un casillero del Parque de las Cigarras.»",
		"Lucía: «La clave la dejó repartida en tres cigarras pintadas: aquí en el Santander, en el García Rovira y en la 27.»",
	]:
		EventBus.notify.emit(line)
	_give("mensaje_cigarra")
	_complete("lucia")
	_refresh_world()


func _on_evidence(id: String, _label: String) -> void:
	if not id.begins_with("senal_"):
		return
	_give(id)
	_complete(id)
	Fx.ring(world, world.player.global_position, Color(0.3, 1.0, 0.55))
	var left := 0
	for e in evidence:
		if not e.collected:
			left += 1
	EventBus.notify.emit("Señal de La Cigarra (%d/3). Revísala en el inventario (Tab)." % (3 - left)
			if left > 0 else "¡Las tres señales! Revísalas en el inventario: juntas dan la clave del casillero 27.")
	_refresh_world()


func _try_locker() -> void:
	if is_done("casillero"):
		EventBus.notify.emit("El casillero 27 está vacío.")
		return
	if not is_available("casillero"):
		EventBus.notify.emit("Un casillero con candado de cuatro números. Sin las tres señales de La Cigarra no hay cómo abrirlo.")
		return
	panel_requested.emit("code")


func code_panel() -> Dictionary:
	return {
		"kind": "plain",
		"subtitle": "PARQUE DE LAS CIGARRAS · CASILLERO 27",
		"title": "Candado de cuatro números",
		"info": "El casillero de La Cigarra tiene un candado de cuatro números.",
		"hint": "Pista: las tres señales están en el inventario. Cada una da uno o dos números, en orden.",
		"ok": "¡Clic! El candado cede. Adentro hay una memoria y una nota.",
		"button": "Abrir",
		"wrong": "El candado no se mueve: %s no es.",
	}


func try_code(code: String) -> bool:
	if is_done("casillero"):
		return true
	if not is_available("casillero"):
		return false
	if code != LOCKER_CODE:
		wrong_answers += 1
		_casillero_slips += 1
		return false
	_give("grabacion")
	_complete("casillero")
	if _casillero_slips == 0 and hints.revealed_count("casillero") == 0:
		PlayerProfile.unlock_achievement("descifrador")
	Fx.burst(world, (points["lockers"] as Vector3) + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.3), 40, 1.3)
	EventBus.notify.emit("Nota de La Cigarra: «Yo era el vigilante de la bodega. Grabé al amigo de Pabón. Llévenselo a Lucía. Y corran.»")
	_call_ordonez.call_deferred()
	_refresh_world()
	return true


## Al abrir el casillero llega la patrulla de Ordóñez por la 27 y la 36.
func _call_ordonez() -> void:
	if _ordonez_called or finished:
		return
	_ordonez_called = true
	while is_inside_tree() and get_tree().paused:
		await get_tree().process_frame
	if finished:
		return
	AudioManager.sfx("alert")
	EventBus.notify.emit("Radio de la policía: «Atención, Ordóñez pide buscar a un muchacho de camiseta roja en el Parque de las Cigarras.»")
	for route: Array in [[Vector3(9.0, 0.15, 6.0), Vector3(9.0, 0.15, 56.0)], [Vector3(14.0, 0.15, 6.0), Vector3(56.0, 0.15, 6.0)]]:
		spawn_officer(PackedVector3Array(route))
	wanted.report(10.0)


func _on_finish() -> void:
	if finished or not is_done("casillero") or is_done("entrega"):
		return
	_complete("entrega")
	_play_finale()


func _refresh_world() -> void:
	var talked := is_done("lucia")
	for e in evidence:
		if talked and not e.collected and not e.revealed:
			e.reveal()
	locker_beacon.active = talked and is_available("casillero") and not is_done("casillero")
	finish_beacon.active = is_done("casillero") and not finished
	if is_done("casillero"):
		lucia.position = (points["meeting_point"] as Vector3) + Vector3(1.6, 0, -1.2)


# ---------------------------------------------------------------------------
# Misiones secundarias
# ---------------------------------------------------------------------------
func _talk_obleas() -> void:
	match quests.state("obleas"):
		"available":
			EventBus.notify.emit("Don Aníbal: «¡Mijo! Tengo tres pedidos de obleas y no puedo dejar el puesto. Uno en el Santander, otro en el García Rovira y otro en las Cigarras.»")
			EventBus.notify.emit("Don Aníbal: «Si llegan blanditas en menos de dos minutos y medio, le doy ñapa.»")
			quests.start("obleas")
			obleas_time = 0.0
			delivered.clear()
		"active":
			EventBus.notify.emit("Don Aníbal: «Faltan %d pedidos, ¡que se ablandan!»" % (3 - delivered.size()))
		"done":
			EventBus.notify.emit("Don Aníbal: «Gracias otra vez, mijo. Las obleas de la casa, cuando quiera.»")


func _talk_customer(i: int) -> void:
	var who := customers[i].display_name
	if quests.state("obleas") != "active":
		EventBus.notify.emit("%s: «¡Buenas tardes! Qué antojo de una oblea…»" % who)
		return
	if i in delivered:
		EventBus.notify.emit("%s: «¡Deliciosa! Gracias.»" % who)
		return
	delivered.append(i)
	AudioManager.sfx("coin")
	Fx.burst(world, customers[i].global_position + Vector3(0, 1.6, 0), Color(1.0, 0.8, 0.4))
	EventBus.notify.emit("%s: «¡Con arequipe y queso, como me gusta!»" % who)
	quests.advance("obleas", "entregas")
	if delivered.size() >= 3:
		if obleas_time <= OBLEAS_SECONDS:
			quests.advance("obleas", "rapido")
		quests.finish("obleas")


func _talk_fotos() -> void:
	match quests.state("fotos"):
		"available":
			EventBus.notify.emit("Mariana: «¡Hola! Hago una guía del Centro y me faltan fotos de la Catedral, la Capilla de los Dolores y la Casa de Bolívar. ¿Me ayudas?»")
			quests.start("fotos")
		"active":
			if quests.is_objective_done("fotos", "fotos"):
				quests.advance("fotos", "volver")
				EventBus.notify.emit("Mariana: «¡Quedaron hermosas! La Capilla con esa luz… Te voy a poner en los créditos.»")
				quests.finish("fotos")
			else:
				EventBus.notify.emit("Mariana: «Llevas %d de 3 fotos. ¡Sigue las columnas de luz!»" % photos_taken.size())
		"done":
			EventBus.notify.emit("Mariana: «La guía ya está en la imprenta. ¡Gracias!»")
	_refresh_side_beacons()


func _take_photo(place: String) -> void:
	if quests.state("fotos") != "active" or place in photos_taken:
		return
	photos_taken.append(place)
	AudioManager.sfx("camera")
	EventBus.camera_shake.emit(0.12)
	quests.advance("fotos", "fotos")
	EventBus.notify.emit("¡Clic! Foto %d de 3.%s" % [photos_taken.size(), " Vuelve con Mariana." if photos_taken.size() >= 3 else ""])
	_refresh_side_beacons()


func _talk_firulais() -> void:
	match quests.state("firulais"):
		"available":
			EventBus.notify.emit("Doña Carmen: «¡Ay, mijo! Firulais se me soltó detrás de una ardilla hacia el Parque de las Cigarras. Es café, chiquito y orejón.»")
			quests.start("firulais")
		"active":
			if dog.mode == "following" and dog.global_position.distance_to(givers["firulais"].global_position) < 4.0:
				_dog_home()
			else:
				EventBus.notify.emit("Doña Carmen: «¿Lo vio? Por allá en el bosque de las Cigarras, cerca de la quebrada.»")
		"done":
			EventBus.notify.emit("Doña Carmen: «Firulais no se despega de mí desde ese día. ¡Dios le pague!»")


func _on_dog_called() -> void:
	if quests.state("firulais") != "active":
		EventBus.notify.emit("El perrito mueve la cola, pero no se te acerca. Lleva un collar que dice «Firulais».")
		return
	dog.follow(world.player)
	AudioManager.sfx("pickup")
	quests.advance("firulais", "encontrar")
	EventBus.notify.emit("¡Firulais! Te sigue moviendo la cola. Llévalo con Doña Carmen al García Rovira.")


func _dog_home() -> void:
	var carmen: Civilian = givers["firulais"]
	dog.sit_at(carmen.global_position + Vector3(0.9, 0, 0.6))
	Fx.burst(world, carmen.global_position + Vector3(0, 1.5, 0), Color(1.0, 0.5, 0.6), 30)
	quests.advance("firulais", "traer")
	EventBus.notify.emit("Doña Carmen: «¡Firulais! ¡Mi chiquito!» Firulais casi la tumba de la alegría.")
	quests.finish("firulais")


func _on_side_quests_changed() -> void:
	_refresh_side_beacons()


func _refresh_side_beacons() -> void:
	for place: String in photo_beacons:
		(photo_beacons[place] as Beacon).active = quests.state("fotos") == "active" and not place in photos_taken


# ---------------------------------------------------------------------------
# Evento inesperado: el raponazo
# ---------------------------------------------------------------------------
func _start_snatch() -> void:
	if event_state != "" or finished or PlayerProfile.is_quest_done("raponero"):
		event_state = "done"
		return
	event_state = "chase"
	# Pasa por la 27, a unos metros del jugador si está cerca; si no, al norte del cruce.
	var start := Vector3(-8.6, 0.15, -14.0)
	victim = _npc({"skin": Color(0.8, 0.62, 0.5), "shirt": Color(0.85, 0.75, 0.3), "pants": Color(0.25, 0.2, 0.3),
			"hair_style": "long", "hair": Color(0.15, 0.1, 0.08)}, "la señora", start, 0.0,
			func(_p: PlayerController) -> void: _talk_victim(), "Hablar con la señora")
	snatcher = Snatcher.new()
	snatcher.position = start + Vector3(0, 0, -1.5)
	snatcher.route = PackedVector3Array([Vector3(-8.6, 0.15, -30.0), Vector3(-8.6, 0.15, -44.0), Vector3(-20.0, 0.15, -44.0),
			Vector3(-46.0, 0.15, -44.0), Vector3(-50.0, 0.15, -44.0)])
	snatcher.player = world.player
	world.add_child(snatcher)
	snatcher.caught.connect(_on_snatcher_caught)
	snatcher.escaped.connect(_on_snatcher_escaped)
	quests.start("raponero")
	AudioManager.sfx("alert")
	EventBus.notify.emit("¡AL LADRÓN! «¡Me robaron el bolso!», grita una señora en la 27. El raponero corre hacia el norte.")


func _on_snatcher_caught() -> void:
	event_state = "bag"
	quests.advance("raponero", "alcanzar")
	AudioManager.sfx("pickup")
	EventBus.notify.emit("El raponero suelta el bolso y se pierde entre la gente. Devuélveselo a la señora.")
	_vanish(snatcher)


func _on_snatcher_escaped() -> void:
	event_state = "escaped"
	quests.abandon("raponero")
	EventBus.notify.emit("El raponero se perdió por las calles del Centro. La próxima vez, ¡corre más!")
	_vanish(snatcher)


func _talk_victim() -> void:
	if event_state == "bag":
		event_state = "done"
		quests.advance("raponero", "devolver")
		EventBus.notify.emit("La señora: «¡Mi bolso! Usted es el muchacho de las noticias, ¿no? ¡Qué va a ser ladrón, si es un héroe!»")
		quests.finish("raponero")
	elif event_state == "chase":
		EventBus.notify.emit("La señora: «¡Corra, mijo, que se va!»")
	else:
		EventBus.notify.emit("La señora: «¡Qué susto tan berraco!»")


func _vanish(n: Node3D) -> void:
	var tw := n.create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(n.queue_free)


# ---------------------------------------------------------------------------
# Cada cuadro
# ---------------------------------------------------------------------------
func _tick(delta: float) -> void:
	if quests.state("obleas") == "active":
		obleas_time += delta
	if is_done("lucia") and event_timer > 0.0:
		event_timer -= delta
		if event_timer <= 0.0:
			_start_snatch()
	if dog != null and dog.mode == "following" and quests.state("firulais") == "active" \
			and dog.global_position.distance_to(givers["firulais"].global_position) < 4.5:
		_dog_home()


## Lo que dice el registro de misiones sobre las cigarras pintadas.
func secrets_found() -> int:
	var n := 0
	for id: String in SideQuests.SECRETS:
		if PlayerProfile.secrets.has(id):
			n += 1
	return n


# ---------------------------------------------------------------------------
# Guardado
# ---------------------------------------------------------------------------
func to_save() -> Dictionary:
	var d := super()
	d["delivered"] = delivered.duplicate()
	d["photos"] = photos_taken.duplicate()
	d["obleas_time"] = obleas_time
	d["event"] = event_state if event_state in ["done", "escaped"] else ""
	d["event_timer"] = event_timer
	return d


func apply_save(data: Dictionary) -> void:
	super(data)
	for e in evidence:
		if e.id in steps_done:
			e.mark_collected()
	# El raponazo no se retoma a medias: si estaba en curso, se cancela.
	if "raponero" in quests.active:
		quests.active.erase("raponero")
		quests.tracked = quests.active[0] if not quests.active.is_empty() else ""
	delivered.clear()
	for v: Variant in data.get("delivered", []):
		if int(v) >= 0 and int(v) < 3 and not int(v) in delivered:
			delivered.append(int(v))
	photos_taken.clear()
	for v: Variant in data.get("photos", []):
		if str(v) in ["catedral", "capilla", "casa_bolivar"] and not str(v) in photos_taken:
			photos_taken.append(str(v))
	obleas_time = maxf(0.0, float(data.get("obleas_time", 0.0)))
	event_state = str(data.get("event", ""))
	if not event_state in ["", "done", "escaped"]:
		event_state = ""
	event_timer = clampf(float(data.get("event_timer", 75.0)), 5.0, 75.0) if event_state == "" else -1.0
	if is_done("casillero"):
		_ordonez_called = true
		_call_again_after_load.call_deferred()
	_refresh_side_beacons()
	_refresh_world()
	# Se vuelve al inicio o, con el casillero abierto, al kiosco de las Cigarras.
	var spot: Vector3 = points["spawn"]
	var yaw: float = points["spawn_yaw"]
	if is_done("casillero"):
		spot = (points["lockers"] as Vector3) + Vector3(0, 0, 2.2)
		yaw = 0.0
	respawn_point = spot + Vector3(0, 0.05, 0)
	respawn_yaw = yaw
	world.player.teleport(respawn_point, yaw)
	world.camera_rig.yaw = yaw
	world.camera_rig.snap()


func _call_again_after_load() -> void:
	for route: Array in [[Vector3(9.0, 0.15, 6.0), Vector3(9.0, 0.15, 56.0)], [Vector3(14.0, 0.15, 6.0), Vector3(56.0, 0.15, 6.0)]]:
		spawn_officer(PackedVector3Array(route))
