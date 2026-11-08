class_name RoboPlazaMission
extends Mission
## Capítulo 2 · «El robo de la plaza» (de mañana).
##
## A Doña Rosa le robaron el sobre de la natillera del barrio:
##   1. Hablar con ella (la testigo) en su kiosco.
##   2. Encontrar tres pistas en la escena (aparecen después de hablarle).
##   3. Identificar al ladrón entre cuatro personas de la plaza: el único con
##      chaqueta verde Y morral naranja. Señalar a otro cuenta como error.
##   4. Seguirlo hasta su escondite sin acercarse demasiado ni quedarse lejos:
##      si se aleja más de LOST_DISTANCE durante LOST_TIME, o te ve cuando
##      mira hacia atrás, vuelves al último punto de control y él a la plaza.
##   5. Sacar el sobre de la caneca que vigila (una lata lo distrae).
##   6. Volver donde Doña Rosa sin que te atrape la policía que llamó el ladrón.
##
## Los textos están en ChapterStory; lo común (vidas, guardado) en Mission.

const LOST_DISTANCE := 30.0
const LOST_TIME := 5.0
const SPOTTED_TIME := 0.8
const ROSA := Vector3(-27.9, 0.15, 10.2)
const BIN := Vector3(-34.5, 0.15, -37.6)
## Pistas: [id, posición]. La del botón se pone al pie de las escaleras.
const CLUES := [
	["huella", Vector3(-30.0, 0.15, 12.5)],
	["boton", Vector3.INF],
	["tiquete", Vector3(-13.6, 0.15, 14.0)],
]
## Personas de la plaza (en el mismo orden que ChapterStory.SUSPECTS).
const SUSPECT_SPOTS := [Vector3(-11.0, 0.15, 16.5), Vector3(-33.5, 0.15, 16.0), Vector3(-20.0, 0.15, 15.2), Vector3(-35.0, 0.15, 28.5)]
const SUSPECT_LOOKS := [
	{"skin": Color(0.68, 0.5, 0.38), "shirt": Color(0.3, 0.42, 0.2), "pants": Color(0.18, 0.2, 0.28), "backpack": Color(0.95, 0.5, 0.1)},
	{"skin": Color(0.6, 0.44, 0.33), "shirt": Color(0.3, 0.42, 0.2), "pants": Color(0.35, 0.3, 0.25), "hair_style": "bald"},
	{"skin": Color(0.8, 0.62, 0.5), "shirt": Color(0.85, 0.35, 0.55), "pants": Color(0.2, 0.2, 0.3), "hair_style": "long", "backpack": Color(0.95, 0.5, 0.1)},
	{"skin": Color(0.5, 0.36, 0.27), "shirt": Color(0.9, 0.9, 0.88), "pants": Color(0.2, 0.25, 0.4), "cap": Color(0.15, 0.3, 0.75)},
]
## Del kiosco al patio noroeste, por el callejón entre los edificios.
const THIEF_ROUTE := [
	Vector3(-11.0, 0.15, 16.5), Vector3(-7.0, 0.15, 10.0), Vector3(-6.2, 0.15, 0.0), Vector3(-6.2, 0.15, -12.0),
	Vector3(-6.4, 0.15, -20.5), Vector3(-12.0, 0.15, -20.5), Vector3(-18.8, 0.15, -20.6), Vector3(-24.0, 0.15, -26.0),
	Vector3(-30.0, 0.15, -32.0), Vector3(-32.0, 0.15, -35.0),
]
## Patrullas que llegan cuando el ladrón grita.
const ALARM_ROUTES := [
	[Vector3(-6.2, 0.15, -44.0), Vector3(-6.2, 0.15, -8.0), Vector3(-40.0, 0.15, -6.2), Vector3(-8.0, 0.15, -6.2)],
	[Vector3(-20.0, 0.15, -6.2), Vector3(-50.0, 0.15, -6.2)],
	[Vector3(-40.0, 0.15, 6.2), Vector3(-12.0, 0.15, 6.2)],
]

var rosa: Civilian
var suspects: Array[Suspect] = []
var thief: Suspect
var clues_found: Array[String] = []
var envelope_taken := false

