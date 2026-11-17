class_name CentroBuilder
extends CabeceraBuilder
## Tercer distrito (versión 2.0): EL CENTRO DE BUCARAMANGA (capítulo 6).
##
## Inspirado en Bucaramanga, no es una reproducción exacta. Unidades en metros,
## norte = -Z, este = +X. El área mide 120 × 120 m y la cruzan dos vías:
##
##   · La Carrera 27 (x = 0), avenida de norte a sur con separador de guayacanes.
##   · La Calle 36 (z = 0), de oriente a occidente.
##
## Las cuatro cuadras que quedan tienen personalidad propia:
##   · Noroeste: el PARQUE SANTANDER, con la estatua en el centro, ceibas
##     enormes, bancas y, al norte, la CATEDRAL de dos torres.
##   · Suroeste: el PARQUE GARCÍA ROVIRA, el centro histórico: plaza de
##     adoquín con palmas, estatua, la CAPILLA blanca y casas coloniales.
##   · Noreste: el comercio de LA 27, con un pasaje entre edificios, un patio
##     de atrás y una escalera de incendios a una terraza (ruta alternativa).
##   · Sureste: el PARQUE DE LAS CIGARRAS, un bosque con senderos de gravilla,
##     una quebrada con puente de madera y los casilleros del kiosco.
##
## Reutiliza las palmas y las escaleras de CabeceraBuilder y los edificios y
## lotes (MultiMesh) de PrototypeBlockBuilder. Registra en `points` todo lo que
## usa la misión (CentroMission).

const C_HALF := 60.0
const AVE := 7.0           ## Carrera 27: calzada de 14 m con separador.
const CALLE := 4.0         ## Calle 36: calzada de 8 m.
const SANTANDER := Rect2(-48.0, -40.0, 37.0, 32.0)
const ROVIRA := Rect2(-46.0, 10.0, 34.0, 34.0)
const CIGARRAS := Rect2(12.0, 9.0, 46.0, 49.0)
const STREAM_Z := 33.0     ## Quebrada del parque de las Cigarras.
const ALLEY := Vector2(-32.0, -28.0)   ## Pasaje de la 27 (de z a z).
const ROOF_A := 9.15       ## Altura de la terraza del edificio del pasaje.

var _tree_count := 0


func _init(parent: Node3D) -> void:
	super(parent)
	root.name = "Centro"
	half_size = C_HALF
	_rng.seed = 2026_11_17


func build() -> Dictionary:
	points["map"] = "centro"
	points["map_half"] = C_HALF
	points["minimap_rects"] = []
	points["zones"] = []
	points["hiding_spots"] = []
	points["secrets"] = []
	points["footprints"] = []
	_c_ground()
	_carrera_27()
	_parque_santander()
	_catedral()
	_parque_garcia_rovira()
	_capilla()
	_colonial_rows()
	_comercio_27()
	_parque_cigarras()
	_c_street_props()
	_build_windows()
	_flush_batches()
	_build_bounds()
	# Esquina suroriental del Parque Santander, mirando hacia la estatua.
	points["spawn"] = Vector3(-9.6, G, -6.4)
	points["spawn_yaw"] = deg_to_rad(38.0)
	points["trees"] = _tree_count
	points["reinforcement_entries"] = [Vector3(0.0, 0.0, -57.0), Vector3(0.0, 0.0, 57.0), Vector3(57.0, 0.0, 0.0), Vector3(-57.0, 0.0, 0.0)]
	points["sidewalk_route"] = PackedVector3Array([
		Vector3(-8.6, G, -40.0), Vector3(-8.6, G, -10.0), Vector3(-8.6, G, 20.0), Vector3(-8.6, G, 46.0),
		Vector3(8.6, G, -46.0), Vector3(8.6, G, -12.0), Vector3(8.6, G, 30.0), Vector3(8.6, G, 52.0),
		Vector3(-30.0, G, -5.6), Vector3(-50.0, G, 5.6), Vector3(30.0, G, -5.6), Vector3(48.0, G, 5.6),
	])
	return points


## Dónde está cada zona (para la misión y las pruebas).
static func zone_center(id: String) -> Vector3:
	match id:
		"santander":
			return Vector3(SANTANDER.get_center().x, G, SANTANDER.get_center().y)
		"rovira":
			return Vector3(ROVIRA.get_center().x, G, ROVIRA.get_center().y)
		"cigarras":
			return Vector3(CIGARRAS.get_center().x, G, CIGARRAS.get_center().y)
		"carrera27":
			return Vector3(0.0, G, -20.0)
	return Vector3.ZERO


# ---------------------------------------------------------------------------
# Suelo y vías
# ---------------------------------------------------------------------------
func _c_ground() -> void:
	add_box(Vector3(C_HALF * 2.0, 0.4, C_HALF * 2.0), Vector3(0, -0.2, 0), "asphalt")
	var w := C_HALF - AVE
	var d := C_HALF - CALLE
	for r: Rect2 in [Rect2(-C_HALF, -C_HALF, w, d), Rect2(AVE, -C_HALF, w, d), Rect2(-C_HALF, CALLE, w, d), Rect2(AVE, CALLE, w, d)]:
		_slab(r, "sidewalk")
	# Línea amarilla de la Calle 36 y cebras en los cuatro lados del cruce.
	var x := -C_HALF + 2.0
	while x < C_HALF - 2.0:
		if absf(x) > AVE + 4.0:
			add_box(Vector3(2.0, 0.01, 0.14), Vector3(x, 0.005, 0), "paint_yellow", false)
		x += 4.0
	for side: float in [-1.0, 1.0]:
		var s := -AVE + 0.8
		while s < AVE - 0.6:
			add_box(Vector3(0.55, 0.01, 2.6), Vector3(s, 0.006, side * (CALLE + 1.6)), "paint_white", false)
			s += 1.1
		var s2 := -CALLE + 0.6
		while s2 < CALLE - 0.4:
			add_box(Vector3(2.6, 0.01, 0.55), Vector3(side * (AVE + 1.6), 0.006, s2), "paint_white", false)
			s2 += 1.0
	var mm: Array = points["minimap_rects"]
	mm.append([Rect2(-C_HALF, -C_HALF, C_HALF * 2.0, C_HALF * 2.0), Color(0.16, 0.16, 0.18)])
	for r: Rect2 in [Rect2(-C_HALF, -C_HALF, w, d), Rect2(AVE, -C_HALF, w, d), Rect2(-C_HALF, CALLE, w, d), Rect2(AVE, CALLE, w, d)]:
		mm.append([r, Color(0.36, 0.36, 0.36)])


