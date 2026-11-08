class_name Mission
extends Node
## Base de los capítulos de la aventura.
##
## Reúne lo que comparten todas las misiones: el reloj, los pasos (cada uno con
## sus pistas), el inventario, las oportunidades (corazones), la policía y el
## nivel de búsqueda, los escondites, el vendedor de granizados, los peatones,
## las postales coleccionables, el guardado y las recompensas al ganar.
##
## Cada capítulo es una subclase que pone sus personajes y pruebas en _setup()
## y completa los pasos con _complete(). Los textos de cada capítulo viven en
## datos (EscapeStory para el capítulo 1, ChapterStory para los demás).
##
## La interfaz (HUD, minimapa, paneles, pantallas finales) solo conoce esta
## clase, así que cualquier capítulo nuevo la usa sin cambios.

signal caught(count: int)
signal won(stats: Dictionary)
signal lost(reason: String)
signal step_completed(id: String)
## La interfaz abre el panel pedido: "code", "phone", "deduction", "inventory", "hints".
signal panel_requested(kind: String)
signal discovered(item_id: String)
signal checkpoint_reached(index: int)

const GRACE_SECONDS := 3.0
const AUTOSAVE_SECONDS := 20.0
const GRANIZADO_SECONDS := 25.0
const GRANIZADO_COOLDOWN := 20.0

## Identificador del capítulo (ver Chapters).
var chapter_id := ""
var world: PrototypeWorld
var points: Dictionary
var inventory := Inventory.new()
var hints := HintSystem.new()
var wanted: WantedSystem
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
## Oportunidades que quedan; -1 = sin límite (capítulo 1).
var lives := -1
var max_lives := -1
## Alguna vez llegó a haber persecución (para el logro «Fantasma»).
var was_chased := false
var officers: Array[PoliceOfficer] = []
var friends: Array[Civilian] = []
var vendor: Civilian
var evidence: Array[EvidencePickup] = []
var lock_box: LockBox
var collectibles: Array[Collectible] = []
var police_enabled := true
## Rutas de patrulla de la policía (se recorren en ciclo).
var routes: Array = []
## Punto y orientación donde se reaparece al ser atrapado.
var respawn_point := Vector3.ZERO
var respawn_yaw := 0.0

## La chaqueta de la tienda se puede usar una vez por capítulo.
var jacket_used := false

var _granizado_ready_at := 0.0
var _grace := 0.0
var _autosave := AUTOSAVE_SECONDS


func _init(w: PrototypeWorld) -> void:
	world = w
	# El reloj sigue corriendo con los paneles de acertijos abiertos (el mundo
	# se congela), pero no en el menú de pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	points = world.points
	hints.lookup = step
	inventory.catalog = ItemCatalog.has
	respawn_point = points["meeting_point"] + Vector3(2.0, 0.05, -2.0)
	respawn_yaw = PI * 0.75
	wanted = WantedSystem.new(self)
	add_child(wanted)
	_spawn_hiding_spots()
	_spawn_vendor()
	_spawn_pedestrians()
	_setup()
	if police_enabled:
		_spawn_police()
	_spawn_collectibles()
	EventBus.evidence_collected.connect(_on_evidence)
	EventBus.player_caught.connect(_on_caught)
	if GameSession.continue_saved and GameSession.save_enabled:
		var data := SaveGame.load_data()
		if str(data.get("chapter", Chapters.FIRST)) == chapter_id:
			apply_save(data)
	_grace = GRACE_SECONDS
	_set_police_active(false)
	if PlayerProfile.has_item("termo"):
		world.player.drink_granizado(20.0)
	world.player.cans = PlayerProfile.cans_per_chapter()
	world.player.disguise_requested.connect(_on_disguise)


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
	if alert_level() == 2:
		was_chased = true
	_tick(delta)
	_autosave -= delta
	if _autosave <= 0.0:
		save_progress()


# ---------------------------------------------------------------------------
# Lo que define cada capítulo
# ---------------------------------------------------------------------------
## Pasos en orden: {"id", "title", "requires", "hints"}.
func step_list() -> Array:
	return []


## Pone los personajes, pruebas y objetos del capítulo.
func _setup() -> void:
	pass


## Lógica por cuadro del capítulo (no corre en la pausa).
func _tick(_delta: float) -> void:
	pass


func _on_evidence(_id: String, _label: String) -> void:
	pass


## Texto del objetivo cuando no queda ningún paso disponible.
func idle_objective() -> String:
	return "Habla con tus amigos"


## Título del capítulo para las pantallas.
func title() -> String:
	return Chapters.get_chapter(chapter_id).get("title", "")


## Texto de la pantalla de victoria.
func victory_text() -> String:
	return Chapters.get_chapter(chapter_id).get("outro", "")


## Usar un objeto desde el inventario. Los disfraces son comunes a todos los
## capítulos; cada capítulo agrega los suyos (y llama a super).
## Barra opcional del HUD (por ejemplo, la distancia al ladrón en el
## capítulo 2): {"label", "value" 0..1, "danger" 0..1, "icon"} o {} si no hay.
func hud_meter() -> Dictionary:
	return {}