var _bin: Node3D
var _bin_interact: Interactable
var _lost_t := 0.0
var _seen_t := 0.0
var _rosa_line := 0


func _init(w: PrototypeWorld) -> void:
	super(w)
	name = "RoboPlazaMission"
	chapter_id = "robo_plaza"
	max_lives = int(Chapters.get_chapter(chapter_id).get("lives", 3))
	lives = max_lives


func step_list() -> Array:
	return ChapterStory.steps(chapter_id)


func idle_objective() -> String:
	return "Vuelve donde Doña Rosa"


func _setup() -> void:
	rosa = Civilian.new({"skin": Color(0.7, 0.52, 0.42), "shirt": Color(0.75, 0.3, 0.35), "pants": Color(0.25, 0.22, 0.3),
			"hair_style": "long", "hair": Color(0.55, 0.55, 0.58), "vest": null})
	rosa.display_name = "Doña Rosa"
	rosa.position = ROSA
	rosa.facing_yaw = PI * 0.5
	rosa.on_talk = _talk_to_rosa
	world.add_child(rosa)
	rosa.interactable.prompt = "Hablar con Doña Rosa"
	for c: Array in CLUES:
		var pos: Vector3 = c[1]
		if pos == Vector3.INF:
			pos = points.get("stairs_bottom", Vector3(-24, 0.15, 14)) + Vector3(1.4, 0, 0.6)
			pos.y = 0.15
		var e := EvidencePickup.new(c[0], item_data(c[0]).get("name", c[0]))
		e.position = pos
		e.revealed = false
		world.add_child(e)
		evidence.append(e)
	for i in ChapterStory.SUSPECTS.size():
		var data: Dictionary = ChapterStory.SUSPECTS[i]
		var s := Suspect.new(SUSPECT_LOOKS[i])
		s.display_name = data["name"]
		s.is_thief = bool(data.get("thief", false))
		s.position = SUSPECT_SPOTS[i]
		s.facing_yaw = randf() * TAU
		var index := i
		s.on_talk = func(_p: PlayerController) -> void: _point_at(index)
		world.add_child(s)
		s.interactable.prompt = "Señalar a %s" % data["name"]
		suspects.append(s)
		if s.is_thief:
			thief = s
			s.reached_hideout.connect(_on_thief_hideout)
			s.noise_heard.connect(func(_p: Vector3) -> void:
				EventBus.notify.emit("El ladrón oyó algo y fue a mirar. ¡Ahora!"))
	_build_bin()


func _build_bin() -> void:
	_bin = Node3D.new()
	_bin.name = "Caneca"
	_bin.position = BIN
	world.add_child(_bin)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.32
	cyl.height = 0.95
	mi.mesh = cyl
	mi.position.y = 0.48
	mi.material_override = MaterialLibrary.get_material("plastic_green")
	_bin.add_child(mi)
	var lid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.4
	lm.bottom_radius = 0.4
	lm.height = 0.06
	lid.mesh = lm
	lid.position.y = 0.98
	lid.material_override = MaterialLibrary.get_material("plastic_gray")
	_bin.add_child(lid)
	_bin_interact = Interactable.new("Sacar el sobre de la caneca", 1.4)
	_bin_interact.action = _try_take_envelope
	_bin_interact.enabled = false
	_bin.add_child(_bin_interact)


# ---------------------------------------------------------------------------
# Conversaciones y acusación
# ---------------------------------------------------------------------------
func _talk_to_rosa(_player: PlayerController) -> void:
	if finished:
		return
	if not is_done("testigo"):
		for line: String in ChapterStory.WITNESS_LINES:
			EventBus.notify.emit(line)
		_complete("testigo")
		_reveal_clues()
		return
	if is_done("recuperar"):
		if wanted.level > 1:
			EventBus.notify.emit("Doña Rosa: «¡Mijo, la policía viene detrás suyo! Piérdase primero y vuelva.»")
			return
		EventBus.notify.emit("Doña Rosa: «¡Ay, bendito! Toda la plata del barrio. Y esta nota… "
				+ "“Para A. P. — la bodega del norte”. Esto no es un robo cualquiera, Sebas.»")
		_complete("escapar")
		_win()
		return
	var lines := [
		"Doña Rosa: «Chaqueta verde y morral naranja, mijo. Fíjese bien.»",
		"Doña Rosa: «Si lo ve, no se le pegue mucho, que esos miran para atrás.»",
	]
	EventBus.notify.emit(lines[_rosa_line % lines.size()])
	_rosa_line += 1


