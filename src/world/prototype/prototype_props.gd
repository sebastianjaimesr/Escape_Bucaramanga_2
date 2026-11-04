class_name PrototypeProps
extends RefCounted
## Utilería urbana de la manzana de prueba: carros parqueados, patrulla con
## luces, semáforos, canecas, bolardos, paradero, postes con cables, carrito de
## granizados, kiosco y matorrales donde esconderse.
##
## Registra en builder.points los lugares que usan otros sistemas
## ("hiding_spots", "vendor", "police_car", "meeting_point").

const G := PrototypeBlockBuilder.CURB_HEIGHT
const CURB_LANE := PrototypeBlockBuilder.STREET_HALF - 1.1   ## Centro de un carro parqueado.

var b: PrototypeBlockBuilder
var _rng := RandomNumberGenerator.new()


func _init(builder: PrototypeBlockBuilder) -> void:
	b = builder
	_rng.seed = 4_11_2026


func build() -> void:
	_parked_cars()
	_police_car(Vector3(15.0, 0.0, CURB_LANE), PI * 0.5)
	_traffic_lights()
	_bins_and_bollards()
	_bus_stop(Vector3(-28.0, G, -6.6))
	_power_lines()
	_kiosk(Vector3(-30.0, G, 10.5))
	_granizado_stand(Vector3(-15.0, G, 12.5))
	_hiding_spots()
	b.points["meeting_point"] = Vector3(-43.0, G, 37.5)


# ---------------------------------------------------------------------------
# Vehículos
# ---------------------------------------------------------------------------
func _parked_cars() -> void:
	var slots: Array = []
	for x: float in [14.0, 22.0, 33.0, 41.0, 50.0]:
		slots.append([Vector3(x, 0, -CURB_LANE), -PI * 0.5])
	for x: float in [-16.0, -26.0, -44.0, -51.0]:
		slots.append([Vector3(x, 0, -CURB_LANE), PI * 0.5])
	for z: float in [-16.0, -34.0, -48.0]:
		slots.append([Vector3(CURB_LANE, 0, z), 0.0])
	for z: float in [18.0, 34.0, 47.0]:
		slots.append([Vector3(-CURB_LANE, 0, z), PI])
	for s: Array in slots:
		_car(s[0], s[1], "car_%d" % _rng.randi_range(0, MaterialLibrary.CAR_COLORS.size() - 1))
	b.points["parked_cars"] = slots.size()


## Carro sencillo (sedán): chasis, cabina con vidrios, ruedas y luces.
## Mira hacia -Z local; yaw lo orienta en el mundo.
func _car(pos: Vector3, yaw: float, paint: String) -> Node3D:
	var car := _group(pos, yaw, "Carro")
	_part(car, _box(Vector3(1.8, 0.62, 4.3)), Vector3(0, 0.6, 0), paint)
	_part(car, _box(Vector3(1.62, 0.56, 2.2)), Vector3(0, 1.18, 0.25), paint)
	_part(car, _box(Vector3(1.66, 0.44, 2.0)), Vector3(0, 1.2, 0.25), "glass")
	_part(car, _box(Vector3(1.5, 0.5, 0.06)), Vector3(0, 1.15, -0.88), "glass")
	_part(car, _box(Vector3(1.82, 0.18, 4.32)), Vector3(0, 0.36, 0), "plastic_gray")
	for wx: float in [-0.85, 0.85]:
		for wz: float in [-1.35, 1.35]:
			var wheel := _part(car, _cyl(0.33, 0.24), Vector3(wx, 0.33, wz), "tire")
			wheel.rotation.z = PI * 0.5
	for lx: float in [-0.62, 0.62]:
		_part(car, _box(Vector3(0.36, 0.14, 0.04)), Vector3(lx, 0.75, -2.15), "bulb")
		_part(car, _box(Vector3(0.36, 0.14, 0.04)), Vector3(lx, 0.75, 2.15), "light_red")
	_solid(car, Vector3(1.8, 1.45, 4.3), Vector3(0, 0.75, 0), PhysicsLayers.VEHICLES)
	return car


## Patrulla parqueada con barra de luces intermitentes (policía ficticia).
func _police_car(pos: Vector3, yaw: float) -> void:
	var car := _car(pos, yaw, "car_0")
	_part(car, _box(Vector3(1.84, 0.22, 4.34)), Vector3(0, 0.68, 0), "metal_green")
	_part(car, _box(Vector3(1.64, 0.1, 1.0)), Vector3(0, 1.5, 0.25), "metal_green")
	var lights := PoliceLights.new()
	lights.position = Vector3(0, 1.6, 0.25)
	car.add_child(lights)
	b.points["police_car"] = pos


