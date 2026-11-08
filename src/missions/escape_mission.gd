class_name EscapeMission
extends Mission
## Capítulo 1 · «Las pruebas del malentendido» (el escape room de la v0.4.0).
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
## contrarreloj hay 15 minutos. Los textos y soluciones están en EscapeStory;
## lo común a todos los capítulos (policía, guardado, recompensas) en Mission.

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

var total := EVIDENCE.size()
var collected: Array[String] = []
## Diaz ya dijo cuál es su patrón.
var diaz_told := false

var _friend_line := 0


func _init(w: PrototypeWorld) -> void:
	super(w)
	name = "EscapeMission"
	chapter_id = "malentendido"
	routes = ROUTES


func _ready() -> void:
	mode = GameSession.mode
	time_limit = float(EscapeStory.mode(mode)["time_limit"])
	super()


func _setup() -> void:
	_spawn_evidence()
	_spawn_lock_box()
	_spawn_friends(_talk_to_friends)


func step_list() -> Array:
	return EscapeStory.STEPS


func victory_text() -> String:
	return "La foto, el video, tu recibo y la gorra cuentan lo que pasó a las 17:42: tú estabas pagando en la Tienda Doña Rosa y el ladrón era otro, con gorra roja."


func objective_text() -> String:
	if finished:
		return "Se acabó el tiempo." if failed else "¡Lo lograste! Todo quedó aclarado."
	return super()


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
	super(item_id)
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


func _reveal_gorra() -> void:
	for e in evidence:
		if e.id == "gorra":
			e.reveal()


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


# ---------------------------------------------------------------------------
# Guardado
# ---------------------------------------------------------------------------
func to_save() -> Dictionary:
	var d := super()
	d["collected"] = collected.duplicate()
	d["diaz_told"] = diaz_told
	return d


func apply_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	mode = str(data.get("mode", mode)) if EscapeStory.MODES.has(str(data.get("mode", ""))) else mode
	time_limit = float(EscapeStory.mode(mode)["time_limit"])
	diaz_told = bool(data.get("diaz_told", false))
	super(data)
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


# ---------------------------------------------------------------------------
# Colocación
# ---------------------------------------------------------------------------
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