## Carrera 27: separador con guayacanes en flor y faroles a los dos lados.
func _carrera_27() -> void:
	for seg: Vector2 in [Vector2(-C_HALF, -CALLE - 1.0), Vector2(CALLE + 1.0, C_HALF)]:
		var len := seg.y - seg.x
		add_box(Vector3(2.0, G, len), Vector3(0, G * 0.5, (seg.x + seg.y) * 0.5), "curb")
		add_box(Vector3(1.7, 0.03, len - 0.3), Vector3(0, G + 0.015, (seg.x + seg.y) * 0.5), "grass", false)
		var z := seg.x + 5.0
		while z < seg.y - 3.0:
			_guayacan(Vector3(0, G, z))
			z += 11.0
	# Marcas de carril.
	var zz := -C_HALF + 2.0
	while zz < C_HALF - 2.0:
		if absf(zz) > CALLE + 6.0:
			for x: float in [-3.8, 3.8]:
				add_box(Vector3(0.14, 0.01, 2.0), Vector3(x, 0.005, zz), "paint_white", false)
		zz += 4.5
	(points["zones"] as Array).append({"name": "Carrera 27", "sub": "La avenida del Centro",
			"aabb": AABB(Vector3(-AVE - 3.0, -1, -C_HALF), Vector3((AVE + 3.0) * 2.0, 6, C_HALF * 2.0))})


## Guayacán: tronco delgado y copa amarilla (florecen en la ciudad).
func _guayacan(pos: Vector3) -> void:
	_tree_count += 1
	var h := _rng.randf_range(2.6, 3.2)
	add_cylinder(0.14, h, pos + Vector3(0, h * 0.5, 0), "bark", true)
	var crown := _rng.randf_range(1.4, 1.8)
	add_sphere(crown, pos + Vector3(0, h + crown * 0.55, 0), "awning_yellow")
	for i in 3:
		var a := i * TAU / 3.0 + _rng.randf()
		add_sphere(crown * 0.65, pos + Vector3(cos(a) * crown * 0.6, h + crown * 0.4, sin(a) * crown * 0.6), "leaves" if i == 0 else "awning_yellow")


## Ceiba: tronco grueso con raíces de tabla y una copa ancha y aplanada.
func _ceiba(pos: Vector3, size: float = 1.0) -> void:
	_tree_count += 1
	var h := 4.2 * size
	add_cylinder(0.45 * size, h, pos + Vector3(0, h * 0.5, 0), "bark", true)
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		var fin := add_box(Vector3(0.12, 0.9 * size, 1.1 * size), Vector3.ZERO, "bark", false)
		fin.rotation.y = a
		fin.position = pos + Vector3(cos(a) * 0.45 * size, 0.45 * size, -sin(a) * 0.45 * size)
	for i in 6:
		var a := i * TAU / 6.0 + _rng.randf_range(-0.3, 0.3)
		var r := _rng.randf_range(2.0, 2.8) * size
		var blob := add_sphere(r, pos + Vector3(cos(a) * 2.6 * size, h + 1.2 * size + _rng.randf_range(-0.3, 0.5), sin(a) * 2.6 * size),
				"leaves" if i % 2 == 0 else "leaves_dark")
		blob.scale = Vector3(1.0, 0.6, 1.0)
	var top := add_sphere(3.0 * size, pos + Vector3(0, h + 1.8 * size, 0), "leaves_dark")
	top.scale = Vector3(1.0, 0.55, 1.0)


## Matorral para esconderse (agachado adentro, nadie te ve).
func _bush_spot(pos: Vector3, size: Vector3) -> void:
	add_box(Vector3(size.x, 0.06, size.z), pos + Vector3(0, 0.03, 0), "soil", false)
	var n := int(maxf(size.x, size.z) / 0.8) + 1
	for i in n:
		var t := (i + 0.5) / n - 0.5
		var off := Vector3(t * size.x, 0, 0) if size.x > size.z else Vector3(0, 0, t * size.z)
		var r := minf(size.x, size.z) * 0.62
		var bush := add_sphere(r, pos + off + Vector3(0, size.y * 0.55, 0), "hedge" if i % 2 == 0 else "leaves_dark")
		bush.scale = Vector3(1.0, size.y / (r * 1.6), 1.0)
	(points["hiding_spots"] as Array).append({"position": pos, "size": size})


