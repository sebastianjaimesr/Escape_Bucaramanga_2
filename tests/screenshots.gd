extends Node
## Capturas de pantalla del prototipo para revisar el aspecto visual.
##
##   godot --path . --rendering-method gl_compatibility res://tests/screenshots.tscn -- <carpeta_salida> [perfil] [vistas]
##
## [vistas]: prefijos separados por comas para capturar solo algunas (ej. "07,10").
##
## Necesita una ventana (no funciona con --headless). Sin carpeta, guarda en user://capturas.

const VIEWS := [
	# [nombre, posición del jugador, yaw de la cámara, pitch de la cámara]
	["01_cruce", Vector3(-8.0, 0.15, 9.0), -PI * 0.25, -0.12],
	["02_calle", Vector3(-1.5, 0.0, 30.0), 0.0, -0.08],
	["03_plaza_pruebas", Vector3(-12.0, 0.15, 12.0), PI * 0.8, -0.3],
	["04_escaleras", Vector3(-24.0, 0.15, 13.0), PI * 0.95, -0.2],
	["05_tunel", Vector3(-20.0, 0.15, 37.0), PI * 0.5, -0.15],
	["06_fachadas", Vector3(20.0, 0.15, 5.5), PI * 0.1, 0.15],
	["07_patrulla", Vector3(25.0, 0.0, 1.0), 1.75, -0.08],
	["08_amigos", Vector3(-39.0, 0.15, 33.5), 0.75, -0.15],
	["09_granizados", Vector3(-12.5, 0.15, 10.0), 1.1, -0.12],
	["10_hud_persecucion", Vector3(-1.5, 0.15, 24.0), 0.0, -0.1],
	["11_prueba_escaleras", Vector3(-24.0, 0.15, 13.0), PI * 0.95, -0.25],
]

## Dónde poner a los policías en cada vista (los demás quedan en su ruta, quietos).
const OFFICERS := {
	"07_patrulla": [Vector3(19.0, 0.0, 1.2), -PI * 0.5],
	"10_hud_persecucion": [Vector3(1.0, 0.0, 17.0), PI],
}


func _ready() -> void:
	var out := "user://capturas"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var profile := "medio"
	if args.size() > 1:
		profile = args[1]
	Settings.config_path = "user://screenshot_settings.cfg"
	Settings.load_settings()
	Settings.set_value("graphics", "profile", profile, false)
	var world: PrototypeWorld = (load("res://scenes/world/prototype/prototype_world.tscn") as PackedScene).instantiate()
	add_child(world)
	world.hud.visible = false
	await get_tree().process_frame
	world.mission._grace = 1.0e9   # La policía no se activa durante las capturas.
	for o in world.mission.officers:
		o.active = false
	var only: PackedStringArray = args[2].split(",") if args.size() > 2 else PackedStringArray()
	for v: Array in VIEWS:
		if not only.is_empty() and not Array(only).any(func(p: String) -> bool: return String(v[0]).begins_with(p)):
			continue
		world.hud.visible = v[0].begins_with("10_")
		var officer: PoliceOfficer = world.mission.officers[0]
		if OFFICERS.has(v[0]):
			officer.place(OFFICERS[v[0]][0], OFFICERS[v[0]][1])
			officer.state = PoliceOfficer.State.CHASE if v[0].begins_with("10_") else PoliceOfficer.State.PATROL
			officer._update_indicator()
		world.player.teleport(v[1], v[2])
		world.camera_rig.yaw = v[2]
		world.camera_rig.pitch = v[3]
		world.camera_rig.snap()
		for i in 40:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := out.path_join("%s_%s.png" % [v[0], profile])
		img.save_png(path)
		print("Captura: ", ProjectSettings.globalize_path(path))
	get_tree().quit()
