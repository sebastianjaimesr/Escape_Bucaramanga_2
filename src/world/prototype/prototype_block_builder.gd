class_name PrototypeBlockBuilder
extends RefCounted
## Construye la MANZANA DE PRUEBA de la Fase 2: un cruce de dos calles con
## aceras y bordillos, edificios variados en tres cuadras, y en la cuarta una
## plaza con elementos para probar el movimiento (escaleras, rampa, pendiente
## empinada, túnel bajo, cajas de distintas alturas).
##
## No es la ciudad final: la primera zona de Bucaramanga se construye en la Fase 5.
## Unidades en metros. Norte = -Z, Este = +X.

const HALF_SIZE := 60.0          ## El área mide 120 × 120 m.
const STREET_HALF := 4.5         ## Calzada de 9 m.
const SIDEWALK := 3.0
const CURB_HEIGHT := 0.15
const STEP_RISE := 0.17
const STEP_RUN := 0.32
const STEP_COUNT := 8
const TUNNEL_CLEARANCE := 1.3

var root: Node3D
var points: Dictionary = {}       ## Puntos con nombre (aparición, pruebas).
var _rng := RandomNumberGenerator.new()
var _windows: Array[Transform3D] = []
var _lit_windows: Array[Transform3D] = []
var _batches: Dictionary = {}     ## Grupo -> {"mesh": Mesh, "xforms": Array[Transform3D]}


