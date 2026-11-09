class_name GranHuidaMission
extends Mission
## Capítulo 5 · «La gran huida» (Cabecera y el Parque de las Palmas, de la
## madrugada al amanecer). El final de la primera temporada.
##
## Lucía Rangel, periodista, puede contar la verdad en vivo al amanecer desde
## el Puente de la Novena, pero necesita el contrato que une a El Búho con la
## red. Se juega en tres actos, cada uno con su forma de moverse:
##   1. Sigilo en el parque: encontrar a Lucía en la fuente (policía a pie).
##   2. Parkour en las terrazas: subir por la escalera de incendios y cruzar
##      saltando hasta la oficina de El Búho; un dron vigila desde arriba y
##      un vigilante cuida la caseta. La caja fuerte se abre con 1622 (el año
##      de fundación, en la placa del monumento del parque).
##   3. Huida: suena la alarma (nivel Persecución), salen más drones y bloqueos;
##      la tirolesa baja al parque y hay que cruzar el puente antes de que salga
##      el sol (DAWN_SECONDS). El cielo se aclara a medida que avanza.
##
## Cinemáticas: al empezar (la ciudad dormida), al robar el contrato (los
## drones despegan) y al llegar al puente (la transmisión en vivo).

const DAWN_SECONDS := 170.0
const SAFE_CODE := "1622"
const ROOF_RECORD_SECONDS := 75.0
const LUCIA_LOOK := {"skin": Color(0.78, 0.58, 0.46), "shirt": Color(0.45, 0.18, 0.55), "pants": Color(0.12, 0.12, 0.16),
		"hair_style": "long", "hair": Color(0.2, 0.12, 0.08), "sleeves": true}

var lucia: Civilian
var safe: SafeBox
var zipline: Zipline
var drones: Array[SurveillanceDrone] = []
var stairs_beacon: Beacon
var office_beacon: Beacon
var zip_beacon: Beacon
var finish_beacon: Beacon
var cinematic: CinematicDirector
## Segundos que quedan para el amanecer (corre desde la tirolesa).
var dawn_left := DAWN_SECONDS
var dawn_running := false
var alarm_raised := false

var _roof_time := -1.0
var _roof_clean := true
var _sky_timer := 0.0
var _intro_played := false
var _ending := false


func _init(w: PrototypeWorld) -> void:
	super(w)
	name = "GranHuidaMission"
	chapter_id = "gran_huida"
	max_lives = int(Chapters.get_chapter(chapter_id).get("lives", 3))
	lives = max_lives
	routes = [
		[Vector3(-9.0, 0.15, -28.0), Vector3(-9.0, 0.15, 28.0)],
		[Vector3(29.0, 0.15, -28.0), Vector3(29.0, 0.15, 28.0)],
		[Vector3(-26.0, 0.15, -10.0), Vector3(-46.0, 0.15, -10.0), Vector3(-46.0, 0.15, 10.0), Vector3(-26.0, 0.15, 10.0)],
	]


func _ready() -> void:
	super()
	world.player.hard_landing.connect(_on_hard_landing)
	if not GameSession.continue_saved:
		respawn_point = points["spawn"]
		respawn_yaw = points["spawn_yaw"]
	_update_beacons()
	_update_sky(true)
	if not GameSession.continue_saved:
		# Diferida: el HUD se crea después de la misión y tiene que ver la cinemática.
		_play_intro.call_deferred()
	else:
		AudioManager.play_music("finale" if alarm_raised else "explore")


func step_list() -> Array:
	return ChapterStory.steps(chapter_id)


func idle_objective() -> String:
	return "Llega con Lucía al otro lado del puente"


