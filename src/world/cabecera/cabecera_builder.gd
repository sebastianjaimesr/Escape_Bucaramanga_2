class_name CabeceraBuilder
extends PrototypeBlockBuilder
## Segundo distrito: CABECERA Y EL PARQUE DE LAS PALMAS (capítulo 5).
##
## Inspirado en Bucaramanga, no es una reproducción exacta. Unidades en metros,
## norte = -Z, este = +X. El área mide 140 × 140 m:
##
##   · Oeste: un parque de palmas con fuente, senderos, bancas, kiosco,
##     granizados, matorrales y un mirador de madera (llegada de la tirolesa).
##   · Centro: la Carrera 33, una avenida ancha con separador de palmas.
##   · Este: una fila de edificios bajos con TERRAZAS CONECTADAS (la ruta de
##     parkour, de sur a norte, con saltos de distinta dificultad), una calle
##     de servicio detrás y, al fondo, torres de vidrio y el C.C. La Meseta.
##   · Sur: la cañada y el Puente de la Novena, que lleva al mirador del final.
##
## Reutiliza las primitivas, los lotes (MultiMesh) y los edificios de
## PrototypeBlockBuilder. Registra en `points` todo lo que usa la misión.

const HALF := 70.0
const G := CURB_HEIGHT
const AVE_HALF := 7.0            ## Carrera 33: calzada de 14 m con separador.
const NORTH_Z := -40.0           ## Eje de la calle norte.
const SOUTH_Z := 40.0            ## Eje de la calle sur.
const CROSS_HALF := 4.0
const RAVINE := Vector2(47.5, 60.5)   ## Cañada (de z a z).
const BRIDGE_X := Vector2(-30.0, -24.0)
const ROW_X := Vector2(12.0, 26.0)    ## Fila de edificios con terrazas.
const LANE_X := Vector2(26.0, 32.0)   ## Calle de servicio.

## Terrazas de la ruta de parkour, de sur a norte: [z_min, z_max, altura].
## Entre ellas quedan callejones de 2 a 3 m que hay que saltar.
const ROOFS := [
	[21.0, 32.0, 6.6],
	[8.0, 19.0, 7.4],
	[-6.0, 5.4, 6.8],
	[-21.0, -9.0, 7.6],
	[-32.0, -23.0, 7.6],
]
const ROOF_SLAB := 0.27
const MIRADOR := Vector3(-21.0, 0.0, -23.0)   ## Centro del mirador del parque.
const MIRADOR_TOP := 2.6

var _palm_count := 0


func _init(parent: Node3D) -> void:
	super(parent)
	root.name = "Cabecera"
	half_size = HALF
	_rng.seed = 2026_11_09


func build() -> Dictionary:
	points["map"] = "cabecera"
	points["map_half"] = HALF
	points["minimap_rects"] = []
	points["zones"] = []
	_ground()
	_avenue()
	_park()
	_rooftop_row()
	_service_lane()
	_towers()
	_north_row()
	_ravine_and_bridge()
	_street_props()
	_finish_plaza()
	_build_windows()
	_flush_batches()
	_build_bounds()
	points["spawn"] = Vector3(-52.0, G, 26.0)
	points["spawn_yaw"] = deg_to_rad(-135.0)
	points["palms"] = _palm_count
	points["reinforcement_entries"] = [Vector3(0.0, 0.0, -66.0), Vector3(66.0, G, 0.0), Vector3(-66.0, G, 0.0), Vector3(0.0, 0.0, SOUTH_Z)]
	return points


static func roof_top(i: int) -> float:
	return G + float(ROOFS[i][2]) + ROOF_SLAB


static func roof_center(i: int) -> Vector3:
	return Vector3((ROW_X.x + ROW_X.y) * 0.5, roof_top(i), (float(ROOFS[i][0]) + float(ROOFS[i][1])) * 0.5)