func _init(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "PrototypeBlock"
	parent.add_child(root)
	_rng.seed = 2026_11_03  # Determinista: misma manzana en cada ejecución.


func build() -> Dictionary:
	_build_ground()
	_build_markings()
	_build_buildings(Vector2(1, -1))   # noreste
	_build_buildings(Vector2(-1, -1))  # noroeste
	_build_buildings(Vector2(1, 1))    # sureste
	_build_test_plaza()                # suroeste
	_build_perimeter()
	_build_street_props()
	PrototypeProps.new(self).build()
	BodegaBuilder.new(self).build()
	_build_windows()
	_flush_batches()
	_build_bounds()
	points["spawn"] = Vector3(-8.0, CURB_HEIGHT, 9.0)
	points["spawn_yaw"] = -PI * 0.25
	return points


# ---------------------------------------------------------------------------
# Suelo, aceras y bordillos
# ---------------------------------------------------------------------------
func _build_ground() -> void:
	var s := HALF_SIZE * 2.0
	add_box(Vector3(s, 0.4, s), Vector3(0, -0.2, 0), "asphalt")
	# Cada cuadra es una losa elevada (acera + interior) con bordillo en sus bordes.
	for q: Vector2 in [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var w := HALF_SIZE - STREET_HALF
		var center := Vector3(q.x * (STREET_HALF + w * 0.5), CURB_HEIGHT * 0.5, q.y * (STREET_HALF + w * 0.5))
		add_box(Vector3(w, CURB_HEIGHT, w), center, "sidewalk")
		# Bordillo visual (sin colisión propia: la losa ya colisiona).
		var edge_x := q.x * (STREET_HALF + 0.1)
		var edge_z := q.y * (STREET_HALF + 0.1)
		add_box(Vector3(0.2, CURB_HEIGHT + 0.01, w), Vector3(edge_x, CURB_HEIGHT * 0.5 + 0.005, center.z), "curb", false)
		add_box(Vector3(w, CURB_HEIGHT + 0.01, 0.2), Vector3(center.x, CURB_HEIGHT * 0.5 + 0.005, edge_z), "curb", false)


func _build_markings() -> void:
	# Línea central discontinua amarilla en ambas calles.
	var d := STREET_HALF + SIDEWALK + 6.0
	var x := -HALF_SIZE + 2.0
	while x < HALF_SIZE - 2.0:
		if absf(x) > d:
			add_box(Vector3(2.0, 0.01, 0.14), Vector3(x, 0.005, 0), "paint_yellow", false)
			add_box(Vector3(0.14, 0.01, 2.0), Vector3(0, 0.005, x), "paint_yellow", false)
		x += 4.0
	# Pasos de cebra en las cuatro entradas del cruce.
	for side: float in [-1.0, 1.0]:
		var offset := side * (STREET_HALF + 2.0)
		var stripe := -STREET_HALF + 0.6
		while stripe < STREET_HALF - 0.4:
			add_box(Vector3(0.5, 0.01, 3.0), Vector3(stripe, 0.006, offset), "paint_white", false)
			add_box(Vector3(3.0, 0.01, 0.5), Vector3(offset, 0.006, stripe), "paint_white", false)
			stripe += 1.0


# ---------------------------------------------------------------------------
# Edificios
# ---------------------------------------------------------------------------
## Una fila de edificios a lo largo de cada calle de la cuadra, con alturas,
## anchos, colores y locales distintos.
func _build_buildings(q: Vector2) -> void:
	var front := STREET_HALF + SIDEWALK          # Fachada a 7,5 m del eje.
	var far := HALF_SIZE - 2.0
	# Fila paralela al eje X (da a la calle este-oeste).
	var pos := front
	while pos < far - 4.0:
		var w := _rng.randf_range(6.0, 11.0)
		w = minf(w, far - pos)
		var depth := _rng.randf_range(10.0, 14.0)
		var floors := _rng.randi_range(2, 7)
		var cx := q.x * (pos + w * 0.5)
		var cz := q.y * (front + depth * 0.5)
		_building(Vector3(cx, 0, cz), Vector3(w, 0, depth), floors, Vector3(0, 0, -q.y), "%s_x_%d" % [_qname(q), int(pos)])
		pos += w
	# Fila paralela al eje Z (da a la calle norte-sur), empezando después de la esquina.
	pos = front + 14.0
	while pos < far - 4.0:
		var w := _rng.randf_range(6.0, 11.0)
		w = minf(w, far - pos)
		var depth := _rng.randf_range(10.0, 13.0)
		var floors := _rng.randi_range(2, 6)
		var cx := q.x * (front + depth * 0.5)
		var cz := q.y * (pos + w * 0.5)
		_building(Vector3(cx, 0, cz), Vector3(depth, 0, w), floors, Vector3(-q.x, 0, 0), "%s_z_%d" % [_qname(q), int(pos)])
		pos += w


func _building(center: Vector3, footprint: Vector3, floors: int, facing: Vector3, id: String) -> void:
	var floor_h := 3.0
	var h := 3.6 + (floors - 1) * floor_h
	var base := CURB_HEIGHT
	# Uno de cada cuatro edificios es de ladrillo a la vista, muy común en Bucaramanga.
	var brick := _rng.randf() < 0.25
	var mat := "brick" if brick else "facade_%d" % _rng.randi_range(0, MaterialLibrary.FACADE_COLORS.size() - 1)
	add_box(Vector3(footprint.x, h, footprint.z), Vector3(center.x, base + h * 0.5, center.z), mat)
	# Cornisa, antepecho de la terraza y zócalo oscuro.
	add_box(Vector3(footprint.x + 0.3, 0.25, footprint.z + 0.3), Vector3(center.x, base + h + 0.12, center.z), "concrete", false)
	add_box(Vector3(footprint.x - 0.6, 0.02, footprint.z - 0.6), Vector3(center.x, base + h + 0.255, center.z), "roof", false)
	add_box(Vector3(footprint.x + 0.04, 0.45, footprint.z + 0.04), Vector3(center.x, base + 0.225, center.z), "concrete_dark", false)
	_rooftop(Vector3(center.x, base + h + 0.25, center.z), footprint)
	# Local en la planta baja: vitrina oscura y toldo, sobre la fachada que da a la calle.
	var along := Vector3(absf(facing.z), 0, absf(facing.x))   # Eje a lo largo de la fachada.
	var width := footprint.x if along.x > 0.0 else footprint.z
	var half_depth := (footprint.z if along.x > 0.0 else footprint.x) * 0.5
	var face := center + facing * half_depth
	var basis := Basis.looking_at(facing, Vector3.UP)
	var shop_w := width * 0.8
	var shop := Vector3(shop_w, 2.6, 0.08) if along.x > 0.0 else Vector3(0.08, 2.6, shop_w)
	add_box(shop, face + facing * 0.04 + Vector3(0, base + 1.35, 0), "storefront", false)
	# Interior iluminado detrás del vidrio (se ve a través de la vitrina).
	var inner := Vector3(shop_w - 0.4, 2.2, 0.02) if along.x > 0.0 else Vector3(0.02, 2.2, shop_w - 0.4)
	add_box(inner, face + facing * 0.085 + Vector3(0, base + 1.3, 0), "shop_interior", false)
	var pane := Vector3(shop_w, 2.5, 0.02) if along.x > 0.0 else Vector3(0.02, 2.5, shop_w)
	add_box(pane, face + facing * 0.13 + Vector3(0, base + 1.35, 0), "shop_glass", false)
	# Divisiones de la vitrina (montantes) y puerta en el centro.
	var mullions := maxi(2, int(shop_w / 1.8))
	for m in range(1, mullions):
		var t := float(m) / mullions - 0.5
		add_instance("mullion", _box_mesh(Vector3(0.08, 2.5, 0.08)), "rail",
				Transform3D(basis, face + along * (t * shop_w) + facing * 0.12 + Vector3(0, base + 1.35, 0)))
	# Marco de la vitrina y columnas laterales.
	for side: float in [-1.0, 1.0]:
		var col := Vector3(0.25, 2.8, 0.18) if along.x > 0.0 else Vector3(0.18, 2.8, 0.25)
		add_box(col, face + along * (side * shop_w * 0.5) + facing * 0.09 + Vector3(0, base + 1.4, 0), "concrete", false)
	var awning_mat: String = ["awning", "awning_green", "awning_blue", "awning_yellow"][_rng.randi() % 4]
	if _rng.randf() < 0.7:
		var awning := add_box(Vector3(shop_w, 0.08, 1.3), Vector3.ZERO, awning_mat, false)
		awning.basis = basis * Basis(Vector3.RIGHT, deg_to_rad(-14.0))
		awning.position = face + facing * 0.65 + Vector3(0, base + 2.9, 0)
	# Letrero con el nombre del local.
	var sign_size := Vector3(minf(shop_w, 5.5), 0.6, 0.12) if along.x > 0.0 else Vector3(0.12, 0.6, minf(shop_w, 5.5))
	var sign_pos := face + facing * 0.12 + Vector3(0, base + 3.25, 0)
	add_box(sign_size, sign_pos, "sign_%d" % _rng.randi_range(0, MaterialLibrary.SIGN_COLORS.size() - 1), false)
	var label := Label3D.new()
	label.text = SHOP_NAMES[_rng.randi() % SHOP_NAMES.size()]
	label.font_size = 64
	label.pixel_size = 0.0045
	label.outline_size = 10
	label.modulate = Color(1, 1, 0.96)
	label.outline_modulate = Color(0, 0, 0, 0.6)
	label.basis = basis.rotated(Vector3.UP, PI)
	label.position = sign_pos + facing * 0.075
	label.width = sign_size.x if along.x > 0.0 else sign_size.z
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	root.add_child(label)
	# Pisos superiores: franja entre pisos, ventanas con marco y alféizar, balcones.
	var balconies := _rng.randf() < 0.45
	for f in range(1, floors):
		var y := base + 3.6 + (f - 1) * floor_h + 1.4
		var band := Vector3(width + 0.06, 0.18, 0.1) if along.x > 0.0 else Vector3(0.1, 0.18, width + 0.06)
		add_instance("band_%s" % ("x" if along.x > 0.0 else "z"), _box_mesh(band), "concrete",
				Transform3D(Basis.IDENTITY, face + facing * 0.05 + Vector3(0, y - 1.48, 0)))
		var n := int(floor(width / 2.6))
		for i in n:
			var t := (i + 0.5) / n - 0.5
			var p := face + along * (t * width) + Vector3(0, y, 0)
			add_instance("frame", _box_mesh(Vector3(1.42, 1.72, 0.1)), "window_frame",
					Transform3D(basis, p + facing * 0.03))
			add_instance("sill", _box_mesh(Vector3(1.6, 0.08, 0.22)), "concrete",
					Transform3D(basis, p + facing * 0.1 + Vector3(0, -0.9, 0)))
			var xf := Transform3D(basis, p + facing * 0.085)
			if _rng.randf() < 0.22:
				_lit_windows.append(xf)
			else:
				_windows.append(xf)
			if balconies and f % 2 == 1:
				add_instance("balcony", _box_mesh(Vector3(1.9, 0.12, 0.8)), "concrete",
						Transform3D(basis, p + facing * 0.45 + Vector3(0, -0.92, 0)))
				# Baranda: pasamanos y barrotes.
				add_instance("balcony_rail", _box_mesh(Vector3(1.9, 0.05, 0.05)), "rail",
						Transform3D(basis, p + facing * 0.83 + Vector3(0, 0.0, 0)))
				for k in 7:
					var bx := (k / 6.0 - 0.5) * 1.84
					add_instance("balcony_bar", _box_mesh(Vector3(0.025, 0.86, 0.025)), "rail",
							Transform3D(basis, p + facing * 0.83 + along * bx + Vector3(0, -0.43, 0)))
	points["building_" + id] = {"face": face + Vector3(0, base, 0), "facing": facing}
	if not points.has("footprints"):
		points["footprints"] = []
	(points["footprints"] as Array).append(Rect2(center.x - footprint.x * 0.5, center.z - footprint.z * 0.5, footprint.x, footprint.z))


## Tanque de agua, aire acondicionado y antena en algunas terrazas.
func _rooftop(top: Vector3, footprint: Vector3) -> void:
	var r := _rng.randf()
	if r < 0.45:
		var p := top + Vector3(_rng.randf_range(-0.3, 0.3) * footprint.x, 0.0, _rng.randf_range(-0.3, 0.3) * footprint.z)
		add_instance("tank", _cyl_mesh(0.55, 1.1), "plastic_gray", Transform3D(Basis.IDENTITY, p + Vector3(0, 0.75, 0)))
		add_instance("tank_stand", _box_mesh(Vector3(1.2, 0.2, 1.2)), "metal", Transform3D(Basis.IDENTITY, p + Vector3(0, 0.1, 0)))
	if r > 0.3:
		var p2 := top + Vector3(_rng.randf_range(-0.35, 0.35) * footprint.x, 0.25, _rng.randf_range(-0.35, 0.35) * footprint.z)
		add_instance("ac", _box_mesh(Vector3(0.9, 0.5, 0.6)), "plastic_gray", Transform3D(Basis.IDENTITY, p2))


func _build_windows() -> void:
	var glass := _box_mesh(Vector3(1.2, 1.5, 0.02))
	for xf in _windows:
		add_instance("windows", glass, "glass", xf)
	for xf in _lit_windows:
		add_instance("windows_lit", glass, "glass_lit", xf)
	points["window_count"] = _windows.size() + _lit_windows.size()


## Fila de edificios en los bordes de la cuadra suroeste para que no se vea el
## final del área de prueba.
func _build_perimeter() -> void:
	var edge := HALF_SIZE - 6.0
	var pos := STREET_HALF + SIDEWALK + 2.0
	while pos < HALF_SIZE - 8.0:
		var w := _rng.randf_range(7.0, 12.0)
		var floors := _rng.randi_range(3, 6)
		_building(Vector3(-(pos + w * 0.5), 0, edge), Vector3(w, 0, 10.0), floors, Vector3(0, 0, -1), "so_borde_s_%d" % int(pos))
		_building(Vector3(-edge, 0, pos + w * 0.5), Vector3(10.0, 0, w), floors, Vector3(1, 0, 0), "so_borde_o_%d" % int(pos))
		pos += w


# ---------------------------------------------------------------------------
# Plaza de pruebas (cuadra suroeste)
# ---------------------------------------------------------------------------
func _build_test_plaza() -> void:
	var g := CURB_HEIGHT
	# Plataforma elevada con escaleras al norte y rampa al este.
	var top := g + STEP_RISE * STEP_COUNT
	var plat_min := Vector2(-30, 18)
	var plat_max := Vector2(-18, 26)
	var plat_size := Vector3(plat_max.x - plat_min.x, top - g, plat_max.y - plat_min.y)
	add_box(plat_size, Vector3((plat_min.x + plat_max.x) * 0.5, g + plat_size.y * 0.5, (plat_min.y + plat_max.y) * 0.5), "plaza")
	for i in STEP_COUNT:
		var h := STEP_RISE * (i + 1)
		var z := plat_min.y - STEP_RUN * (STEP_COUNT - i) + STEP_RUN * 0.5
		add_box(Vector3(4.0, h, STEP_RUN), Vector3(-24.0, g + h * 0.5, z), "concrete")
	points["stairs_bottom"] = Vector3(-24.0, g, plat_min.y - STEP_RUN * STEP_COUNT - 1.5)
	points["platform_top_y"] = top
	# Rampa de 15° desde el borde este de la plataforma hasta el suelo.
	var rise := top - g
	var angle := deg_to_rad(15.0)
	var length := rise / sin(angle)
	var run := rise / tan(angle)
	var ramp := add_box(Vector3(length + 0.1, 0.3, 4.0), Vector3.ZERO, "concrete")
	# Rotación negativa en Z: el extremo oeste (pegado a la plataforma) queda arriba.
	ramp.rotation.z = -angle
	# La cara superior de la rampa une el borde de la plataforma con el suelo.
	ramp.position = Vector3(plat_max.x + run * 0.5 + 0.15 * sin(angle), g + rise * 0.5 - 0.15 * cos(angle), 22.0)
	points["ramp_bottom"] = Vector3(plat_max.x + run + 1.5, g, 22.0)
	# Pendiente de 50°: demasiado empinada para subirla caminando.
	var steep := add_box(Vector3(5.0, 0.4, 5.0), Vector3(-36.0, g + 1.6, 22.0), "test_orange")
	steep.rotation.z = deg_to_rad(-50.0)
	points["steep_bottom"] = Vector3(-31.0, g, 22.0)
	# Túnel bajo: solo se pasa agachado.
	var tz := 37.0
	var tx := Vector2(-30.0, -24.0)
	var tlen := tx.y - tx.x
	var tcx := (tx.x + tx.y) * 0.5
	add_box(Vector3(tlen, 2.0, 0.3), Vector3(tcx, g + 1.0, tz - 1.35), "concrete")
	add_box(Vector3(tlen, 2.0, 0.3), Vector3(tcx, g + 1.0, tz + 1.35), "concrete")
	add_box(Vector3(tlen, 0.4, 3.0), Vector3(tcx, g + TUNNEL_CLEARANCE + 0.2, tz), "test_orange")
	points["tunnel_entry"] = Vector3(tx.y + 2.0, g, tz)
	points["tunnel_exit_x"] = tx.x - 1.0
	points["tunnel_inside"] = Vector3(tcx, g, tz)
	# Cajas: 0,3 m (se sube sin saltar), 0,6 m y 1,0 m (hay que saltar).
	for spec: Array in [[0.3, -12.0], [0.6, -16.0], [1.0, -20.0]]:
		add_box(Vector3(1.6, spec[0], 1.6), Vector3(spec[1], g + spec[0] * 0.5, 31.0), "wood")
		points["box_%d" % int(spec[0] * 10)] = Vector3(spec[1], g, 31.0)
	# Zona verde con árboles y bancas.
	add_box(Vector3(10.0, 0.05, 8.0), Vector3(-42.0, g + 0.025, 43.0), "grass", false)
	for p: Vector2 in [Vector2(-45, 40), Vector2(-41, 46), Vector2(-38, 41), Vector2(-46, 45)]:
		_tree(Vector3(p.x, g, p.y))
	for p: Vector2 in [Vector2(-40, 36), Vector2(-48, 36)]:
		_bench(Vector3(p.x, g, p.y))


# ---------------------------------------------------------------------------
# Mobiliario urbano
# ---------------------------------------------------------------------------
func _build_street_props() -> void:
	var d := STREET_HALF + 0.8
	var g := CURB_HEIGHT
	var along := -HALF_SIZE + 10.0
	while along < HALF_SIZE - 6.0:
		if absf(along) > STREET_HALF + SIDEWALK + 2.0:
			for side: float in [-1.0, 1.0]:
				_lamp(Vector3(along, g, side * d))
				_lamp(Vector3(side * d, g, along))
		along += 16.0
	for p: Vector2 in [Vector2(14, 6.3), Vector2(30, -6.3), Vector2(-6.3, -22), Vector2(6.3, 30)]:
		_tree(Vector3(p.x, g, p.y))


func _lamp(pos: Vector3) -> void:
	if not points.has("lamps"):
		points["lamps"] = []
	add_cylinder(0.07, 5.5, pos + Vector3(0, 2.75, 0), "metal", true)
	add_cylinder(0.12, 0.6, pos + Vector3(0, 0.3, 0), "metal", false)
	# El brazo apunta hacia la calle más cercana.
	var to_street := Vector3(-signf(pos.x), 0, 0) if absf(pos.x) < absf(pos.z) else Vector3(0, 0, -signf(pos.z))
	if absf(pos.x) < 0.01 or absf(pos.z) < 0.01:
		to_street = Vector3.FORWARD
	var arm := add_box(Vector3(0.06, 0.06, 1.2), Vector3.ZERO, "metal", false)
	arm.basis = Basis.looking_at(to_street, Vector3.UP)
	arm.position = pos + Vector3(0, 5.45, 0) + to_street * 0.55
	add_box(Vector3(0.45, 0.12, 0.3), pos + Vector3(0, 5.4, 0) + to_street * 1.1, "metal", false)
	add_box(Vector3(0.35, 0.04, 0.2), pos + Vector3(0, 5.33, 0) + to_street * 1.1, "bulb", false)
	# Donde va la luz de noche (TimeOfDay).
	(points["lamps"] as Array).append(pos + Vector3(0, 5.2, 0) + to_street * 1.1)


func _tree(pos: Vector3) -> void:
	var trunk_h := _rng.randf_range(2.4, 3.4)
	add_cylinder(0.16, trunk_h, pos + Vector3(0, trunk_h * 0.5, 0), "bark", true)
	add_cylinder(0.5, 0.06, pos + Vector3(0, 0.03, 0), "soil", false)   # Alcorque.
	var crown := _rng.randf_range(1.5, 2.3)
	# Algunos árboles florecidos (ocobos), el resto en dos tonos de verde.
	var leaves := "leaves_flower" if _rng.randf() < 0.25 else "leaves"
	add_sphere(crown, pos + Vector3(0, trunk_h + crown * 0.6, 0), leaves)
	for i in 4:
		var a := i * TAU / 4.0 + _rng.randf_range(-0.4, 0.4)
		var r := crown * _rng.randf_range(0.5, 0.75)
		var off := Vector3(cos(a) * crown * 0.6, _rng.randf_range(-0.1, 0.5) * crown, sin(a) * crown * 0.6)
		add_sphere(r, pos + Vector3(0, trunk_h + crown * 0.5, 0) + off, leaves if i % 2 == 0 else "leaves_dark")


func _bench(pos: Vector3) -> void:
	add_box(Vector3(1.8, 0.08, 0.45), pos + Vector3(0, 0.45, 0), "wood")
	add_box(Vector3(1.8, 0.45, 0.06), pos + Vector3(0, 0.75, 0.22), "wood", false)
	for x: float in [-0.75, 0.75]:
		add_box(Vector3(0.06, 0.45, 0.4), pos + Vector3(x, 0.22, 0), "metal", false)


func _build_bounds() -> void:
	var s := HALF_SIZE
	for spec: Array in [
		[Vector3(s * 2, 12, 1), Vector3(0, 6, -s - 0.5)],
		[Vector3(s * 2, 12, 1), Vector3(0, 6, s + 0.5)],
		[Vector3(1, 12, s * 2), Vector3(-s - 0.5, 6, 0)],
		[Vector3(1, 12, s * 2), Vector3(s + 0.5, 6, 0)],
	]:
		var body := StaticBody3D.new()
		body.collision_layer = PhysicsLayers.WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[0]
		shape.shape = box
		body.position = spec[1]
		body.add_child(shape)
		root.add_child(body)


# ---------------------------------------------------------------------------
# Primitivas con colisión
# ---------------------------------------------------------------------------
func add_box(size: Vector3, pos: Vector3, material: String, collide: bool = true) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var box := BoxShape3D.new()
	box.size = size
	return _add(mesh, box if collide else null, pos, material)


func add_cylinder(radius: float, height: float, pos: Vector3, material: String, collide: bool) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return _add(mesh, shape if collide else null, pos, material)


func add_sphere(radius: float, pos: Vector3, material: String) -> Node3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	return _add(mesh, null, pos, material)


## Agrega una instancia a un grupo dibujado con un solo MultiMesh (ventanas,
## marcos, balcones, tanques…). Todas las instancias de un grupo comparten malla.
func add_instance(group: String, mesh: Mesh, material: String, xform: Transform3D) -> void:
	if not _batches.has(group):
		_batches[group] = {"mesh": mesh, "material": material, "xforms": []}
	(_batches[group]["xforms"] as Array).append(xform)


func _flush_batches() -> void:
	var total := 0
	for group: String in _batches:
		var b: Dictionary = _batches[group]
		var xforms: Array = b["xforms"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b["mesh"]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batch_" + group
		mmi.multimesh = mm
		mmi.material_override = MaterialLibrary.get_material(b["material"])
		root.add_child(mmi)
		total += xforms.size()
	points["instanced_count"] = total


func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _cyl_mesh(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 12
	return m


func _add(mesh: Mesh, shape: Shape3D, pos: Vector3, material: String) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MaterialLibrary.get_material(material)
	if shape == null:
		mi.position = pos
		root.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.add_child(mi)
	root.add_child(body)
	return body


const SHOP_NAMES := [
	"Tienda Doña Rosa", "Panadería El Santandereano", "Droguería La Novena",
	"Granizados El Parque", "Miscelánea Cabecera", "Papelería El Estudiante",
	"Arepas La 33", "Cerrajería Rápida", "Ferretería San Pío", "Café La Ceiba",
	"Ropa y Calzado Sotomayor", "Restaurante El Paisa", "Peluquería Estilo",
	"Frutería Girón", "Cacharrería La Esquina", "Bocadillos Veleños",
]


static func _qname(q: Vector2) -> String:
	return ("n" if q.y < 0 else "s") + ("e" if q.x > 0 else "o")
