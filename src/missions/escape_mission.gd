class_name EscapeMission
extends Node
## Escape room de la manzana de prueba: «Las pruebas del malentendido».
##
## La policía cree que Sebastián es el ladrón de un robo en la manzana. Para
## aclararlo tiene que reunir pruebas, abrir lo que está cerrado y reconstruir
## con sus amigos (Buitrago, Diaz y Gordo) lo que de verdad pasó:
##
##   1. La foto del robo (arriba de las escaleras): tiene la hora, 17:42.
##   2. Su recibo (sobre la caja alta): Tienda Doña Rosa a las 17:42, su coartada.
##   3. La caja de grabación del túnel: se abre con la hora del robo (1742) y da la USB con el video.
##   4. El celular de Diaz (al fondo de la calle del oriente): está bloqueado.
##   5. Desbloquearlo: Diaz dice que su patrón es la última letra del abecedario (Z).
##   6. La gorra del ladrón: el video del celular dice dónde la tiró. Solo aparece después.
##   7. La reconstrucción con los amigos: tres preguntas cuyas respuestas están en las pruebas.
##
## Si la policía lo atrapa, vuelve con sus amigos sin perder nada. En el modo
## contrarreloj hay 15 minutos. Los textos y soluciones están en EscapeStory.

signal caught(count: int)
signal won(stats: Dictionary)
signal lost(reason: String)
signal step_completed(id: String)
## La interfaz abre el panel pedido: "code" (caja), "phone" (patrón), "deduction".
signal panel_requested(kind: String)
signal discovered(item_id: String)

## Pruebas que se recogen en el mundo: [id, nombre, posición]. La USB sale de la caja.
const EVIDENCE := [
	["foto", "Foto borrosa del robo", Vector3(-24.0, 0.0, 22.0)],
	["recibo", "Tu recibo de la tienda", Vector3(-20.0, 1.15, 31.0)],
	["celular", "Celular de Diaz", Vector3(52.0, 0.15, 6.2)],
	["gorra", "Gorra roja del ladrón", Vector3(-6.2, 0.15, -52.0)],
]
## Prueba recogida -> objeto del inventario y paso de la misión.
const PICKUP_ITEM := {"foto": "foto", "recibo": "recibo", "celular": "celular_bloqueado", "gorra": "gorra"}
const PICKUP_STEP := {"foto": "foto", "recibo": "recibo", "celular": "celular", "gorra": "gorra"}
## Caja de grabación, dentro del túnel bajo de la plaza, contra la pared norte.
const LOCK_BOX_POSITION := Vector3(-27.0, 0.15, 35.95)

## Rutas de patrulla (sobre andenes y calles). Se recorren en ciclo.
const ROUTES := [
	[Vector3(42, 0.15, -6.0), Vector3(10, 0.15, -6.0), Vector3(10, 0.15, 6.0), Vector3(42, 0.15, 6.0)],
	[Vector3(6.0, 0.15, -44), Vector3(6.0, 0.15, -10), Vector3(-6.0, 0.15, -10), Vector3(-6.0, 0.15, -44)],
	[Vector3(-10, 0.15, 30), Vector3(-10, 0.15, 46), Vector3(-32, 0.15, 46), Vector3(-34, 0.15, 30)],
]

const GRANIZADO_SECONDS := 25.0
const GRANIZADO_COOLDOWN := 20.0
const GRACE_SECONDS := 3.0
const AUTOSAVE_SECONDS := 20.0

var world: PrototypeWorld
var points: Dictionary
var total := EVIDENCE.size()
var collected: Array[String] = []
var inventory := Inventory.new()
var hints := HintSystem.new()
var steps_done: Array[String] = []
var mode := "explorador"
var time_limit := 0.0
var caught_count := 0
var wrong_answers := 0
## Segundos jugados (no corren en la pausa). La penalización se suma aparte.
var elapsed := 0.0
var penalty := 0.0
var finished := false
var failed := false
## Diaz ya dijo cuál es su patrón.
var diaz_told := false
var officers: Array[PoliceOfficer] = []
var friends: Array[Civilian] = []
var vendor: Civilian
var evidence: Array[EvidencePickup] = []
var lock_box: LockBox
var police_enabled := true

var _granizado_ready_at := 0.0
var _grace := 0.0
var _friend_line := 0
var _autosave := AUTOSAVE_SECONDS