# ---------------------------------------------------------------------------
# Suelo
# ---------------------------------------------------------------------------
func _ground() -> void:
	var n := -HALF
	var s := RAVINE.x
	# Asfalto hasta la cañada; al otro lado, la plaza del mirador.
	add_box(Vector3(HALF * 2.0, 0.4, s - n), Vector3(0, -0.2, (n + s) * 0.5), "asphalt")
	# Losas elevadas (andén) de cada cuadra.
	for r: Rect2 in [
		Rect2(-HALF, NORTH_Z + CROSS_HALF, HALF - AVE_HALF, SOUTH_Z - CROSS_HALF - NORTH_Z - CROSS_HALF),
		Rect2(AVE_HALF, NORTH_Z + CROSS_HALF, HALF - AVE_HALF, SOUTH_Z - CROSS_HALF - NORTH_Z - CROSS_HALF),
		Rect2(-HALF, -HALF, HALF - AVE_HALF, HALF + NORTH_Z - CROSS_HALF),
		Rect2(AVE_HALF, -HALF, HALF - AVE_HALF, HALF + NORTH_Z - CROSS_HALF),
		Rect2(-HALF, SOUTH_Z + CROSS_HALF, HALF - AVE_HALF, RAVINE.x - SOUTH_Z - CROSS_HALF),
		Rect2(AVE_HALF, SOUTH_Z + CROSS_HALF, HALF - AVE_HALF, RAVINE.x - SOUTH_Z - CROSS_HALF),
	]:
		_slab(r, "sidewalk")
	# Marcas viales: línea discontinua y cebras.
	var z := -HALF + 2.0
	while z < RAVINE.x - 2.0:
		if absf(z - NORTH_Z) > 7.0 and absf(z - SOUTH_Z) > 7.0:
			for x: float in [-3.6, 3.6]:
				add_box(Vector3(0.14, 0.01, 2.0), Vector3(x, 0.005, z), "paint_white", false)
		z += 4.5
	for cz: float in [NORTH_Z, SOUTH_Z]:
		var x := -HALF + 2.0
		while x < HALF - 2.0:
			if absf(x) > AVE_HALF + 5.0:
				add_box(Vector3(2.0, 0.01, 0.14), Vector3(x, 0.005, cz), "paint_yellow", false)
			x += 4.0
		for side: float in [-1.0, 1.0]:
			var stripe := -AVE_HALF + 0.8
			while stripe < AVE_HALF - 0.6:
				add_box(Vector3(0.55, 0.01, 2.6), Vector3(stripe, 0.006, cz + side * (CROSS_HALF + 1.6)), "paint_white", false)
				stripe += 1.1
			var s2 := cz - CROSS_HALF + 0.6
			while s2 < cz + CROSS_HALF - 0.4:
				add_box(Vector3(2.6, 0.01, 0.55), Vector3(side * (AVE_HALF + 1.6), 0.006, s2), "paint_white", false)
				s2 += 1.0
	var mm: Array = points["minimap_rects"]
	mm.append([Rect2(-HALF, -HALF, HALF * 2.0, RAVINE.x + HALF), Color(0.16, 0.16, 0.18)])
	for r: Rect2 in [Rect2(-HALF, -32.0, HALF - AVE_HALF - 4.0, 64.0), Rect2(AVE_HALF + 4.0, -32.0, HALF - AVE_HALF - 4.0, 64.0),
			Rect2(-HALF, -HALF, HALF - AVE_HALF - 4.0, HALF + NORTH_Z - CROSS_HALF - 4.0), Rect2(AVE_HALF + 4.0, -HALF, HALF - AVE_HALF - 4.0, HALF + NORTH_Z - CROSS_HALF - 4.0)]:
		mm.append([r, Color(0.36, 0.36, 0.36)])


func _slab(r: Rect2, material: String) -> void:
	add_box(Vector3(r.size.x, G, r.size.y), Vector3(r.get_center().x, G * 0.5, r.get_center().y), material)


# ---------------------------------------------------------------------------
# Carrera 33: separador con palmas
# ---------------------------------------------------------------------------
func _avenue() -> void:
	var segments := [Vector2(-HALF, NORTH_Z - CROSS_HALF - 1.0), Vector2(NORTH_Z + CROSS_HALF + 1.0, SOUTH_Z - CROSS_HALF - 1.0),
			Vector2(SOUTH_Z + CROSS_HALF + 1.0, RAVINE.x - 0.5)]
	for seg: Vector2 in segments:
		var len := seg.y - seg.x
		add_box(Vector3(2.0, G, len), Vector3(0, G * 0.5, (seg.x + seg.y) * 0.5), "curb")
		add_box(Vector3(1.7, 0.03, len - 0.3), Vector3(0, G + 0.015, (seg.x + seg.y) * 0.5), "grass", false)
		var z := seg.x + 4.0
		while z < seg.y - 2.0:
			# Sin palmas donde pasa el cable de la tirolesa.
			if z < -30.0 or z > -18.0:
				_palm(Vector3(0, G, z), _rng.randf_range(7.5, 9.5))
			z += 9.0
	(points["zones"] as Array).append({"name": "Carrera 33", "sub": "La avenida de las palmas",
			"aabb": AABB(Vector3(-AVE_HALF, -1, NORTH_Z + CROSS_HALF), Vector3(AVE_HALF * 2.0, 6, SOUTH_Z - NORTH_Z - CROSS_HALF * 2.0))})


## Palma real: tronco delgado con una leve curva y una corona de hojas caídas.
func _palm(pos: Vector3, height: float) -> void:
	_palm_count += 1
	add_cylinder(0.24, 2.0, pos + Vector3(0, 1.0, 0), "palm_trunk", true)
	var seg := _cyl_mesh(0.19, 1.6)
	var lean := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(0.02, 0.06)
	var p := pos + Vector3(0, 2.0, 0)
	var n := int((height - 2.0) / 1.5)
	for i in n:
		var offset := lean * float(i * i) * 0.5
		add_instance("palm_trunk", seg, "palm_trunk", Transform3D(Basis.IDENTITY, p + offset + Vector3(0, 0.75, 0)))
		p.y += 1.5
	var top := p + lean * float(n * n) * 0.5
	var frond := _box_mesh(Vector3(0.6, 0.04, 2.9))
	var count := 9
	var spin := _rng.randf() * TAU
	for k in count:
		var b := Basis(Vector3.UP, spin + k * TAU / count) * Basis(Vector3.RIGHT, -_rng.randf_range(0.3, 0.75))
		var xf := Transform3D(b, top) * Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.4))
		add_instance("palm_frond" if k % 2 == 0 else "palm_frond_dark", frond, "palm_frond" if k % 2 == 0 else "palm_frond_dark", xf)
	var nut := SphereMesh.new()
	nut.radius = 0.13
	nut.height = 0.26
	nut.radial_segments = 8
	nut.rings = 4
	for k in 3:
		var a := k * TAU / 3.0
		add_instance("palm_nut", nut, "bark", Transform3D(Basis.IDENTITY, top + Vector3(cos(a) * 0.2, -0.2, sin(a) * 0.2)))