# ---------------------------------------------------------------------------
# Mobiliario
# ---------------------------------------------------------------------------
func _traffic_lights() -> void:
	var c := PrototypeBlockBuilder.STREET_HALF + 0.5
	for spec: Array in [
		[Vector3(c, G, c), 0.0, "ns"], [Vector3(-c, G, -c), PI, "ns"],
		[Vector3(-c, G, c), -PI * 0.5, "ew"], [Vector3(c, G, -c), PI * 0.5, "ew"],
	]:
		var t := TrafficLight.new()
		t.axis = spec[2]
		t.position = spec[0]
		t.rotation.y = spec[1]
		b.root.add_child(t)


func _bins_and_bollards() -> void:
	var c := PrototypeBlockBuilder.STREET_HALF + 0.35
	# Bolardos en las esquinas del cruce.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for i in 3:
				var p := Vector3(sx * (c + 1.2 + i * 1.1), G, sz * c)
				b.add_instance("bollard", _cyl(0.1, 0.8), "metal", Transform3D(Basis.IDENTITY, p + Vector3(0, 0.4, 0)))
				var q := Vector3(sx * c, G, sz * (c + 1.2 + i * 1.1))
				b.add_instance("bollard", _cyl(0.1, 0.8), "metal", Transform3D(Basis.IDENTITY, q + Vector3(0, 0.4, 0)))
	# Canecas de basura verdes junto a los postes.
	for p: Vector3 in [Vector3(12, G, 7.0), Vector3(-20, G, -7.0), Vector3(7.0, G, -28), Vector3(-7.0, G, 40),
			Vector3(40, G, 7.0), Vector3(7.0, G, 44)]:
		var bin := _group(p, 0.0, "Caneca")
		_part(bin, _cyl(0.28, 0.85), Vector3(0, 0.45, 0), "plastic_green")
		_part(bin, _cyl(0.3, 0.06), Vector3(0, 0.9, 0), "plastic_gray")
		_solid(bin, Vector3(0.56, 0.9, 0.56), Vector3(0, 0.45, 0), PhysicsLayers.WORLD)


func _bus_stop(pos: Vector3) -> void:
	var stop := _group(pos, 0.0, "Paradero")
	_part(stop, _box(Vector3(3.2, 0.08, 1.4)), Vector3(0, 2.5, 0), "metal_green")
	_part(stop, _box(Vector3(3.2, 2.0, 0.04)), Vector3(0, 1.3, -0.65), "glass")
	for x: float in [-1.5, 1.5]:
		_part(stop, _box(Vector3(0.08, 2.5, 0.08)), Vector3(x, 1.25, -0.6), "metal")
	_part(stop, _box(Vector3(2.4, 0.08, 0.4)), Vector3(0, 0.48, -0.4), "wood")
	_solid(stop, Vector3(3.2, 2.5, 0.12), Vector3(0, 1.25, -0.65), PhysicsLayers.WORLD)
	var sign := Label3D.new()
	sign.text = "PARADERO"
	sign.font_size = 48
	sign.pixel_size = 0.005
	sign.position = Vector3(0, 2.62, 0.72)
	sign.outline_size = 8
	stop.add_child(sign)


## Postes de concreto con cables colgando de lado a lado: muy de barrio.
func _power_lines() -> void:
	var z := PrototypeBlockBuilder.STREET_HALF + 2.6
	var xs := [-52.0, -38.0, -24.0, 24.0, 38.0, 52.0]
	for x: float in xs:
		b.add_cylinder(0.13, 8.0, Vector3(x, G + 4.0, -z), "concrete", true)
		b.add_box(Vector3(0.12, 0.12, 1.4), Vector3(x, G + 7.6, -z), "concrete", false)
	for i in xs.size() - 1:
		var a: float = xs[i]
		var c: float = xs[i + 1]
		if a < 0.0 and c > 0.0:
			continue
		for dz: float in [-0.5, 0.0, 0.5]:
			# Cable con comba: dos tramos inclinados que bajan hacia el centro.
			for half in 2:
				var x0: float = a if half == 0 else (a + c) * 0.5
				var x1: float = (a + c) * 0.5 if half == 0 else c
				var y0 := G + 7.55 - (0.0 if half == 0 else 0.45)
				var y1 := G + 7.55 - (0.45 if half == 0 else 0.0)
				var from := Vector3(x0, y0, -z + dz)
				var to := Vector3(x1, y1, -z + dz)
				var mid := (from + to) * 0.5
				var length := from.distance_to(to)
				var xf := Transform3D(Basis.looking_at(to - from, Vector3.UP), mid)
				b.add_instance("cable", _box(Vector3(0.025, 0.025, 1.0)), "rail", xf.scaled_local(Vector3(1, 1, length)))


