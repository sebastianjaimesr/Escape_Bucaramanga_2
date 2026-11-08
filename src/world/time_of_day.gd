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
		"sky_top": Color(0.3, 0.52, 0.85), "sky_horizon": Color(0.82, 0.86, 0.9),
		"ground_horizon": Color(0.7, 0.68, 0.64), "sun_color": Color(1.0, 0.96, 0.88),
		"sun_energy": 1.35, "sun_rot": Vector3(-42.0, 120.0, 0.0), "ambient": 0.85,
		"fog": Color(0.8, 0.84, 0.88), "fog_density": 1.0, "exposure": 1.05, "lamps": false,
	},
	"tarde": {
		"sky_top": Color(0.24, 0.42, 0.74), "sky_horizon": Color(0.92, 0.76, 0.6),
		"ground_horizon": Color(0.72, 0.62, 0.54), "sun_color": Color(1.0, 0.84, 0.66),
		"sun_energy": 1.45, "sun_rot": Vector3(-30.0, -58.0, 0.0), "ambient": 0.75,
		"fog": Color(0.86, 0.76, 0.66), "fog_density": 1.0, "exposure": 1.08, "lamps": false,
	},
	"noche": {
		"sky_top": Color(0.02, 0.03, 0.08), "sky_horizon": Color(0.12, 0.12, 0.2),
		"ground_horizon": Color(0.06, 0.06, 0.08), "sun_color": Color(0.55, 0.65, 1.0),
		"sun_energy": 0.22, "sun_rot": Vector3(-55.0, 30.0, 0.0), "ambient": 0.32,
		"fog": Color(0.1, 0.11, 0.16), "fog_density": 1.0, "exposure": 1.25, "lamps": true,
	},
}
const LAMP_COLOR := Color(1.0, 0.78, 0.5)
const LAMP_ENERGY := 2.2
const LAMP_RANGE := 11.0


static func apply(world: PrototypeWorld, preset: String, rain: bool) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["tarde"])
	var env := world.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = p["sky_top"]
	sky_mat.sky_horizon_color = p["sky_horizon"]
	sky_mat.ground_horizon_color = p["ground_horizon"]
	if rain:
		sky_mat.sky_top_color = (p["sky_top"] as Color).lerp(Color(0.2, 0.22, 0.25), 0.5)
		sky_mat.sky_horizon_color = (p["sky_horizon"] as Color).lerp(Color(0.25, 0.27, 0.3), 0.5)
	env.ambient_light_energy = p["ambient"]
	env.fog_light_color = p["fog"]
	env.fog_density = float(p["fog_density"]) * (1.6 if rain else 1.0)
	env.tonemap_exposure = p["exposure"]
	world.sun.light_color = p["sun_color"]
	world.sun.light_energy = float(p["sun_energy"]) * (0.7 if rain else 1.0)
	world.sun.rotation_degrees = p["sun_rot"]
	if p["lamps"]:
		_light_lamps(world)
	if rain:
		var r := RainFx.new()
		r.name = "Lluvia"
		world.add_child(r)


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
