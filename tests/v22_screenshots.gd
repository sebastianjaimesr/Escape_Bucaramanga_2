extends Node
## Capturas de la versión 2.2 (vida de barrio): Valentina y sus hojas, el
## aguacero con las canastas de Don Pacho y el pan de madrugada en Cabecera.
##
##   godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/v22_screenshots.tscn -- <carpeta> [perfil]
##
## Necesita una ventana. Usa un perfil y una configuración aparte.

var out := "user://capturas_v22"
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
	GameSession.chapter = "robo_plaza"
	var world: PrototypeWorld = (load("res://scenes/world/prototype/prototype_world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(5)
	var m := world.mission as RoboPlazaMission
	m._grace = 1.0e9
	for o in m.officers:
		o.active = false
	world.hud._hint_timer = 0.0
	world.hud._hint.modulate.a = 0.0
	var vale: Civilian = m.givers["hojas"]
	_look(world, vale.global_position + Vector3(4.0, 0, 1.0), vale.global_position + Vector3(0, 0.6, 0))
	await wait(40)
	await shot("v01_valentina")
	vale.interactable.interact(world.player)
	await wait(5)
	var page: QuestPickup = m.pages[0]
	_look(world, page.global_position + Vector3(-2.5, 0, 3.0), page.global_position)
	world.camera_rig.pitch = -0.3
	await wait(30)
	await shot("v02_hoja_plataforma")
	m.rosa.interactable.interact(world.player)
	m.start_aguacero()
	await wait(10)
	m.baskets[1].interactable.interact(world.player)
	_look(world, m.FRUIT_STAND + Vector3(5.0, 0, 3.5), m.FRUIT_STAND + Vector3(0, 0.8, 0))
	world.camera_rig.pitch = -0.12
	await wait(120)
	await shot("v03_aguacero")
	var b: QuestPickup = m.baskets[1]
	_look(world, b.global_position + Vector3(1.8, 0, 2.0), b.global_position)
	world.camera_rig.pitch = -0.35
	await wait(20)
	await shot("v03b_canasta_tapada")
	world.escape_ui.open_panel("journal")
	await wait(20)
	await shot("v04_registro_capitulo2")
	world.escape_ui.journal.close()
	await wait(5)
	world.queue_free()
	await wait(5)
	GameSession.chapter = "gran_huida"
	world = (load("res://scenes/world/prototype/prototype_world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(5)
	var g := world.mission as GranHuidaMission
	g._grace = 1.0e9
	for o in g.officers:
		o.active = false
	world.hud._hint_timer = 0.0
	world.hud._hint.modulate.a = 0.0
	var baker: Civilian = g.givers["pan"]
	_look(world, baker.global_position + Vector3(3.0, 0, -2.5), baker.global_position + Vector3(0, 0.6, 0))
	await wait(60)
	await shot("v05_pan_de_madrugada")
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