# ---------------------------------------------------------------------------
# Parque de las Palmas
# ---------------------------------------------------------------------------
func _park() -> void:
	var park := Rect2(-66.0, -32.0, 55.0, 64.0)
	add_box(Vector3(park.size.x, 0.03, park.size.y), Vector3(park.get_center().x, G + 0.015, park.get_center().y), "grass", false)
	(points["minimap_rects"] as Array).append([park, Color(0.3, 0.5, 0.28)])
	var fountain := Vector3(-36.0, G, 0.0)
	points["fountain"] = fountain
	# Senderos de adoquín: en cruz, perimetral y la glorieta de la fuente.
	add_box(Vector3(4.0, 0.04, park.size.y), Vector3(fountain.x, G + 0.02, 0), "plaza", false)
	add_box(Vector3(park.size.x, 0.04, 4.0), Vector3(park.get_center().x, G + 0.02, 0), "plaza", false)
	for z: float in [-29.5, 29.5]:
		add_box(Vector3(park.size.x - 2.0, 0.04, 2.6), Vector3(park.get_center().x, G + 0.02, z), "plaza", false)
	for x: float in [-63.5, -13.5]:
		add_box(Vector3(2.6, 0.04, park.size.y - 2.0), Vector3(x, G + 0.02, 0), "plaza", false)
	var ring := add_cylinder(9.0, 0.05, fountain + Vector3(0, 0.025, 0), "plaza", false)
	(ring as MeshInstance3D).mesh.radial_segments = 32
	_fountain(fountain)
	# Palmas a lo largo de los senderos (la imagen del parque).
	for z in range(-26, 28, 7):
		if absf(z) > 4:
			for x: float in [fountain.x - 3.6, fountain.x + 3.6]:
				_palm(Vector3(x, G, z), _rng.randf_range(8.0, 10.5))
	for x in range(-60, -14, 7):
		if absf(x - fountain.x) > 5:
			for z: float in [-27.2, 27.2]:
				if not (x > -26 and z < 0):  # Deja libre la llegada de la tirolesa.
					_palm(Vector3(x, G, z), _rng.randf_range(7.0, 9.0))
	# Árboles, bancas y faroles.
	for p: Vector2 in [Vector2(-56, -14), Vector2(-48, -20), Vector2(-56, 14), Vector2(-46, 18), Vector2(-24, 14), Vector2(-20, 22), Vector2(-26, -8)]:
		_tree(Vector3(p.x, G, p.y))
	for z: float in [-16.0, -9.0, 9.0, 16.0]:
		_bench(Vector3(fountain.x - 2.6, G, z))
		_bench(Vector3(fountain.x + 2.6, G, z))
	for x: float in [-58.0, -48.0, -24.0, -17.0]:
		_bench(Vector3(x, G, 2.6))
	for z: float in [-20.0, -6.0, 6.0, 20.0]:
		_lamp(Vector3(fountain.x - 2.3, G, z), Vector3(1, 0, 0))
	for x: float in [-56.0, -44.0, -26.0, -16.0]:
		_lamp(Vector3(x, G, -2.3), Vector3(0, 0, 1))
	# Monumento con placa (marca de orientación).
	add_box(Vector3(2.0, 1.2, 2.0), Vector3(-56.0, G + 0.6, 0.0), "concrete_light")
	add_box(Vector3(0.8, 3.6, 0.8), Vector3(-56.0, G + 3.0, 0.0), "concrete_light", false)
	add_sphere(0.55, Vector3(-56.0, G + 5.2, 0.0), "metal")
	var plate := Label3D.new()
	plate.text = "CIUDAD DE LOS PARQUES\nFUNDADA EN 1622"
	plate.font_size = 40
	plate.pixel_size = 0.004
	plate.modulate = Color(0.95, 0.85, 0.55)
	plate.outline_size = 6
	plate.position = Vector3(-54.98, G + 0.7, 0.0)
	plate.rotation.y = PI * 0.5
	root.add_child(plate)
	# Kiosco y granizados (el vendedor de siempre).
	var props := PrototypeProps.new(self)
	props._kiosk(Vector3(-48.0, G, -10.0))
	props._granizado_stand(Vector3(-24.0, G, 6.0))
	_mirador()
	# Matorrales para esconderse.
	var spots: Array = []
	for spec: Array in [
		[Vector3(-42.0, G, -12.0), Vector3(1.4, 1.25, 3.4)],
		[Vector3(-30.0, G, 12.0), Vector3(1.4, 1.25, 3.4)],
		[Vector3(-52.0, G, 22.0), Vector3(3.4, 1.3, 1.4)],
		[Vector3(-17.0, G, -12.0), Vector3(1.4, 1.25, 3.2)],
		[Vector3(-60.0, G, -22.0), Vector3(3.2, 1.3, 1.4)],
		[Vector3(-16.0, G, 30.0), Vector3(3.2, 1.25, 1.2)],
		# Calle de servicio y terrazas (jardineras donde los drones no te ven).
		[Vector3(29.0, G, 12.0), Vector3(1.2, 1.25, 3.2)],
		[Vector3(23.5, roof_top(1), 13.5), Vector3(1.4, 1.2, 3.0)],
		[Vector3(23.5, roof_top(3), -15.0), Vector3(1.4, 1.2, 3.0)],
		[Vector3(-40.0, G, 44.6), Vector3(3.4, 1.25, 1.2)],
	]:
		_hedge(spec[0], spec[1])
		spots.append({"position": spec[0], "size": spec[1]})
	points["hiding_spots"] = spots
	points["meeting_hint"] = fountain
	(points["zones"] as Array).append({"name": "Parque de las Palmas", "sub": "Cabecera del Llano",
			"aabb": AABB(Vector3(park.position.x, -1, park.position.y), Vector3(park.size.x, 6, park.size.y))})
	# Recorrido de los peatones por los senderos.
	points["sidewalk_route"] = PackedVector3Array([
		Vector3(-36, G, -26), Vector3(-36, G, -12), Vector3(-30, G, 0), Vector3(-20, G, 0), Vector3(-13.5, G, 14),
		Vector3(-36, G, 26), Vector3(-50, G, 29.5), Vector3(-63.5, G, 10), Vector3(-50, G, 0), Vector3(-42, G, 0),
		Vector3(-8.8, G, -20), Vector3(-8.8, G, 22), Vector3(9.0, G, 26), Vector3(9.0, G, -20),
	])