func use_item(item_id: String) -> void:
	if item_data(item_id).get("use", "") == "disguise":
		_disguise(item_id)


# ---------------------------------------------------------------------------
# Estado
# ---------------------------------------------------------------------------
func step(step_id: String) -> Dictionary:
	for s: Dictionary in step_list():
		if s["id"] == step_id:
			return s
	return {}


func item_data(item_id: String) -> Dictionary:
	return ItemCatalog.item(item_id)


func is_done(step_id: String) -> bool:
	return step_id in steps_done


func is_available(step_id: String) -> bool:
	for r: String in step(step_id).get("requires", []):
		if not is_done(r):
			return false
	return true


## Primer paso sin hacer que ya se puede hacer (al que apuntan las pistas).
func current_step() -> Dictionary:
	for s: Dictionary in step_list():
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
		return "Se acabó." if failed else "¡Capítulo superado!"
	var s := current_step()
	return s.get("title", "") if not s.is_empty() else idle_objective()


func progress_text() -> String:
	return "%d/%d" % [steps_done.size(), step_list().size()]


## Alerta de la policía para la música y el HUD: 0 tranquila, 1 sospecha/búsqueda, 2 persecución.
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
# Progreso
# ---------------------------------------------------------------------------
func _give(item_id: String) -> void:
	if inventory.add(item_id):
		discovered.emit(item_id)


func _complete(step_id: String) -> void:
	if is_done(step_id) or finished:
		return
	steps_done.append(step_id)
	step_completed.emit(step_id)
	PlayerProfile.add_xp(Chapters.STEP_XP, "Objetivo")
	if step(step_id).get("checkpoint", false):
		set_checkpoint(world.player.global_position, world.player.facing_yaw)
	save_progress()


## Punto de control: si te atrapan, vuelves aquí.
func set_checkpoint(pos: Vector3, yaw: float) -> void:
	respawn_point = pos + Vector3(0, 0.05, 0)
	respawn_yaw = yaw
	checkpoint_reached.emit(steps_done.size())


func _on_caught(_by: Node) -> void:
	if finished:
		return
	caught_count += 1
	_set_police_active(false)
	world.player.input_enabled = false
	PlayerProfile.change_reputation(-2)
	if lives > 0:
		lives -= 1
		if lives == 0:
			_fail("capturado")
			return
	caught.emit(caught_count)
	save_progress()


## Lo llama la pantalla de "atrapado" al terminar: vuelve al punto de control.
func resume_after_caught() -> void:
	if finished:
		return
	world.player.input_enabled = true
	world.player.teleport(respawn_point, respawn_yaw)
	world.camera_rig.yaw = respawn_yaw
	world.camera_rig.snap()
	for i in officers.size():
		officers[i].reset_to(officers[i].route[0] if not officers[i].route.is_empty() else officers[i].global_position)
	wanted.clear()
	_after_respawn()
	_grace = GRACE_SECONDS


func _after_respawn() -> void:
	pass


func _win() -> void:
	if finished:
		return
	finished = true
	_set_police_active(false)
	world.player.input_enabled = false
	EventBus.mission_completed.emit()
	if GameSession.save_enabled:
		SaveGame.erase()
	var s := stats()
	s["reward"] = PlayerProfile.complete_chapter(chapter_id, s)
	won.emit(s)


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
		"chapter": chapter_id, "time": total_time(), "penalty": penalty, "caught": caught_count,
		"hints": hints.total_used(), "wrong": wrong_answers, "mode": mode, "steps": steps_done.size(),
		"rank": rank(), "chased": was_chased, "lives": lives, "max_lives": max_lives,
	}


## Título final según cómo se jugó (sin pistas, sin que te atrapen, sin errores).
func rank() -> String:
	var slips := hints.total_used() + caught_count + wrong_answers
	if slips == 0:
		return Chapters.RANKS[0]
	if slips <= 3:
		return Chapters.RANKS[1]
	return Chapters.RANKS[2]


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
		"chapter": chapter_id, "mode": mode, "elapsed": elapsed, "penalty": penalty, "caught": caught_count,
		"wrong": wrong_answers, "inventory": inventory.to_data(), "steps_done": steps_done.duplicate(),
		"hints": hints.to_data(), "lives": lives,
	}


func apply_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	elapsed = float(data.get("elapsed", 0.0))
	penalty = float(data.get("penalty", 0.0))
	caught_count = int(data.get("caught", 0))
	wrong_answers = int(data.get("wrong", 0))
	if max_lives > 0:
		lives = clampi(int(data.get("lives", max_lives)), 1, max_lives)
	inventory.from_data(data.get("inventory", []))
	hints.from_data(data.get("hints", {}))
	steps_done.clear()
	for s: Variant in data.get("steps_done", []):
		if not step(str(s)).is_empty() and not str(s) in steps_done:
			steps_done.append(str(s))


# ---------------------------------------------------------------------------
# Cosas que comparten todos los capítulos
# ---------------------------------------------------------------------------
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