## Estatua de bronce sobre un pedestal de cantera, con placa.
func _statue(pos: Vector3, plate: String, facing_yaw: float) -> void:
	add_box(Vector3(2.6, 0.5, 2.6), pos + Vector3(0, 0.25, 0), "stone")
	add_box(Vector3(1.8, 2.2, 1.8), pos + Vector3(0, 1.6, 0), "stone")
	add_box(Vector3(2.1, 0.25, 2.1), pos + Vector3(0, 2.82, 0), "stone", false)
	var figure := Node3D.new()
	figure.position = pos + Vector3(0, 2.95, 0)
	figure.rotation.y = facing_yaw
	root.add_child(figure)
	var parts := [
		[_cyl_mesh(0.32, 1.1), Vector3(0, 0.55, 0)],
		[_box_mesh(Vector3(0.75, 1.1, 0.42)), Vector3(0, 1.55, 0)],
		[_box_mesh(Vector3(0.9, 0.18, 0.5)), Vector3(0, 2.05, 0)],
	]
	for p: Array in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.position = p[1]
		mi.material_override = MaterialLibrary.get_material("bronze")
		figure.add_child(mi)
	var head := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.48
	head.mesh = s
	head.position = Vector3(0, 2.4, 0)
	head.material_override = MaterialLibrary.get_material("bronze")
	figure.add_child(head)
	var arm := MeshInstance3D.new()
	arm.mesh = _box_mesh(Vector3(0.16, 0.85, 0.16))
	arm.position = Vector3(0.48, 1.95, -0.25)
	arm.rotation.x = deg_to_rad(-60.0)
	arm.material_override = MaterialLibrary.get_material("bronze")
	figure.add_child(arm)
	var label := Label3D.new()
	label.text = plate
	label.font_size = 40
	label.pixel_size = 0.005
	label.outline_size = 6
	label.modulate = Color(1.0, 0.9, 0.65)
	label.position = pos + Vector3(0, 1.7, 0.92)
	root.add_child(label)


func _bench_facing(pos: Vector3, yaw: float) -> void:
	var b := add_box(Vector3(1.8, 0.08, 0.45), pos + Vector3(0, 0.45, 0), "wood")
	b.rotation.y = yaw
	var back := add_box(Vector3(1.8, 0.45, 0.06), Vector3.ZERO, "wood", false)
	back.rotation.y = yaw
	back.position = pos + Vector3(0, 0.75, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.22)


## Farol colonial: poste negro con un farol de cuatro caras.
func _colonial_lamp(pos: Vector3) -> void:
	add_cylinder(0.08, 3.4, pos + Vector3(0, 1.7, 0), "rail", true)
	add_cylinder(0.16, 0.5, pos + Vector3(0, 0.25, 0), "rail", false)
	add_box(Vector3(0.42, 0.55, 0.42), pos + Vector3(0, 3.7, 0), "rail", false)
	add_box(Vector3(0.34, 0.42, 0.34), pos + Vector3(0, 3.68, 0), "bulb", false)
	add_box(Vector3(0.5, 0.08, 0.5), pos + Vector3(0, 4.0, 0), "rail", false)
	(points.get_or_add("lamps", []) as Array).append(pos + Vector3(0, 3.4, 0))


# ---------------------------------------------------------------------------
# Parque Santander y la Catedral
# ---------------------------------------------------------------------------
func _parque_santander() -> void:
	var r := SANTANDER
	var c := Vector3(r.get_center().x, G, r.get_center().y)
	add_box(Vector3(r.size.x, 0.03, r.size.y), Vector3(c.x, G + 0.015, c.z), "grass", false)
	(points["minimap_rects"] as Array).append([r, Color(0.3, 0.5, 0.28)])
	# Senderos: en cruz, en diagonal y la plazoleta redonda de la estatua.
	add_box(Vector3(3.2, 0.04, r.size.y), Vector3(c.x, G + 0.02, c.z), "plaza", false)
	add_box(Vector3(r.size.x, 0.04, 3.2), Vector3(c.x, G + 0.02, c.z), "plaza", false)
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var d := Vector3(corner.x, 0, corner.y) - Vector3(c.x, 0, c.z)
		var path := add_box(Vector3(2.4, 0.04, d.length()), Vector3.ZERO, "plaza", false)
		path.basis = Basis.looking_at(d.normalized(), Vector3.UP)
		path.position = c + d * 0.5 + Vector3(0, 0.02, 0)
	var disc := add_cylinder(6.5, 0.05, c + Vector3(0, 0.025, 0), "plaza", false)
	disc.name = "PlazoletaSantander"
	_statue(c, "GENERAL\nFRANCISCO DE PAULA\nSANTANDER", 0.0)
	points["santander_statue"] = c
	# Ceibas en las cuatro esquinas (sombra enorme) y bancas alrededor de la plazoleta.
	for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_ceiba(c + Vector3(q.x * 10.5, 0, q.y * 9.0), _rng.randf_range(0.85, 1.05))
	for k in 8:
		var a := k * TAU / 8.0 + TAU / 16.0
		_bench_facing(c + Vector3(cos(a) * 7.6, 0, sin(a) * 7.6), -a + PI * 0.5)
	for p: Vector3 in [c + Vector3(-15.0, 0, -12.0), c + Vector3(15.0, 0, 12.0), c + Vector3(-15.0, 0, 12.0), c + Vector3(15.0, 0, -12.0)]:
		_lamp(p, Vector3(0, 0, 1))
	_bush_spot(c + Vector3(-6.0, 0, 12.5), Vector3(3.2, 1.3, 1.4))
	_bush_spot(c + Vector3(12.5, 0, -4.5), Vector3(1.4, 1.3, 3.2))
	_bush_spot(c + Vector3(-13.0, 0, -4.0), Vector3(1.4, 1.3, 3.2))
	(points["zones"] as Array).append({"name": "Parque Santander", "sub": "El corazón del Centro",
			"aabb": AABB(Vector3(r.position.x, -1, r.position.y), Vector3(r.size.x, 8, r.size.y))})
	var props := PrototypeProps.new(self)
	props._granizado_stand(Vector3(r.end.x - 1.6, G, r.end.y - 2.5))