func _init(w: PrototypeWorld) -> void:
	world = w
	name = "EscapeMission"
	# El reloj sigue corriendo con los paneles de acertijos abiertos (el mundo
	# se congela), pero no en el menú de pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	points = world.points
	mode = GameSession.mode
	time_limit = float(EscapeStory.mode(mode)["time_limit"])
	_spawn_hiding_spots()
	_spawn_evidence()
	_spawn_lock_box()
	_spawn_friends()
	_spawn_vendor()
	_spawn_pedestrians()
	if police_enabled:
		_spawn_police()
	EventBus.evidence_collected.connect(_on_evidence)
	EventBus.player_caught.connect(_on_caught)
	if GameSession.continue_saved and GameSession.save_enabled:
		apply_save(SaveGame.load_data())
	_grace = GRACE_SECONDS
	_set_police_active(false)


func _physics_process(delta: float) -> void:
	if finished:
		return
	if get_tree().paused and not world.modal_open:
		return
	elapsed += delta
	if time_limit > 0.0 and time_left() <= 0.0:
		_fail("tiempo")
		return
	if get_tree().paused:
		return
	if _grace > 0.0:
		_grace -= delta
		if _grace <= 0.0:
			_set_police_active(true)
	_autosave -= delta
	if _autosave <= 0.0:
		save_progress()


# ---------------------------------------------------------------------------
# Estado
# ---------------------------------------------------------------------------
func is_done(step_id: String) -> bool:
	return step_id in steps_done


func is_available(step_id: String) -> bool:
	for r: String in EscapeStory.step(step_id).get("requires", []):
		if not is_done(r):
			return false
	return true


## Primer paso sin hacer que ya se puede hacer (al que apuntan las pistas).
func current_step() -> Dictionary:
	for s: Dictionary in EscapeStory.STEPS:
		if not is_done(s["id"]) and is_available(s["id"]):
			return s
	return {}


## Tiempo total con penalizaciones (lo que se muestra al final).
func total_time() -> float:
	return elapsed + penalty


func time_left() -> float:
	return maxf(0.0, time_limit - total_time()) if time_limit > 0.0 else INF


func objective_text() -> String:
	if finished:
		return "Se acabó el tiempo." if failed else "¡Lo lograste! Todo quedó aclarado."
	var s := current_step()
	return s.get("title", "") if not s.is_empty() else "Habla con tus amigos"


func progress_text() -> String:
	return "%d/%d" % [steps_done.size(), EscapeStory.STEPS.size()]


## Nivel de alerta más alto de la policía: 0 tranquila, 1 sospecha/búsqueda, 2 persecución.
func alert_level() -> int:
	var level := 0
	for o in officers:
		if not o.active:
			continue
		if o.state == PoliceOfficer.State.CHASE:
			return 2
		if o.state in [PoliceOfficer.State.SUSPICIOUS, PoliceOfficer.State.SEARCH]:
			level = 1
	return level


func request_hint() -> String:
	var s := current_step()
	if s.is_empty() or finished:
		return ""
	var text := hints.reveal_next(s["id"])
	if text != "":
		save_progress()
	return text


# ---------------------------------------------------------------------------
# Acertijos
# ---------------------------------------------------------------------------
## Teclado de la caja de grabación. Devuelve true si la clave abre la caja.
func try_code(code: String) -> bool:
	if is_done("caja"):
		return true
	if code != EscapeStory.CAMERA_CODE:
		return false
	lock_box.open()
	_complete("caja")
	_give("usb")
	EventBus.notify.emit("¡Clic! El video de las 17:42 quedó en la memoria USB.")
	return true


## Patrón del celular (puntos 1..9 en orden). Devuelve true si lo desbloquea.
func try_pattern(pattern: Array) -> bool:
	if is_done("desbloqueo"):
		return true
	if not inventory.has("celular_bloqueado"):
		return false
	if pattern != EscapeStory.PHONE_PATTERN:
		return false
	inventory.replace("celular_bloqueado", "celular")
	_reveal_gorra()
	_complete("desbloqueo")
	discovered.emit("celular")
	EventBus.notify.emit("Desbloqueado. En el video, el ladrón tira la gorra al fondo de la calle norte.")
	return true


