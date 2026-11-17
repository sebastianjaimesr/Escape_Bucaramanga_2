class_name TextureFactory
extends RefCounted
## Texturas procedurales (generadas al iniciar, sin archivos): ladrillo,
## baldosas de andén, asfalto con grietas, revoque, pasto, follaje, corteza,
## teja de barro, cantera y tablas de madera. Cada una devuelve el color y un
## mapa de normales calculado a partir de su relieve.
##
## Las de pasto, follaje, corteza, teja, cantera y madera son casi grises: el
## material les pone el color (así la misma textura sirve para el pasto del
## parque y para el seto, o para la teja y la madera de distinto tono).
## Son de 256 × 256 px (128 las más pequeñas) y se generan una sola vez.

const SIZE := 256
const SMALL_SIZE := 128
## Texturas que no necesitan tanto detalle (superficies pequeñas o lejanas).
const SMALL_KINDS := ["bark", "planks", "stone_blocks"]
## Fuerza del relieve de cada textura al convertirlo en normales.
const BUMP := {"stucco": 2.0, "grass": 3.0, "leaves": 5.0, "bark": 6.0, "roof_tile": 5.0,
		"stone_blocks": 4.0, "planks": 3.0}

## Las texturas generadas se guardan en disco (user://) y en la siguiente
## partida se cargan en vez de volver a calcularlas: en un celular eso ahorra
## un par de segundos de carga. Subir la versión si cambia algún patrón.
const DISK_CACHE_VERSION := 2
const DISK_CACHE_DIR := "user://cache_texturas"

static var _cache: Dictionary = {}
static var _noise_size := SIZE
## Las pruebas lo apagan para medir y comprobar la generación real.
static var disk_cache_enabled := true


## Devuelve {"albedo": Texture2D, "normal": Texture2D} para el patrón pedido.
static func get_pair(kind: String) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var cached := _load_from_disk(kind)
	if not cached.is_empty():
		_cache[kind] = cached
		return cached
	var size: int = SMALL_SIZE if kind in SMALL_KINDS else SIZE
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.04
	noise.fractal_octaves = 3
	match kind:
		"brick":
			_bricks(albedo, height, rng, noise, Color(0.62, 0.3, 0.2), Color(0.78, 0.74, 0.68), 8, 4)
		"brick_plaza":
			_bricks(albedo, height, rng, noise, Color(0.66, 0.38, 0.26), Color(0.55, 0.5, 0.45), 8, 8)
		"tiles":
			_tiles(albedo, height, rng, noise)
		"asphalt":
			_asphalt(albedo, height, rng, noise)
		"stucco":
			_stucco(albedo, height, noise)
		"grass":
			_grass(albedo, height, rng, noise)
		"leaves":
			_leaves(albedo, height, rng, noise)
		"bark":
			_bark(albedo, height, rng, noise)
		"roof_tile":
			_roof_tiles(albedo, height, rng, noise)
		"stone_blocks":
			_stone_blocks(albedo, height, rng, noise)
		"planks":
			_planks(albedo, height, rng, noise)
		_:
			push_error("Textura procedural desconocida: %s" % kind)
	albedo.generate_mipmaps()
	var normal_img := height.duplicate() as Image
	normal_img.bump_map_to_normal_map(BUMP.get(kind, 4.0))
	normal_img.generate_mipmaps()
	var pair := {
		"albedo": ImageTexture.create_from_image(albedo),
		"normal": ImageTexture.create_from_image(normal_img),
	}
	_cache[kind] = pair
	_save_to_disk(kind, albedo, normal_img)
	return pair


static func _disk_path(kind: String, layer: String) -> String:
	return "%s/%s_%s_v%d.res" % [DISK_CACHE_DIR, kind, layer, DISK_CACHE_VERSION]