# ---------------------------------------------------------------------------
# Montaje
# ---------------------------------------------------------------------------
func _setup() -> void:
	cinematic = CinematicDirector.new(world)
	world.add_child(cinematic)
	var fountain: Vector3 = points["fountain"]
	lucia = Civilian.new(LUCIA_LOOK)
	lucia.display_name = "Lucía"
	lucia.position = fountain + Vector3(6.6, 0, 2.0)
	lucia.facing_yaw = -PI * 0.5
	lucia.on_talk = _talk_to_lucia
	world.add_child(lucia)
	lucia.interactable.prompt = "Hablar con Lucía"
	friends.append(lucia)
	stairs_beacon = _beacon("Escalera de incendios", points["roof_stairs"], func(_p: PlayerController) -> void: pass, 1.6)
	_zone(CabeceraBuilder.roof_center(0) + Vector3(0, 1.0, 0), Vector3(12.0, 2.4, 9.0), _on_reach_roofs)
	office_beacon = _beacon("Oficina de El Búho", points["office_door"], func(_p: PlayerController) -> void: _on_reach_office(), 1.6)
	# La nota con la pista y la caja fuerte dentro de la caseta.
	var note := EvidencePickup.new("nota_clave", item_data("nota_clave")["name"])
	note.position = (points["office"] as Vector3) + Vector3(0.6, 0.0, -1.2)
	world.add_child(note)
	note.interactable.prompt = "Leer la nota del escritorio"
	evidence.append(note)
	safe = SafeBox.new()
	safe.position = points["safe"]
	safe.rotation.y = PI
	world.add_child(safe)
	safe.interactable.action = func(_p: PlayerController) -> void:
		if not is_done("oficina"):
			_on_reach_office()
		panel_requested.emit("code")
	zipline = Zipline.new(points["zip_start"], points["zip_end"])
	world.add_child(zipline)
	zipline.enabled = false
	zipline.arrived.connect(func(_p: PlayerController) -> void: _on_zip_arrived())
	zipline.ridden.connect(func(_p: PlayerController) -> void: PlayerProfile.add_stats({"ziplines": 1}))
	zip_beacon = _beacon("Tirolesa", points["zip_start"], func(_p: PlayerController) -> void: pass, 1.2)
	finish_beacon = _beacon("Lucía · En vivo", points["finish"], func(_p: PlayerController) -> void: _on_finish(), 2.6)
	# Amigos y la furgoneta de la emisora al otro lado del puente.
	_spawn_friends(func(_p: PlayerController) -> void:
		EventBus.notify.emit("Gordo: «¡Venga, venga! ¡Lucía ya va a salir al aire!»"), "Hablar con tus amigos")
	# Un dron vigila las terrazas desde el principio.
	var roof_route := PackedVector3Array()
	for i in [0, 1, 2, 3, 4, 3, 2, 1]:
		roof_route.append(CabeceraBuilder.roof_center(i) + Vector3(-1.5, 0, 0))
	_spawn_drone(roof_route)
	# Vigilante de El Búho alrededor de la caseta.
	var t := CabeceraBuilder.roof_top(4)
	var guard := Guard.new()
	guard.name = "VigilanteOficina"
	spawn_officer(PackedVector3Array([Vector3(13.6, t, -31.2), Vector3(13.6, t, -23.8), Vector3(25.0, t, -23.8), Vector3(25.0, t, -31.2)]), guard)
	# spawn_officer lo deja con la policía de la ronda: los vigilantes de la
	# terraza se activan con el resto al terminar el tiempo de gracia.


func _spawn_drone(route: PackedVector3Array) -> SurveillanceDrone:
	var d := SurveillanceDrone.new()
	d.name = "Dron%d" % (drones.size() + 1)
	world.add_child(d)
	d.setup(route)
	d.wanted = wanted
	d.active = _grace <= 0.0 and not finished
	drones.append(d)
	return d


func _set_police_active(value: bool) -> void:
	super(value)
	for d in drones:
		d.active = value


func _after_respawn() -> void:
	for d in drones:
		d.reset()


# ---------------------------------------------------------------------------
# Cinemáticas
# ---------------------------------------------------------------------------
## Pausa la amenaza mientras dura una cinemática y la devuelve al terminar.
func _cinematic(shots: Array, on_done: Callable = Callable()) -> void:
	_set_police_active(false)
	cinematic.play(shots, func() -> void:
		if not finished:
			_grace = maxf(_grace, 1.0)
		if on_done.is_valid():
			on_done.call())