## Respuestas de la reconstrucción (un índice por pregunta). Devuelve los
## índices de las preguntas equivocadas; si está vacío, se gana.
func submit_deduction(answers: Array) -> Array[int]:
	var wrong: Array[int] = []
	for i in EscapeStory.DEDUCTION.size():
		if i >= answers.size() or int(answers[i]) != int(EscapeStory.DEDUCTION[i]["answer"]):
			wrong.append(i)
	if finished:
		return wrong
	if not wrong.is_empty():
		wrong_answers += 1
		if time_limit > 0.0:
			penalty += EscapeStory.WRONG_ANSWER_PENALTY
		save_progress()
		return wrong
	_complete("reconstruccion")
	_win()
	return wrong


func use_item(item_id: String) -> void:
	if EscapeStory.item(item_id).get("use", "") == "phone" and not is_done("desbloqueo"):
		panel_requested.emit("phone")


# ---------------------------------------------------------------------------
# Eventos
# ---------------------------------------------------------------------------
func _on_evidence(id: String, _label: String) -> void:
	if id in collected:
		return
	collected.append(id)
	_give(PICKUP_ITEM.get(id, id))
	_complete(PICKUP_STEP.get(id, id))
	if id == "celular":
		EventBus.notify.emit("El celular de Diaz tiene patrón de bloqueo. Diaz sabe cuál es.")
		panel_requested.emit("phone")


func _give(item_id: String) -> void:
	if inventory.add(item_id):
		discovered.emit(item_id)


func _complete(step_id: String) -> void:
	if is_done(step_id):
		return
	steps_done.append(step_id)
	step_completed.emit(step_id)
	save_progress()


func _reveal_gorra() -> void:
	for e in evidence:
		if e.id == "gorra":
			e.reveal()


func _on_caught(_by: Node) -> void:
	if finished:
		return
	caught_count += 1
	_set_police_active(false)
	world.player.input_enabled = false
	caught.emit(caught_count)
	save_progress()


## Lo llama la pantalla de "atrapado" al terminar: vuelve con los amigos.
func resume_after_caught() -> void:
	if finished:
		return
	world.player.input_enabled = true
	world.player.teleport(points["meeting_point"] + Vector3(2.0, 0.05, -2.0), PI * 0.75)
	world.camera_rig.yaw = PI * 0.75
	world.camera_rig.snap()
	for i in officers.size():
		officers[i].reset_to(ROUTES[i % ROUTES.size()][0])
	_grace = GRACE_SECONDS


func _talk_to_friends(_player: PlayerController) -> void:
	if finished:
		return
	if inventory.has("celular_bloqueado"):
		diaz_told = true
		EventBus.notify.emit("Diaz: «¡Mi celular! El patrón es una letra: la última del abecedario.»")
		save_progress()
		return
	if is_available("reconstruccion") and not is_done("reconstruccion"):
		EventBus.notify.emit("Buitrago: «Listo, parce. Repasemos qué fue lo que pasó.»")
		panel_requested.emit("deduction")
		return
	var lines: Array[String] = []
	var missing := 5 - steps_done.filter(func(s: String) -> bool:
			return s in ["foto", "recibo", "caja", "desbloqueo", "gorra"]).size()
	lines.append("Buitrago: «Todavía nos faltan %d pruebas. Sin eso nadie nos va a creer.»" % missing)
	if not is_done("celular"):
		lines.append("Diaz: «Se me cayó el celular persiguiendo al ladrón, por la calle del oriente.»")
	if not is_done("caja"):
		lines.append("Gordo: «La cámara del túnel de la plaza graba todo. Si sabemos la hora, sacamos el video.»")
	if not is_done("foto"):
		lines.append("Diaz: «Un vecino dijo que tomó una foto desde arriba de las escaleras.»")
	EventBus.notify.emit(lines[_friend_line % lines.size()])
	_friend_line += 1


func _win() -> void:
	finished = true
	_set_police_active(false)
	world.player.input_enabled = false
	EventBus.notify.emit("Buitrago: «¡Eso, Sebas! Con esto queda todo aclarado.»")
	EventBus.mission_completed.emit()
	if GameSession.save_enabled:
		SaveGame.erase()
	won.emit(stats())


func _fail(reason: String) -> void:
	finished = true
	failed = true
	_set_police_active(false)
	world.player.input_enabled = false
	if GameSession.save_enabled:
		SaveGame.erase()
	lost.emit(reason)


