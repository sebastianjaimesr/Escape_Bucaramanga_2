class_name TimeOfDay
extends RefCounted
## Hora del día de cada capítulo: mañana, tarde o noche, con o sin lluvia.
##
## Cambia el cielo, el sol, la luz ambiente y la niebla del entorno que arma
## PrototypeWorld. De noche prende los faroles de la calle (una OmniLight por
## farol, sin sombras para que alcance en el celular) y las ventanas se ven
## encendidas por la luz ambiente baja. La lluvia es una nube de partículas
## que sigue al jugador (RainFx).

const PRESETS := {
	"manana": {
		"clouds": 0.42, "cloud_light": Color(1.0, 0.99, 0.97), "cloud_dark": Color(0.68, 0.72, 0.8), "stars": 0.0, "saturation": 1.1, "contrast": 1.05,
		"sky_top": Color(0.3, 0.52, 0.85), "sky_horizon": Color(0.82, 0.86, 0.9),
		"ground_horizon": Color(0.7, 0.68, 0.64), "sun_color": Color(1.0, 0.96, 0.88),
		"sun_energy": 1.35, "sun_rot": Vector3(-42.0, 120.0, 0.0), "ambient": 0.85,
		"fog": Color(0.8, 0.84, 0.88), "fog_density": 1.0, "exposure": 1.05, "lamps": false,
	},
	"tarde": {
		"clouds": 0.5, "cloud_light": Color(1.0, 0.9, 0.78), "cloud_dark": Color(0.62, 0.55, 0.62), "stars": 0.0, "saturation": 1.14, "contrast": 1.06,
		"sky_top": Color(0.24, 0.42, 0.74), "sky_horizon": Color(0.92, 0.76, 0.6),
		"ground_horizon": Color(0.72, 0.62, 0.54), "sun_color": Color(1.0, 0.84, 0.66),
		"sun_energy": 1.45, "sun_rot": Vector3(-30.0, -58.0, 0.0), "ambient": 0.75,
		"fog": Color(0.86, 0.76, 0.66), "fog_density": 1.0, "exposure": 1.08, "lamps": false,
	},
	"noche": {
		"clouds": 0.3, "cloud_light": Color(0.14, 0.15, 0.22), "cloud_dark": Color(0.05, 0.05, 0.09), "stars": 0.8, "saturation": 1.05, "contrast": 1.08,
		"sky_top": Color(0.02, 0.03, 0.08), "sky_horizon": Color(0.12, 0.12, 0.2),
		"ground_horizon": Color(0.06, 0.06, 0.08), "sun_color": Color(0.55, 0.65, 1.0),
		"sun_energy": 0.22, "sun_rot": Vector3(-55.0, 30.0, 0.0), "ambient": 0.32,
		"fog": Color(0.1, 0.11, 0.16), "fog_density": 1.0, "exposure": 1.25, "lamps": true,
	},
	# Capítulo 5: empieza de madrugada y el cielo se aclara mientras avanza la
	# huida (la misión mezcla "madrugada" y "amanecer" con blend()).
	"madrugada": {
		"clouds": 0.35, "cloud_light": Color(0.3, 0.26, 0.42), "cloud_dark": Color(0.12, 0.11, 0.2), "stars": 0.5, "saturation": 1.05, "contrast": 1.06,
		"sky_top": Color(0.07, 0.09, 0.22), "sky_horizon": Color(0.26, 0.2, 0.34),
		"ground_horizon": Color(0.1, 0.09, 0.13), "sun_color": Color(0.6, 0.62, 1.0),
		"sun_energy": 0.42, "sun_rot": Vector3(-34.0, 95.0, 0.0), "ambient": 0.75,
		"fog": Color(0.16, 0.14, 0.22), "fog_density": 1.0, "exposure": 1.22, "lamps": true,
	},
	"amanecer": {
		"clouds": 0.45, "cloud_light": Color(1.0, 0.72, 0.6), "cloud_dark": Color(0.5, 0.4, 0.52), "stars": 0.0, "saturation": 1.12, "contrast": 1.06,
		"sky_top": Color(0.2, 0.3, 0.62), "sky_horizon": Color(1.0, 0.62, 0.42),
		"ground_horizon": Color(0.55, 0.42, 0.4), "sun_color": Color(1.0, 0.7, 0.48),
		"sun_energy": 1.25, "sun_rot": Vector3(-9.0, 95.0, 0.0), "ambient": 0.68,
		"fog": Color(0.95, 0.68, 0.55), "fog_density": 1.0, "exposure": 1.1, "lamps": true,
	},
}
const LAMP_COLOR := Color(1.0, 0.78, 0.5)
const LAMP_ENERGY := 2.2
const LAMP_RANGE := 11.0