func _catedral() -> void:
	# Fachada hacia el sur (al parque). Nave central, dos torres y atrio.
	var front := -46.0
	var cx := -30.0
	var nave_w := 12.0
	var depth := 14.0
	var nave_h := 13.0
	add_box(Vector3(nave_w, nave_h, depth), Vector3(cx, G + nave_h * 0.5, front - depth * 0.5), "stone")
	# Techo a dos aguas de teja.
	for side: float in [-1.0, 1.0]:
		var roof := add_box(Vector3(nave_w * 0.58, 0.25, depth + 0.6), Vector3.ZERO, "tile_roof", false)
		roof.rotation.z = side * deg_to_rad(-28.0)
		roof.position = Vector3(cx + side * nave_w * 0.25, G + nave_h + 1.5, front - depth * 0.5)
	# Frontón triangular (tres franjas escalonadas).
	for i in 4:
		var w := nave_w * (1.0 - i * 0.24)
		add_box(Vector3(w, 0.9, 0.6), Vector3(cx, G + nave_h + 0.45 + i * 0.9, front - 0.3), "stone", false)
	add_box(Vector3(0.3, 1.6, 0.3), Vector3(cx, G + nave_h + 4.4, front - 0.3), "stone", false)
	add_box(Vector3(1.0, 0.3, 0.3), Vector3(cx, G + nave_h + 4.7, front - 0.3), "stone", false)
	for side: float in [-1.0, 1.0]:
		var tx := cx + side * (nave_w * 0.5 + 2.2)
		var th := 20.0
		add_box(Vector3(4.4, th, 4.4), Vector3(tx, G + th * 0.5, front - 2.2), "stone")
		for y: float in [nave_h * 0.5, nave_h, th - 0.4]:
			add_box(Vector3(4.8, 0.35, 4.8), Vector3(tx, G + y, front - 2.2), "concrete_light", false)
		# Campanario con vanos oscuros y cúpula.
		for f in 4:
			var dir := Vector3(sin(f * PI * 0.5), 0, cos(f * PI * 0.5))
			add_box(Vector3(1.2 if absf(dir.z) > 0.5 else 0.1, 2.2, 0.1 if absf(dir.z) > 0.5 else 1.2),
					Vector3(tx, G + th - 2.2, front - 2.2) + dir * 2.22, "storefront", false)
		var dome := add_sphere(2.0, Vector3(tx, G + th + 0.4, front - 2.2), "tile_roof")
		dome.scale = Vector3(1.0, 1.15, 1.0)
		add_box(Vector3(0.18, 1.8, 0.18), Vector3(tx, G + th + 3.1, front - 2.2), "metal", false)
		add_box(Vector3(0.8, 0.16, 0.16), Vector3(tx, G + th + 3.4, front - 2.2), "metal", false)
	# Portón de madera, rosetón iluminado y escalinata del atrio.
	add_box(Vector3(3.0, 4.6, 0.2), Vector3(cx, G + 2.3, front + 0.05), "door_wood", false)
	var rose := add_cylinder(1.5, 0.12, Vector3(cx, G + 8.2, front + 0.08), "glass_lit", false)
	rose.rotation.x = PI * 0.5
	for i in 3:
		add_box(Vector3(18.0 - i * 1.2, 0.17 * (i + 1), 1.2), Vector3(cx, G + 0.085 * (i + 1), front + 3.0 - i * 1.0), "stone")
	add_box(Vector3(22.0, 0.03, 6.0), Vector3(cx, G + 0.015, front + 3.0), "plaza", false)
	var sign := Label3D.new()
	sign.text = "CATEDRAL DE LA SAGRADA FAMILIA"
	sign.font_size = 56
	sign.pixel_size = 0.006
	sign.outline_size = 8
	sign.modulate = Color(1.0, 0.92, 0.75)
	sign.position = Vector3(cx, G + 5.6, front + 0.15)
	root.add_child(sign)
	(points["footprints"] as Array).append(Rect2(cx - nave_w * 0.5 - 4.4, front - depth, nave_w + 8.8, depth))
	points["catedral"] = Vector3(cx, G, front + 4.5)
	# Edificios que cierran la cuadra (oeste y a los lados de la catedral).
	var z := -C_HALF + 2.0
	while z < -8.0:
		var w := minf(_rng.randf_range(7.0, 10.0), -6.0 - z)
		_building(Vector3(-55.0, 0, z + w * 0.5), Vector3(10.0, 0, w), _rng.randi_range(2, 4), Vector3(1, 0, 0), "santander_o_%d" % int(z))
		z += w
	_building(Vector3(-13.5, 0, -54.0), Vector3(9.0, 0, 12.0), 5, Vector3(0, 0, 1), "santander_n_e")
	(points["zones"] as Array).append({"name": "La Catedral", "sub": "De la Sagrada Familia",
			"aabb": AABB(Vector3(cx - 12.0, -1, front - 2.0), Vector3(24.0, 8, 8.0))})