## Tecla de disfraz (Q): primero el impermeable del capítulo 4, si no la
## chaqueta comprada en la tienda (una vez por capítulo).
func _on_disguise() -> void:
	if finished or get_tree().paused:
		return
	for id: String in inventory.items:
		if item_data(id).get("use", "") == "disguise":
			_disguise(id)
			return
	if PlayerProfile.has_item("chaqueta"):
		if jacket_used:
			EventBus.notify.emit("Ya te cambiaste de chaqueta en este capítulo.")
			return
		jacket_used = true
		_apply_disguise("Volteaste la chaqueta reversible: ya no te reconocen tan fácil.")
		return
	EventBus.notify.emit("No tienes con qué cambiarte. En la tienda venden una chaqueta reversible.")


func _disguise(item_id: String) -> void:
	inventory.remove(item_id)
	_apply_disguise("Te pusiste: %s. La policía ya no te reconoce tan fácil." % item_data(item_id).get("name", item_id))


func _apply_disguise(text: String) -> void:
	wanted.disguise()
	Fx.burst(world, world.player.global_position + Vector3.UP, Color(1.0, 0.9, 0.3))
	AudioManager.sfx("checkpoint")
	EventBus.notify.emit(text)
	save_progress()


## Columna de luz de objetivo; on_reached(player) al entrar.
func _beacon(text: String, pos: Vector3, on_reached: Callable, r: float = 2.2) -> Beacon:
	var b := Beacon.new(text, r)
	b.position = pos
	world.add_child(b)
	b.reached.connect(on_reached)
	return b


## Zona invisible: on_enter() cuando el jugador entra.
func _zone(center: Vector3, size: Vector3, on_enter: Callable) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = PhysicsLayers.PLAYER
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	a.add_child(col)
	a.position = center
	world.add_child(a)
	a.body_entered.connect(func(b: Node3D) -> void:
		if b is PlayerController:
			on_enter.call())
	return a


func _set_police_active(value: bool) -> void:
	for o in officers:
		o.active = value


func _spawn_hiding_spots() -> void:
	for spot: Dictionary in points.get("hiding_spots", []):
		var area := HidingSpot.new(spot["size"])
		area.position = spot["position"]
		world.add_child(area)


func _spawn_vendor() -> void:
	vendor = Civilian.new({"skin": Color(0.55, 0.38, 0.28), "shirt": Color(0.95, 0.95, 0.95),
			"pants": Color(0.3, 0.3, 0.32), "cap": Color(0.1, 0.3, 0.7), "hair_style": "bald"})
	vendor.display_name = "el vendedor"
	vendor.position = points["vendor"]
	vendor.facing_yaw = -PI * 0.5
	vendor.on_talk = _buy_granizado
	world.add_child(vendor)
	vendor.interactable.prompt = "Comprar un granizado"


## Buitrago, Diaz y Gordo en la zona verde. Al hablarles se llama on_talk.
func _spawn_friends(on_talk: Callable, prompt: String = "Hablar con tus amigos") -> void:
	var meet: Vector3 = points["meeting_point"]
	for s: Array in Chapters.FRIENDS:
		var f := Civilian.new(s[1])
		f.display_name = s[0]
		f.position = meet + s[2]
		# Miran hacia el centro del grupo.
		f.facing_yaw = atan2((s[2] as Vector3).x, (s[2] as Vector3).z)
		f.on_talk = on_talk
		world.add_child(f)
		f.interactable.prompt = prompt
		friends.append(f)


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
	var phrases := pedestrian_lines()
	for i in looks.size():
		var p := Civilian.new(looks[i])
		p.display_name = ["una señora", "un señor", "una muchacha", "un señor"][i]
		p.wander_points = sidewalk
		p.walk_speed = randf_range(1.1, 1.5)
		p.lines = PackedStringArray(phrases[i % phrases.size()])
		p.position = sidewalk[(i * 3) % sidewalk.size()]
		world.add_child(p)


## Lo que dicen los peatones (cuatro grupos de frases).
func pedestrian_lines() -> Array:
	return Chapters.get_chapter(chapter_id).get("pedestrians", [["¡Buenas!"]])


func _spawn_police() -> void:
	for i in routes.size():
		spawn_officer(PackedVector3Array(routes[i]))


func spawn_officer(route: PackedVector3Array, officer: PoliceOfficer = null) -> PoliceOfficer:
	var o := officer if officer != null else PoliceOfficer.new()
	o.name = "Policia%d" % (officers.size() + 1)
	o.position = route[0]
	world.add_child(o)
	o.setup(route)
	o.active = _grace <= 0.0 and not finished
	officers.append(o)
	return o


func _spawn_collectibles() -> void:
	for c: Dictionary in Chapters.COLLECTIBLES:
		if PlayerProfile.has_collectible(c["id"]):
			continue
		var item := Collectible.new(c["id"], c["name"], c["fact"])
		item.position = c["position"]
		world.add_child(item)
		collectibles.append(item)