func stats() -> Dictionary:
	return {
		"time": total_time(), "penalty": penalty, "caught": caught_count, "hints": hints.total_used(),
		"wrong": wrong_answers, "mode": mode, "steps": steps_done.size(), "rank": rank(),
	}


## Título final según cómo se jugó (sin pistas, sin que te atrapen, sin errores).
func rank() -> String:
	var slips := hints.total_used() + caught_count + wrong_answers
	if slips == 0:
		return "Detective impecable"
	if slips <= 3:
		return "Buen ojo"
	return "Salvado por los amigos"


# ---------------------------------------------------------------------------
# Guardado
# ---------------------------------------------------------------------------
func save_progress() -> void:
	_autosave = AUTOSAVE_SECONDS
	if finished or not GameSession.save_enabled:
		return
	SaveGame.save(to_save())


func to_save() -> Dictionary:
	return {
		"mode": mode, "elapsed": elapsed, "penalty": penalty, "caught": caught_count,
		"wrong": wrong_answers, "inventory": inventory.to_data(), "steps_done": steps_done.duplicate(),
		"collected": collected.duplicate(), "hints": hints.to_data(), "diaz_told": diaz_told,
	}


func apply_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	mode = str(data.get("mode", mode)) if EscapeStory.MODES.has(str(data.get("mode", ""))) else mode
	time_limit = float(EscapeStory.mode(mode)["time_limit"])
	elapsed = float(data.get("elapsed", 0.0))
	penalty = float(data.get("penalty", 0.0))
	caught_count = int(data.get("caught", 0))
	wrong_answers = int(data.get("wrong", 0))
	diaz_told = bool(data.get("diaz_told", false))
	inventory.from_data(data.get("inventory", []))
	hints.from_data(data.get("hints", {}))
	steps_done.clear()
	for s: Variant in data.get("steps_done", []):
		if not EscapeStory.step(str(s)).is_empty() and not str(s) in steps_done:
			steps_done.append(str(s))
	collected.clear()
	for c: Variant in data.get("collected", []):
		collected.append(str(c))
	for e in evidence:
		if e.id in collected:
			e.mark_collected()
	if is_done("caja"):
		lock_box.set_open_instant()
	if is_done("desbloqueo"):
		_reveal_gorra()


func _buy_granizado(player: PlayerController) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _granizado_ready_at:
		EventBus.notify.emit("Vendedor: «Espere un momentico que estoy raspando el hielo.»")
		return
	_granizado_ready_at = now + GRANIZADO_COOLDOWN
	player.drink_granizado(GRANIZADO_SECONDS)
	var flavors := ["mora", "maracuyá", "mandarina", "limón"]
	EventBus.notify.emit("Granizado de %s bien frío: resistencia sin límite por %d s." % [
			flavors[randi() % flavors.size()], int(GRANIZADO_SECONDS)])


func _set_police_active(value: bool) -> void:
	for o in officers:
		o.active = value


# ---------------------------------------------------------------------------
# Colocación
# ---------------------------------------------------------------------------
func _spawn_hiding_spots() -> void:
	for spot: Dictionary in points.get("hiding_spots", []):
		var area := HidingSpot.new(spot["size"])
		area.position = spot["position"]
		world.add_child(area)


func _spawn_evidence() -> void:
	var top: float = points.get("platform_top_y", 1.5)
	for e: Array in EVIDENCE:
		var item := EvidencePickup.new(e[0], e[1])
		var pos: Vector3 = e[2]
		if e[0] == "foto":
			pos.y = top
		item.position = pos
		item.revealed = e[0] != "gorra"
		world.add_child(item)
		evidence.append(item)


func _spawn_lock_box() -> void:
	lock_box = LockBox.new()
	lock_box.position = LOCK_BOX_POSITION
	world.add_child(lock_box)
	lock_box.interactable.action = func(_p: PlayerController) -> void: panel_requested.emit("code")