func _hedge(pos: Vector3, size: Vector3) -> void:
	add_box(Vector3(size.x, 0.06, size.z), pos + Vector3(0, 0.03, 0), "soil", false)
	var n := int(maxf(size.x, size.z) / 0.8) + 1
	for i in n:
		var t := (i + 0.5) / n - 0.5
		var off := Vector3(t * size.x, 0, 0) if size.x > size.z else Vector3(0, 0, t * size.z)
		var r := minf(size.x, size.z) * 0.62
		var bush := add_sphere(r, pos + off + Vector3(0, size.y * 0.55, 0), "hedge" if i % 2 == 0 else "leaves_dark")
		bush.scale = Vector3(1.0, size.y / (r * 1.6), 1.0)


func _fountain(c: Vector3) -> void:
	var basin := add_cylinder(5.0, 0.55, c + Vector3(0, 0.275, 0), "concrete_light", true)
	((basin.get_child(1) as MeshInstance3D).mesh as CylinderMesh).radial_segments = 32
	var water := add_cylinder(4.65, 0.06, c + Vector3(0, 0.46, 0), "water", false)
	((water as MeshInstance3D).mesh as CylinderMesh).radial_segments = 32
	add_cylinder(0.8, 1.7, c + Vector3(0, 0.85, 0), "concrete_light", true)
	add_cylinder(1.8, 0.22, c + Vector3(0, 1.8, 0), "concrete_light", false)
	add_cylinder(1.6, 0.05, c + Vector3(0, 1.93, 0), "water", false)
	add_cylinder(0.3, 1.0, c + Vector3(0, 2.4, 0), "concrete_light", false)
	add_cylinder(0.75, 0.15, c + Vector3(0, 2.95, 0), "concrete_light", false)
	# Chorros de agua (partículas livianas; se saltan con "Reducir animaciones").
	if not Fx.reduced():
		var jets := CPUParticles3D.new()
		jets.name = "ChorrosFuente"
		jets.amount = 70
		jets.lifetime = 1.1
		jets.position = c + Vector3(0, 3.05, 0)
		jets.direction = Vector3.UP
		jets.spread = 18.0
		jets.initial_velocity_min = 2.6
		jets.initial_velocity_max = 3.4
		jets.gravity = Vector3(0, -6.0, 0)
		jets.scale_amount_min = 0.05
		jets.scale_amount_max = 0.09
		var drop := SphereMesh.new()
		drop.radius = 1.0
		drop.height = 2.0
		drop.radial_segments = 6
		drop.rings = 3
		jets.mesh = drop
		jets.material_override = MaterialLibrary.get_material("light_blue")
		root.add_child(jets)


## Mirador de madera en la esquina noreste del parque: aquí llega la tirolesa.
func _mirador() -> void:
	var c := MIRADOR
	var top := MIRADOR_TOP
	add_box(Vector3(6.0, 0.3, 6.0), Vector3(c.x, top - 0.15, c.z), "wood")
	for dx: float in [-2.7, 2.7]:
		for dz: float in [-2.7, 2.7]:
			add_box(Vector3(0.25, top, 0.25), Vector3(c.x + dx, top * 0.5, c.z + dz), "wood")
	# Baranda al norte y al oeste (por el este llega la tirolesa y al sur baja la escalera).
	add_box(Vector3(6.0, 1.0, 0.1), Vector3(c.x, top + 0.5, c.z - 3.0), "rail")
	add_box(Vector3(0.1, 1.0, 6.0), Vector3(c.x - 3.0, top + 0.5, c.z), "rail")
	# Escalera hacia el sur.
	var steps := 9
	var rise := (top - G) / steps
	for i in steps:
		var h := rise * (i + 1)
		add_box(Vector3(2.6, h, 0.36), Vector3(c.x, G + h * 0.5, c.z + 3.0 + 0.36 * (steps - i) - 0.18), "wood")
	points["mirador_top"] = Vector3(c.x, top, c.z)
	points["mirador_stairs"] = Vector3(c.x, G, c.z + 3.0 + 0.36 * steps + 1.0)


