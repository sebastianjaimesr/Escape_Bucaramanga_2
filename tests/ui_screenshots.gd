extends Node
## Capturas de la interfaz del escape room (portada, HUD, paneles y finales).
##
##   godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/ui_screenshots.tscn -- <carpeta> [touch]
##
## Necesita una ventana (no funciona con --headless). Con "touch" muestra los
## controles táctiles. No toca la partida ni la configuración del jugador.

var out := "user://capturas_ui"
var touch := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	touch = args.size() > 1 and args[1] == "touch"
	DirAccess.make_dir_recursive_absolute(out)
	Settings.config_path = "user://ui_screenshot_settings.cfg"
	Settings.load_settings()
	Settings.set_value("graphics", "profile", "bajo", false)
	Settings.set_value("interface", "touch_controls", "on" if touch else "off", false)
	GameSession.save_enabled = false
	SaveGame.path = "user://ui_screenshot_partida.cfg"
	var suffix := "_touch" if touch else ""
	# Portada
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await wait(90)
	await shot("01_portada" + suffix)
	menu._show_page("modes", false)
	await wait(10)
	await shot("02_modos" + suffix)
	menu._show_page("howto", false)
	await wait(10)
	await shot("03_como_se_juega" + suffix)
	menu._show_page("settings", false)
	await wait(10)
	await shot("04_configuracion" + suffix)
	menu.queue_free()
	await wait(2)
	# Juego
	GameSession.mode = "contrarreloj"
	var world: PrototypeWorld = (load("res://scenes/world/prototype/prototype_world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(5)
	world.mission._grace = 1.0e9
	for o in world.mission.officers:
		o.active = false
	var m := world.mission
	world.player.teleport(Vector3(-20.0, 0.15, 24.0), PI * 0.9)
	world.camera_rig.yaw = PI * 0.9
	world.camera_rig.pitch = -0.18
	world.camera_rig.snap()
	world.hud._hint_timer = 0.0
	for e in m.evidence:
		if e.id == "foto":
			e.interactable.interact(world.player)
	m.elapsed = 4 * 60 + 18
	await wait(12)
	await shot("05_hud_descubrimiento" + suffix)
	await wait(200)
	world.escape_ui.open_panel("inventory")
	await wait(20)
	await shot("06_inventario" + suffix)
	world.escape_ui.inventory.close()
	world.escape_ui.open_panel("hints")
	world.escape_ui.hints._on_reveal()
	world.escape_ui.hints._on_reveal()
	await wait(20)
	await shot("07_pistas" + suffix)
	world.escape_ui.hints.close()
	world.escape_ui.open_panel("code")
	for k: String in ["1", "2", "3", "4", "Buscar"]:
		world.escape_ui.code_lock._press(k)
	await wait(4)
	await shot("08_caja_codigo_error" + suffix)
	world.escape_ui.code_lock.close()
	for e in m.evidence:
		if e.id == "celular":
			e.interactable.interact(world.player)
	await wait(5)
	var pad := world.escape_ui.pattern_lock.pad
	for n: int in [1, 2, 3, 5]:
		pad.add_point(n)
	await wait(10)
	await shot("09_patron_celular" + suffix)
	world.escape_ui.pattern_lock.close()
	for e in m.evidence:
		if e.id == "recibo":
			e.interactable.interact(world.player)
	m.try_code("1742")
	m.try_pattern(EscapeStory.PHONE_PATTERN)
	for e in m.evidence:
		if e.id == "gorra":
			e.interactable.interact(world.player)
	await wait(5)
	world.escape_ui.open_panel("deduction")
	var d := world.escape_ui.deduction
	(d._groups[0][1] as Button).button_pressed = true
	(d._groups[1][0] as Button).button_pressed = true
	(d._groups[2][2] as Button).button_pressed = true
	d._on_submit()
	await wait(20)
	await shot("10_reconstruccion" + suffix)
	world.pause_menu.open()
	world.escape_ui.deduction.close()
	world.pause_menu.open()
	await wait(10)
	await shot("11_pausa" + suffix)
	world.pause_menu.close()
	await wait(5)
	world.escape_ui.open_panel("deduction")
	(d._groups[1][1] as Button).button_pressed = true
	d._on_submit()
	await wait(60)
	await shot("12_victoria" + suffix)
	get_tree().paused = false
	get_tree().quit()


func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out.path_join(name + ".png")
	img.save_png(path)
	print("Captura: ", ProjectSettings.globalize_path(path))