static func _load_from_disk(kind: String) -> Dictionary:
	if not disk_cache_enabled:
		return {}
	var a_path := _disk_path(kind, "color")
	var n_path := _disk_path(kind, "normal")
	if not FileAccess.file_exists(a_path) or not FileAccess.file_exists(n_path):
		return {}
	var a := ResourceLoader.load(a_path, "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
	var n := ResourceLoader.load(n_path, "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
	if a == null or n == null or a.is_empty() or n.is_empty():
		return {}
	return {"albedo": ImageTexture.create_from_image(a), "normal": ImageTexture.create_from_image(n)}


static func _save_to_disk(kind: String, albedo: Image, normal_img: Image) -> void:
	if not disk_cache_enabled:
		return
	DirAccess.make_dir_recursive_absolute(DISK_CACHE_DIR)
	ResourceSaver.save(albedo, _disk_path(kind, "color"))
	ResourceSaver.save(normal_img, _disk_path(kind, "normal"))


## Ruido que se repite sin costuras en una textura de `size` px (la textura se
## repite en el mundo: con ruido normal se notaría una cuadrícula). k cambia la
## escala igual que multiplicar las coordenadas en get_noise_2d.
static func _seamless(noise: FastNoiseLite, k: float, size: int) -> PackedByteArray:
	var n := noise.duplicate() as FastNoiseLite
	n.frequency = noise.frequency * k
	var img := n.get_seamless_image(size, size, false, false, 0.15, false)
	img.convert(Image.FORMAT_L8)
	_noise_size = size
	return img.get_data()


## Valor del ruido (-1 a 1) en un píxel, dando la vuelta en los bordes.
## Lee los bytes directamente: es varias veces más rápido que get_pixel().
static func _s(data: PackedByteArray, x: int, y: int) -> float:
	return data[posmod(y, _noise_size) * _noise_size + posmod(x, _noise_size)] / 127.5 - 1.0


## Ladrillo en aparejo corrido: filas desplazadas medio ladrillo, juntas de mortero.
static func _bricks(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite,
		base: Color, mortar: Color, cols: int, rows: int) -> void:
	var n3 := _seamless(noise, 3.0, albedo.get_width())
	var bw := SIZE / cols
	var bh := SIZE / (rows * 2)
	var tints: Dictionary = {}
	for y in SIZE:
		var row := y / bh
		var offset := (bw / 2) if row % 2 == 1 else 0
		for x in SIZE:
			var xx := (x + offset) % SIZE
			var col := xx / bw
			var lx := xx % bw
			var ly := y % bh
			var key := row * 1000 + col
			if not tints.has(key):
				tints[key] = rng.randf_range(-0.09, 0.09)
			var n := _s(n3, x, y) * 0.06
			if lx < 2 or ly < 2:
				var m := mortar.darkened(0.05 + n)
				albedo.set_pixel(x, y, m)
				height.set_pixel(x, y, Color(0.15, 0.15, 0.15))
			else:
				var t: float = tints[key] + n
				albedo.set_pixel(x, y, Color(base.r + t, base.g + t * 0.7, base.b + t * 0.5))
				var h := 0.8 + n
				height.set_pixel(x, y, Color(h, h, h))


## Baldosas cuadradas de andén (concreto prensado) con juntas y manchas.
static func _tiles(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var n1 := _seamless(noise, 1.0, albedo.get_width())
	var n8 := _seamless(noise, 8.0, albedo.get_width())
	var t := SIZE / 4
	var tints: Dictionary = {}
	for y in SIZE:
		for x in SIZE:
			var key := (y / t) * 10 + (x / t)
			if not tints.has(key):
				tints[key] = rng.randf_range(-0.05, 0.05)
			var lx := x % t
			var ly := y % t
			var n := _s(n1, x, y) * 0.08 + _s(n8, x, y) * 0.03
			if lx < 2 or ly < 2:
				albedo.set_pixel(x, y, Color(0.3, 0.3, 0.29))
				height.set_pixel(x, y, Color(0.1, 0.1, 0.1))
			else:
				# Relieve de "puntos" típico de las baldosas de andén.
				var dot := 0.0
				if (lx % 8) in [3, 4] and (ly % 8) in [3, 4]:
					dot = 0.12
				var v: float = 0.62 + tints[key] + n
				albedo.set_pixel(x, y, Color(v, v * 0.98, v * 0.95))
				var h := 0.7 + dot + n
				height.set_pixel(x, y, Color(h, h, h))


## Asfalto: grano fino, parches más oscuros y algunas grietas.
static func _asphalt(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var n06 := _seamless(noise, 0.6, albedo.get_width())
	for y in SIZE:
		for x in SIZE:
			var grain := rng.randf_range(-0.035, 0.035)
			var patch := _s(n06, x, y) * 0.05
			var v := 0.16 + grain + patch
			albedo.set_pixel(x, y, Color(v, v, v * 1.04))
			var h := 0.5 + grain * 3.0
			height.set_pixel(x, y, Color(h, h, h))
	# Grietas: caminos aleatorios oscuros y hundidos.
	for c in 6:
		var p := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
		var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
		for step in rng.randi_range(40, 110):
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			p += dir
			var ix := posmod(int(p.x), SIZE)
			var iy := posmod(int(p.y), SIZE)
			albedo.set_pixel(ix, iy, Color(0.07, 0.07, 0.075))
			height.set_pixel(ix, iy, Color(0.1, 0.1, 0.1))


## Revoque (pañete) de fachada: solo relieve suave, el color lo pone el material.
static func _stucco(albedo: Image, height: Image, noise: FastNoiseLite) -> void:
	var n2 := _seamless(noise, 2.0, albedo.get_width())
	var n9 := _seamless(noise, 9.0, albedo.get_width())
	for y in SIZE:
		for x in SIZE:
			var n := _s(n2, x, y) * 0.5 + _s(n9, x, y) * 0.25
			var v := 0.92 + n * 0.12
			albedo.set_pixel(x, y, Color(v, v, v))
			var h := 0.5 + n * 0.5
			height.set_pixel(x, y, Color(h, h, h))


## Pasto: briznas cortas en varias direcciones, manchas más secas y más
## oscuras. Sin rayas: el ruido no tiene dirección dominante.
static func _grass(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var n08 := _seamless(noise, 0.8, albedo.get_width())
	var n035 := _seamless(noise, 0.35, albedo.get_width())
	var s := albedo.get_width()
	for y in s:
		for x in s:
			var patch := _s(n08, x, y)
			var fine := rng.randf_range(-0.1, 0.1)
			var v := 0.82 + patch * 0.14 + fine
			# Manchas secas: algo más amarillas.
			var dry := clampf(_s(n035, x + 97, y + 41) * 1.6, 0.0, 1.0)
			albedo.set_pixel(x, y, Color(v + dry * 0.1, v + dry * 0.04, v * (1.0 - dry * 0.18)))
			var h := 0.45 + fine * 1.5
			height.set_pixel(x, y, Color(h, h, h))
	# Briznas: trazos cortos claros con la punta más clara.
	for i in s * 6:
		var p := Vector2(rng.randf() * s, rng.randf() * s)
		var dir := Vector2.UP.rotated(rng.randf_range(-0.7, 0.7))
		var length := rng.randi_range(3, 7)
		var light := rng.randf_range(0.0, 0.22)
		for k in length:
			var ix := posmod(int(p.x), s)
			var iy := posmod(int(p.y), s)
			var t := float(k) / length
			var c := albedo.get_pixel(ix, iy)
			albedo.set_pixel(ix, iy, c.lightened(light * t))
			var hh := 0.6 + 0.35 * t
			height.set_pixel(ix, iy, Color(hh, hh, hh))
			p += dir


## Follaje: racimos de hojas pequeñas (manchas ovaladas con nervadura), con
## huecos oscuros entre ellos. Rompe la forma de esfera lisa de las copas.
static func _leaves(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var n15 := _seamless(noise, 1.5, albedo.get_width())
	var s := albedo.get_width()
	for y in s:
		for x in s:
			var n := _s(n15, x, y)
			var v := 0.5 + n * 0.12
			albedo.set_pixel(x, y, Color(v, v, v))
			height.set_pixel(x, y, Color(0.2, 0.2, 0.2))
	for i in 900:
		var c := Vector2(rng.randf() * s, rng.randf() * s)
		var ang := rng.randf() * TAU
		var r := rng.randf_range(3.0, 6.5)
		var shade := rng.randf_range(0.72, 1.18)
		var ax := Vector2.RIGHT.rotated(ang)
		var ay := Vector2.UP.rotated(ang)
		for oy in range(-7, 8):
			for ox in range(-7, 8):
				var d := Vector2(ox, oy)
				var lx := d.dot(ax) / r
				var ly := d.dot(ay) / (r * 0.55)
				var q := lx * lx + ly * ly
				if q > 1.0:
					continue
				var ix := posmod(int(c.x) + ox, s)
				var iy := posmod(int(c.y) + oy, s)
				# Nervadura central un poco más clara, borde más oscuro.
				var vein := 0.06 if absf(ly) < 0.12 else 0.0
				var v := shade * (0.95 - q * 0.25) + vein
				albedo.set_pixel(ix, iy, Color(v * 0.97, v, v * 0.9))
				var h := 0.55 + (1.0 - q) * 0.4
				height.set_pixel(ix, iy, Color(h, h, h))


## Corteza: surcos verticales irregulares.
static func _bark(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var n05 := _seamless(noise, 0.5, albedo.get_width())
	var n2 := _seamless(noise, 1.5, albedo.get_width())
	var s := albedo.get_width()
	for y in s:
		for x in s:
			var warp := _s(n05, x, y * 4) * 6.0
			var groove := absf(sin((x + warp) * 0.45))
			var n := _s(n2, x * 3, y) * 0.1
			var v := 0.62 + groove * 0.35 + n + rng.randf_range(-0.03, 0.03)
			albedo.set_pixel(x, y, Color(v, v, v))
			var h := groove * 0.8 + n
			height.set_pixel(x, y, Color(h, h, h))


## Teja de barro (española): hileras de canales con sombra entre una fila y
## la siguiente. Las tejas cambian un poco de tono.
static func _roof_tiles(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var n3 := _seamless(noise, 3.0, albedo.get_width())
	var s := albedo.get_width()
	var cols := 8
	var rows := 8
	var tw := s / cols
	var th := s / rows
	var tints := {}
	for y in s:
		var row := y / th
		var ly := float(y % th) / th
		var offset := (tw / 2) if row % 2 == 1 else 0
		for x in s:
			var xx := (x + offset) % s
			var col := xx / tw
			var key := row * 100 + col
			if not tints.has(key):
				tints[key] = rng.randf_range(-0.1, 0.1)
			var lx := float(xx % tw) / tw
			# Curva del canal: más alta en el centro de la teja.
			var curve := sin(lx * PI)
			# El borde inferior de la fila de arriba deja sombra.
			var lap := smoothstep(0.0, 0.18, ly)
			var n := _s(n3, x, y) * 0.06
			var v: float = (0.7 + curve * 0.3) * (0.55 + lap * 0.45) + tints[key] + n
			albedo.set_pixel(x, y, Color(v, v, v))
			var h := curve * 0.7 * lap + 0.15
			height.set_pixel(x, y, Color(h, h, h))


## Cantera: bloques grandes de piedra con juntas finas y vetas.
static func _stone_blocks(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var n2 := _seamless(noise, 2.0, albedo.get_width())
	var s := albedo.get_width()
	var bw := s / 2
	var bh := s / 4
	var tints := {}
	for y in s:
		var row := y / bh
		var offset := (bw / 2) if row % 2 == 1 else 0
		for x in s:
			var xx := (x + offset) % s
			var key := row * 10 + xx / bw
			if not tints.has(key):
				tints[key] = rng.randf_range(-0.06, 0.06)
			var n := _s(n2, x, y) * 0.08 + rng.randf_range(-0.025, 0.025)
			if xx % bw < 1 or y % bh < 1:
				albedo.set_pixel(x, y, Color(0.62, 0.62, 0.62))
				height.set_pixel(x, y, Color(0.1, 0.1, 0.1))
			else:
				var v: float = 0.92 + tints[key] + n
				albedo.set_pixel(x, y, Color(v, v, v))
				var h := 0.7 + n * 2.0
				height.set_pixel(x, y, Color(h, h, h))


## Tablas de madera: vetas alargadas y juntas entre tablas.
static func _planks(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var n04 := _seamless(noise, 0.6, albedo.get_width())
	var s := albedo.get_width()
	var pw := s / 4
	var tints := {}
	for y in s:
		for x in s:
			var plank := x / pw
			if not tints.has(plank):
				tints[plank] = rng.randf_range(-0.08, 0.08)
			var grain := sin((x + _s(n04, x * 4, y) * 14.0) * 1.3) * 0.06
			var v: float = 0.85 + tints[plank] + grain
			if x % pw < 1:
				albedo.set_pixel(x, y, Color(0.45, 0.45, 0.45))
				height.set_pixel(x, y, Color(0.1, 0.1, 0.1))
			else:
				albedo.set_pixel(x, y, Color(v, v, v))
				var h := 0.6 + grain
				height.set_pixel(x, y, Color(h, h, h))