# ---------------------------------------------------------------------------
# Terrazas de Cabecera (ruta de parkour)
# ---------------------------------------------------------------------------
func _rooftop_row() -> void:
	var cx := (ROW_X.x + ROW_X.y) * 0.5
	var depth := ROW_X.y - ROW_X.x
	for i in ROOFS.size():
		var r: Array = ROOFS[i]
		var z0: float = r[0]
		var z1: float = r[1]
		var h: float = r[2]
		_building(Vector3(cx, 0, (z0 + z1) * 0.5), Vector3(depth, 0, z1 - z0), 2, Vector3(-1, 0, 0), "terraza_%d" % i, h)
		# Losa de la terraza con colisión (se camina encima de la cornisa).
		add_box(Vector3(depth - 0.2, ROOF_SLAB, z1 - z0 - 0.2), Vector3(cx, G + h + ROOF_SLAB * 0.5, (z0 + z1) * 0.5), "roof")
		points["roof_%d" % i] = roof_center(i)
	var t := roof_top(0)
	# Escalera de incendios: sube por el costado sur del primer edificio.
	_stair_run(Vector3(25.5, G, 32.7), Vector3(-1, 0, 0), t - G, 1.3)
	add_box(Vector3(3.6, t - G, 1.3), Vector3(14.6, G + (t - G) * 0.5, 32.7), "concrete_light")
	points["roof_stairs"] = Vector3(27.5, G, 33.4)
	# Escalera de rescate en el callejón entre la terraza 3 y la 4 (si te caes).
	var t3 := roof_top(3)
	_stair_run(Vector3(25.5, G, -8.2), Vector3(-1, 0, 0), t3 - G, 1.3, 0.42)
	add_box(Vector3(1.8, t3 - G, 1.3), Vector3(13.2, G + (t3 - G) * 0.5, -8.2), "concrete_light")
	# Tabla para cruzar entre la terraza 2 y la 3 (opcional: también se salta).
	var plank_y := (roof_top(1) + roof_top(2)) * 0.5
	var plank := add_box(Vector3(0.6, 0.08, 3.6), Vector3(19.0, plank_y, (5.4 + 8.0) * 0.5), "wood")
	plank.rotation.x = atan2(roof_top(1) - roof_top(2), 3.6) * -1.0
	# Utilería de terraza: tanques, aires, tendederos y toldos (sombra contra los drones).
	for i in ROOFS.size():
		var c := roof_center(i)
		add_box(Vector3(1.2, 1.0, 1.0), c + Vector3(4.5, 0.5, -1.5), "plastic_gray")
		add_cylinder(0.6, 1.3, c + Vector3(4.6, 0.65, 2.0), "plastic_gray", true)
		if i % 2 == 1:
			_awning(c + Vector3(-2.5, 0, 0.5), Vector2(4.0, 3.0))
		# Bombillo de obra en un poste: de noche alumbra la terraza (TimeOfDay).
		var post := c + Vector3(5.8, 0, -3.2 if i % 2 == 0 else 3.2)
		add_cylinder(0.05, 2.7, post + Vector3(0, 1.35, 0), "metal", false)
		add_box(Vector3(0.22, 0.14, 0.22), post + Vector3(0, 2.7, 0), "bulb", false)
		(points.get_or_add("lamps", []) as Array).append(post + Vector3(0, 2.55, 0))
	_office(roof_center(4))
	points["parkour_start"] = Vector3(15.0, roof_top(0), 30.0)
	(points["zones"] as Array).append({"name": "Terrazas de Cabecera", "sub": "Arriba nadie mira… casi nadie",
			"aabb": AABB(Vector3(ROW_X.x, 5.0, -33.0), Vector3(depth, 8.0, 66.0))})
	_zipline_anchor()


## Escalones macizos de `rise` cada uno, que suben `height` hacia `dir`.
func _stair_run(start: Vector3, dir: Vector3, height: float, width: float, run: float = 0.38) -> void:
	var rise := 0.3
	var steps := int(ceil(height / rise))
	rise = height / steps
	for i in steps:
		var h := rise * (i + 1)
		var p := start + dir * (run * i + run * 0.5) + Vector3(0, h * 0.5, 0)
		var size := Vector3(run, h, width) if absf(dir.x) > 0.5 else Vector3(width, h, run)
		add_box(size, p, "concrete_light")
	# Baranda del lado de afuera.
	var length := run * steps
	var mid := start + dir * length * 0.5 + Vector3(0, height * 0.5 + 0.9, 0)
	var rail := add_box(Vector3(length * 1.02, 0.05, 0.05), Vector3.ZERO, "rail", false)
	rail.position = mid + Vector3(0, 0, width * 0.5)
	rail.rotation.z = atan2(height, length) * (-1.0 if dir.x < 0.0 else 1.0)


func _awning(pos: Vector3, size: Vector2) -> void:
	add_box(Vector3(size.x, 0.08, size.y), pos + Vector3(0, 2.3, 0), "awning_blue")
	for dx: float in [-size.x * 0.5 + 0.1, size.x * 0.5 - 0.1]:
		for dz: float in [-size.y * 0.5 + 0.1, size.y * 0.5 - 0.1]:
			add_cylinder(0.04, 2.3, pos + Vector3(dx, 1.15, dz), "metal", false)


