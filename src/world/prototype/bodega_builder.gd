class_name BodegaBuilder
extends RefCounted
## La bodega del patio noreste (capítulo 3, «Sombras en el callejón»).
##
## Un galpón de lámina de 18 × 14 m con puerta grande al sur, una rejilla baja
## en el costado oriental (solo se pasa agachado) y una oficina en la esquina
## del fondo. Afuera: un camión de carga, contenedores y cajas que dan sombra.
## Se construye siempre (es parte de la manzana) para que la navegación de los
## vigilantes quede horneada; los vigilantes, cámaras y documentos los pone
## CallejonMission. Las posiciones que usa la misión están aquí como constantes.

const G := PrototypeBlockBuilder.CURB_HEIGHT
const WALL_H := 5.0
const WALL_T := 0.3
## Esquinas del galpón (x mín, z mín) - (x máx, z máx).
const MIN := Vector2(32.0, -52.0)
const MAX := Vector2(50.0, -38.0)
const DOOR := Vector2(39.0, 43.0)          ## Hueco de la puerta sur (x).
const VENT := Vector2(-46.2, -44.8)        ## Hueco de la rejilla este (z).
const VENT_HEIGHT := 1.25
## Oficina: esquina noreste dentro del galpón.
const OFFICE_X := 44.0
const OFFICE_Z := -47.0
const OFFICE_DOOR := Vector2(45.0, 46.4)

## Lo que recoge el jugador (posición del objeto sobre su apoyo).
const GUIA := Vector3(28.0, G + 1.0, -42.0)
const PLACA := Vector3(26.0, G, -34.4)
const FACTURA := Vector3(37.0, G + 0.8, -49.0)
const LIBRO := Vector3(47.5, G + 0.8, -50.5)
## Toda el área del patio (para saber si el jugador entró).
const YARD_CENTER := Vector3(39.5, 1.5, -39.5)
const YARD_SIZE := Vector3(37.0, 3.0, 36.0)
## Cámaras: [posición, yaw]. Miran hacia -Z local.
const CAMERAS := [
	[Vector3(34.6, G + 3.5, -37.7), PI],
	[Vector3(49.5, G + 3.6, -38.5), PI * 0.25],
]
## Rondas de los vigilantes: el patio, el perímetro del galpón y el interior.
const GUARD_ROUTES := [
	[Vector3(22.5, G, -24.5), Vector3(49.0, G, -24.5), Vector3(49.0, G, -35.0), Vector3(22.5, G, -35.5)],
	[Vector3(30.0, G, -37.0), Vector3(30.0, G, -55.0), Vector3(52.0, G, -55.0), Vector3(52.0, G, -36.5)],
	[Vector3(35.0, G, -40.5), Vector3(35.0, G, -46.0), Vector3(42.0, G, -46.0), Vector3(42.0, G, -40.5)],
]

var b: PrototypeBlockBuilder


func _init(builder: PrototypeBlockBuilder) -> void:
	b = builder


func build() -> void:
	_warehouse()
	_office()
	_yard()
	b.points["bodega_door"] = Vector3((DOOR.x + DOOR.y) * 0.5, G, MAX.y + 1.0)
	b.points["bodega_vent"] = Vector3(MAX.x + 0.8, G, (VENT.x + VENT.y) * 0.5)


func _warehouse() -> void:
	var y := G + WALL_H * 0.5
	var w := MAX.x - MIN.x
	var d := MAX.y - MIN.y
	var cx := (MIN.x + MAX.x) * 0.5
	var cz := (MIN.y + MAX.y) * 0.5
	# Norte y oeste completos.
	b.add_box(Vector3(w, WALL_H, WALL_T), Vector3(cx, y, MIN.y), "corrugated")
	b.add_box(Vector3(WALL_T, WALL_H, d), Vector3(MIN.x, y, cz), "corrugated")
	# Sur con la puerta grande (y el dintel encima).
	_wall_x(MIN.x, DOOR.x, MAX.y, 0.0, WALL_H)
	_wall_x(DOOR.y, MAX.x, MAX.y, 0.0, WALL_H)
	_wall_x(DOOR.x, DOOR.y, MAX.y, 3.4, WALL_H)
	# Este con la rejilla baja.
	_wall_z(MIN.y, VENT.x, MAX.x, 0.0, WALL_H)
	_wall_z(VENT.y, MAX.y, MAX.x, 0.0, WALL_H)
	_wall_z(VENT.x, VENT.y, MAX.x, VENT_HEIGHT, WALL_H)
	# Marco y barrotes de la rejilla (abierta: se quitó la malla).
	var vz := (VENT.x + VENT.y) * 0.5
	b.add_box(Vector3(0.12, 0.08, VENT.y - VENT.x + 0.2), Vector3(MAX.x + 0.2, G + VENT_HEIGHT, vz), "metal", false)
	for z: float in [VENT.x, VENT.y]:
		b.add_box(Vector3(0.12, VENT_HEIGHT, 0.08), Vector3(MAX.x + 0.2, G + VENT_HEIGHT * 0.5, z), "metal", false)
	# Techo de lámina y piso de concreto.
	b.add_box(Vector3(w + 0.8, 0.2, d + 0.8), Vector3(cx, G + WALL_H + 0.1, cz), "corrugated")
	b.add_box(Vector3(w - 0.4, 0.02, d - 0.4), Vector3(cx, G + 0.01, cz), "concrete_dark", false)
	# Estantes contra la pared oeste y cajas que dan cobertura.
	for z: float in [-50.0, -47.0, -44.0, -41.0]:
		b.add_box(Vector3(1.2, 2.4, 2.2), Vector3(MIN.x + 0.9, G + 1.2, z), "wood")
		b.add_box(Vector3(1.0, 0.5, 0.8), Vector3(MIN.x + 0.9, G + 2.65, z + 0.4), "crate", false)
	b.add_box(Vector3(1.4, 0.8, 0.8), Vector3(FACTURA.x, G + 0.4, FACTURA.z), "wood")
	b.add_box(Vector3(1.2, 1.2, 1.2), Vector3(38.5, G + 0.6, -43.5), "crate")
	b.add_box(Vector3(1.0, 1.0, 1.0), Vector3(39.6, G + 0.5, -43.2), "crate")
	b.add_box(Vector3(1.0, 0.9, 1.0), Vector3(45.5, G + 0.45, -41.0), "crate")
	# Luz de adentro: un bombillo que siempre está prendido.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.light_energy = 1.6
	lamp.omni_range = 12.0
	lamp.position = Vector3(39.0, G + WALL_H - 0.6, -44.0)
	b.root.add_child(lamp)
	b.add_sphere(0.15, lamp.position + Vector3(0, 0.2, 0), "bulb")
	# Letrero apagado (nunca lo prenden) y un tubo de neón sobre la puerta.
	var sign := Label3D.new()
	sign.text = "BODEGA DEL NORTE"
	sign.font_size = 72
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.modulate = Color(0.95, 0.75, 0.35)
	sign.position = Vector3((DOOR.x + DOOR.y) * 0.5, G + 4.2, MAX.y + 0.2)
	b.root.add_child(sign)
	b.add_box(Vector3(DOOR.y - DOOR.x, 0.06, 0.06), Vector3((DOOR.x + DOOR.y) * 0.5, G + 3.6, MAX.y + 0.2), "neon_amber", false)