# ---------------------------------------------------------------------------
# Parque García Rovira, la capilla y las casas coloniales
# ---------------------------------------------------------------------------
func _parque_garcia_rovira() -> void:
	var r := ROVIRA
	var c := Vector3(r.get_center().x, G, r.get_center().y)
	add_box(Vector3(r.size.x, 0.04, r.size.y), Vector3(c.x, G + 0.02, c.z), "plaza", false)
	(points["minimap_rects"] as Array).append([r, Color(0.55, 0.42, 0.34)])
	# Cuatro jardines con palmas y matorrales; en el centro, la estatua.
	for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var gc := c + Vector3(q.x * 9.0, 0, q.y * 9.0)
		add_box(Vector3(11.0, 0.3, 11.0), gc + Vector3(0, 0.15, 0), "curb")
		add_box(Vector3(10.6, 0.03, 10.6), gc + Vector3(0, 0.31, 0), "grass", false)
		_palm(gc + Vector3(-2.5, 0.3, -2.5), _rng.randf_range(8.0, 10.0))
		_palm(gc + Vector3(2.5, 0.3, 2.5), _rng.randf_range(7.0, 9.0))
		_colonial_lamp(gc + Vector3(-q.x * 6.2, 0, -q.y * 6.2))
	_bush_spot(c + Vector3(-9.0, 0.3, 11.5), Vector3(3.2, 1.3, 1.4))
	_bush_spot(c + Vector3(11.5, 0.3, -9.0), Vector3(1.4, 1.3, 3.2))
	_statue(c, "GARCÍA ROVIRA", PI)
	points["rovira_statue"] = c
	for k in 4:
		var a := k * TAU / 4.0
		_bench_facing(c + Vector3(cos(a) * 4.2, 0, sin(a) * 4.2) + Vector3(sin(a), 0, -cos(a)) * 1.2, -a + PI * 0.5)
	(points["zones"] as Array).append({"name": "Parque García Rovira", "sub": "Donde empezó la ciudad",
			"aabb": AABB(Vector3(r.position.x, -1, r.position.y), Vector3(r.size.x, 8, r.size.y))})
	points["meeting_point"] = c + Vector3(6.0, 0, 6.0)


func _capilla() -> void:
	# Capilla blanca con espadaña de campanas, mirando al este (al parque).
	var c := Vector3(-54.0, G, 27.0)
	var w := 8.0     # a lo largo de z
	var d := 10.0    # a lo largo de x
	var h := 6.5
	add_box(Vector3(d, h, w), c + Vector3(0, h * 0.5, 0), "whitewash")
	for side: float in [-1.0, 1.0]:
		var roof := add_box(Vector3(d + 0.6, 0.2, w * 0.6), Vector3.ZERO, "tile_roof", false)
		roof.rotation.x = side * deg_to_rad(26.0)
		roof.position = c + Vector3(0, h + 1.0, side * w * 0.24)
	var fx := c.x + d * 0.5
	# Espadaña: muro escalonado con dos vanos y sus campanas.
	add_box(Vector3(0.6, 4.0, 5.0), Vector3(fx, G + h + 2.0, c.z), "whitewash")
	add_box(Vector3(0.6, 1.4, 2.6), Vector3(fx, G + h + 4.7, c.z), "whitewash")
	for dz: float in [-1.2, 1.2]:
		add_box(Vector3(0.62, 1.4, 0.9), Vector3(fx, G + h + 2.3, c.z + dz), "storefront", false)
		add_sphere(0.32, Vector3(fx, G + h + 2.25, c.z + dz), "bronze")
	add_box(Vector3(0.62, 1.0, 0.7), Vector3(fx, G + h + 4.7, c.z), "storefront", false)
	add_box(Vector3(0.12, 3.4, 1.9), Vector3(fx + 0.02, G + 1.7, c.z), "door_wood", false)
	add_box(Vector3(0.14, 0.25, 2.4), Vector3(fx + 0.03, G + 3.55, c.z), "colonial_blue", false)
	var sign := Label3D.new()
	sign.text = "CAPILLA DE LOS DOLORES"
	sign.font_size = 44
	sign.pixel_size = 0.006
	sign.outline_size = 8
	sign.modulate = Color(0.25, 0.2, 0.15)
	sign.outline_modulate = Color(1, 1, 1, 0.6)
	sign.position = Vector3(fx + 0.1, G + 4.4, c.z)
	sign.rotation.y = PI * 0.5
	root.add_child(sign)
	(points["footprints"] as Array).append(Rect2(c.x - d * 0.5, c.z - w * 0.5, d, w))
	points["capilla"] = Vector3(fx + 2.0, G, c.z)
	(points["zones"] as Array).append({"name": "Capilla de los Dolores", "sub": "La iglesia más antigua del Centro",
			"aabb": AABB(Vector3(fx, -1, c.z - 5.0), Vector3(5.0, 6, 10.0))})