## Oficina de «Inversiones La Meseta» en la última terraza: caseta con puerta
## al oeste, escritorio y la caja fuerte del contrato.
func _office(c: Vector3) -> void:
	var o := c + Vector3(2.0, 0, -0.5)
	var w := 5.0
	var d := 4.4
	var h := 2.7
	add_box(Vector3(w, h, 0.15), o + Vector3(0, h * 0.5, -d * 0.5), "facade_5")
	add_box(Vector3(w, h, 0.15), o + Vector3(0, h * 0.5, d * 0.5), "facade_5")
	add_box(Vector3(0.15, h, d), o + Vector3(w * 0.5, h * 0.5, 0), "facade_5")
	# Pared oeste con puerta de 1,3 m.
	var side := (d - 1.3) * 0.5
	add_box(Vector3(0.15, h, side), o + Vector3(-w * 0.5, h * 0.5, -d * 0.5 + side * 0.5), "facade_5")
	add_box(Vector3(0.15, h, side), o + Vector3(-w * 0.5, h * 0.5, d * 0.5 - side * 0.5), "facade_5")
	add_box(Vector3(0.15, 0.5, 1.3), o + Vector3(-w * 0.5, h - 0.25, 0), "facade_5")
	add_box(Vector3(w + 0.4, 0.15, d + 0.4), o + Vector3(0, h + 0.07, 0), "concrete")
	add_box(Vector3(1.6, 0.75, 0.8), o + Vector3(0.6, 0.375, -1.2), "wood")
	add_box(Vector3(1.2, 0.02, 0.5), o + Vector3(0.6, 0.76, -1.2), "paper", false)
	var sign := Label3D.new()
	sign.text = "INVERSIONES LA MESETA"
	sign.font_size = 52
	sign.pixel_size = 0.006
	sign.outline_size = 4
	sign.modulate = Color(1.0, 0.85, 0.5)
	sign.position = o + Vector3(-w * 0.5 - 0.09, h - 0.6, 0)
	sign.rotation.y = -PI * 0.5
	root.add_child(sign)
	# Lámpara de techo: la nota de la clave tiene que poder leerse.
	add_box(Vector3(0.5, 0.06, 0.5), o + Vector3(0.2, h - 0.12, -0.3), "bulb", false)
	(points.get_or_add("lamps", []) as Array).append(o + Vector3(0.2, h - 0.35, -0.3))
	points["office"] = o
	points["office_door"] = o + Vector3(-w * 0.5 - 1.2, 0, 0)
	points["safe"] = o + Vector3(w * 0.5 - 0.6, 0, 1.2)


## Poste y plataforma de la tirolesa en el borde oeste de la última terraza.
func _zipline_anchor() -> void:
	var t := roof_top(4)
	var start := Vector3(ROW_X.x + 1.0, t, -26.0)
	add_cylinder(0.12, 3.2, start + Vector3(0, 1.6, 0), "metal", true)
	add_box(Vector3(0.8, 0.1, 0.1), start + Vector3(0, 3.1, 0), "metal", false)
	# Poste de llegada un poco más allá del final del cable.
	add_cylinder(0.12, 3.0, Vector3(MIRADOR.x - 0.6, MIRADOR_TOP + 1.5, MIRADOR.z), "metal", true)
	# El cable (cuelga a 2,1 m sobre los pies) se dibuja en Zipline.
	points["zip_start"] = start + Vector3(-0.5, 0, 0)
	points["zip_end"] = Vector3(MIRADOR.x + 0.8, MIRADOR_TOP, MIRADOR.z)


# ---------------------------------------------------------------------------
# Calle de servicio, torres y centro comercial
# ---------------------------------------------------------------------------
func _service_lane() -> void:
	# Contenedores y canecas grandes en la calle de servicio.
	for z: float in [-18.0, 2.0, 24.0]:
		add_box(Vector3(1.6, 1.3, 2.6), Vector3(LANE_X.y - 1.2, G + 0.65, z), "plastic_green")
	(points["zones"] as Array).append({"name": "Calle de servicio", "sub": "Detrás de las vitrinas",
			"aabb": AABB(Vector3(LANE_X.x, -1, -32), Vector3(LANE_X.y - LANE_X.x, 5, 64))})


func _towers() -> void:
	_mall(Rect2(34.0, 8.0, 28.0, 24.0), 12.0)
	_tower(Rect2(36.0, -30.0, 14.0, 16.0), 15)
	_tower(Rect2(52.0, -28.0, 10.0, 16.0), 11)
	_tower(Rect2(38.0, -8.0, 22.0, 12.0), 8)


func _tower(r: Rect2, floors: int) -> void:
	var floor_h := 3.2
	var h := 4.0 + floors * floor_h
	var c := Vector3(r.get_center().x, G, r.get_center().y)
	add_box(Vector3(r.size.x, h, r.size.y), c + Vector3(0, h * 0.5, 0), "concrete_light")
	# Bandas de vidrio en cada piso, en las cuatro fachadas.
	for f in floors:
		var y := G + 4.0 + f * floor_h + 1.5
		for side in 4:
			var along_x := side < 2
			var sgn := -1.0 if side % 2 == 0 else 1.0
			var size := Vector3(r.size.x + 0.04, 1.9, 0.06) if along_x else Vector3(0.06, 1.9, r.size.y + 0.04)
			var off := Vector3(0, y - G, sgn * r.size.y * 0.5) if along_x else Vector3(sgn * r.size.x * 0.5, y - G, 0)
			var lit := _rng.randf() < 0.18
			add_instance("tower_band_lit_%s" % ("x" if along_x else "z") if lit else "tower_band_%s" % ("x" if along_x else "z"),
					_box_mesh(size), "tower_glass_lit" if lit else "tower_glass", Transform3D(Basis.IDENTITY, c + off))
	# Vestíbulo y remate con antena y luz roja de aviación.
	add_box(Vector3(r.size.x + 0.6, 0.4, r.size.y + 0.6), c + Vector3(0, h + 0.2, 0), "concrete")
	add_cylinder(0.08, 5.0, c + Vector3(0, h + 2.9, 0), "metal", false)
	add_sphere(0.2, c + Vector3(0, h + 5.5, 0), "light_red")
	if not points.has("footprints"):
		points["footprints"] = []
	(points["footprints"] as Array).append(r)