func _office() -> void:
	var h := 3.0
	_wall_z(MIN.y, OFFICE_Z, OFFICE_X, 0.0, h, 0.15)
	_wall_x(OFFICE_X, OFFICE_DOOR.x, OFFICE_Z, 0.0, h, 0.15)
	_wall_x(OFFICE_DOOR.y, MAX.x, OFFICE_Z, 0.0, h, 0.15)
	# Escritorio y silla.
	b.add_box(Vector3(1.6, 0.8, 0.8), Vector3(LIBRO.x, G + 0.4, LIBRO.z), "wood")
	b.add_box(Vector3(0.5, 0.5, 0.5), Vector3(LIBRO.x, G + 0.25, LIBRO.z + 0.9), "metal", false)
	b.add_box(Vector3(0.8, 1.8, 0.5), Vector3(MAX.x - 0.5, G + 0.9, -48.0), "metal")   # archivador
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.85, 0.95, 1.0)
	lamp.light_energy = 1.0
	lamp.omni_range = 5.0
	lamp.position = Vector3(47.0, G + 2.6, -49.5)
	b.root.add_child(lamp)


func _yard() -> void:
	# Camión de carga (mira hacia el callejón).
	b.add_box(Vector3(2.4, 2.5, 5.0), Vector3(26.0, G + 0.6 + 1.25, -31.0), "paint_white")
	b.add_box(Vector3(2.3, 1.9, 1.8), Vector3(26.0, G + 0.6 + 0.95, -27.6), "metal_green")
	b.add_box(Vector3(2.1, 0.7, 0.05), Vector3(26.0, G + 2.0, -26.68), "glass", false)
	b.add_box(Vector3(2.0, 0.5, 6.8), Vector3(26.0, G + 0.35, -30.2), "concrete_dark")
	for z: float in [-28.0, -32.5]:
		for x: float in [24.85, 27.15]:
			var wheel := b.add_cylinder(0.45, 0.3, Vector3(x, G + 0.45, z), "tire", false)
			wheel.rotation.z = PI * 0.5
	# Placa trasera.
	b.add_box(Vector3(0.6, 0.18, 0.03), Vector3(26.0, G + 0.9, -33.53), "paint_yellow", false)
	# Contenedores y cajas.
	b.add_box(Vector3(6.0, 2.6, 2.4), Vector3(38.0, G + 1.3, -27.0), "container_red")
	b.add_box(Vector3(2.4, 2.6, 6.0), Vector3(54.5, G + 1.3, -30.0), "container_blue")
	b.add_box(Vector3(2.4, 2.6, 6.0), Vector3(54.5, G + 1.3, -47.0), "container_red")
	b.add_box(Vector3(1.0, 1.0, 1.0), Vector3(GUIA.x, G + 0.5, GUIA.z), "crate")
	b.add_box(Vector3(1.0, 1.0, 1.0), Vector3(GUIA.x, G + 0.5, GUIA.z - 1.05), "crate")
	b.add_box(Vector3(0.9, 0.9, 0.9), Vector3(GUIA.x, G + 1.45, GUIA.z - 1.05), "crate")
	b.add_box(Vector3(1.0, 1.2, 1.0), Vector3(45.0, G + 0.6, -27.5), "crate")


## Pared a lo largo de X (en z fijo), de x0 a x1, entre las alturas y0 y y1.
func _wall_x(x0: float, x1: float, z: float, y0: float, y1: float, t: float = WALL_T) -> void:
	if x1 - x0 < 0.01:
		return
	b.add_box(Vector3(x1 - x0, y1 - y0, t), Vector3((x0 + x1) * 0.5, G + (y0 + y1) * 0.5, z), "corrugated")


## Pared a lo largo de Z (en x fijo), de z0 a z1.
func _wall_z(z0: float, z1: float, x: float, y0: float, y1: float, t: float = WALL_T) -> void:
	if z1 - z0 < 0.01:
		return
	b.add_box(Vector3(t, y1 - y0, z1 - z0), Vector3(x, G + (y0 + y1) * 0.5, (z0 + z1) * 0.5), "corrugated")
