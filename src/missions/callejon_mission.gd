class_name CallejonMission
extends Mission
## Capítulo 3 · «Sombras en el callejón» (de noche).
##
## La nota del sobre llevaba a «la bodega del norte» (BodegaBuilder, en el
## patio noreste). Hay que entrar al patio, fotografiar tres documentos (en
## el patio, en el camión y dentro del galpón), sacar el libro de cuentas de
## la oficina y salir hasta el paradero donde espera Buitrago.
##
## Tres vigilantes hacen su ronda (Guard) y dos cámaras barren la entrada y el
## interior. Una cámara que te graba sube la búsqueda y llama a los vigilantes;
## en el nivel 3 llega la policía. Las latas (G) mueven a los vigilantes y la
## rejilla del costado oriental es una entrada que solo se pasa agachado.

## Documentos: [id de la prueba, objeto del inventario, posición].
const DOCUMENTS := [
	["guia", "foto_guia", BodegaBuilder.GUIA],
	["placa", "foto_placa", BodegaBuilder.PLACA],
	["factura", "foto_factura", BodegaBuilder.FACTURA],
]
const BUS_STOP := Vector3(-28.0, 0.15, -6.4)

var cameras: Array[SecurityCamera] = []
var photos: Array[String] = []
var exit_beacon: Beacon


func _init(w: PrototypeWorld) -> void:
	super(w)
	name = "CallejonMission"
	chapter_id = "callejon"
	max_lives = int(Chapters.get_chapter(chapter_id).get("lives", 3))
	lives = max_lives


func _ready() -> void:
	super()
	# Se empieza en la esquina, frente a la calle norte.
	if not GameSession.continue_saved:
		respawn_point = Vector3(-8.0, 0.15, -9.0)
		respawn_yaw = -PI * 0.5
		world.player.teleport(respawn_point, respawn_yaw)
		world.camera_rig.yaw = respawn_yaw
		world.camera_rig.snap()


func step_list() -> Array:
	return ChapterStory.steps(chapter_id)


func idle_objective() -> String:
	return "Encuéntrate con Buitrago en el paradero"


func _setup() -> void:
	_zone(BodegaBuilder.YARD_CENTER, BodegaBuilder.YARD_SIZE, _on_enter_yard)
	for d: Array in DOCUMENTS:
		var e := EvidencePickup.new(d[0], item_data(d[1]).get("name", d[1]))
		e.position = d[2]
		world.add_child(e)
		e.interactable.prompt = "Fotografiar: %s" % item_data(d[1]).get("name", "").trim_prefix("Foto de ").trim_prefix("la ").trim_prefix("una ")
		evidence.append(e)
	var book := EvidencePickup.new("libro", item_data("libro")["name"])
	book.position = BodegaBuilder.LIBRO
	world.add_child(book)
	book.interactable.prompt = "Tomar el libro de cuentas"
	evidence.append(book)
	for c: Array in BodegaBuilder.CAMERAS:
		var cam := SecurityCamera.new()
		cam.position = c[0]
		cam.rotation.y = c[1]
		cam.wanted = wanted
		world.add_child(cam)
		cameras.append(cam)
	for r: Array in BodegaBuilder.GUARD_ROUTES:
		spawn_officer(PackedVector3Array(r), Guard.new())
	exit_beacon = _beacon("Buitrago", BUS_STOP, _on_exit_reached)
	exit_beacon.active = false
	var buitrago := Civilian.new(Chapters.FRIENDS[0][1])
	buitrago.display_name = "Buitrago"
	buitrago.position = BUS_STOP + Vector3(-1.5, 0, -0.6)
	buitrago.lines = PackedStringArray(["Buitrago: «Hágale, parce, que yo lo espero aquí.»",
			"Buitrago: «Fotos de todo y el libro. Sin eso no hay caso.»"])
	world.add_child(buitrago)
	friends.append(buitrago)


func _set_police_active(value: bool) -> void:
	super(value)
	for c in cameras:
		c.active = value


func _on_enter_yard() -> void:
	if is_done("entrar") or finished:
		return
	EventBus.notify.emit("Estás en el patio de la bodega. Ojo con las cámaras y los vigilantes.")
	_complete("entrar")


func _on_evidence(id: String, _label: String) -> void:
	if not is_done("entrar"):
		_complete("entrar")
	if id == "libro":
		_give("libro")
		EventBus.notify.emit("El libro de cuentas. Todas las páginas están firmadas por A. Pabón.")
		_complete("libro")
	else:
		for d: Array in DOCUMENTS:
			if d[0] == id and not id in photos:
				photos.append(id)
				_give(d[1])
				AudioManager.sfx("camera")
		if photos.size() >= DOCUMENTS.size():
			_complete("documentos")
		else:
			EventBus.notify.emit("Foto %d de %d." % [photos.size(), DOCUMENTS.size()])
			save_progress()
	_update_exit()


func _update_exit() -> void:
	exit_beacon.active = is_available("salir") and not is_done("salir")
	if exit_beacon.active:
		EventBus.notify.emit("¡Listo! Sal de la bodega y encuéntrate con Buitrago en el paradero.")


func _on_exit_reached(_p: PlayerController) -> void:
	if finished or not is_available("salir"):
		return
	if wanted.level > 1:
		EventBus.notify.emit("Buitrago: «¡Lo vienen siguiendo! Piérdalos primero, yo me escondo.»")
		return
	EventBus.notify.emit("Buitrago: «¡Eso, parce! Con este libro ya sabemos quién es A. Pabón.»")
	_complete("salir")
	_win()


func _tick(_delta: float) -> void:
	# Si llegó al paradero con la búsqueda alta y espera ahí a que baje.
	if exit_beacon.active and wanted.level <= 1 and exit_beacon.has_player():
		_on_exit_reached(world.player)


func progress_text() -> String:
	if is_done("entrar") and not is_done("documentos"):
		return "%d/%d fotos" % [photos.size(), DOCUMENTS.size()]
	return super()


func to_save() -> Dictionary:
	var d := super()
	d["photos"] = photos.duplicate()
	return d


func apply_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	super(data)
	photos.clear()
	for p: Variant in data.get("photos", []):
		photos.append(str(p))
	for e in evidence:
		if e.id in photos or (e.id == "libro" and is_done("libro")):
			e.mark_collected()
	exit_beacon.active = is_available("salir") and not is_done("salir")