## Casa colonial: muros encalados, zócalo de color, techo de teja con alero,
## puertas y ventanas de madera y, en las de dos pisos, balcón corrido.
func _colonial_house(center: Vector3, size: Vector3, facing: Vector3, floors: int) -> void:
	var h := 3.4 * floors
	add_box(Vector3(size.x, h, size.z), center + Vector3(0, G + h * 0.5, 0), "whitewash")
	var accent: String = ["colonial_green", "colonial_blue", "door_wood"][_rng.randi() % 3]
	add_box(Vector3(size.x + 0.04, 0.7, size.z + 0.04), center + Vector3(0, G + 0.35, 0), accent, false)
	var along_x := absf(facing.z) > 0.5
	var width := size.x if along_x else size.z
	var depth := size.z if along_x else size.x
	# Techo inclinado hacia la calle con alero.
	var roof := add_box(Vector3(size.x + 0.8, 0.22, size.z + 0.8), Vector3.ZERO, "tile_roof", false)
	roof.position = center + Vector3(0, G + h + 0.6, 0)
	roof.rotation = Vector3(-facing.z * deg_to_rad(12.0), 0, facing.x * deg_to_rad(12.0))
	var face := center + facing * (depth * 0.5)
	var basis := Basis.looking_at(facing, Vector3.UP)
	var along := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var n := maxi(2, int(width / 3.0))
	for i in n:
		var t := (i + 0.5) / n - 0.5
		var p := face + along * (t * width)
		var is_door := i == n / 2
		var panel := Vector3(1.2, 2.4 if is_door else 1.5, 0.1)
		var y := 1.2 if is_door else 1.5
		add_instance("colonial_door" if is_door else "colonial_window", _box_mesh(panel), "door_wood",
				Transform3D(basis, p + facing * 0.05 + Vector3(0, G + y, 0)))
		if not is_door:
			add_instance("colonial_bars", _box_mesh(Vector3(1.3, 1.6, 0.06)), "rail",
					Transform3D(basis, p + facing * 0.14 + Vector3(0, G + y, 0)))
		if floors > 1:
			add_instance("colonial_window2", _box_mesh(Vector3(1.0, 1.8, 0.1)), "door_wood",
					Transform3D(basis, p + facing * 0.05 + Vector3(0, G + 4.6, 0)))
	if floors > 1:
		var bal := Vector3(width - 0.6, 0.12, 0.9) if along_x else Vector3(0.9, 0.12, width - 0.6)
		add_box(bal, face + facing * 0.45 + Vector3(0, G + 3.55, 0), "door_wood", false)
		var rail := Vector3(width - 0.6, 0.9, 0.05) if along_x else Vector3(0.05, 0.9, width - 0.6)
		add_box(rail, face + facing * 0.88 + Vector3(0, G + 4.05, 0), accent, false)
	(points["footprints"] as Array).append(Rect2(center.x - size.x * 0.5, center.z - size.z * 0.5, size.x, size.z))


func _colonial_rows() -> void:
	# Al sur del parque, mirando al norte.
	var x := -C_HALF + 1.0
	while x < -9.0:
		var w := minf(_rng.randf_range(6.0, 9.0), -8.5 - x)
		if w < 4.0:
			break
		_colonial_house(Vector3(x + w * 0.5, 0, 54.0), Vector3(w, 0, 10.0), Vector3(0, 0, -1), _rng.randi_range(1, 2))
		x += w
	# Al oeste, a los lados de la capilla, mirando al este.
	for spec: Vector2 in [Vector2(8.0, 14.0), Vector2(36.0, 42.0)]:
		_colonial_house(Vector3(-55.0, 0, (spec.x + spec.y) * 0.5), Vector3(10.0, 0, spec.y - spec.x), Vector3(1, 0, 0), 2)
	# Casa de Bolívar: casona colonial (hoy museo) en la esquina noreste.
	_colonial_house(Vector3(-55.0, 0, 46.5), Vector3(10.0, 0, 5.0), Vector3(1, 0, 0), 2)
	var plate := Label3D.new()
	plate.text = "CASA DE BOLÍVAR\nMUSEO"
	plate.font_size = 36
	plate.pixel_size = 0.005
	plate.outline_size = 6
	plate.modulate = Color(0.3, 0.2, 0.12)
	plate.outline_modulate = Color(1, 1, 1, 0.5)
	plate.position = Vector3(-49.9, G + 2.9, 46.5)
	plate.rotation.y = PI * 0.5
	root.add_child(plate)
	points["casa_bolivar"] = Vector3(-48.6, G, 46.5)


# ---------------------------------------------------------------------------
# El comercio de la 27: pasaje, patio y terraza
# ---------------------------------------------------------------------------
func _comercio_27() -> void:
	# Fila de locales mirando a la 27 (oeste), con el pasaje en medio.
	var z := -C_HALF + 1.5
	while z < -8.0:
		var w := minf(_rng.randf_range(7.0, 9.5), -7.5 - z)
		if z < ALLEY.y and z + w > ALLEY.x:
			w = ALLEY.x - z
		if w < 3.0:
			z = ALLEY.y
			continue
		var floors := _rng.randi_range(3, 5)
		var height := 0.0
		# El edificio al sur del pasaje tiene la terraza de la escalera de incendios.
		if absf(z - ALLEY.y) < 0.01:
			height = ROOF_A - G
		_building(Vector3(16.0, 0, z + w * 0.5), Vector3(12.0, 0, w), floors, Vector3(-1, 0, 0), "la27_%d" % int(z), height)
		z += w
	# Pasaje peatonal con guirnalda de bombillos.
	add_box(Vector3(12.0, 0.04, ALLEY.y - ALLEY.x), Vector3(16.0, G + 0.02, (ALLEY.x + ALLEY.y) * 0.5), "plaza", false)
	for i in 6:
		add_sphere(0.09, Vector3(11.0 + i * 2.0, G + 4.2 - sin(i / 5.0 * PI) * 0.4, (ALLEY.x + ALLEY.y) * 0.5), "bulb")
	(points["zones"] as Array).append({"name": "Pasaje de la 27", "sub": "Un atajo entre los locales",
			"aabb": AABB(Vector3(10.0, -1, ALLEY.x), Vector3(12.0, 5, ALLEY.y - ALLEY.x))})
	# Patio de atrás: canecas, cajas y la escalera de incendios a la terraza.
	add_box(Vector3(1.6, 1.3, 2.6), Vector3(26.0, G + 0.65, -36.0), "plastic_green")
	add_box(Vector3(1.2, 1.0, 1.2), Vector3(27.0, G + 0.5, -20.0), "crate")
	add_box(Vector3(1.2, 1.0, 1.2), Vector3(27.0, G + 1.5, -20.0), "crate")
	var stair_start := Vector3(33.6, G, -25.0)
	_stair_run(stair_start, Vector3(-1, 0, 0), ROOF_A - G, 1.4)
	add_box(Vector3(1.6, 0.2, 1.6), Vector3(22.4, ROOF_A - 0.1, -25.0), "metal")
	points["fire_stairs"] = stair_start + Vector3(0.6, 0, 0)
	points["roof_a"] = Vector3(16.0, ROOF_A + 0.05, -23.0)
	# Fila sobre la Calle 36 (mirando al sur) y fila del fondo (mirando al patio).
	var x := 24.0
	while x < C_HALF - 4.0:
		var w := minf(_rng.randf_range(8.0, 11.0), C_HALF - 2.0 - x)
		_building(Vector3(x + w * 0.5, 0, -12.5), Vector3(w, 0, 9.0), _rng.randi_range(4, 7), Vector3(0, 0, 1), "calle36_%d" % int(x))
		_building(Vector3(x + w * 0.5, 0, -53.0), Vector3(w, 0, 12.0), _rng.randi_range(5, 9), Vector3(0, 0, 1), "fondo_%d" % int(x))
		x += w
	(points["minimap_rects"] as Array).append([Rect2(22.0, -47.0, 36.0, 30.0), Color(0.42, 0.4, 0.38)])
	(points["zones"] as Array).append({"name": "Patio de la 27", "sub": "Detrás de los locales",
			"aabb": AABB(Vector3(22.0, -1, -47.0), Vector3(36.0, 6, 30.0))})