func _mall(r: Rect2, h: float) -> void:
	var c := Vector3(r.get_center().x, G, r.get_center().y)
	add_box(Vector3(r.size.x, h, r.size.y), c + Vector3(0, h * 0.5, 0), "concrete_light")
	var face := r.position.x
	add_box(Vector3(0.1, h * 0.55, r.size.y - 2.0), Vector3(face - 0.06, G + h * 0.35, c.z), "tower_glass", false)
	add_box(Vector3(0.15, 0.5, r.size.y - 4.0), Vector3(face - 0.1, G + h * 0.72, c.z), "mall_sign", false)
	add_box(Vector3(2.4, 0.2, 8.0), Vector3(face - 1.2, G + 3.4, c.z), "concrete", false)
	var sign := Label3D.new()
	sign.text = "C.C. LA MESETA"
	sign.font_size = 160
	sign.pixel_size = 0.012
	sign.outline_size = 16
	sign.modulate = Color(1.0, 0.95, 0.85)
	sign.position = Vector3(face - 0.2, G + h - 1.6, c.z)
	sign.rotation.y = -PI * 0.5
	root.add_child(sign)
	if not points.has("footprints"):
		points["footprints"] = []
	(points["footprints"] as Array).append(r)


## Fila de edificios al otro lado de la calle norte (cierra el horizonte).
func _north_row() -> void:
	var front := NORTH_Z - CROSS_HALF - 3.0
	for side: float in [-1.0, 1.0]:
		var pos := AVE_HALF + 4.0
		while pos < HALF - 6.0:
			var w := _rng.randf_range(7.0, 12.0)
			w = minf(w, HALF - 4.0 - pos)
			var depth := _rng.randf_range(10.0, 14.0)
			_building(Vector3(side * (pos + w * 0.5), 0, front - depth * 0.5), Vector3(w, 0, depth),
					_rng.randi_range(3, 8), Vector3(0, 0, 1), "norte_%d_%d" % [int(side), int(pos)])
			pos += w
	# Al sur de la calle sur, del lado este: casas bajas frente a la cañada.
	var x := AVE_HALF + 4.0
	while x < HALF - 6.0:
		var w := _rng.randf_range(6.0, 9.0)
		_lamp(Vector3(x + w * 0.5, G, SOUTH_Z + CROSS_HALF + 0.8), Vector3(0, 0, -1))
		x += w * 2.0


# ---------------------------------------------------------------------------
# La cañada y el Puente de la Novena
# ---------------------------------------------------------------------------
func _ravine_and_bridge() -> void:
	var z0 := RAVINE.x
	var z1 := RAVINE.y
	var depth := 9.0
	# Muros de contención y laderas verdes (sin colisión abajo: caer = volver al punto de control).
	for z: float in [z0, z1]:
		add_box(Vector3(HALF * 2.0, depth, 0.6), Vector3(0, G - depth * 0.5, z), "concrete_dark", false)
	for x in range(-66, 70, 12):
		var slope := add_box(Vector3(12.0, 0.4, 5.0), Vector3(x, -4.0, z0 + 2.4), "grass", false)
		slope.rotation.x = deg_to_rad(-48.0)
		var slope2 := add_box(Vector3(12.0, 0.4, 5.0), Vector3(x, -4.0, z1 - 2.4), "grass", false)
		slope2.rotation.x = deg_to_rad(48.0)
	add_box(Vector3(HALF * 2.0, 0.1, 4.0), Vector3(0, -7.6, (z0 + z1) * 0.5), "water", false)
	for i in 14:
		var p := Vector3(_rng.randf_range(-64, 64), -6.0, _rng.randf_range(z0 + 3.0, z1 - 3.0))
		add_sphere(_rng.randf_range(1.2, 2.2), p, "leaves_dark" if i % 2 == 0 else "leaves")
	# Barandas a lo largo de la cañada (con colisión), con hueco en el puente.
	for z: float in [z0 - 0.2, z1 + 0.2]:
		for seg: Vector2 in [Vector2(-HALF, BRIDGE_X.x), Vector2(BRIDGE_X.y, HALF)]:
			var len := seg.y - seg.x
			add_box(Vector3(len, 1.2, 0.12), Vector3((seg.x + seg.y) * 0.5, G + 0.6, z), "rail")
	# Puente: tablero, barandas, arco y faroles.
	var bx := (BRIDGE_X.x + BRIDGE_X.y) * 0.5
	var bw := BRIDGE_X.y - BRIDGE_X.x
	var blen := z1 - z0 + 1.0
	add_box(Vector3(bw, 0.6, blen), Vector3(bx, G - 0.3, (z0 + z1) * 0.5), "concrete")
	add_box(Vector3(bw - 0.4, 0.03, blen), Vector3(bx, G + 0.015, (z0 + z1) * 0.5), "plaza", false)
	for x: float in [BRIDGE_X.x + 0.1, BRIDGE_X.y - 0.1]:
		add_box(Vector3(0.2, 1.15, blen), Vector3(x, G + 0.575, (z0 + z1) * 0.5), "rail")
		add_box(Vector3(0.3, 0.12, blen), Vector3(x, G + 1.18, (z0 + z1) * 0.5), "concrete_light", false)
	# Arco de concreto bajo el tablero (silueta reconocible desde la ladera).
	var segs := 10
	for i in segs:
		var a0 := PI * float(i) / segs
		var a1 := PI * float(i + 1) / segs
		var r := (z1 - z0) * 0.5
		var p0 := Vector3(0, -sin(a0) * 6.0, -cos(a0) * r)
		var p1 := Vector3(0, -sin(a1) * 6.0, -cos(a1) * r)
		var mid := (p0 + p1) * 0.5
		for x: float in [BRIDGE_X.x + 0.6, BRIDGE_X.y - 0.6]:
			var piece := add_box(Vector3(0.6, 0.6, p0.distance_to(p1) + 0.2), Vector3.ZERO, "concrete_light", false)
			piece.basis = Basis.looking_at(p1 - p0, Vector3.UP)
			piece.position = Vector3(x, G - 0.6, (z0 + z1) * 0.5) + mid
	for z: float in [z0 + 3.0, (z0 + z1) * 0.5, z1 - 3.0]:
		_lamp(Vector3(BRIDGE_X.x + 0.3, G, z), Vector3(1, 0, 0))
	var name_plate := Label3D.new()
	name_plate.text = "PUENTE DE LA NOVENA"
	name_plate.font_size = 64
	name_plate.pixel_size = 0.006
	name_plate.outline_size = 10
	name_plate.modulate = Color(1.0, 0.9, 0.6)
	name_plate.position = Vector3(bx, G + 3.2, z0 - 1.0)
	name_plate.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	root.add_child(name_plate)
	points["bridge_start"] = Vector3(bx, G, z0 - 1.5)
	points["bridge_end"] = Vector3(bx, G, z1 + 2.5)
	(points["minimap_rects"] as Array).append([Rect2(-HALF, z0, HALF * 2.0, z1 - z0), Color(0.12, 0.25, 0.3)])
	(points["minimap_rects"] as Array).append([Rect2(BRIDGE_X.x, z0, bw, z1 - z0), Color(0.6, 0.6, 0.6)])
	(points["zones"] as Array).append({"name": "Puente de la Novena", "sub": "El último tramo",
			"aabb": AABB(Vector3(BRIDGE_X.x, -1, z0), Vector3(bw, 5, z1 - z0))})