func _point_at(index: int) -> void:
	if finished or is_done("sospechoso"):
		return
	var s := suspects[index]
	if not is_done("pistas"):
		EventBus.notify.emit("%s: «¿Qué me mira? Yo no he hecho nada.»" % s.display_name.capitalize())
		return
	var data: Dictionary = ChapterStory.SUSPECTS[index]
	if data.get("thief", false):
		EventBus.notify.emit("¡Es él! Chaqueta verde y morral naranja. Ya se va… síguelo sin que te vea.")
		_complete("sospechoso")
		_stop_pointing()
		thief.start_walk(PackedVector3Array(THIEF_ROUTE))
		return
	wrong_answers += 1
	var has := "chaqueta verde" if data["jacket"] else ("morral naranja" if data["bag"] else "nada de lo que dijo")
	var lacks := "morral naranja" if data["jacket"] else "chaqueta verde"
	EventBus.notify.emit("No es: tiene %s, pero no %s." % [has, lacks] if has != "nada de lo que dijo"
			else "No es: no tiene ni chaqueta verde ni morral naranja.")
	save_progress()


func _stop_pointing() -> void:
	for s in suspects:
		s.interactable.enabled = false


func _reveal_clues() -> void:
	for e in evidence:
		if not e.id in clues_found:
			e.reveal()


func _on_evidence(id: String, _label: String) -> void:
	if id in clues_found:
		return
	clues_found.append(id)
	_give(id)
	if clues_found.size() >= CLUES.size():
		EventBus.notify.emit("Con estas pistas ya sabes a quién buscar en la plaza.")
		_complete("pistas")
	else:
		EventBus.notify.emit("Pista %d de %d." % [clues_found.size(), CLUES.size()])
		save_progress()


func progress_text() -> String:
	if is_done("testigo") and not is_done("pistas"):
		return "%d/%d pistas" % [clues_found.size(), CLUES.size()]
	return super()


# ---------------------------------------------------------------------------
# Seguimiento y caneca
# ---------------------------------------------------------------------------
func _tick(delta: float) -> void:
	if thief == null:
		return
	if is_done("sospechoso") and not is_done("seguir"):
		_follow(delta)
	elif is_done("seguir") and not is_done("recuperar"):
		_guard_bin(delta)


func _follow(delta: float) -> void:
	var d := world.player.global_position.distance_to(thief.global_position)
	if d > LOST_DISTANCE:
		if _lost_t == 0.0:
			EventBus.notify.emit("¡Se te está alejando! Acércate o lo pierdes.")
		_lost_t += delta
		if _lost_t >= LOST_TIME:
			_restart_follow("Lo perdiste de vista. Vuelves a la plaza a esperarlo.")
			return
	else:
		_lost_t = 0.0
	if thief.sees_player:
		_seen_t += delta
		if _seen_t >= SPOTTED_TIME:
			_restart_follow("¡Te vio! Se devolvió a la plaza como si nada. Inténtalo otra vez, más escondido.")
	else:
		_seen_t = maxf(0.0, _seen_t - delta)


func _guard_bin(delta: float) -> void:
	_bin_interact.enabled = not envelope_taken
	if thief.sees_player and world.player.global_position.distance_to(BIN) < 9.0:
		_seen_t += delta
		if _seen_t >= SPOTTED_TIME:
			_seen_t = 0.0
			wrong_answers += 1
			EventBus.notify.emit("Ladrón: «¡Ey! ¿Usted qué busca por aquí?» Te alejas antes de que llame a alguien.")
			_back_to_checkpoint()
	else:
		_seen_t = maxf(0.0, _seen_t - delta)


