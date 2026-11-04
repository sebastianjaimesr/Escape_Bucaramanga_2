class_name MaterialLibrary
extends RefCounted
## Materiales PBR compartidos (uno por tipo, reutilizados por todas las mallas
## para reducir cambios de estado al dibujar).
##
## Las superficies principales (asfalto, andenes, ladrillo, revoque) usan
## texturas procedurales con mapa de normales (TextureFactory); el resto, ruido
## procedural o colores planos. En la Fase 5 se reemplazan por texturas PBR CC0.

static var _cache: Dictionary = {}

const FACADE_COLORS := [
	Color(0.93, 0.9, 0.82),   # blanco cal
	Color(0.86, 0.72, 0.5),   # ocre
	Color(0.78, 0.48, 0.36),  # terracota
	Color(0.68, 0.76, 0.72),  # verde pálido
	Color(0.84, 0.8, 0.66),   # arena
	Color(0.62, 0.66, 0.74),  # azul gris
	Color(0.9, 0.82, 0.7),    # crema
	Color(0.95, 0.86, 0.42),  # amarillo colonial
	Color(0.55, 0.72, 0.82),  # azul cielo
]

const CAR_COLORS := [
	Color(0.85, 0.85, 0.83),  # blanco
	Color(0.55, 0.06, 0.06),  # rojo vino
	Color(0.1, 0.12, 0.16),   # negro
	Color(0.6, 0.62, 0.64),   # plateado
	Color(0.08, 0.2, 0.45),   # azul
	Color(0.95, 0.78, 0.1),   # amarillo taxi
]

const SIGN_COLORS := [
	Color(0.85, 0.15, 0.15),
	Color(0.1, 0.45, 0.8),
	Color(0.95, 0.7, 0.1),
	Color(0.15, 0.6, 0.3),
	Color(0.6, 0.2, 0.6),
]