func _kiosk(pos: Vector3) -> void:
	var k := _group(pos, 0.0, "Kiosco")
	_part(k, _box(Vector3(2.2, 2.2, 1.6)), Vector3(0, 1.1, 0), "metal_green")
	_part(k, _box(Vector3(2.6, 0.12, 2.0)), Vector3(0, 2.3, 0), "awning_yellow")
	_part(k, _box(Vector3(1.6, 0.9, 0.04)), Vector3(0, 1.35, 0.81), "shop_interior")
	_solid(k, Vector3(2.2, 2.2, 1.6), Vector3(0, 1.1, 0), PhysicsLayers.WORLD)


## Carrito de granizados con sombrilla: aquí está el vendedor (interactuable).
func _granizado_stand(pos: Vector3) -> void:
	var s := _group(pos, PI * 0.5, "CarritoGranizados")
	_part(s, _box(Vector3(1.6, 0.9, 0.8)), Vector3(0, 0.65, 0), "paint_white")
	_part(s, _box(Vector3(1.62, 0.2, 0.82)), Vector3(0, 0.9, 0), "awning_blue")
	for wx: float in [-0.6, 0.6]:
		var w := _part(s, _cyl(0.2, 0.08), Vector3(wx, 0.2, 0.42), "tire")
		w.rotation.x = PI * 0.5
	# Bloque de hielo y frascos de colores (los sabores).
	_part(s, _box(Vector3(0.5, 0.3, 0.4)), Vector3(-0.4, 1.25, 0), "glass")
	var flavors := ["light_red", "light_yellow", "light_green"]
	for i in 3:
		_part(s, _cyl(0.07, 0.25), Vector3(0.2 + i * 0.18, 1.22, 0), flavors[i])
	_part(s, _cyl(0.03, 1.6), Vector3(0, 1.85, 0), "metal")
	var umbrella := _part(s, _cyl(0.0, 0.5), Vector3(0, 2.6, 0), "awning")
	(umbrella.mesh as CylinderMesh).bottom_radius = 1.3
	(umbrella.mesh as CylinderMesh).top_radius = 0.05
	_solid(s, Vector3(1.6, 1.1, 0.8), Vector3(0, 0.55, 0), PhysicsLayers.WORLD)
	var label := Label3D.new()
	label.text = "GRANIZADOS"
	label.font_size = 40
	label.pixel_size = 0.005
	label.outline_size = 8
	label.modulate = Color(1, 0.95, 0.6)
	label.position = Vector3(0, 0.65, 0.41)
	s.add_child(label)
	# El vendedor se para del lado de la acera.
	b.points["vendor"] = pos + Vector3(-0.9, 0, 0)


## Matorrales (setos altos) sin colisión: agachado adentro, la policía no te ve.
func _hiding_spots() -> void:
	var spots: Array = []
	for spec: Array in [
		[Vector3(24.0, G, 6.7), Vector3(3.0, 1.25, 1.2)],
		[Vector3(-6.7, G, -30.0), Vector3(1.2, 1.25, 3.0)],
		[Vector3(6.7, G, 26.0), Vector3(1.2, 1.25, 3.0)],
		[Vector3(38.0, G, -6.7), Vector3(3.0, 1.25, 1.2)],
		[Vector3(-9.5, G, 27.0), Vector3(1.4, 1.25, 3.2)],
		[Vector3(-44.0, G, 30.0), Vector3(3.4, 1.3, 1.6)],
		[Vector3(-6.7, G, -48.0), Vector3(1.2, 1.25, 3.0)],
	]:
		var pos: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		b.add_box(Vector3(size.x, 0.06, size.z), pos + Vector3(0, 0.03, 0), "soil", false)
		# Varias esferas aplastadas: se lee como arbusto, no como caja.
		var n := int(maxf(size.x, size.z) / 0.8) + 1
		for i in n:
			var t := (i + 0.5) / n - 0.5
			var off := Vector3(t * size.x, 0, t * size.z) if size.x > size.z else Vector3(0, 0, t * size.z)
			if size.x > size.z:
				off = Vector3(t * size.x, 0, 0)
			var r := minf(size.x, size.z) * 0.62
			var bush := b.add_sphere(r, pos + off + Vector3(0, size.y * 0.55, 0), "hedge" if i % 2 == 0 else "leaves_dark")
			bush.scale = Vector3(1.0, size.y / (r * 1.6), 1.0)
		spots.append({"position": pos, "size": size})
	b.points["hiding_spots"] = spots


# ---------------------------------------------------------------------------
# Ayudas
# ---------------------------------------------------------------------------
func _group(pos: Vector3, yaw: float, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation.y = yaw
	b.root.add_child(n, true)
	return n


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, material: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = MaterialLibrary.get_material(material)
	parent.add_child(mi)
	return mi


func _solid(parent: Node3D, size: Vector3, pos: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cyl(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 14
	return m
