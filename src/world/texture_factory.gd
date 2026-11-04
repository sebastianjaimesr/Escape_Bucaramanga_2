class_name TextureFactory
extends RefCounted
## Texturas procedurales (generadas al iniciar, sin archivos): ladrillo,
## baldosas de andén, asfalto con grietas y revoque. Cada una devuelve el color
## y un mapa de normales calculado a partir de su relieve.
##
## Son de 256 × 256 px y se generan una sola vez (MaterialLibrary las guarda).
## En la Fase 5 se reemplazan por texturas PBR CC0.

const SIZE := 256

static var _cache: Dictionary = {}


## Devuelve {"albedo": Texture2D, "normal": Texture2D} para el patrón pedido.
static func get_pair(kind: String) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
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
		_:
			push_error("Textura procedural desconocida: %s" % kind)
	albedo.generate_mipmaps()
	var normal_img := height.duplicate() as Image
	normal_img.bump_map_to_normal_map(4.0 if kind != "stucco" else 2.0)
	normal_img.generate_mipmaps()
	var pair := {
		"albedo": ImageTexture.create_from_image(albedo),
		"normal": ImageTexture.create_from_image(normal_img),
	}
	_cache[kind] = pair
	return pair


## Ladrillo en aparejo corrido: filas desplazadas medio ladrillo, juntas de mortero.
static func _bricks(albedo: Image, height: Image, rng: RandomNumberGenerator, noise: FastNoiseLite,
		base: Color, mortar: Color, cols: int, rows: int) -> void:
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
			var n := noise.get_noise_2d(x * 3.0, y * 3.0) * 0.06
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
	var t := SIZE / 4
	var tints: Dictionary = {}
	for y in SIZE:
		for x in SIZE:
			var key := (y / t) * 10 + (x / t)
			if not tints.has(key):
				tints[key] = rng.randf_range(-0.05, 0.05)
			var lx := x % t
			var ly := y % t
			var n := noise.get_noise_2d(x, y) * 0.08 + noise.get_noise_2d(x * 8.0, y * 8.0) * 0.03
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
	for y in SIZE:
		for x in SIZE:
			var grain := rng.randf_range(-0.035, 0.035)
			var patch := noise.get_noise_2d(x * 0.6, y * 0.6) * 0.05
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
	for y in SIZE:
		for x in SIZE:
			var n := noise.get_noise_2d(x * 2.0, y * 2.0) * 0.5 + noise.get_noise_2d(x * 9.0, y * 9.0) * 0.25
			var v := 0.92 + n * 0.12
			albedo.set_pixel(x, y, Color(v, v, v))
			var h := 0.5 + n * 0.5
			height.set_pixel(x, y, Color(h, h, h))