static func get_material(id: String) -> StandardMaterial3D:
	if _cache.has(id):
		return _cache[id]
	var m: StandardMaterial3D
	match id:
		"asphalt":
			m = _patterned("asphalt", Color(1, 1, 1), 0.93, 0.25)
		"sidewalk":
			m = _patterned("tiles", Color(1, 1, 1), 0.85, 0.7)
		"curb":
			m = _surface(Color(0.62, 0.6, 0.56), 0.8, 0.08, 1.0)
		"curb_yellow":
			m = _flat(Color(0.9, 0.7, 0.12), 0.7)
		"plaza":
			m = _patterned("brick_plaza", Color(1, 1, 1), 0.85, 0.7)
		"brick":
			m = _patterned("brick", Color(1, 1, 1), 0.9, 0.55)
		"concrete":
			m = _surface(Color(0.55, 0.54, 0.52), 0.88, 0.1, 0.4)
		"concrete_dark":
			m = _surface(Color(0.36, 0.36, 0.36), 0.9, 0.1, 0.4)
		"roof":
			m = _surface(Color(0.32, 0.31, 0.3), 0.95, 0.15, 0.5)
		"tile_roof":
			m = _surface(Color(0.6, 0.27, 0.16), 0.85, 0.15, 1.5)
		"grass":
			m = _surface(Color(0.22, 0.38, 0.13), 0.95, 0.25, 0.7)
		"soil":
			m = _surface(Color(0.33, 0.24, 0.16), 0.97, 0.2, 0.8)
		"paint_white":
			m = _flat(Color(0.9, 0.9, 0.87), 0.6)
		"paint_yellow":
			m = _flat(Color(0.95, 0.75, 0.15), 0.6)
		"glass":
			m = _flat(Color(0.1, 0.14, 0.19), 0.06)
			m.metallic = 0.3
			m.metallic_specular = 0.9
		"glass_lit":
			# Ventanas con luz cálida encendida (atardecer).
			m = _flat(Color(0.35, 0.28, 0.18), 0.1)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.72, 0.4)
			m.emission_energy_multiplier = 0.9
		"window_frame":
			m = _flat(Color(0.92, 0.91, 0.88), 0.5)
		"storefront":
			m = _flat(Color(0.14, 0.16, 0.18), 0.12)
			m.metallic = 0.35
			m.metallic_specular = 0.8
		"shop_interior":
			m = _flat(Color(0.3, 0.24, 0.17), 0.7)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.8, 0.55)
			m.emission_energy_multiplier = 0.22
		"shop_glass":
			# Vidrio de vitrina: deja ver el interior y refleja el cielo.
			m = _flat(Color(0.6, 0.7, 0.75, 0.28), 0.04)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.4
			m.metallic_specular = 1.0
		"awning":
			m = _flat(Color(0.7, 0.14, 0.14), 0.7)
		"awning_green":
			m = _flat(Color(0.12, 0.45, 0.25), 0.7)
		"awning_blue":
			m = _flat(Color(0.12, 0.3, 0.6), 0.7)
		"awning_yellow":
			m = _flat(Color(0.95, 0.72, 0.12), 0.7)
		"metal":
			m = _flat(Color(0.22, 0.23, 0.24), 0.45)
			m.metallic = 0.85
		"metal_green":
			m = _flat(Color(0.1, 0.3, 0.2), 0.5)
			m.metallic = 0.6
		"rail":
			m = _flat(Color(0.08, 0.08, 0.09), 0.4)
			m.metallic = 0.8
		"wood":
			m = _surface(Color(0.45, 0.3, 0.18), 0.8, 0.15, 2.0)
		"bark":
			m = _surface(Color(0.3, 0.22, 0.15), 0.95, 0.2, 2.0)
		"leaves":
			m = _surface(Color(0.2, 0.4, 0.14), 0.9, 0.3, 1.5)
		"leaves_dark":
			m = _surface(Color(0.12, 0.3, 0.1), 0.9, 0.3, 1.5)
		"leaves_flower":
			m = _surface(Color(0.82, 0.25, 0.5), 0.85, 0.25, 1.5)   # Ocobo / bugambilia.
		"hedge":
			m = _surface(Color(0.16, 0.36, 0.12), 0.95, 0.35, 2.5)
		"bulb":
			m = _flat(Color(1.0, 0.95, 0.8), 0.3)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.86, 0.6)
			m.emission_energy_multiplier = 2.5
		"light_red":
			m = _emissive(Color(1.0, 0.1, 0.08), 3.0)
		"light_yellow":
			m = _emissive(Color(1.0, 0.7, 0.1), 2.0)
		"light_green":
			m = _emissive(Color(0.15, 1.0, 0.35), 2.5)
		"light_blue":
			m = _emissive(Color(0.15, 0.35, 1.0), 3.0)
		"light_off":
			m = _flat(Color(0.12, 0.12, 0.12), 0.4)
		"tire":
			m = _flat(Color(0.05, 0.05, 0.05), 0.9)
		"plastic_green":
			m = _flat(Color(0.12, 0.42, 0.2), 0.6)
		"plastic_gray":
			m = _flat(Color(0.3, 0.32, 0.33), 0.6)
		"evidence_glow":
			m = _emissive(Color(1.0, 0.82, 0.2), 2.2)
		"evidence_beam":
			m = _emissive(Color(1.0, 0.8, 0.25), 1.2)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.25
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"test_orange":
			m = _flat(Color(0.95, 0.45, 0.12), 0.6)
		_:
			if id.begins_with("facade_"):
				var i := int(id.trim_prefix("facade_")) % FACADE_COLORS.size()
				m = _patterned("stucco", FACADE_COLORS[i], 0.9, 0.35)
			elif id.begins_with("car_"):
				m = _flat(CAR_COLORS[int(id.trim_prefix("car_")) % CAR_COLORS.size()], 0.25)
				m.metallic = 0.55
				m.clearcoat_enabled = true
				m.clearcoat = 0.6
			elif id.begins_with("sign_"):
				var c: Color = SIGN_COLORS[int(id.trim_prefix("sign_")) % SIGN_COLORS.size()]
				m = _flat(c, 0.5)
				m.emission_enabled = true
				m.emission = c
				m.emission_energy_multiplier = 0.35
			else:
				push_error("Material desconocido: %s" % id)
				m = _flat(Color.MAGENTA, 0.5)
	_cache[id] = m
	return m


## Material con textura procedural de TextureFactory (color + normales),
## proyectada en triplanar con coordenadas del mundo.
static func _patterned(kind: String, tint: Color, roughness: float, scale: float) -> StandardMaterial3D:
	var pair := TextureFactory.get_pair(kind)
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = pair["albedo"]
	m.normal_enabled = true
	m.normal_texture = pair["normal"]
	m.normal_scale = 0.8
	m.roughness = roughness
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := _flat(color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Superficie con variación procedural de color (proyección triplanar en
## coordenadas del mundo, así no hay que preparar UV en la geometría de prueba).
static func _surface(color: Color, roughness: float, variation: float, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0 - variation, 1.0 - variation, 1.0 - variation))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	tex.color_ramp = ramp
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale * 0.25
	return m


static func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