# ---------------------------------------------------------------------------
# Parque de las Cigarras
# ---------------------------------------------------------------------------
func _parque_cigarras() -> void:
	var r := CIGARRAS
	add_box(Vector3(r.size.x, 0.03, r.size.y), Vector3(r.get_center().x, G + 0.015, r.get_center().y), "leaves_dark", false)
	(points["minimap_rects"] as Array).append([r, Color(0.2, 0.4, 0.2)])
	# Senderos de gravilla: entrada desde la 27, un anillo y un ramal al kiosco.
	var path_pts := [Vector3(12.0, 0, 20.0), Vector3(22.0, 0, 16.0), Vector3(36.0, 0, 14.0), Vector3(50.0, 0, 18.0),
			Vector3(53.0, 0, 30.0), Vector3(50.0, 0, 44.0), Vector3(40.0, 0, 50.0), Vector3(26.0, 0, 48.0),
			Vector3(19.0, 0, 38.0), Vector3(22.0, 0, 16.0)]
	for i in path_pts.size() - 1:
		var a: Vector3 = path_pts[i]
		var b: Vector3 = path_pts[i + 1]
		var d := b - a
		var seg := add_box(Vector3(2.2, 0.04, d.length() + 2.0), Vector3.ZERO, "gravel", false)
		seg.basis = Basis.looking_at(d.normalized(), Vector3.UP)
		seg.position = (a + b) * 0.5 + Vector3(0, G + 0.035, 0)
	points["cigarras_path"] = PackedVector3Array(path_pts.map(func(p: Vector3) -> Vector3: return p + Vector3(0, G, 0)))
	# La quebrada con piedras y el puente de madera.
	add_box(Vector3(r.size.x, 0.02, 2.6), Vector3(r.get_center().x, G + 0.045, STREAM_Z), "water", false)
	for i in 10:
		add_sphere(_rng.randf_range(0.25, 0.5), Vector3(_rng.randf_range(r.position.x + 1, r.end.x - 1), G + 0.05, STREAM_Z + _rng.randf_range(-1.6, 1.6)), "concrete")
	var bx := 52.0
	add_box(Vector3(2.4, 0.2, 5.0), Vector3(bx, G + 0.35, STREAM_Z), "wood")
	for s: float in [-1.15, 1.15]:
		add_box(Vector3(0.08, 0.9, 5.0), Vector3(bx + s, G + 0.85, STREAM_Z), "wood", false)
	# Piedras para cruzar saltando (ruta alternativa) cerca del sendero oeste.
	for k in 3:
		add_cylinder(0.45, 0.3, Vector3(19.0, G + 0.15, STREAM_Z - 1.4 + k * 1.4), "concrete", true)
	# Bosque: muchos árboles fuera de los senderos.
	var placed := 0
	var tries := 0
	while placed < 34 and tries < 400:
		tries += 1
		var p := Vector3(_rng.randf_range(r.position.x + 2.0, r.end.x - 2.0), G, _rng.randf_range(r.position.y + 2.0, r.end.y - 2.0))
		if absf(p.z - STREAM_Z) < 2.6 or _near_path(p, path_pts, 2.6) or p.distance_to(Vector3(46.0, G, 46.0)) < 6.0:
			continue
		if placed % 5 == 0:
			_ceiba(p, _rng.randf_range(0.55, 0.75))
		else:
			_tree(p)
			_tree_count += 1
		placed += 1
	# Kiosco de los casilleros (el casillero 27 lo usa la misión).
	var k := Vector3(46.0, G, 46.0)
	add_box(Vector3(5.0, 0.2, 4.0), k + Vector3(0, 0.1, 0), "wood")
	for dx: float in [-2.3, 2.3]:
		for dz: float in [-1.8, 1.8]:
			add_cylinder(0.1, 2.8, k + Vector3(dx, 1.5, dz), "wood", false)
	var roof := add_box(Vector3(5.8, 0.18, 4.8), k + Vector3(0, 3.0, 0), "tile_roof", false)
	roof.rotation.x = deg_to_rad(6.0)
	add_box(Vector3(3.6, 2.0, 0.5), k + Vector3(0, 1.2, -1.6), "locker")
	for i in 4:
		for j in 2:
			add_box(Vector3(0.82, 0.9, 0.03), k + Vector3(-1.35 + i * 0.9, 0.75 + j * 0.95, -1.34), "metal", false)
	var label := Label3D.new()
	label.text = "CASILLEROS"
	label.font_size = 44
	label.pixel_size = 0.005
	label.outline_size = 8
	label.position = k + Vector3(0, 2.5, -1.3)
	root.add_child(label)
	points["lockers"] = k + Vector3(0.45, 0, -0.6)
	for p2: Vector3 in [Vector3(14.0, G, 12.0), Vector3(40.0, G, 18.0), Vector3(28.0, G, 46.0)]:
		_colonial_lamp(p2)
	_bench_facing(Vector3(30.0, G, 16.8), PI)
	_bench_facing(Vector3(52.2, G, 38.0), -PI * 0.5)
	_bush_spot(Vector3(33.0, G, 23.0), Vector3(3.2, 1.3, 1.4))
	_bush_spot(Vector3(24.0, G, 52.0), Vector3(3.2, 1.3, 1.4))
	_bush_spot(Vector3(44.0, G, 40.0), Vector3(1.4, 1.3, 3.2))
	# Claro escondido en la esquina sureste (un secreto).
	add_cylinder(2.5, 0.04, Vector3(55.0, G + 0.04, 55.0), "grass", false)
	(points["zones"] as Array).append({"name": "Parque de las Cigarras", "sub": "Un bosque en plena ciudad",
			"aabb": AABB(Vector3(r.position.x, -1, r.position.y), Vector3(r.size.x, 8, r.size.y))})