func _play_intro() -> void:
	if _intro_played:
		return
	_intro_played = true
	AudioManager.sfx("cinematic")
	var spawn: Vector3 = points["spawn"]
	_cinematic([
		{"from": Vector3(60.0, 34.0, 62.0), "to": Vector3(30.0, 30.0, 58.0), "look": Vector3(10.0, 10.0, -10.0),
			"look_to": Vector3(-10.0, 6.0, -10.0), "time": 4.2,
			"caption": "Cabecera, 4:50 a. m. La ciudad todavía duerme."},
		{"from": Vector3(-20.0, 14.0, 20.0), "to": Vector3(-28.0, 9.0, 14.0), "look": points["fountain"] + Vector3(0, 2, 0), "time": 3.6,
			"caption": "Lucía Rangel saldrá en vivo al amanecer… si alguien le lleva la prueba."},
		{"from": spawn + Vector3(4.0, 3.0, 5.0), "to": spawn + Vector3(2.0, 2.0, 3.5), "look": spawn + Vector3(0, 1.4, 0),
			"look_to": spawn + Vector3(-3.0, 1.6, -3.0), "time": 2.6,
			"caption": "Capítulo 5 · La gran huida"},
	], func() -> void: AudioManager.play_music("explore"))


func _play_alarm_cinematic() -> void:
	var office: Vector3 = points["office"]
	var tower := Vector3(43.0, 50.0, -22.0)
	_cinematic([
		{"from": office + Vector3(-12.0, 6.0, 10.0), "to": office + Vector3(-9.0, 4.0, 7.0), "look": tower,
			"look_to": office + Vector3(0, 2.0, 0), "time": 3.0,
			"caption": "¡ALARMA! Las torres de Cabecera encienden sus reflectores."},
		{"from": Vector3(-6.0, 16.0, -36.0), "to": Vector3(-14.0, 12.0, -30.0), "look": points["zip_start"],
			"look_to": points["mirador_top"], "time": 2.8,
			"caption": "Lucía (radio): «¡La tirolesa, Sebas! ¡Baje al parque y corra al puente!»"},
	], func() -> void: AudioManager.play_music("finale"))


func _play_finale() -> void:
	var finish: Vector3 = points["finish"]
	var bridge: Vector3 = points["bridge_start"]
	AudioManager.sfx("cinematic")
	_cinematic([
		{"from": finish + Vector3(6.0, 2.2, 6.0), "to": finish + Vector3(-5.0, 2.6, 6.0), "look": finish + Vector3(0, 1.3, 0),
			"time": 3.6, "caption": "Lucía: «Estamos en vivo desde el Puente de la Novena…»"},
		{"from": bridge + Vector3(18.0, 6.0, 8.0), "to": bridge + Vector3(10.0, 4.0, 14.0), "look": finish + Vector3(0, 1.5, 0),
			"time": 3.6, "caption": "«…El Búho es Aurelio Pabón. Y aquí están las pruebas.»"},
		{"from": finish + Vector3(0.0, 9.0, 12.0), "to": finish + Vector3(0.0, 16.0, 22.0), "look": finish + Vector3(0, 1.0, 0),
			"look_to": Vector3(10.0, 20.0, -40.0), "time": 4.0, "caption": "Amanece en Bucaramanga. Malentendido aclarado."},
	], _win)


# ---------------------------------------------------------------------------
# Acto 1 · el parque
# ---------------------------------------------------------------------------
func _talk_to_lucia(_p: PlayerController) -> void:
	if is_done("periodista"):
		EventBus.notify.emit("Lucía: «La escalera de incendios está al otro lado de la avenida. ¡Rápido, que amanece!»")
		return
	for line: String in [
		"Lucía: «¿Sebastián? Leí el libro de cuentas. A. Pabón firma todo… pero ¿quién es El Búho?»",
		"Lucía: «Su oficina está en la última terraza de los edificios bajos. Ahí guarda el contrato que lo prueba.»",
		"Lucía: «Tráigalo al Puente de la Novena antes del amanecer y salgo en vivo con todo.»",
	]:
		EventBus.notify.emit(line)
	_complete("periodista")
	_update_beacons()


# ---------------------------------------------------------------------------
# Acto 2 · las terrazas
# ---------------------------------------------------------------------------
func _on_reach_roofs() -> void:
	if finished or is_done("terrazas") or not is_done("periodista"):
		return
	EventBus.notify.emit("Arriba. Ve hacia el norte de terraza en terraza; corre antes de los saltos largos.")
	_complete("terrazas")
	_roof_time = 0.0
	_roof_clean = true
	_update_beacons()