func _spawn_friends() -> void:
	var meet: Vector3 = points["meeting_point"]
	var specs := [
		["Buitrago", {"skin": Color(0.6, 0.42, 0.3), "shirt": Color(0.95, 0.75, 0.15), "sleeves": false,
				"pants": Color(0.15, 0.15, 0.17), "shoes": Color(0.1, 0.1, 0.1)}, Vector3(-0.9, 0, 0)],
		["Diaz", {"skin": Color(0.93, 0.8, 0.72), "shirt": Color(0.15, 0.35, 0.7), "sleeves": false,
				"pants": Color(0.55, 0.5, 0.42), "height": 1.1, "hair": Color(0.3, 0.2, 0.1)}, Vector3(0.9, 0, 0.2)],
		["Gordo", {"skin": Color(0.7, 0.5, 0.38), "shirt": Color(0.2, 0.55, 0.3), "sleeves": false,
				"pants": Color(0.25, 0.3, 0.45), "girth": 1.35, "cap": Color(0.75, 0.1, 0.1)}, Vector3(0, 0, -0.9)],
	]
	for s: Array in specs:
		var f := Civilian.new(s[1])
		f.display_name = s[0]
		f.position = meet + s[2]
		# Miran hacia el centro del grupo.
		f.facing_yaw = atan2((s[2] as Vector3).x, (s[2] as Vector3).z)
		f.on_talk = _talk_to_friends
		world.add_child(f)
		f.interactable.prompt = "Hablar con tus amigos"
		friends.append(f)


func _spawn_vendor() -> void:
	vendor = Civilian.new({"skin": Color(0.55, 0.38, 0.28), "shirt": Color(0.95, 0.95, 0.95),
			"pants": Color(0.3, 0.3, 0.32), "cap": Color(0.1, 0.3, 0.7), "hair_style": "bald"})
	vendor.display_name = "el vendedor"
	vendor.position = points["vendor"]
	vendor.facing_yaw = -PI * 0.5
	vendor.on_talk = _buy_granizado
	world.add_child(vendor)
	vendor.interactable.prompt = "Comprar un granizado"


func _spawn_pedestrians() -> void:
	var sidewalk := PackedVector3Array([
		Vector3(-20, 0.15, -6.2), Vector3(-45, 0.15, -6.2), Vector3(20, 0.15, 6.2), Vector3(48, 0.15, 6.2),
		Vector3(6.2, 0.15, 20), Vector3(6.2, 0.15, 48), Vector3(-6.2, 0.15, -20), Vector3(-6.2, 0.15, -40),
		Vector3(-14, 0.15, 44), Vector3(-10, 0.15, 14),
	])
	var looks := [
		{"skin": Color(0.8, 0.62, 0.5), "shirt": Color(0.85, 0.3, 0.5), "pants": Color(0.2, 0.2, 0.25), "hair_style": "long"},
		{"skin": Color(0.5, 0.35, 0.25), "shirt": Color(0.9, 0.9, 0.85), "pants": Color(0.35, 0.3, 0.2)},
		{"skin": Color(0.75, 0.56, 0.42), "shirt": Color(0.3, 0.6, 0.65), "pants": Color(0.15, 0.2, 0.35), "hair_style": "long", "hair": Color(0.35, 0.2, 0.1)},
		{"skin": Color(0.66, 0.48, 0.36), "shirt": Color(0.45, 0.2, 0.15), "pants": Color(0.4, 0.4, 0.42), "hair_style": "bald", "cap": Color(0.9, 0.9, 0.9)},
	]
	var phrases := [
		["¡Uy, qué calor tan berraco!", "Por la carrera vi pasar a un policía hace ratico.", "Dicen que el ladrón tenía una gorra roja."],
		["Los granizados del parque son los mejores.", "Si lo persiguen, métase entre los matorrales y agáchese.", "En el túnel de la plaza hay una cámara de seguridad."],
		["¿Usted no es el muchacho de las noticias?", "La policía no ve bien si uno va agachadito.", "Arriba de las escaleras de la plaza vi algo brillando."],
		["Ojo con correr cerca de los tombos, que lo oyen.", "Al fondo de la calle, por el lado oriental, alguien dejó un celular.", "¡Qué pena, voy de afán!"],
	]
	for i in looks.size():
		var p := Civilian.new(looks[i])
		p.display_name = ["una señora", "un señor", "una muchacha", "un señor"][i]
		p.wander_points = sidewalk
		p.walk_speed = randf_range(1.1, 1.5)
		p.lines = PackedStringArray(phrases[i])
		p.position = sidewalk[(i * 3) % sidewalk.size()]
		world.add_child(p)


func _spawn_police() -> void:
	for i in ROUTES.size():
		var o := PoliceOfficer.new()
		o.name = "Policia%d" % (i + 1)
		o.position = ROUTES[i][0]
		world.add_child(o)
		o.setup(PackedVector3Array(ROUTES[i]))
		officers.append(o)