func _near_path(p: Vector3, pts: Array, dist: float) -> bool:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), a, b)
		if q.distance_to(Vector3(p.x, 0, p.z)) < dist:
			return true
	return false


# ---------------------------------------------------------------------------
# Mobiliario
# ---------------------------------------------------------------------------
func _c_street_props() -> void:
	var props := PrototypeProps.new(self)
	var z := -C_HALF + 6.0
	while z < C_HALF - 4.0:
		if absf(z) > CALLE + 4.0:
			_lamp(Vector3(-AVE - 0.8, G, z), Vector3(1, 0, 0))
			_lamp(Vector3(AVE + 0.8, G, z), Vector3(-1, 0, 0))
		z += 15.0
	var lane := AVE - 1.1
	for spec: Array in [[-lane, -34.0, PI], [-lane, -18.0, PI], [-lane, 22.0, PI], [lane, -40.0, 0.0], [lane, -14.0, 0.0],
			[lane, 40.0, 0.0], [-lane, 44.0, PI]]:
		props._car(Vector3(spec[0], 0, spec[1]), spec[2], "car_%d" % _rng.randi_range(0, MaterialLibrary.CAR_COLORS.size() - 1))
	# Semáforos del cruce de la 27 con la 36.
	for sx: float in [-1.0, 1.0]:
		var tl := TrafficLight.new()
		tl.position = Vector3(sx * (AVE + 0.6), G, sx * (CALLE + 0.6))
		tl.rotation.y = PI * 0.5 if sx > 0.0 else -PI * 0.5
		tl.axis = "ns" if sx > 0.0 else "ew"
		root.add_child(tl)
	_paradero(Vector3(9.4, G, 24.0))
	# Puesto de obleas de Don Aníbal en la 27.
	var stand := props._group(Vector3(8.4, G, -16.0), -PI * 0.5, "PuestoObleas")
	props._part(stand, props._box(Vector3(1.6, 0.95, 0.8)), Vector3(0, 0.62, 0), "paint_white")
	props._part(stand, props._box(Vector3(1.8, 0.08, 1.1)), Vector3(0, 2.2, 0), "awning")
	props._part(stand, props._cyl(0.03, 1.2), Vector3(0, 1.6, 0), "metal")
	props._solid(stand, Vector3(1.6, 1.0, 0.8), Vector3(0, 0.5, 0), PhysicsLayers.WORLD)
	var sign := Label3D.new()
	sign.text = "OBLEAS DON ANÍBAL"
	sign.font_size = 36
	sign.pixel_size = 0.005
	sign.outline_size = 8
	sign.modulate = Color(1.0, 0.9, 0.6)
	sign.position = Vector3(0, 0.75, 0.42)
	stand.add_child(sign)
	points["obleas"] = Vector3(9.6, G, -16.0)


## Paradero con techo al que se puede subir: jardinera, caja de luz y techo.
func _paradero(pos: Vector3) -> void:
	# Mirando al oeste (a la 27): vidrio al este.
	add_box(Vector3(1.6, 0.12, 3.6), pos + Vector3(0, 2.45, 0), "metal_green")
	add_box(Vector3(0.05, 2.0, 3.6), pos + Vector3(0.7, 1.3, 0), "glass")
	for dz: float in [-1.7, 1.7]:
		add_box(Vector3(0.1, 2.4, 0.1), pos + Vector3(0.7, 1.2, dz), "metal")
	add_box(Vector3(0.4, 0.08, 2.6), pos + Vector3(0.45, 0.48, 0), "wood")
	add_box(Vector3(0.1, 2.4, 3.6), pos + Vector3(0.72, 1.2, 0), "metal")   # colisión del vidrio
	# Escalones para subir al techo: jardinera y caja de luz.
	add_box(Vector3(1.2, 0.6, 1.2), pos + Vector3(1.6, 0.3, 3.0), "concrete")
	add_box(Vector3(0.8, 1.4, 0.8), pos + Vector3(1.3, 0.7, 1.9), "metal_green")
	var label := Label3D.new()
	label.text = "PARADERO · RUTA 27"
	label.font_size = 44
	label.pixel_size = 0.005
	label.outline_size = 8
	label.position = pos + Vector3(-0.82, 2.62, 0)
	label.rotation.y = -PI * 0.5
	root.add_child(label)
	points["paradero"] = pos + Vector3(-1.4, 0, 0)
	points["paradero_roof"] = pos + Vector3(0, 2.52, 0)