## Plaza del mirador al otro lado del puente: aquí termina la huida.
func _finish_plaza() -> void:
	var r := Rect2(-48.0, RAVINE.y, 40.0, HALF - RAVINE.y)
	add_box(Vector3(r.size.x, 0.4 + G, r.size.y), Vector3(r.get_center().x, (G - 0.4) * 0.5, r.get_center().y), "plaza")
	(points["minimap_rects"] as Array).append([r, Color(0.5, 0.46, 0.4)])
	for x: float in [-44.0, -12.0]:
		_palm(Vector3(x, G, 66.0), 8.0)
	for x: float in [-40.0, -16.0]:
		_lamp(Vector3(x, G, 63.0), Vector3(0, 0, 1))
	# Furgoneta de la emisora (la periodista transmite desde aquí).
	var props := PrototypeProps.new(self)
	var van := props._group(Vector3(-18.0, 0.0, 66.0), PI * 0.5, "FurgonetaEmisora")
	props._part(van, props._box(Vector3(2.0, 1.9, 4.8)), Vector3(0, 1.25, 0), "van_white")
	props._part(van, props._box(Vector3(1.9, 0.6, 1.2)), Vector3(0, 1.6, -2.0), "glass")
	props._part(van, props._cyl(0.55, 0.08), Vector3(0, 2.55, 0.6), "metal")
	for wx: float in [-0.95, 0.95]:
		for wz: float in [-1.5, 1.5]:
			var wheel := props._part(van, props._cyl(0.36, 0.25), Vector3(wx, 0.36, wz), "tire")
			wheel.rotation.z = PI * 0.5
	props._solid(van, Vector3(2.0, 2.2, 4.8), Vector3(0, 1.1, 0), PhysicsLayers.VEHICLES)
	var logo := Label3D.new()
	logo.text = "LA VOZ DE SANTANDER\nEN VIVO"
	logo.font_size = 48
	logo.pixel_size = 0.005
	logo.outline_size = 8
	logo.modulate = Color(0.95, 0.3, 0.25)
	logo.position = Vector3(1.03, 1.4, 0)
	logo.rotation.y = PI * 0.5
	van.add_child(logo)
	points["meeting_point"] = Vector3(-27.0, G, 65.0)
	points["finish"] = Vector3(-27.0, G, 63.5)


# ---------------------------------------------------------------------------
# Mobiliario de las calles
# ---------------------------------------------------------------------------
func _street_props() -> void:
	var props := PrototypeProps.new(self)
	# Faroles en los andenes de la avenida.
	var z := -HALF + 8.0
	while z < RAVINE.x - 4.0:
		if absf(z - NORTH_Z) > 7.0 and absf(z - SOUTH_Z) > 7.0:
			_lamp(Vector3(-AVE_HALF - 0.8, G, z), Vector3(1, 0, 0))
			_lamp(Vector3(AVE_HALF + 0.8, G, z), Vector3(-1, 0, 0))
		z += 14.0
	# Carros parqueados junto al andén de la avenida.
	var lane := AVE_HALF - 1.1
	for spec: Array in [[-lane, -24.0, PI], [-lane, -10.0, PI], [-lane, 14.0, PI], [lane, -16.0, 0.0], [lane, 2.0, 0.0],
			[lane, 22.0, 0.0], [-lane, 28.0, PI]]:
		props._car(Vector3(spec[0], 0, spec[1]), spec[2], "car_%d" % _rng.randi_range(0, MaterialLibrary.CAR_COLORS.size() - 1))
	props._bus_stop(Vector3(-AVE_HALF - 1.0, G, 20.0))
	# Semáforos en los dos cruces de la avenida.
	for cz: float in [NORTH_Z, SOUTH_Z]:
		for sx: float in [-1.0, 1.0]:
			var tl := TrafficLight.new()
			tl.position = Vector3(sx * (AVE_HALF + 0.6), G, cz + sx * (CROSS_HALF + 0.6))
			tl.rotation.y = PI * 0.5 if sx > 0.0 else -PI * 0.5
			tl.axis = "ns" if sx > 0.0 else "ew"
			root.add_child(tl)
