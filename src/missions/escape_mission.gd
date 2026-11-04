class_name EscapeMission
extends Node
## Misión jugable de la manzana de prueba: «Las pruebas del malentendido».
##
## Sebastián tiene que recoger 5 pruebas repartidas por la manzana y llevarlas
## a sus amigos (Buitrago, Diaz y Gordo), que lo esperan en la zona verde,
## sin que lo atrape la policía. Si lo atrapan, vuelve con sus amigos (no pierde
## las pruebas que ya tiene) y la policía regresa a sus rutas.
##
## Coloca en el mundo: policías con sus rutas, peatones, vendedor de granizados,
## amigos, pruebas y matorrales para esconderse.

signal caught(count: int)
signal won(time_seconds: float, caught_count: int)

const EVIDENCE := [
	# [id, nombre visible, punto del mundo (clave de points) o posición]
	["foto", "Foto borrosa del ladrón", Vector3(-24.0, 0.0, 22.0)],
	["usb", "Memoria USB de la cámara", Vector3(-27.0, 0.15, 37.0)],
	["recibo", "Recibo de la tienda", Vector3(-20.0, 1.15, 31.0)],
	["celular", "Celular de Diaz", Vector3(52.0, 0.15, 6.2)],
	["gorra", "Gorra del verdadero ladrón", Vector3(-6.2, 0.15, -52.0)],
]

## Rutas de patrulla (sobre andenes y calles). Se recorren en ciclo.
const ROUTES := [
	[Vector3(42, 0.15, -6.0), Vector3(10, 0.15, -6.0), Vector3(10, 0.15, 6.0), Vector3(42, 0.15, 6.0)],
	[Vector3(6.0, 0.15, -44), Vector3(6.0, 0.15, -10), Vector3(-6.0, 0.15, -10), Vector3(-6.0, 0.15, -44)],
	[Vector3(-10, 0.15, 30), Vector3(-10, 0.15, 46), Vector3(-32, 0.15, 46), Vector3(-34, 0.15, 30)],
]

const GRANIZADO_SECONDS := 25.0
const GRANIZADO_COOLDOWN := 20.0
const GRACE_SECONDS := 3.0

var world: PrototypeWorld
var points: Dictionary
var total := EVIDENCE.size()
var collected: Array[String] = []
var caught_count := 0
var elapsed := 0.0
var finished := false
var officers: Array[PoliceOfficer] = []
var friends: Array[Civilian] = []
var vendor: Civilian
var evidence: Array[EvidencePickup] = []
var police_enabled := true

var _granizado_ready_at := 0.0
var _grace := 0.0


func _init(w: PrototypeWorld) -> void:
	world = w
	name = "EscapeMission"


func _ready() -> void:
	points = world.points
	_spawn_hiding_spots()
	_spawn_evidence()
	_spawn_friends()
	_spawn_vendor()
	_spawn_pedestrians()
	if police_enabled:
		_spawn_police()
	EventBus.evidence_collected.connect(_on_evidence)
	EventBus.player_caught.connect(_on_caught)
	_grace = GRACE_SECONDS
	_set_police_active(false)


func _physics_process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if _grace > 0.0:
		_grace -= delta
		if _grace <= 0.0:
			_set_police_active(true)


func objective_text() -> String:
	if finished:
		return "¡Lo lograste! Todo quedó aclarado."
	var missing := total - collected.size()
	if missing > 0:
		return "Encuentra las pruebas (%d/%d) sin que te atrape la policía" % [collected.size(), total]
	return "Lleva las pruebas a tus amigos en la zona verde"


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


# ---------------------------------------------------------------------------
# Eventos
# ---------------------------------------------------------------------------
func _on_evidence(id: String, label: String) -> void:
	if id in collected:
		return
	collected.append(id)
	var missing := total - collected.size()
	if missing > 0:
		EventBus.notify.emit("Prueba encontrada: %s. Faltan %d." % [label, missing])
	else:
		EventBus.notify.emit("¡Tienes todas las pruebas! Llévaselas a tus amigos en la zona verde.")


func _on_caught(_by: Node) -> void:
	if finished:
		return
	caught_count += 1
	_set_police_active(false)
	world.player.input_enabled = false
	caught.emit(caught_count)


## Lo llama la pantalla de "atrapado" al terminar: vuelve con los amigos.
func resume_after_caught() -> void:
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
	var missing := total - collected.size()
	if missing > 0:
		var lines := [
			"Buitrago: «Parce, todavía faltan %d pruebas. Sin eso nadie nos va a creer.»",
			"Diaz: «Revisa la plaza de las escaleras y las esquinas. Faltan %d.»",
			"Gordo: «Yo cuido el puesto... ¡pero apúrese que faltan %d!»",
		]
		EventBus.notify.emit(lines[randi() % lines.size()] % missing)
		return
	finished = true
	_set_police_active(false)
	world.player.input_enabled = false
	EventBus.notify.emit("Buitrago: «¡Eso, Sebas! Con esto queda todo aclarado.»")
	EventBus.mission_completed.emit()
	won.emit(elapsed, caught_count)


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
		world.add_child(item)
		evidence.append(item)


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
		["Los granizados del parque son los mejores.", "Si lo persiguen, métase entre los matorrales y agáchese.", "Por allá en la plaza hay una memoria tirada en el túnel."],
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