func _on_reach_office() -> void:
	if finished or is_done("oficina") or not is_done("terrazas"):
		return
	if _roof_time >= 0.0 and _roof_clean and _roof_time <= ROOF_RECORD_SECONDS:
		PlayerProfile.unlock_achievement("rey_terrazas")
	_roof_time = -1.0
	EventBus.notify.emit("La oficina de Inversiones La Meseta. La caja fuerte está al fondo.")
	_complete("oficina")
	_update_beacons()


func _on_evidence(id: String, _label: String) -> void:
	if id == "nota_clave":
		_give("nota_clave")
		EventBus.notify.emit("Nota: «La clave de siempre: el año en que se fundó la ciudad. Lo dice la placa del monumento.»")
		if not is_done("oficina"):
			_on_reach_office()
		save_progress()


func code_panel() -> Dictionary:
	return {
		"kind": "plain",
		"subtitle": "INVERSIONES LA MESETA · CAJA FUERTE",
		"title": "Clave de cuatro dígitos",
		"info": "La caja fuerte de El Búho pide una clave de cuatro dígitos.",
		"hint": "Pista: la nota del escritorio habla del año de fundación de la ciudad.",
		"ok": "¡Clac! La caja se abre. Ahí está el contrato.",
		"button": "Abrir",
		"wrong": "La caja pita: %s no es la clave.",
	}


func try_code(code: String) -> bool:
	if is_done("caja"):
		return true
	if code != SAFE_CODE:
		wrong_answers += 1
		wanted.report(6.0)
		return false
	if not is_done("oficina"):
		_complete("oficina")
	safe.open()
	_give("contrato")
	_complete("caja")
	# Robar el contrato dispara la alarma, pero después de cerrar el panel.
	_raise_alarm.call_deferred()
	return true


func _raise_alarm() -> void:
	if alarm_raised or finished:
		return
	alarm_raised = true
	# Espera a que se cierre el teclado de la caja (el mundo está en pausa).
	while is_inside_tree() and get_tree().paused:
		await get_tree().process_frame
	if finished:
		return
	zipline.enabled = true
	_update_beacons()
	_spawn_threats()
	_play_alarm_cinematic()
	# Al volver del plano, ya te buscan.
	cinematic.finished.connect(func() -> void:
		if finished:
			return
		wanted.set_level(3)
		for o in officers:
			o.investigate(world.player.global_position)
		EventBus.notify.emit("Radio: «Intruso en la terraza de Inversiones La Meseta. Todas las unidades.»"), CONNECT_ONE_SHOT)


## Después de la alarma: dos drones en el parque y bloqueos camino al puente.
func _spawn_threats() -> void:
	_spawn_drone(PackedVector3Array([Vector3(-20.0, 0.15, -12.0), Vector3(-30.0, 0.15, 12.0), Vector3(-18.0, 0.15, 28.0), Vector3(-12.0, 0.15, 0.0)]))
	_spawn_drone(PackedVector3Array([Vector3(-50.0, 0.15, 24.0), Vector3(-36.0, 0.15, 30.0), Vector3(-24.0, 0.15, 44.0), Vector3(-40.0, 0.15, 44.0)]))
	var props := PrototypeProps.new(PrototypeBlockBuilder.new(world))
	props.b.root.name = "Bloqueos"
	props._police_car(Vector3(-4.0, 0.0, CabeceraBuilder.SOUTH_Z), 0.0)
	props._police_car(Vector3(-46.0, 0.0, CabeceraBuilder.SOUTH_Z + 1.5), PI * 0.5)
	if police_enabled:
		spawn_officer(PackedVector3Array([Vector3(-36.0, 0.15, 45.0), Vector3(-18.0, 0.15, 45.0)]))
		spawn_officer(PackedVector3Array([Vector3(-9.0, 0.15, 36.0), Vector3(-9.0, 0.15, 44.0), Vector3(-2.0, 0.0, 44.0)]))


# ---------------------------------------------------------------------------
# Acto 3 · la huida
# ---------------------------------------------------------------------------
func _on_zip_arrived() -> void:
	if finished or is_done("tirolesa"):
		return
	EventBus.notify.emit("¡En el parque! Ahora al sur, al Puente de la Novena, antes de que salga el sol.")
	_complete("tirolesa")
	set_checkpoint(points["mirador_top"] + Vector3(-1.0, 0, 0), PI)
	dawn_running = true
	_update_beacons()


