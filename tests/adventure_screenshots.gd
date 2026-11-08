extends Node
## Capturas de la aventura (v0.5): portada con la campaña, selección de
## capítulo, perfil y tienda, y una escena de cada capítulo nuevo (mañana,
## noche en la bodega y lluvia), más la pantalla de recompensas.
##
##   godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/adventure_screenshots.tscn -- <carpeta>
##
## Necesita una ventana. Usa un perfil y una configuración aparte.

var out := "user://capturas_aventura"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.config_path = "user://ui_screenshot_settings.cfg"
	Settings.load_settings()
	Settings.set_value("graphics", "profile", "bajo", false)
	Settings.set_value("interface", "touch_controls", "off", false)
	GameSession.save_enabled = false
	SaveGame.path = "user://ui_screenshot_partida.cfg"
	PlayerProfile.path = "user://ui_screenshot_perfil.cfg"
	PlayerProfile.reset()
	# Un perfil de ejemplo: capítulo 1 superado, algo de plata y una postal.
	PlayerProfile.complete_chapter("malentendido", {"time": 612.0, "rank": Chapters.RANKS[1], "hints": 1, "caught": 1, "chased": true})
	PlayerProfile.find_collectible("parques")
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await wait(90)
	await shot("a01_portada_campana")
	menu._show_page("chapters", false)
	await wait(10)
	await shot("a02_capitulos")
	menu._open_profile("shop")
	await wait(10)
	await shot("a03_tienda")
	menu._open_profile("skills")
	await wait(10)
	await shot("a04_habilidades")
	menu.queue_free()
	await wait(2)
	# Capítulo 2, de mañana: siguiendo al ladrón.
	var world := await _world("robo_plaza")
	var m := world.mission as RoboPlazaMission
	m.rosa.interactable.interact(world.player)
	for e in m.evidence:
		e.interactable.interact(world.player)
	m.thief.interactable.interact(world.player)
	await wait(200)
	_look(world, m.thief.global_position + Vector3(-3.0, 0, 12.0), m.thief.global_position)
	world.camera_rig.pitch = -0.32
	world.camera_rig.snap()
	world.player.state_machine.change_state(&"Crouch")
	await wait(20)
	await shot("a05_cap2_seguimiento")
	world.queue_free()
	await wait(2)
	# Capítulo 3, de noche en la bodega.
	world = await _world("callejon")
	_look(world, Vector3(36.0, 0.15, -31.0), Vector3(39.0, 0.15, -38.0))
	await wait(60)
	await shot("a06_cap3_bodega")
	world.queue_free()
	await wait(2)
	# Capítulo 4, persecución bajo la lluvia.
	world = await _world("persecucion")
	world.mission.wanted.set_level(3)
	_look(world, Vector3(-8.0, 0.15, 14.0), Vector3(-20.0, 0.15, 22.0))
	await wait(60)
	await shot("a07_cap4_lluvia")
	world.mission._win()
	await wait(60)
	await shot("a08_recompensas")
	get_tree().paused = false
	get_tree().quit()


func _world(chapter: String) -> PrototypeWorld:
	GameSession.chapter = chapter
	var world: PrototypeWorld = (load("res://scenes/world/prototype/prototype_world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(5)
	world.mission._grace = 1.0e9
	for o in world.mission.officers:
		o.active = false
	world.hud._hint_timer = 0.0
	world.hud._hint.modulate.a = 0.0
	return world


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
