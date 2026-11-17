extends Node
## Capturas de la versión 2.0 (El Centro y «La Cigarra»): los cuatro lugares
## del Centro, Lucía, una misión secundaria, el registro de misiones y una
## cigarra pintada.
##
##   godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/v20_screenshots.tscn -- <carpeta> [perfil]
##
## Necesita una ventana. Usa un perfil y una configuración aparte.

var out := "user://capturas_v20"
var profile := "bajo"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		profile = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.config_path = "user://ui_screenshot_settings.cfg"
	Settings.load_settings()
	Settings.set_value("graphics", "profile", profile, false)
	Settings.set_value("interface", "touch_controls", "off", false)
	GameSession.save_enabled = false
	GameSession.cinematics_enabled = false
	SaveGame.path = "user://ui_screenshot_partida.cfg"
	PlayerProfile.path = "user://ui_screenshot_perfil.cfg"
	PlayerProfile.reset()
	for c: Dictionary in Chapters.LIST:
		if c["id"] != "cigarra":
			PlayerProfile.chapters[c["id"]] = {"done": true}
	GameSession.chapter = "cigarra"
	var world: PrototypeWorld = (load("res://scenes/world/prototype/prototype_world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(5)
	var m := world.mission as CentroMission
	m._grace = 1.0e9
	for o in m.officers:
		o.active = false
	world.hud._hint_timer = 0.0
	world.hud._hint.modulate.a = 0.0
	var p := world.points
	var sant: Vector3 = p["santander_statue"]
	world.hud.show_zone("Parque Santander", "El corazón del Centro")
	_look(world, sant + Vector3(6.0, 0, 16.0), sant + Vector3(0, 3.0, -14.0))
	world.camera_rig.pitch = -0.05
	await wait(60)
	await shot("c01_santander_catedral")
	world.hud._zone_card.visible = false
	_look(world, m.lucia.global_position + Vector3(-2.0, 0, 3.6), m.lucia.global_position)
	await wait(30)
	await shot("c02_lucia")
	var rov: Vector3 = p["rovira_statue"]
	_look(world, rov + Vector3(14.0, 0, 12.0), rov + Vector3(-20.0, 3.0, 0.0))
	world.camera_rig.pitch = -0.08
	await wait(40)
	await shot("c03_garcia_rovira_capilla")
	_look(world, Vector3(-3.0, 0.15, 30.0), Vector3(0.0, 3.0, -30.0))
	world.camera_rig.pitch = -0.04
	await wait(40)
	await shot("c04_carrera27")
	_look(world, Vector3(24.0, 0.15, 16.0), Vector3(50.0, 1.5, 34.0))
	world.camera_rig.pitch = -0.1
	await wait(40)
	await shot("c05_cigarras")
	var anibal: Civilian = m.givers["obleas"]
	_look(world, anibal.global_position + Vector3(-3.5, 0, 2.0), anibal.global_position)
	await wait(30)
	await shot("c06_don_anibal_mision")
	anibal.interactable.interact(world.player)
	await wait(10)
	world.escape_ui.open_panel("journal")
	await wait(20)
	await shot("c07_registro_misiones")
	world.escape_ui.journal.close()
	await wait(5)
	var s: SecretSpot = m.secrets[2]
	_look(world, s.global_position - s.global_basis.z * 4.0, s.global_position + Vector3(0, 1.2, 0))
	await wait(30)
	await shot("c08_cigarra_pintada")
	m.lucia.interactable.interact(world.player)
	await wait(5)
	_look(world, (p["paradero"] as Vector3) + Vector3(-5.0, 0, 5.0), p["paradero_roof"])
	world.camera_rig.pitch = -0.02
	await wait(30)
	await shot("c09_paradero_senal")
	get_tree().quit()


func _look(world: PrototypeWorld, pos: Vector3, at: Vector3) -> void:
	var to := at - pos
	var yaw := atan2(-to.x, -to.z)
	world.player.teleport(pos, yaw)
	world.camera_rig.yaw = yaw
	world.camera_rig.pitch = -0.2
	world.camera_rig.snap()


func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out.path_join(file + ".png")
	img.save_png(path)
	print("Captura: ", ProjectSettings.globalize_path(path))