func _on_finish() -> void:
	if finished or _ending or not is_done("tirolesa"):
		return
	_ending = true
	dawn_running = false
	_complete("puente")
	_set_police_active(false)
	for d in drones:
		d.active = false
	world.player.input_enabled = false
	_play_finale()


func _tick(delta: float) -> void:
	if _roof_time >= 0.0:
		_roof_time += delta
		# Bajar a la calle (o a un callejón) anula el récord de las terrazas.
		if world.player.is_on_floor() and world.player.global_position.y < 4.0:
			_roof_clean = false
	if dawn_running:
		dawn_left = maxf(0.0, dawn_left - delta)
		if dawn_left <= 0.0:
			_fail("amanecer")
			return
		if finish_beacon.has_player():
			_on_finish()
	_sky_timer -= delta
	if _sky_timer <= 0.0:
		_update_sky(false)


## El cielo pasa de la madrugada al amanecer con el avance del capítulo.
func _update_sky(_force: bool) -> void:
	_sky_timer = 0.25
	var t := float(steps_done.size()) / 6.0 * 0.55
	if dawn_running or is_done("tirolesa"):
		t = 0.55 + 0.45 * (1.0 - dawn_left / DAWN_SECONDS)
	if is_done("puente"):
		t = 1.0
	TimeOfDay.blend(world, "madrugada", "amanecer", t)


func hud_meter() -> Dictionary:
	if not (dawn_running or is_done("tirolesa")) or is_done("puente"):
		return {}
	var k := dawn_left / DAWN_SECONDS
	return {"label": "Amanecer en %d s" % ceili(dawn_left), "value": k, "danger": 1.0 - k, "icon": "clock"}


func _update_beacons() -> void:
	stairs_beacon.active = is_done("periodista") and not is_done("terrazas")
	office_beacon.active = is_done("terrazas") and not is_done("oficina")
	zip_beacon.active = is_done("caja") and not is_done("tirolesa")
	finish_beacon.active = is_done("tirolesa") and not is_done("puente")
	zipline.enabled = is_done("caja")


## Caer de muy alto sin rodar cuesta un corazón.
func _on_hard_landing(speed: float, rolled: bool) -> void:
	if finished or rolled or speed < PlayerController.HURT_SPEED or lives <= 0:
		return
	lives -= 1
	EventBus.notify.emit("¡Auch! Esa caída dolió. Pulsa %s al aterrizar para rodar." % InputConfig.key_name("crouch"))
	if lives == 0:
		_fail("caida")
		return
	save_progress()


# ---------------------------------------------------------------------------
# Guardado
# ---------------------------------------------------------------------------
func to_save() -> Dictionary:
	var d := super()
	d["dawn_left"] = dawn_left
	d["alarm"] = alarm_raised
	return d


func apply_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	super(data)
	dawn_left = clampf(float(data.get("dawn_left", DAWN_SECONDS)), 20.0, DAWN_SECONDS)
	if is_done("caja"):
		safe.set_open_instant()
		alarm_raised = true
		_spawn_threats()
		wanted.set_level(2)
	for e in evidence:
		if e.id == "nota_clave" and inventory.has("nota_clave"):
			e.mark_collected()
	dawn_running = is_done("tirolesa") and not is_done("puente")
	# Se vuelve al último punto de control del capítulo.
	var spot: Vector3 = points["spawn"]
	var yaw: float = points["spawn_yaw"]
	if is_done("tirolesa"):
		spot = points["mirador_top"] + Vector3(-1.0, 0, 0)
		yaw = PI
	elif is_done("oficina"):
		spot = (points["office_door"] as Vector3) + Vector3(-0.5, 0, 0)
		yaw = PI * 0.5
	elif is_done("terrazas"):
		spot = points["parkour_start"]
		yaw = 0.0
	respawn_point = spot + Vector3(0, 0.05, 0)
	respawn_yaw = yaw
	world.player.teleport(respawn_point, yaw)
	world.camera_rig.yaw = yaw
	world.camera_rig.snap()
	_update_beacons()