func _restart_follow(text: String) -> void:
	wrong_answers += 1
	_lost_t = 0.0
	_seen_t = 0.0
	EventBus.notify.emit(text)
	thief.restart_walk()
	_back_to_checkpoint()
	save_progress()


func _back_to_checkpoint() -> void:
	world.player.teleport(respawn_point, respawn_yaw)
	world.camera_rig.yaw = respawn_yaw
	world.camera_rig.snap()


func _on_thief_hideout() -> void:
	if is_done("seguir"):
		return
	EventBus.notify.emit("El ladrón escondió algo en una caneca del patio y se quedó vigilando.")
	_complete("seguir")


func _try_take_envelope(_player: PlayerController) -> void:
	if envelope_taken or finished or not is_done("seguir"):
		return
	if thief.mode == Suspect.Mode.GUARD and thief.global_position.distance_to(BIN) < 5.0:
		wrong_answers += 1
		EventBus.notify.emit("Ladrón: «¡Quieto ahí!» Está demasiado cerca: distráelo primero (lanza una lata con G).")
		_back_to_checkpoint()
		return
	_take_envelope()


func _take_envelope() -> void:
	envelope_taken = true
	_bin_interact.enabled = false
	_give("sobre")
	thief.flee(Vector3(-56.0, 0.15, -56.0))
	EventBus.notify.emit("¡El sobre! El ladrón gritó «¡Policía, me robaron!» y salió corriendo. Vienen patrullas.")
	AudioManager.sfx("alarm")
	_complete("recuperar")
	_call_police()


func _call_police() -> void:
	if not police_enabled or officers.size() > 0:
		wanted.set_level(3)
		return
	for r: Array in ALARM_ROUTES:
		var o := spawn_officer(PackedVector3Array(r))
		o.investigate(world.player.global_position)
	wanted.set_level(3)


## Barra del HUD mientras sigues al ladrón: distancia y si te está viendo.
func hud_meter() -> Dictionary:
	if thief == null or finished:
		return {}
	if is_done("sospechoso") and not is_done("seguir"):
		var d := world.player.global_position.distance_to(thief.global_position)
		var danger := maxf(_seen_t / SPOTTED_TIME, _lost_t / LOST_TIME)
		var state := "te está mirando" if thief.mode == Suspect.Mode.LOOK_BACK else "camina"
		return {"label": "Ladrón a %d m · %s" % [int(d), state], "value": clampf(d / LOST_DISTANCE, 0.0, 1.0),
				"danger": danger, "icon": "eye"}
	if is_done("seguir") and not is_done("recuperar"):
		var state2 := "fue a mirar un ruido" if thief.mode == Suspect.Mode.INVESTIGATE else "vigila la caneca"
		return {"label": "Ladrón: %s" % state2, "value": 1.0 if thief.mode == Suspect.Mode.INVESTIGATE else 0.2,
				"danger": _seen_t / SPOTTED_TIME, "icon": "eye"}
	return {}


# ---------------------------------------------------------------------------
# Guardado
# ---------------------------------------------------------------------------
func to_save() -> Dictionary:
	var d := super()
	d["clues"] = clues_found.duplicate()
	d["envelope"] = envelope_taken
	return d


func apply_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	super(data)
	clues_found.clear()
	for c: Variant in data.get("clues", []):
		clues_found.append(str(c))
	envelope_taken = bool(data.get("envelope", false))
	for e in evidence:
		if e.id in clues_found:
			e.mark_collected()
		elif is_done("testigo"):
			e.reveal()
	if is_done("sospechoso"):
		_stop_pointing()
	if is_done("recuperar"):
		thief.visible = false
		thief.interactable.enabled = false
		thief.process_mode = Node.PROCESS_MODE_DISABLED
		_call_police()
	elif is_done("seguir"):
		thief.start_walk(PackedVector3Array(THIEF_ROUTE))
		thief.place_at_hideout()
		_bin_interact.enabled = true
	elif is_done("sospechoso"):
		thief.start_walk(PackedVector3Array(THIEF_ROUTE))