static func apply(world: PrototypeWorld, preset: String, rain: bool) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["tarde"])
	_set_sky(world, p, rain)
	if p["lamps"]:
		_light_lamps(world)
	if rain:
		var r := RainFx.new()
		r.name = "Lluvia"
		world.add_child(r)


## Mezcla dos horas (0 = from, 1 = to) sin tocar faroles ni lluvia: el cielo de
## la huida final pasa de la madrugada al amanecer.
static func blend(world: PrototypeWorld, from: String, to: String, t: float) -> void:
	var a: Dictionary = PRESETS[from]
	var b: Dictionary = PRESETS[to]
	var p := {}
	t = clampf(t, 0.0, 1.0)
	for key: String in a:
		var va: Variant = a[key]
		var vb: Variant = b[key]
		if va is Color:
			p[key] = (va as Color).lerp(vb, t)
		elif va is Vector3:
			p[key] = (va as Vector3).lerp(vb, t)
		elif va is float:
			p[key] = lerpf(va, vb, t)
		else:
			p[key] = va
	_set_sky(world, p, false)


static func _set_sky(world: PrototypeWorld, p: Dictionary, rain: bool) -> void:
	var env := world.environment
	var sky_mat := env.sky.sky_material as ShaderMaterial
	var top: Color = p["sky_top"]
	var horizon: Color = p["sky_horizon"]
	var clouds: float = p["clouds"]
	var c_light: Color = p["cloud_light"]
	var c_dark: Color = p["cloud_dark"]
	if rain:
		# Aguacero: cielo encapotado y gris, sin estrellas.
		top = top.lerp(Color(0.2, 0.22, 0.25), 0.5)
		horizon = horizon.lerp(Color(0.25, 0.27, 0.3), 0.5)
		clouds = 0.92
		c_light = c_light.lerp(Color(0.42, 0.44, 0.48), 0.6)
		c_dark = c_dark.lerp(Color(0.16, 0.17, 0.2), 0.6)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("ground_horizon_color", p["ground_horizon"])
	sky_mat.set_shader_parameter("cloud_cover", clouds)
	sky_mat.set_shader_parameter("cloud_light", c_light)
	sky_mat.set_shader_parameter("cloud_dark", c_dark)
	sky_mat.set_shader_parameter("stars", 0.0 if rain else float(p["stars"]))
	env.adjustment_saturation = p["saturation"]
	env.adjustment_contrast = p["contrast"]
	env.ambient_light_energy = p["ambient"]
	env.ambient_light_color = p["fog"]
	env.fog_light_color = p["fog"]
	env.fog_density = float(p["fog_density"]) * (1.6 if rain else 1.0)
	env.tonemap_exposure = p["exposure"]
	world.sun.light_color = p["sun_color"]
	world.sun.light_energy = float(p["sun_energy"]) * (0.7 if rain else 1.0)
	world.sun.rotation_degrees = p["sun_rot"]


static func _light_lamps(world: PrototypeWorld) -> void:
	var holder := Node3D.new()
	holder.name = "LucesFaroles"
	world.add_child(holder)
	for pos: Vector3 in world.points.get("lamps", []):
		var l := OmniLight3D.new()
		l.light_color = LAMP_COLOR
		l.light_energy = LAMP_ENERGY
		l.omni_range = LAMP_RANGE
		l.omni_attenuation = 1.3
		l.shadow_enabled = false
		l.position = pos
		holder.add_child(l)
		# Halo alrededor de la bombilla: un cuadro que siempre mira a la
		# cámara. Cuesta casi nada y se ve igual en el celular que en el PC.
		var halo := MeshInstance3D.new()
		halo.mesh = _halo_mesh()
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.position = pos
		holder.add_child(halo)


static var _halo: QuadMesh


## Cuadro con degradado radial aditivo para el halo de los faroles.
static func _halo_mesh() -> QuadMesh:
	if _halo != null:
		return _halo
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.6, 0.55))
	grad.set_color(1, Color(1.0, 0.7, 0.4, 0.0))
	grad.add_point(0.25, Color(1.0, 0.78, 0.5, 0.22))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = tex
	m.albedo_color = LAMP_COLOR
	m.no_depth_test = false
	m.disable_fog = true
	_halo = QuadMesh.new()
	_halo.size = Vector2(1.6, 1.6)
	_halo.material = m
	return _halo
