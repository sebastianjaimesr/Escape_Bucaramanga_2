extends Node
## Capturas de la versión 0.6 (Cabecera y «La gran huida»): portada, créditos,
## estadísticas y escenas del capítulo 5 (parque, avenida, terrazas, dron,
## tirolesa, puente al amanecer, cinemática y título de zona).
##
##   godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/v06_screenshots.tscn -- <carpeta> [perfil]
##
## Necesita una ventana. Usa un perfil y una configuración aparte.

var out := "user://capturas_v06"
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
	for id: String in ["malentendido", "robo_plaza", "callejon", "persecucion"]:
		PlayerProfile.complete_chapter(id, {"time": 540.0, "rank": Chapters.RANKS[1], "hints": 1, "caught": 1, "chased": true})
	PlayerProfile.add_stats({"play_time": 3900.0, "jumps": 212, "vaults": 31, "slides": 18, "rolls": 6, "cans": 14,
			"caught": 5, "ziplines": 1, "drone_alarms": 2, "distance": 4800.0})
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await wait(90)
	await shot("v01_portada")
	menu._show_page("chapters", false)
	await wait(10)
	await shot("v02_capitulos")
	menu._show_page("credits", false)
	await wait(10)
	await shot("v03_creditos")
	menu._open_profile("stats")
	await wait(10)
	await shot("v04_estadisticas")
	menu.queue_free()
	await wait(2)
	var world := await _world()
	var m := world.mission as GranHuidaMission
	# Parque de las Palmas, con el título de la zona.
	world.hud.show_zone("Parque de las Palmas", "Cabecera del Llano")
	_look(world, Vector3(-36.0, 0.15, 22.0), Vector3(-36.0, 1.5, 0.0))
	world.camera_rig.pitch = -0.12
	await wait(50)
	await shot("v05_parque_fuente")
	world.hud._zone_card.visible = false
	# Lucía en la fuente.
	_look(world, m.lucia.global_position + Vector3(-2.5, 0, 3.5), m.lucia.global_position)
	await wait(30)
	await shot("v06_lucia")
	# La Carrera 33 con las torres al fondo.
	_look(world, Vector3(-3.0, 0.0, 30.0), Vector3(20.0, 6.0, -20.0))
	world.camera_rig.pitch = -0.05
	await wait(40)
	await shot("v07_avenida_torres")
	# Terrazas: a punto de saltar de la 3 a la 4.
	m._complete("periodista")
	m._complete("terrazas")
	_look(world, Vector3(19.0, CabeceraBuilder.roof_top(2), -4.6), Vector3(19.0, CabeceraBuilder.roof_top(3), -16.0))
	world.camera_rig.pitch = -0.22
	await wait(40)
	await shot("v08_terrazas_salto")
	# El dron alumbrando la terraza.
	var d: SurveillanceDrone = m.drones[0]
	d.active = true
	d.global_position = Vector3(17.0, CabeceraBuilder.roof_top(3) + SurveillanceDrone.ALTITUDE, -14.0)
	_look(world, Vector3(21.0, CabeceraBuilder.roof_top(3), -10.0), Vector3(17.0, CabeceraBuilder.roof_top(3) + 3.0, -16.0))
	world.camera_rig.pitch = 0.05
	await wait(40)
	await shot("v09_dron")
	d.active = false
	# Oficina y caja fuerte.
	_look(world, (world.points["office_door"] as Vector3) + Vector3(-2.0, 0, 1.5), world.points["office"])
	await wait(30)
	await shot("v10_oficina")
	# Tirolesa a mitad de camino, con el cielo aclarando.
	m._complete("oficina")
	m.try_code("1622")
	await wait(10)
	m.wanted.clear()
	for o in m.officers:
		o.active = false
	for dr in m.drones:
		dr.active = false
	world.player.teleport(m.zipline.start, -PI * 0.5)
	world.camera_rig.yaw = -PI * 0.5 + 0.5
	world.camera_rig.pitch = -0.15
	m.zipline.ride(world.player)
	# A mitad del cable (la ventana virtual puede ir a pocos cuadros por segundo).
	var mid_x := (m.zipline.start.x + m.zipline.end.x) * 0.5
	for i in 600:
		if world.player.global_position.x < mid_x:
			break
		await wait(1)
	await shot("v11_tirolesa")
	await wait(240)
	m.dawn_left = GranHuidaMission.DAWN_SECONDS * 0.35
	# El puente al amanecer.
	_look(world, (world.points["bridge_start"] as Vector3) + Vector3(0, 0, -6.0), world.points["finish"])
	world.camera_rig.pitch = -0.08
	await wait(40)
	await shot("v12_puente_amanecer")
	# Una cinemática (franjas y texto).
	GameSession.cinematics_enabled = true
	m._play_finale()
	await wait(80)
	await shot("v13_cinematica")
	m.cinematic.skip()
	GameSession.cinematics_enabled = false
	await wait(60)
	await shot("v14_victoria")
	get_tree().paused = false
	get_tree().quit()


func _world() -> PrototypeWorld:
	GameSession.chapter = "gran_huida"
	var world: PrototypeWorld = (load("res://scenes/world/prototype/prototype_world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(5)
	world.mission._grace = 1.0e9
	for o in world.mission.officers:
		o.active = false
	for d in (world.mission as GranHuidaMission).drones:
		d.active = false
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
