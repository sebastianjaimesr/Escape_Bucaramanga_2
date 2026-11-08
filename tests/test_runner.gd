extends Node
## Pruebas de integración del prototipo 3D, ejecutadas dentro del motor.
##
##   godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
##
## Cada prueba crea una manzana de prueba nueva, simula la entrada del jugador
## con Input.action_press y avanza cuadros de física reales. Al final imprime
## el resumen y sale con código 0 (todo bien) o 1 (algún fallo).
## Con la variable TEST_ONLY=prueba1,prueba2 corre solo esas.
## Usa un archivo de configuración aparte para no tocar el del jugador.

const WORLD_SCENE := "res://scenes/world/prototype/prototype_world.tscn"
const TEST_SETTINGS := "user://test_settings.cfg"
const TEST_SAVE := "user://test_partida.cfg"
const TEST_PROFILE := "user://test_perfil.cfg"

var _passed := 0
var _failed: Array[String] = []
var _current := ""
var _current_ok := true
var world: PrototypeWorld
var player: PlayerController


func _ready() -> void:
	Settings.config_path = TEST_SETTINGS
	SaveGame.path = TEST_SAVE
	PlayerProfile.path = TEST_PROFILE
	PlayerProfile.reset()
	GameSession.save_enabled = false
	_remove_test_settings()
	Settings.load_settings()
	InputConfig.apply_all()
	await get_tree().process_frame
	for test: String in [
		"test_project_configuration",
		"test_input_actions_exist",
		"test_rebind_and_persist",
		"test_rebind_swaps_conflicting_key",
		"test_settings_roundtrip_and_corrupt_file",
		"test_world_builds",
		"test_player_lands_on_ground",
		"test_walk_relative_to_camera",
		"test_run_is_faster_and_uses_stamina",
		"test_stamina_exhaustion_forces_walk",
		"test_jump_height",
		"test_short_jump_is_lower",
		"test_wall_blocks_player",
		"test_step_up_curb",
		"test_climb_stairs",
		"test_walk_up_ramp",
		"test_steep_slope_not_climbable",
		"test_box_heights",
		"test_crouch_tunnel",
		"test_camera_does_not_clip_wall",
		"test_camera_rotation_moves_player_direction",
		"test_quality_profiles_apply",
		"test_scene_loader_missing_scene",
		"test_fall_reset",
		# Policía, interacción y misión
		"test_navmesh_and_paths",
		"test_police_patrols",
		"test_police_sees_player_in_open",
		"test_police_blind_through_buildings",
		"test_police_does_not_see_behind",
		"test_crouching_reduces_view",
		"test_police_catches_player",
		"test_hidden_player_is_lost",
		"test_radio_calls_nearby_officer",
		"test_hiding_requires_crouch",
		"test_evidence_pickup",
		"test_vendor_granizado",
		"test_friends_complete_mission",
		"test_civilians_walk",
		"test_traffic_lights_cycle",
		# Escape room
		"test_story_data_is_consistent",
		"test_inventory_and_hint_units",
		"test_hints_follow_current_step",
		"test_lock_box_code",
		"test_phone_pattern_reveals_cap",
		"test_diaz_tells_the_pattern",
		"test_deduction_wrong_then_right",
		"test_inventory_and_hint_panels_toggle",
		"test_save_and_continue",
		"test_corrupt_save_is_ignored",
		"test_time_limit_ends_game",
		"test_restart_from_pause",
		"test_touch_controls_drive_actions",
		"test_ui_scales_with_orientation",
		"test_audio_buses_and_volume",
		# Aventura: progresión, sistemas nuevos y capítulos 2 a 4
		"test_profile_levels_skills_and_shop",
		"test_profile_save_and_corrupt_file",
		"test_chapter_rewards_and_unlocks",
		"test_wanted_levels_decay_and_disguise",
		"test_wanted_reinforcements",
		"test_can_distracts_officer",
		"test_vault_onto_high_box",
		"test_slide_from_run",
		"test_collectible_pickup",
		"test_chapter2_investigation_and_thief",
		"test_chapter2_follow_fails_when_far",
		"test_chapter2_lives_run_out",
		"test_chapter3_bodega",
		"test_security_camera_raises_alarm",
		"test_chapter4_chase_and_disguise",
		"test_continue_saved_chapter",
		"test_chapter_select_and_profile_pages",
		"test_victory_screen_rewards",
	]:
		# TEST_ONLY=prueba1,prueba2 corre solo esas (para depurar).
		var only := OS.get_environment("TEST_ONLY")
		if only != "" and not test in only.split(","):
			continue
		await _run(test)
	_remove_test_settings()
	print("")
	if _failed.is_empty():
		print("==== RESULTADO: %d pruebas OK, 0 fallos ====" % _passed)
	else:
		print("==== RESULTADO: %d OK, %d FALLOS: %s ====" % [_passed, _failed.size(), ", ".join(_failed)])
	get_tree().quit(0 if _failed.is_empty() else 1)


func _run(test: String) -> void:
	_current = test
	_current_ok = true
	await call(test)
	_release_all()
	GameSession.save_enabled = false
	GameSession.continue_saved = false
	GameSession.mode = "explorador"
	GameSession.chapter = Chapters.FIRST
	SaveGame.erase()
	PlayerProfile.reset()
	for suffix: String in ["", ".tmp", ".bad"]:
		if FileAccess.file_exists(TEST_PROFILE + suffix):
			DirAccess.remove_absolute(TEST_PROFILE + suffix)
	if world != null:
		world.queue_free()
		world = null
		player = null
		await get_tree().process_frame
	get_tree().paused = false
	if _current_ok:
		_passed += 1
		print("[OK]    ", test)
	else:
		_failed.append(test)
		print("[FALLO] ", test)


# ---------------------------------------------------------------------------
# Ayudas
# ---------------------------------------------------------------------------
func check(cond: bool, message: String) -> void:
	if not cond:
		_current_ok = false
		print("        ✗ ", message)


func _remove_test_settings() -> void:
	for suffix: String in ["", ".tmp", ".bad"]:
		if FileAccess.file_exists(TEST_SETTINGS + suffix):
			DirAccess.remove_absolute(TEST_SETTINGS + suffix)


## Las pruebas de movimiento apagan la policía para que no las interrumpa.
func spawn_world(police: bool = false) -> void:
	world = (load(WORLD_SCENE) as PackedScene).instantiate()
	world.police_enabled = police
	add_child(world)
	player = world.player
	await frames(30)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await frames(int(ceil(s * Engine.physics_ticks_per_second)))


func hold(actions: Array, s: float) -> void:
	for a: String in actions:
		Input.action_press(a)
	await seconds(s)
	for a: String in actions:
		Input.action_release(a)


func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)


func _release_all() -> void:
	for a: String in InputConfig.ACTIONS:
		Input.action_release(a)


## Coloca al jugador mirando en la dirección yaw (la cámara también).
func place(pos: Vector3, yaw: float) -> void:
	player.teleport(pos + Vector3.UP * 0.05, yaw)
	world.camera_rig.yaw = yaw
	world.camera_rig.snap()
	await frames(20)


func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ---------------------------------------------------------------------------
# Configuración y controles
# ---------------------------------------------------------------------------
func test_project_configuration() -> void:
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus", "PC debe usar Forward+")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method.web") == "gl_compatibility", "Web debe usar Compatibilidad")
	check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "Física 3D debe ser Jolt")
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "La interfaz se escala con la pantalla")
	for autoload: String in ["EventBus", "Settings", "InputConfig", "GameSession", "AudioManager", "SceneLoader"]:
		check(get_tree().root.has_node(autoload), "Falta el autoload %s" % autoload)
	check(ResourceLoader.exists(MainMenu.PROTOTYPE_SCENE), "Existe la escena del prototipo")


func test_input_actions_exist() -> void:
	var expected := {
		"move_forward": KEY_W, "move_left": KEY_A, "move_back": KEY_S, "move_right": KEY_D,
		"run": KEY_SHIFT, "jump": KEY_SPACE, "crouch": KEY_C, "interact": KEY_E,
		"vehicle": KEY_F, "inventory": KEY_TAB, "map": KEY_M, "pause": KEY_ESCAPE,
	}
	for action: String in expected:
		check(InputMap.has_action(action), "Existe la acción %s" % action)
		var found := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == expected[action]:
				found = true
		check(found, "%s usa la tecla del encargo" % action)


func test_rebind_and_persist() -> void:
	InputConfig.rebind("jump", KEY_K)
	check(InputConfig.primary_key("jump") == KEY_K, "Salto reasignado a K")
	var has_k := false
	for ev in InputMap.action_get_events("jump"):
		has_k = has_k or (ev is InputEventKey and ev.physical_keycode == KEY_K)
	check(has_k, "InputMap actualizado con K")
	Settings.load_settings()   # Simula reiniciar el juego.
	InputConfig.apply_all()
	check(InputConfig.primary_key("jump") == KEY_K, "La reasignación sobrevive a reiniciar")
	InputConfig.reset_defaults()
	check(InputConfig.primary_key("jump") == KEY_SPACE, "Restaurar vuelve a Espacio")


func test_rebind_swaps_conflicting_key() -> void:
	InputConfig.rebind("jump", KEY_C)  # C era agacharse.
	check(InputConfig.primary_key("jump") == KEY_C, "Salto en C")
	check(InputConfig.primary_key("crouch") == KEY_SPACE, "Agacharse recibe la tecla anterior del salto")
	InputConfig.rebind("crouch", KEY_ESCAPE)
	check(InputConfig.primary_key("crouch") == KEY_SPACE, "Esc está reservada para la pausa")
	InputConfig.reset_defaults()


func test_settings_roundtrip_and_corrupt_file() -> void:
	Settings.set_value("camera", "mouse_sensitivity", 0.4)
	Settings.set_value("graphics", "profile", "alto")
	Settings.load_settings()
	check(is_equal_approx(float(Settings.get_value("camera", "mouse_sensitivity")), 0.4), "Sensibilidad guardada")
	check(Settings.quality_profile() == "alto", "Perfil guardado")
	var f := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	f.store_string("[camera\nesto no es un archivo válido = = =")
	f.close()
	var ok := Settings.load_settings()
	check(not ok, "Detecta el archivo dañado")
	check(Settings.last_error != "", "Informa el error")
	check(is_equal_approx(float(Settings.get_value("camera", "mouse_sensitivity")), 0.25), "Vuelve a los valores por defecto")
	check(FileAccess.file_exists(TEST_SETTINGS + ".bad"), "Conserva el archivo dañado como .bad")
	Settings.reset_to_defaults()


# ---------------------------------------------------------------------------
# Mundo y movimiento
# ---------------------------------------------------------------------------
func test_world_builds() -> void:
	var t0 := Time.get_ticks_msec()
	await spawn_world()
	print("        (mundo construido y 30 cuadros en %d ms)" % (Time.get_ticks_msec() - t0))
	check(world.points.has("spawn"), "Hay punto de aparición")
	check(int(world.points.get("window_count", 0)) > 100, "Ventanas con MultiMesh (%s)" % world.points.get("window_count"))
	check(world.sun.shadow_enabled, "El sol proyecta sombras")
	check(world.get_viewport().get_camera_3d() == world.camera_rig.camera, "La cámara del jugador está activa")


func test_player_lands_on_ground() -> void:
	await spawn_world()
	await seconds(1.0)
	check(player.is_on_floor(), "Está en el suelo")
	check(absf(player.global_position.y - PrototypeBlockBuilder.CURB_HEIGHT) < 0.05,
			"A la altura de la acera (y=%.3f)" % player.global_position.y)
	check(player.state_machine.current_name == &"Idle", "Estado Idle (%s)" % player.state_machine.current_name)


func test_walk_relative_to_camera() -> void:
	await spawn_world()
	await place(Vector3(-40, 0.15, 12), 0.0)
	var start := player.global_position
	await hold(["move_forward"], 1.0)
	var moved := flat(player.global_position - start)
	check(moved.z < -2.0, "Avanza hacia el norte (-Z) con la cámara mirando al norte (dz=%.2f)" % moved.z)
	check(absf(moved.x) < 0.1, "No se desvía (dx=%.2f)" % moved.x)
	check(moved.length() < PlayerController.WALK_SPEED * 1.05, "Velocidad de caminar (%.2f m/s)" % moved.length())


func test_run_is_faster_and_uses_stamina() -> void:
	await spawn_world()
	await place(Vector3(-40, 0.15, 12), PI)  # Mirando al sur (+Z).
	var start := player.global_position
	Input.action_press("run")
	await hold(["move_forward"], 1.0)
	Input.action_release("run")
	var d := flat(player.global_position - start).length()
	check(d > PlayerController.WALK_SPEED * 1.5, "Corre más rápido que caminando (%.2f m en 1 s)" % d)
	check(player.stamina < PlayerController.MAX_STAMINA - 10.0, "Gasta resistencia (%.1f)" % player.stamina)
	var after := player.stamina
	await seconds(2.0)
	check(player.stamina > after, "La resistencia se recupera al parar")


func test_stamina_exhaustion_forces_walk() -> void:
	await spawn_world()
	await place(Vector3(-46, 0.15, 12), PI * 0.5)  # Cámara al oeste; se corre hacia el este.
	player.stamina = 5.0
	Input.action_press("run")
	Input.action_press("move_back")  # Hacia el este: hay espacio libre.
	await seconds(1.0)
	check(player.exhausted, "Queda agotado")
	check(player.state_machine.current_name == &"Walk", "Pasa a caminar (%s)" % player.state_machine.current_name)
	check(player.horizontal_speed() <= PlayerController.WALK_SPEED + 0.05, "Va a velocidad de caminar")
	Input.action_release("run")
	Input.action_release("move_back")


func test_jump_height() -> void:
	await spawn_world()
	await place(Vector3(-40, 0.15, 12), 0.0)
	var base := player.global_position.y
	var peak := base
	Input.action_press("jump")
	for i in 90:
		await frames(1)
		peak = maxf(peak, player.global_position.y)
	Input.action_release("jump")
	var h := peak - base
	check(h > 1.0 and h < 1.3, "Altura de salto ≈ 1,17 m (%.2f)" % h)
	check(player.is_on_floor(), "Aterriza")


func test_short_jump_is_lower() -> void:
	await spawn_world()
	await place(Vector3(-40, 0.15, 12), 0.0)
	var base := player.global_position.y
	await tap("jump")
	var peak := base
	for i in 90:
		await frames(1)
		peak = maxf(peak, player.global_position.y)
	check(peak - base < 0.9, "Salto corto más bajo (%.2f)" % (peak - base))


func test_wall_blocks_player() -> void:
	await spawn_world()
	var key := _first_building("no_x_")
	var info: Dictionary = world.points[key]
	var face: Vector3 = info["face"]
	# Fachada que mira al sur (+Z): el jugador camina al norte contra ella.
	await place(face + Vector3(0, 0, 2.0), 0.0)
	await hold(["move_forward"], 2.0)
	check(player.global_position.z > face.z, "No atraviesa la fachada (z=%.2f, fachada=%.2f)" % [player.global_position.z, face.z])


func test_step_up_curb() -> void:
	await spawn_world()
	await place(Vector3(-2.0, 0.0, 12.0), PI * 0.5)  # En la calzada, mirando al oeste hacia la acera.
	check(player.global_position.y < 0.08, "Empieza en la calzada")
	await hold(["move_forward"], 1.5)
	check(player.global_position.x < -5.0, "Avanzó sobre la acera (x=%.2f)" % player.global_position.x)
	check(absf(player.global_position.y - PrototypeBlockBuilder.CURB_HEIGHT) < 0.05, "Subió el bordillo (y=%.3f)" % player.global_position.y)


func test_climb_stairs() -> void:
	await spawn_world()
	await place(world.points["stairs_bottom"], PI)  # Hacia el sur (+Z), escaleras arriba.
	await hold(["move_forward"], 3.0)
	var top: float = world.points["platform_top_y"]
	check(absf(player.global_position.y - top) < 0.06, "Llega arriba (y=%.2f, plataforma=%.2f)" % [player.global_position.y, top])


func test_walk_up_ramp() -> void:
	await spawn_world()
	await place(world.points["ramp_bottom"], PI * 0.5)  # Hacia el oeste, rampa arriba.
	await hold(["move_forward"], 4.0)
	var top: float = world.points["platform_top_y"]
	check(absf(player.global_position.y - top) < 0.06, "Sube la rampa (y=%.2f)" % player.global_position.y)


func test_steep_slope_not_climbable() -> void:
	await spawn_world()
	await place(world.points["steep_bottom"], PI * 0.5)  # Hacia el oeste, contra la pendiente.
	await hold(["move_forward"], 3.0)
	check(player.global_position.y < 0.9, "No sube la pendiente de 50° (y=%.2f)" % player.global_position.y)


func test_box_heights() -> void:
	await spawn_world()
	var g := PrototypeBlockBuilder.CURB_HEIGHT
	# Caja de 0,3 m: se sube caminando.
	var low: Vector3 = world.points["box_3"]
	await place(low + Vector3(0, 0, -2.0), PI)
	var top := await _max_floor_height(["move_forward"], [], 1.5)
	check(top > g + 0.25, "Sube la caja de 0,3 m sin saltar (y=%.2f)" % top)
	# Caja de 0,6 m: caminando no; saltando sí.
	var mid: Vector3 = world.points["box_6"]
	await place(mid + Vector3(0, 0, -2.0), PI)
	top = await _max_floor_height(["move_forward"], [], 1.5)
	check(top < g + 0.1, "No sube 0,6 m caminando (y=%.2f)" % top)
	await place(mid + Vector3(0, 0, -2.0), PI)
	Input.action_press("move_forward")
	await seconds(0.2)
	top = await _max_floor_height(["move_forward"], ["jump"], 1.5)
	check(top > g + 0.55, "Sube 0,6 m saltando (y=%.2f)" % top)


## Mantiene las acciones y devuelve la mayor altura a la que estuvo apoyado en el suelo.
## Las acciones de "once" se pulsan al empezar. Suelta todo al aterrizar tras un salto.
func _max_floor_height(hold_actions: Array, once: Array, s: float) -> float:
	for a: String in hold_actions + once:
		Input.action_press(a)
	var best := -INF
	var was_air := false
	for i in int(s * Engine.physics_ticks_per_second):
		await frames(1)
		if not player.is_on_floor():
			was_air = true
		elif was_air:
			for a: String in hold_actions + once:
				Input.action_release(a)
		if player.is_on_floor():
			best = maxf(best, player.global_position.y)
	_release_all()
	return best


func test_crouch_tunnel() -> void:
	await spawn_world()
	var entry: Vector3 = world.points["tunnel_entry"]
	var exit_x: float = world.points["tunnel_exit_x"]
	await place(entry, PI * 0.5)  # Hacia el oeste, al túnel.
	await hold(["move_forward"], 2.5)
	check(player.global_position.x > -24.0, "De pie no entra al túnel (x=%.2f)" % player.global_position.x)
	await place(entry, PI * 0.5)
	await tap("crouch")
	await frames(5)
	check(player.crouching, "Se agacha")
	Input.action_press("move_forward")
	await seconds(2.5)
	check(player.global_position.x < -24.5, "Agachado entra al túnel (x=%.2f)" % player.global_position.x)
	Input.action_release("move_forward")
	await tap("crouch")
	await frames(5)
	check(player.crouching, "No puede levantarse bajo el techo")
	Input.action_press("move_forward")
	await seconds(5.0)
	Input.action_release("move_forward")
	check(player.global_position.x < exit_x + 0.5, "Sale del túnel (x=%.2f)" % player.global_position.x)
	await tap("crouch")
	await frames(5)
	check(not player.crouching, "Fuera del túnel se levanta")


func test_camera_does_not_clip_wall() -> void:
	await spawn_world()
	var info: Dictionary = world.points[_first_building("no_x_")]
	var face: Vector3 = info["face"]
	# De espaldas a la fachada a 1 m: la cámara quedaría dentro del edificio.
	await place(face + Vector3(0, 0, 1.0), PI)
	world.camera_rig.pitch = 0.0
	await frames(30)
	var d := world.camera_rig.current_distance()
	check(d < 1.3, "El brazo de la cámara se acorta ante la pared (%.2f m)" % d)
	var cam_z := world.camera_rig.camera.global_position.z
	check(cam_z > face.z, "La cámara queda fuera del edificio (z=%.2f, fachada=%.2f)" % [cam_z, face.z])
	world.camera_rig.yaw = 0.0  # Mirando a la pared: detrás hay calle libre.
	await frames(30)
	check(world.camera_rig.current_distance() > ThirdPersonCamera.ARM_LENGTH - 0.3, "Con espacio libre usa la distancia completa")


func test_camera_rotation_moves_player_direction() -> void:
	await spawn_world()
	await place(Vector3(-40, 0.15, 12), 0.0)
	world.camera_rig.rotate_view(-PI * 0.5, 0.0)  # Girar la cámara 90° a la derecha (mirar al este).
	await frames(3)
	var start := player.global_position
	await hold(["move_forward"], 1.0)
	var moved := flat(player.global_position - start)
	check(moved.x > 2.0 and absf(moved.z) < 0.2, "Avanzar sigue a la cámara (dx=%.2f, dz=%.2f)" % [moved.x, moved.z])
	check(absf(wrapf(player.facing_yaw - world.camera_rig.yaw, -PI, PI)) < 0.2, "El cuerpo gira hacia donde avanza")


func test_quality_profiles_apply() -> void:
	await spawn_world()
	for id: String in QualityProfiles.ORDER:
		Settings.set_value("graphics", "profile", id)
		await frames(2)
		var p: Dictionary = QualityProfiles.PROFILES[id]
		check(is_equal_approx(world.get_viewport().scaling_3d_scale, p["render_scale"]), "%s: escala de render" % id)
		check(is_equal_approx(world.camera_rig.camera.far, p["draw_distance"]), "%s: distancia de dibujo" % id)
		check(is_equal_approx(world.sun.directional_shadow_max_distance, p["shadow_distance"]), "%s: distancia de sombras" % id)
		if not QualityProfiles.is_forward_plus():
			check(not world.environment.ssao_enabled, "%s: sin SSAO fuera de Forward+" % id)
	Settings.reset_to_defaults()


func test_scene_loader_missing_scene() -> void:
	var failures: Array = []
	var cb := func(path: String, message: String) -> void: failures.append([path, message])
	SceneLoader.load_failed.connect(cb)
	SceneLoader.change_scene("res://no_existe.tscn")
	await frames(3)
	SceneLoader.load_failed.disconnect(cb)
	check(failures.size() == 1, "Informa la escena inexistente")
	check(not SceneLoader.busy, "El cargador queda libre para otra carga")
	SceneLoader._screen.hide_screen()


func test_fall_reset() -> void:
	await spawn_world()
	player.teleport(Vector3(-40, -40, 12))
	await frames(5)
	check(player.global_position.distance_to(world.points["spawn"]) < 1.0, "Si cae fuera del mapa vuelve al inicio")


func _first_building(prefix: String) -> String:
	for key: String in world.points:
		if key.begins_with("building_" + prefix):
			return key
	push_error("No hay edificio %s" % prefix)
	return ""


# ---------------------------------------------------------------------------
# Policía, interacción y misión
# ---------------------------------------------------------------------------
## Mundo con policía; espera el tiempo de gracia inicial, apaga a los demás
## policías y deja al indicado quieto en `pos` mirando hacia `yaw`.
func isolate_officer(index: int, pos: Vector3, yaw: float) -> PoliceOfficer:
	await spawn_world(true)
	await seconds(EscapeMission.GRACE_SECONDS + 0.2)
	for o in world.mission.officers:
		o.active = false
	var officer: PoliceOfficer = world.mission.officers[index]
	officer.route = PackedVector3Array([pos])
	officer.reset_to(pos)
	officer.facing_yaw = yaw
	officer.active = true
	return officer


func wait_for(cond: Callable, timeout: float) -> bool:
	var n := int(timeout * Engine.physics_ticks_per_second)
	for i in n:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func crouch_in_place() -> void:
	player.state_machine.change_state(&"Crouch")
	await frames(3)


func test_navmesh_and_paths() -> void:
	await spawn_world(true)
	var nav := world.navigation.navigation_mesh
	check(nav.get_polygon_count() > 50, "La navmesh tiene polígonos (%d)" % nav.get_polygon_count())
	var map := world.get_world_3d().navigation_map
	var from: Vector3 = world.points["spawn"]
	for target: Vector3 in [Vector3(52.0, 0.15, 6.2), Vector3(-6.2, 0.15, -52.0), world.points["meeting_point"],
			world.points["vendor"], Vector3(42, 0.15, -6.0)]:
		var path := NavigationServer3D.map_get_path(map, from, target, true)
		check(path.size() > 1, "Hay ruta hasta %s" % target)
		if path.size() > 1:
			check(path[path.size() - 1].distance_to(target) < 1.5, "La ruta llega a %s (termina en %s)" % [target, path[path.size() - 1]])


func test_police_patrols() -> void:
	await spawn_world(true)
	player.cover_count = 100   # Invisible para la policía durante esta prueba.
	await crouch_in_place()
	await seconds(EscapeMission.GRACE_SECONDS + 0.2)
	var officer: PoliceOfficer = world.mission.officers[0]
	var start := officer.global_position
	await seconds(26.0)
	check(officer.state == PoliceOfficer.State.PATROL, "Sigue patrullando (%s)" % officer.state_name())
	check(flat(officer.global_position - start).length() > 3.0, "Se movió por su ruta")
	check(officer.route_index >= 2, "Llegó al siguiente punto de la ruta (índice %d)" % officer.route_index)
	check(officer.is_on_floor(), "Camina sobre el suelo (subió el bordillo)")


func test_police_sees_player_in_open() -> void:
	var officer := await isolate_officer(0, Vector3(30, 0.15, -6.0), PI * 0.5)   # Mira al oeste.
	await place(Vector3(19, 0.15, -6.0), 0.0)
	var ok := await wait_for(func() -> bool: return officer.state == PoliceOfficer.State.CHASE or world.mission.caught_count > 0, 3.0)
	check(ok, "Lo ve a 11 m en campo abierto y lo persigue (estado %s)" % officer.state_name())


func test_police_blind_through_buildings() -> void:
	var officer := await isolate_officer(0, Vector3(30, 0.15, -6.0), 0.0)        # Mira al norte, hacia los edificios.
	await place(Vector3(30, 0.15, -22.5), 0.0)
	check(not officer.can_see_player(), "Un edificio tapa la vista")
	await seconds(3.0)
	check(officer.state == PoliceOfficer.State.PATROL and officer.alert == 0.0,
			"No lo detecta detrás del edificio (%s, alerta %.2f)" % [officer.state_name(), officer.alert])


func test_police_does_not_see_behind() -> void:
	var officer := await isolate_officer(0, Vector3(30, 0.15, -6.0), -PI * 0.5)  # Mira al este.
	await place(Vector3(22, 0.15, -6.0), 0.0)
	await seconds(3.0)
	check(officer.state == PoliceOfficer.State.PATROL, "No ve a quien está detrás y quieto (%s)" % officer.state_name())


func test_crouching_reduces_view() -> void:
	var officer := await isolate_officer(0, Vector3(30, 0.15, -6.0), PI * 0.5)
	await place(Vector3(18, 0.15, -6.0), 0.0)
	await crouch_in_place()
	await seconds(3.0)
	check(officer.state == PoliceOfficer.State.PATROL, "Agachado a 12 m no lo ve (%s)" % officer.state_name())


func test_police_catches_player() -> void:
	var officer := await isolate_officer(0, Vector3(30, 0.15, -6.0), PI * 0.5)
	await place(Vector3(25, 0.15, -6.0), 0.0)
	var caught := await wait_for(func() -> bool: return world.mission.caught_count == 1, 6.0)
	check(caught, "Lo atrapa si se queda quieto")
	check(not player.input_enabled, "Los controles se bloquean mientras se muestra la pantalla")
	check(world.overlay.is_showing(), "Muestra «¡Te atraparon!»")
	await seconds(MissionOverlay.CAUGHT_SECONDS + 0.5)
	check(player.input_enabled, "Recupera los controles")
	check(flat(player.global_position - world.points["meeting_point"]).length() < 5.0, "Vuelve con los amigos")
	check(not officer.active, "La policía espera unos segundos antes de volver a buscar")
	await seconds(EscapeMission.GRACE_SECONDS + 0.2)
	check(officer.active and officer.state == PoliceOfficer.State.PATROL, "La policía vuelve a patrullar")


func test_hidden_player_is_lost() -> void:
	var officer := await isolate_officer(0, Vector3(34, 0.15, -6.0), PI * 0.5)
	await place(Vector3(24, 0.15, -6.0), 0.0)
	var chasing := await wait_for(func() -> bool: return officer.state == PoliceOfficer.State.CHASE, 3.0)
	check(chasing, "Empieza la persecución")
	# Se mete al matorral de la acera sur y se agacha.
	player.teleport(Vector3(24, 0.2, 6.7), 0.0)
	await crouch_in_place()
	await frames(5)
	check(player.is_hidden(), "Está escondido")
	var searched := await wait_for(func() -> bool: return officer.state == PoliceOfficer.State.SEARCH, 10.0)
	check(searched, "La policía busca donde lo perdió (%s)" % officer.state_name())
	var gave_up := await wait_for(func() -> bool: return officer.state in [PoliceOfficer.State.RETURN, PoliceOfficer.State.PATROL], PoliceOfficer.SEARCH_TIME + 3.0)
	check(gave_up, "Deja de buscar y vuelve a su ruta (%s)" % officer.state_name())
	check(world.mission.caught_count == 0, "Nunca lo atrapó estando escondido")


func test_radio_calls_nearby_officer() -> void:
	var officer := await isolate_officer(0, Vector3(30, 0.15, -6.0), PI * 0.5)
	var other: PoliceOfficer = world.mission.officers[1]
	other.route = PackedVector3Array([Vector3(6, 0.15, -25)])
	other.reset_to(Vector3(6, 0.15, -25))
	other.facing_yaw = 0.0
	other.active = true
	await place(Vector3(19, 0.15, -6.0), 0.0)
	await wait_for(func() -> bool: return officer.state == PoliceOfficer.State.CHASE, 3.0)
	await frames(2)
	check(other.state in [PoliceOfficer.State.SEARCH, PoliceOfficer.State.SUSPICIOUS, PoliceOfficer.State.CHASE],
			"El otro policía recibe el aviso por radio (%s)" % other.state_name())


func test_hiding_requires_crouch() -> void:
	await spawn_world(false)
	await place(Vector3(24, 0.15, 6.7), 0.0)
	check(player.in_cover(), "Está dentro del matorral")
	check(not player.is_hidden(), "De pie no está escondido")
	await crouch_in_place()
	check(player.is_hidden(), "Agachado sí está escondido")


func test_evidence_pickup() -> void:
	await spawn_world(false)
	var item := evidence_item("foto")
	await place(item.global_position + Vector3(-1.0, 0.0, 0.0), 0.0)
	check(player.focused == item.interactable, "La prueba queda resaltada para recoger")
	await tap("interact")
	await frames(2)
	check(item.collected, "Se recogió")
	check(world.mission.collected == ["foto"], "La misión la cuenta")
	check(world.mission.inventory.has("foto"), "Va al inventario")
	check(world.mission.is_done("foto"), "Objetivo cumplido")
	check(world.hud.progress_label.text == "1/7", "El HUD muestra 1/7 (%s)" % world.hud.progress_label.text)
	check(world.hud.objective.text == EscapeStory.step("recibo")["title"], "El objetivo pasa al siguiente (%s)" % world.hud.objective.text)
	check(not evidence_item("gorra").visible and not evidence_item("gorra").interactable.enabled, "La gorra no aparece todavía")


func test_vendor_granizado() -> void:
	await spawn_world(false)
	await place(world.points["vendor"] + Vector3(1.2, 0.0, 0.0), 0.0)
	player.stamina = 5.0
	player.exhausted = true
	check(player.focused == world.mission.vendor.interactable, "Puede hablarle al vendedor")
	await tap("interact")
	await frames(2)
	check(is_equal_approx(player.stamina, PlayerController.MAX_STAMINA), "El granizado llena la resistencia")
	check(player.energy_timer > 20.0, "Da resistencia sin límite un rato")
	await place(Vector3(-40, 0.15, 12), 0.0)
	await hold(["move_forward", "run"], 3.0)
	check(player.stamina > PlayerController.MAX_STAMINA - 1.0, "Correr no gasta resistencia con el granizado")


func test_friends_complete_mission() -> void:
	await spawn_world(false)
	await place(world.points["meeting_point"] + Vector3(2.0, 0.0, 0.0), 0.0)
	check(player.focused != null and player.focused.get_prompt() == "Hablar con tus amigos", "Puede hablar con los amigos")
	await tap("interact")
	await frames(2)
	check(not world.mission.finished, "Sin las pruebas la misión no termina")
	check(not world.escape_ui.deduction.is_open, "Sin las pruebas no hay reconstrucción")
	await solve_everything_but_deduction()
	await place(world.points["meeting_point"] + Vector3(2.0, 0.0, 0.0), 0.0)
	await tap("interact")
	await frames(2)
	check(world.escape_ui.deduction.is_open, "Con todo, los amigos abren la reconstrucción")
	check(get_tree().paused, "El mundo se congela con el panel abierto")
	answer_deduction([1, 1, 2])
	await frames(2)
	check(world.mission.finished and not world.mission.failed, "Con las respuestas correctas se gana")
	check(not get_tree().paused, "Al cerrar el panel el mundo sigue")
	check(world.overlay.is_showing(), "Pantalla de victoria")
	check(world.mission.stats()["rank"] == "Detective impecable", "Sin pistas ni errores: rango máximo")


func test_civilians_walk() -> void:
	await spawn_world(false)
	var walkers: Array = []
	for c in get_tree().get_nodes_in_group("civilian"):
		if not (c as Civilian).wander_points.is_empty():
			walkers.append([c, (c as Node3D).global_position])
	check(walkers.size() >= 3, "Hay peatones (%d)" % walkers.size())
	await seconds(10.0)
	var moved := 0
	for w: Array in walkers:
		if flat((w[0] as Node3D).global_position - w[1]).length() > 2.0:
			moved += 1
	check(moved >= walkers.size() - 1, "Los peatones caminan (%d de %d)" % [moved, walkers.size()])


func test_traffic_lights_cycle() -> void:
	await spawn_world(false)
	var lights: Array = []
	for n in world.find_children("*", "TrafficLight", true, false):
		lights.append(n)
	check(lights.size() == 4, "Hay 4 semáforos (%d)" % lights.size())
	var ns: TrafficLight = null
	var ew: TrafficLight = null
	for t: TrafficLight in lights:
		if t.axis == "ns":
			ns = t
		else:
			ew = t
	check(ns.current_state() == "green" and ew.current_state() == "red", "Un eje en verde y el otro en rojo")
	ns._time = TrafficLight.GREEN_TIME + 0.5
	ew._time = ns._time
	check(ns.current_state() == "yellow", "Después del verde viene el amarillo")


# ---------------------------------------------------------------------------
# Escape room
# ---------------------------------------------------------------------------
func evidence_item(id: String) -> EvidencePickup:
	for e in world.mission.evidence:
		if e.id == id:
			return e
	return null


## Cierra el panel que esté abierto (los paneles congelan el mundo).
func close_panels() -> void:
	for p: ModalPanel in [world.escape_ui.inventory, world.escape_ui.hints, world.escape_ui.code_lock,
			world.escape_ui.pattern_lock, world.escape_ui.deduction]:
		if p.is_open:
			p.close()
	await frames(1)


## Resuelve todo como lo haría el jugador, salvo la reconstrucción final.
func solve_everything_but_deduction() -> void:
	var m := world.mission
	for id: String in ["foto", "recibo", "celular"]:
		evidence_item(id).interactable.interact(player)
		await frames(1)
	await close_panels()
	check(m.try_code(EscapeStory.CAMERA_CODE), "La clave abre la caja")
	check(m.try_pattern(EscapeStory.PHONE_PATTERN), "El patrón desbloquea el celular")
	evidence_item("gorra").interactable.interact(player)
	await frames(1)
	await close_panels()


func answer_deduction(answers: Array) -> void:
	var panel := world.escape_ui.deduction
	for qi in answers.size():
		(panel._groups[qi][answers[qi]] as Button).button_pressed = true
	panel._on_submit()


func press_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(1)


func test_story_data_is_consistent() -> void:
	var ids: Array = []
	for s: Dictionary in EscapeStory.STEPS:
		ids.append(s["id"])
		check((s["hints"] as Array).size() == 3, "El paso %s tiene tres pistas" % s["id"])
	for s: Dictionary in EscapeStory.STEPS:
		for r: String in s["requires"]:
			check(r in ids and ids.find(r) < ids.find(s["id"]), "%s depende de un paso anterior (%s)" % [s["id"], r])
	check(EscapeStory.CAMERA_CODE == EscapeStory.ROBBERY_TIME.replace(":", ""), "La clave es la hora del robo")
	check(EscapeStory.item("foto")["text"].contains(EscapeStory.ROBBERY_TIME), "La foto muestra la hora del robo")
	check(EscapeStory.item("recibo")["text"].contains("Tienda Doña Rosa"), "El recibo dice dónde estabas")
	for q: Dictionary in EscapeStory.DEDUCTION:
		check(int(q["answer"]) >= 0 and int(q["answer"]) < (q["options"] as Array).size(), "Respuesta válida: %s" % q["question"])
	check(EscapeStory.DEDUCTION[0]["options"][EscapeStory.DEDUCTION[0]["answer"]] == EscapeStory.ROBBERY_TIME, "La hora correcta coincide con la foto")
	for k: String in EscapeMission.PICKUP_ITEM:
		check(EscapeStory.ITEMS.has(EscapeMission.PICKUP_ITEM[k]), "El objeto %s existe" % k)
		check(EscapeMission.PICKUP_STEP[k] in ids, "El paso de %s existe" % k)
	for item: Dictionary in EscapeStory.ITEMS.values():
		check(item.has("name") and item.has("text") and item.has("icon"), "Objeto completo: %s" % item.get("name", "?"))


func test_inventory_and_hint_units() -> void:
	var inv := Inventory.new()
	check(inv.add("foto") and not inv.add("foto"), "No se repiten objetos")
	inv.add("celular_bloqueado")
	inv.replace("celular_bloqueado", "celular")
	check(inv.items == ["foto", "celular"], "Reemplazar conserva el orden (%s)" % [inv.items])
	inv.from_data(["usb", "no_existe", "usb"])
	check(inv.items == ["usb"], "Al cargar se ignoran objetos inválidos o repetidos")
	var h := HintSystem.new()
	var texts: Array = []
	for i in 4:
		texts.append(h.reveal_next("caja"))
	check(texts[0] != "" and texts[2].contains("1742") and texts[3] == "", "Tres pistas y la última da la clave")
	check(h.total_used() == 3, "Cuenta las pistas usadas")
	h.from_data({"caja": 99, "inventado": 2})
	check(h.revealed == {"caja": 3}, "Al cargar se limitan las pistas (%s)" % [h.revealed])


func test_hints_follow_current_step() -> void:
	await spawn_world(false)
	var m := world.mission
	check(m.current_step()["id"] == "foto", "Primero, la foto")
	var first := m.request_hint()
	check(first == EscapeStory.step("foto")["hints"][0], "La primera pista orienta")
	m.request_hint()
	m.request_hint()
	check(m.request_hint() == "", "No hay una cuarta pista")
	evidence_item("foto").interactable.interact(player)
	check(m.current_step()["id"] == "recibo", "Después, el recibo")
	check(not m.is_available("gorra"), "La gorra no está disponible sin el celular")
	check(m.hints.total_used() == 3, "Se cuentan 3 pistas")


func test_lock_box_code() -> void:
	await spawn_world(false)
	var box := world.mission.lock_box
	await place(box.global_position + Vector3(0.0, 0.0, 1.0), 0.0)
	await crouch_in_place()
	await frames(5)
	check(player.focused == box.interactable, "La caja se puede revisar desde el túnel")
	await tap("interact")
	await frames(2)
	var panel := world.escape_ui.code_lock
	check(panel.is_open and get_tree().paused, "Se abre el teclado y el mundo se congela")
	for k: String in ["1", "2", "3", "4", "Buscar"]:
		panel._press(k)
	check(not box.opened and not world.mission.is_done("caja"), "Una hora equivocada no abre")
	check(panel._message.text.contains("12:34"), "Dice qué hora buscó (%s)" % panel._message.text)
	for k: String in ["9", "9"]:
		panel._press(k)
	panel._press("Buscar")
	check(panel._message.text.contains("Faltan"), "Pide los cuatro dígitos")
	panel.code = ""
	for k: String in ["1", "7", "4", "2", "Buscar"]:
		panel._press(k)
	check(box.opened and world.mission.is_done("caja"), "La hora del robo abre la caja")
	check(world.mission.inventory.has("usb"), "Da la USB con el video")
	await seconds(1.6)
	check(not panel.is_open and not get_tree().paused, "El panel se cierra solo y el juego sigue")


func test_phone_pattern_reveals_cap() -> void:
	await spawn_world(false)
	var m := world.mission
	check(not m.try_pattern(EscapeStory.PHONE_PATTERN), "Sin el celular no se desbloquea nada")
	evidence_item("celular").interactable.interact(player)
	await frames(2)
	var panel := world.escape_ui.pattern_lock
	check(panel.is_open, "Al recoger el celular se abre el patrón")
	check(m.inventory.has("celular_bloqueado"), "Llega bloqueado al inventario")
	for n: int in [1, 2, 3, 6, 9]:
		panel.pad.add_point(n)
	panel._on_drawn(panel.pad.sequence)
	check(not m.is_done("desbloqueo"), "Un patrón equivocado no desbloquea")
	panel.pad.clear()
	for n: int in EscapeStory.PHONE_PATTERN:
		panel.pad.add_point(n)
	panel._on_drawn(panel.pad.sequence)
	check(m.is_done("desbloqueo") and m.inventory.has("celular") and not m.inventory.has("celular_bloqueado"), "La Z desbloquea el celular")
	var cap := evidence_item("gorra")
	check(cap.revealed and cap.visible and cap.interactable.enabled, "Aparece la gorra")
	await seconds(1.6)
	check(not panel.is_open, "El panel se cierra solo")


func test_diaz_tells_the_pattern() -> void:
	await spawn_world(false)
	var m := world.mission
	evidence_item("celular").interactable.interact(player)
	await frames(1)
	await close_panels()
	var said: Array[String] = []
	var cb := func(t: String) -> void: said.append(t)
	EventBus.notify.connect(cb)
	m._talk_to_friends(player)
	EventBus.notify.disconnect(cb)
	check(m.diaz_told, "Diaz dice su patrón")
	check(said.size() > 0 and said[-1].contains("última del abecedario"), "La pista sale de lo que dice Diaz")
	m.use_item("celular_bloqueado")
	await frames(1)
	check(world.escape_ui.pattern_lock.is_open, "Usar el celular en el inventario abre el patrón")
	check(world.escape_ui.pattern_lock._message.text.contains("abecedario"), "El panel recuerda lo que dijo Diaz")


func test_deduction_wrong_then_right() -> void:
	GameSession.mode = "contrarreloj"
	await spawn_world(false)
	var m := world.mission
	check(m.time_limit == EscapeStory.TIME_LIMIT_SECONDS, "Contrarreloj de 15 minutos")
	await solve_everything_but_deduction()
	m.panel_requested.emit("deduction")
	await frames(1)
	var panel := world.escape_ui.deduction
	check(panel.is_open, "Se abre la reconstrucción")
	panel._on_submit()
	check(panel._message.text.contains("Falta"), "Pide responder todo")
	answer_deduction([0, 1, 2])
	check(not m.finished and m.wrong_answers == 1, "Una respuesta mala no gana")
	check(panel._feedback[0].text != "" and panel._feedback[1].text == "", "Marca solo la pregunta equivocada")
	check(is_equal_approx(m.penalty, EscapeStory.WRONG_ANSWER_PENALTY), "En contrarreloj resta 30 s")
	answer_deduction([1, 1, 2])
	await frames(2)
	check(m.finished and not m.failed, "Corrigiendo se gana")
	check(m.stats()["wrong"] == 1 and m.stats()["rank"] == "Buen ojo", "El resultado cuenta el error (%s)" % m.stats()["rank"])


func test_inventory_and_hint_panels_toggle() -> void:
	await spawn_world(false)
	evidence_item("foto").interactable.interact(player)
	await press_action("inventory")
	var inv := world.escape_ui.inventory
	check(inv.is_open and get_tree().paused, "Tab abre el inventario")
	check(inv._detail_text.text.contains("17:42"), "Examinar la foto muestra la hora")
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await frames(2)
	tab = tab.duplicate()
	tab.pressed = false
	Input.parse_input_event(tab)
	await frames(1)
	check(not inv.is_open and not get_tree().paused, "La tecla Tab lo cierra aunque mueva el foco")
	await press_action("hint")
	var hints := world.escape_ui.hints
	check(hints.is_open, "H abre las pistas")
	hints._on_reveal()
	check(world.mission.hints.revealed_count("recibo") == 1, "Revela la pista del objetivo actual")
	await press_action("pause")
	check(not hints.is_open, "Esc cierra el panel")
	check(not world.pause_menu.visible, "Esc cierra el panel sin abrir la pausa")
	await press_action("pause")
	check(world.pause_menu.visible, "Esc abre la pausa")
	world.escape_ui.open_panel("inventory")
	check(not inv.is_open, "Con la pausa abierta no se abren paneles")
	world.pause_menu.close()


func test_save_and_continue() -> void:
	GameSession.save_enabled = true
	GameSession.new_game("contrarreloj")
	await spawn_world(false)
	var m := world.mission
	evidence_item("foto").interactable.interact(player)
	evidence_item("celular").interactable.interact(player)
	await frames(1)
	await close_panels()
	m.try_code("1742")
	m.try_pattern(EscapeStory.PHONE_PATTERN)
	m.request_hint()
	m.elapsed = 123.0
	m.save_progress()
	check(SaveGame.exists(), "Se guardó la partida")
	check(GameSession.saved_summary().contains("4/7"), "El resumen dice el progreso (%s)" % GameSession.saved_summary())
	world.queue_free()
	world = null
	await get_tree().process_frame
	GameSession.mode = "explorador"
	GameSession.continue_game()
	await spawn_world(false)
	m = world.mission
	check(m.mode == "contrarreloj", "Se recupera el modo")
	check(m.steps_done.size() == 4, "Se recuperan los objetivos (%s)" % [m.steps_done])
	check(m.inventory.has("usb") and m.inventory.has("celular"), "Se recupera el inventario")
	check(m.elapsed >= 123.0, "Se recupera el tiempo")
	check(m.hints.total_used() == 1, "Se recuperan las pistas")
	check(m.lock_box.opened, "La caja sigue abierta")
	check(not evidence_item("foto").visible, "La foto ya recogida no vuelve a aparecer")
	check(evidence_item("gorra").revealed, "La gorra sigue a la vista")
	check(m.current_step()["id"] == "recibo", "Sigue donde iba")


func test_corrupt_save_is_ignored() -> void:
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("esto no es [una partida")
	f.close()
	check(SaveGame.load_data().is_empty(), "Un archivo dañado no se carga")
	check(not SaveGame.exists(), "El archivo dañado se aparta")
	if FileAccess.file_exists(TEST_SAVE + ".bad"):
		DirAccess.remove_absolute(TEST_SAVE + ".bad")
	GameSession.continue_game()
	await spawn_world(false)
	check(world.mission.steps_done.is_empty(), "Empieza de cero sin errores")


func test_time_limit_ends_game() -> void:
	GameSession.mode = "contrarreloj"
	await spawn_world(false)
	var m := world.mission
	m.elapsed = EscapeStory.TIME_LIMIT_SECONDS - 0.5
	await seconds(1.0)
	check(m.finished and m.failed, "Al acabarse el tiempo se pierde")
	check(world.overlay.is_showing() and world.overlay._title.text == "Se acabó el tiempo", "Pantalla de tiempo agotado")
	check(not player.input_enabled, "El jugador deja de moverse")


func test_restart_from_pause() -> void:
	GameSession.save_enabled = true
	await spawn_world(false)
	evidence_item("foto").interactable.interact(player)
	world.pause_menu.open()
	check(get_tree().paused, "La pausa congela el juego")
	check(SaveGame.exists(), "Abrir la pausa guarda la partida")
	world.pause_menu._on_restart()
	check(world.pause_menu._restart.text.begins_with("¿Seguro?"), "Reiniciar pide confirmación")
	check(SaveGame.exists(), "Sin confirmar no se borra nada")
	# Simula un cargador ocupado para que la prueba no reemplace la escena actual.
	SceneLoader.busy = true
	world.pause_menu._on_restart()
	SceneLoader.busy = false
	check(not SaveGame.exists(), "Al confirmar se descarta la partida para empezar de cero")
	check(not GameSession.continue_saved, "La siguiente carga es una partida nueva")
	world.pause_menu.close()


func test_touch_controls_drive_actions() -> void:
	await spawn_world(false)
	var tc := world.touch
	tc.set_active(true)
	check(world.uses_touch(), "Modo táctil activo")
	var vp := tc._canvas.get_viewport_rect().size
	var start := Vector2(160, vp.y - 160)
	tc._on_press(0, start)
	tc._stick_pos = start + Vector2(0, -60)
	tc._apply_stick()
	check(Input.get_action_strength("move_forward") > 0.6, "La palanca empuja hacia adelante")
	await seconds(0.6)
	check(player.velocity.length() > 1.0, "El jugador camina con la palanca")
	tc._on_release(0)
	check(Input.get_action_strength("move_forward") == 0.0, "Al soltar se detiene")
	var jump: Vector2 = tc._buttons["jump"]["center"]
	tc._on_press(1, jump)
	check(Input.is_action_pressed("jump"), "El botón Saltar salta")
	tc._on_release(1)
	var yaw := world.camera_rig.yaw
	tc._on_press(2, Vector2(vp.x * 0.7, vp.y * 0.4))
	tc._input(_drag(2, Vector2(vp.x * 0.7 + 80, vp.y * 0.4)))
	check(absf(world.camera_rig.yaw - yaw) > 0.2, "Arrastrar a la derecha gira la cámara")
	tc._on_release(2)
	tc.set_active(false)


func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var d := InputEventScreenDrag.new()
	d.index = index
	d.position = pos
	return d


func test_ui_scales_with_orientation() -> void:
	var root := get_tree().root
	SceneLoader._fit_ui()
	var s := root.size
	var expected := SceneLoader.BASE_PORTRAIT if s.y > s.x else SceneLoader.BASE_LANDSCAPE
	check(root.content_scale_size == expected, "Tamaño base según la orientación (%s)" % root.content_scale_size)
	check(root.theme == UiStyle.theme(), "El tema del juego está en la ventana")
	var f := UiStyle.font("title", 700)
	check(f != null and (f as FontVariation).base_font != null, "Cargan las tipografías")


func test_audio_buses_and_volume() -> void:
	for bus: String in AudioManager.BUSES.values():
		check(AudioServer.get_bus_index(bus) >= 0, "Existe el bus %s" % bus)
	for t: String in AudioManager.TRACKS.values():
		check(ResourceLoader.exists(t), "Existe %s" % t)
	for sfx: String in AudioManager.SFX:
		check(ResourceLoader.exists("res://assets/audio/sfx_%s.ogg" % sfx), "Existe el efecto %s" % sfx)
	Settings.set_value("audio", "music", 0.5)
	var i := AudioServer.get_bus_index(AudioManager.BUSES["music"])
	check(absf(AudioServer.get_bus_volume_db(i) - linear_to_db(0.5)) < 0.01, "El volumen de la música se aplica")
	AudioManager.toggle_mute()
	check(AudioServer.is_bus_mute(0), "Silenciar apaga todo")
	AudioManager.toggle_mute()
	check(not AudioServer.is_bus_mute(0), "Y se puede volver a activar")
	var music := AudioManager.stream(AudioManager.TRACKS["menu"], true) as AudioStreamOggVorbis
	check(music != null and music.loop, "La música se repite en bucle")
	Settings.reset_to_defaults()


# ---------------------------------------------------------------------------
# Aventura: progresión
# ---------------------------------------------------------------------------
func test_profile_levels_skills_and_shop() -> void:
	PlayerProfile.reset()
	check(PlayerProfile.level() == 1 and PlayerProfile.level_name() == Chapters.level_name(1), "Se empieza en el nivel 1")
	check(PlayerProfile.learn_problem("paso_ligero") != "", "Sin nivel no se aprende nada")
	PlayerProfile.add_xp(Chapters.level_xp(2))
	check(PlayerProfile.level() == 2, "Con la XP del nivel 2 se sube (%d)" % PlayerProfile.level())
	check(PlayerProfile.skill_points == 1, "Subir de nivel da un punto de habilidad")
	check(PlayerProfile.learn_problem("parkour").contains("nivel 3"), "Parkour pide nivel 3")
	check(PlayerProfile.learn("paso_ligero"), "Se aprende Paso ligero")
	check(is_equal_approx(PlayerProfile.noise_mult(), 0.5), "Paso ligero baja el ruido a la mitad")
	check(PlayerProfile.learn_problem("pulmones") == "No tienes puntos de habilidad.", "Sin puntos no se aprende otra")
	check(PlayerProfile.buy_problem("latas") == "No te alcanza la plata.", "Sin plata no se compra")
	PlayerProfile.add_money(300)
	check(PlayerProfile.buy("latas"), "Con plata se compra")
	check(PlayerProfile.money == 200, "Se descuenta el precio (%d)" % PlayerProfile.money)
	check(PlayerProfile.cans_per_chapter() == 6, "La bolsa de latas da 3 más")
	check(PlayerProfile.has_achievement("cliente"), "Primera compra: logro Cliente frecuente")
	check(PlayerProfile.buy_problem("latas") == "Ya lo tienes.", "No se compra dos veces")
	PlayerProfile.add_xp(100000)
	check(PlayerProfile.level() == Chapters.LEVELS.size(), "Hay un nivel máximo (%d)" % PlayerProfile.level())
	check(is_equal_approx(PlayerProfile.level_progress(), 1.0), "En el máximo la barra está llena")
	check(PlayerProfile.has_achievement("nivel_5"), "Llegar al nivel 5 da logro")


func test_profile_save_and_corrupt_file() -> void:
	GameSession.save_enabled = true
	PlayerProfile.reset()
	PlayerProfile.add_money(500)
	PlayerProfile.buy("tenis")
	PlayerProfile.find_collectible("parques")
	PlayerProfile.complete_chapter("malentendido", {"time": 300.0, "rank": Chapters.RANKS[1], "hints": 1, "caught": 0, "chased": true})
	var xp := PlayerProfile.xp
	PlayerProfile.reset()
	PlayerProfile.load_profile()
	check(PlayerProfile.xp == xp and xp > 0, "La XP se guarda (%d)" % PlayerProfile.xp)
	check(PlayerProfile.has_item("tenis"), "Los objetos comprados se guardan")
	check(PlayerProfile.has_collectible("parques"), "Las postales se guardan")
	check(PlayerProfile.is_chapter_done("malentendido"), "Los capítulos terminados se guardan")
	check(PlayerProfile.is_chapter_unlocked("robo_plaza"), "Y desbloquean el siguiente")
	var f := FileAccess.open(TEST_PROFILE, FileAccess.WRITE)
	f.store_string("[perfil\nesto = no [sirve")
	f.close()
	PlayerProfile.load_profile()
	check(PlayerProfile.xp == 0 and not PlayerProfile.is_chapter_done("malentendido"), "Un perfil dañado empieza de cero")
	check(FileAccess.file_exists(TEST_PROFILE + ".bad"), "El perfil dañado se aparta como .bad")


func test_chapter_rewards_and_unlocks() -> void:
	PlayerProfile.reset()
	check(PlayerProfile.is_chapter_unlocked("malentendido") and not PlayerProfile.is_chapter_unlocked("robo_plaza"),
			"Al empezar solo está el capítulo 1")
	var r := PlayerProfile.complete_chapter("malentendido", {"time": 500.0, "rank": Chapters.RANKS[0], "hints": 0, "caught": 0, "chased": false})
	check(r["first"], "Primera vez")
	check(r["lines"].size() == 4, "Bonos: capítulo, sin pistas, sin atrapar y sin persecución (%d)" % r["lines"].size())
	check(r["xp"] == 600 + 100 + 150 + 200, "XP total correcta (%d)" % r["xp"])
	check(r["money"] == 150 + 50, "Dinero del capítulo más el bono por rango (%d)" % r["money"])
	check("caso_cerrado" in r["achievements"] and "fantasma" in r["achievements"] and "impecable" in r["achievements"],
			"Da los logros del capítulo (%s)" % [r["achievements"]])
	check(PlayerProfile.is_chapter_unlocked("robo_plaza"), "Se desbloquea el capítulo 2")
	check(PlayerProfile.next_chapter() == "robo_plaza", "El siguiente es el 2")
	var again := PlayerProfile.complete_chapter("malentendido", {"time": 900.0, "rank": Chapters.RANKS[2], "hints": 5, "caught": 2, "chased": true})
	check(not again["first"] and again["xp"] == int(600 * PlayerProfile.REPLAY_FACTOR), "Repetir da menos (%d)" % again["xp"])
	var rec: Dictionary = PlayerProfile.chapters["malentendido"]
	check(is_equal_approx(float(rec["time"]), 500.0) and rec["rank"] == Chapters.RANKS[0], "Se conserva el mejor tiempo y rango")
	for c: Dictionary in Chapters.LIST:
		var steps := EscapeStory.STEPS if c["id"] == Chapters.FIRST else ChapterStory.steps(c["id"])
		check(steps.size() >= 4, "El capítulo %s tiene objetivos" % c["id"])
		for st: Dictionary in steps:
			check((st["hints"] as Array).size() == 3, "%s/%s tiene tres pistas" % [c["id"], st["id"]])
			for req: String in st["requires"]:
				check(steps.any(func(o: Dictionary) -> bool: return o["id"] == req), "%s/%s requiere algo que existe" % [c["id"], st["id"]])
	for id: String in ChapterStory.ITEMS:
		check(ItemCatalog.has(id) and ItemCatalog.item(id).has("icon"), "El objeto %s está en el catálogo" % id)


# ---------------------------------------------------------------------------
# Aventura: búsqueda, latas y movimiento
# ---------------------------------------------------------------------------
func test_wanted_levels_decay_and_disguise() -> void:
	await spawn_world(false)
	var w := world.mission.wanted
	check(w.level == 0 and world.hud._wanted_name.text == "Tranquilo", "Se empieza tranquilo")
	w.report(40.0)
	check(w.level == 2, "Un aviso sube la búsqueda (%d)" % w.level)
	await frames(2)
	check(world.hud._wanted_name.text == "Búsqueda", "El HUD muestra el nivel (%s)" % world.hud._wanted_name.text)
	var before := w.heat
	await seconds(1.0)
	check(w.heat < before - 3.0, "Sin que nadie te vea, baja (%.1f → %.1f)" % [before, w.heat])
	check(await wait_for(func() -> bool: return w.level == 0, 12.0), "Termina en Tranquilo")
	w.set_level(3)
	w.disguise()
	check(w.level == 1, "El disfraz baja dos niveles (%d)" % w.level)
	w.set_level(3)
	world.mission._on_disguise()
	check(w.level == 3, "Sin chaqueta ni impermeable no hay disfraz")
	PlayerProfile.add_money(300)
	PlayerProfile.buy("chaqueta")
	world.mission._on_disguise()
	check(w.level == 1 and world.mission.jacket_used, "La chaqueta reversible disfraza una vez")
	w.set_level(3)
	world.mission._on_disguise()
	check(w.level == 3, "La chaqueta no sirve dos veces en el mismo capítulo")
	w.set_level(3)
	w.clear()
	await frames(2)
	check(PlayerProfile.has_achievement("escapista"), "Bajar de Persecución a Tranquilo da el logro")


func test_wanted_reinforcements() -> void:
	await spawn_world(true)
	await seconds(Mission.GRACE_SECONDS + 0.2)
	var m := world.mission
	var n := m.officers.size()
	m.wanted.set_level(3)
	await frames(3)
	check(m.officers.size() == n + 1, "En Persecución llega un refuerzo (%d → %d)" % [n, m.officers.size()])
	check(m.officers[-1].is_in_group("reinforcement"), "Es un refuerzo")
	m.wanted._reinforce_timer = 0.0
	m.wanted.set_level(3)
	await frames(3)
	m.wanted._reinforce_timer = 0.0
	await frames(3)
	check(m.wanted.reinforcements.size() == WantedSystem.MAX_REINFORCEMENTS, "Hay un máximo de refuerzos")
	m.wanted.clear()
	for o in m.officers:
		o.active = false
	await frames(3)
	check(m.wanted.reinforcements.is_empty() and m.officers.size() == n, "En Tranquilo se van")


func test_can_distracts_officer() -> void:
	var officer := await isolate_officer(0, Vector3(30, 0.15, 6.0), -PI * 0.5)
	await place(Vector3(14, 0.15, 6.2), -PI * 0.5)
	check(officer.state == PoliceOfficer.State.PATROL, "El policía no te ha visto")
	var cans := player.cans
	check(cans == PlayerProfile.cans_per_chapter(), "Se empieza con latas (%d)" % cans)
	await tap("throw")
	await frames(2)
	check(player.cans == cans - 1, "Lanzar gasta una lata")
	check(get_tree().get_nodes_in_group("thrown_can").size() == 1, "La lata vuela")
	var heard := await wait_for(func() -> bool: return officer.state == PoliceOfficer.State.SEARCH, 3.0)
	check(heard, "El ruido de la lata lo hace ir a revisar (%s)" % officer.state_name())
	check(PlayerProfile.has_achievement("distraccion"), "Distraer con una lata da el logro")
	player.cans = 0
	await tap("throw")
	await frames(2)
	check(player.cans == 0, "Sin latas no se lanza nada")


func test_vault_onto_high_box() -> void:
	await spawn_world()
	var g := PrototypeBlockBuilder.CURB_HEIGHT
	var high: Vector3 = world.points["box_10"]
	await place(high + Vector3(0, 0, -2.0), PI)
	var top := await _max_floor_height(["move_forward"], ["jump"], 2.0)
	check(top > g + 0.95, "Salta y trepa la caja de 1 m (y=%.2f)" % top)
	# Pegado al borde, el jugador encuentra de dónde agarrarse y sube trepando.
	await place(high + Vector3(0, 0, -1.25), PI)
	var edge := player.find_vault()
	check(edge != Vector3.INF and absf(edge.y - (g + 1.0)) < 0.15, "Encuentra el borde de la caja (%s)" % edge)
	player.state_machine.change_state(&"Vault", {"target": edge})
	await seconds(1.0)
	check(player.vault_count >= 1 and player.global_position.y > g + 0.95, "Trepó (y=%.2f)" % player.global_position.y)
	await place(world.points["box_3"] + Vector3(0, 0, -1.25), PI)
	check(player.find_vault() == Vector3.INF, "Lo bajito no se trepa: se sube caminando")


func test_slide_from_run() -> void:
	await spawn_world()
	await place(Vector3(-40, 0.15, 12), PI * 0.5)
	Input.action_press("move_forward")
	Input.action_press("run")
	await seconds(1.2)
	await tap("crouch")
	await frames(3)
	check(player.state_machine.current_name == &"Slide", "Agacharse corriendo desliza (%s)" % player.state_machine.current_name)
	check(player.crouching, "Deslizándose va agachado")
	Input.action_release("run")
	Input.action_release("move_forward")
	await seconds(1.0)
	check(player.state_machine.current_name != &"Slide", "El deslizamiento termina solo")
	check(player.slide_count == 1, "Contó un deslizamiento")


func test_collectible_pickup() -> void:
	await spawn_world()
	var m := world.mission
	check(m.collectibles.size() == Chapters.COLLECTIBLES.size(), "Están todas las postales")
	var c := m.collectibles[0]
	var id := c.id
	var money := PlayerProfile.money
	c.interactable.interact(player)
	await frames(2)
	check(PlayerProfile.has_collectible(id), "La postal queda en el perfil")
	check(PlayerProfile.money == money + 20, "Da dinero")
	check(not is_instance_valid(c) or not c.visible, "Desaparece al recogerla")
	world.queue_free()
	world = null
	await get_tree().process_frame
	await spawn_world()
	check(world.mission.collectibles.size() == Chapters.COLLECTIBLES.size() - 1, "Una postal recogida no vuelve a aparecer")


# ---------------------------------------------------------------------------
# Aventura: capítulos
# ---------------------------------------------------------------------------
func spawn_chapter(id: String, police: bool = false) -> void:
	PlayerProfile.chapters.clear()
	for c: Dictionary in Chapters.LIST:
		if c["id"] == id:
			break
		PlayerProfile.chapters[c["id"]] = {"done": true}
	GameSession.chapter = id
	await spawn_world(police)


func test_chapter2_investigation_and_thief() -> void:
	await spawn_chapter("robo_plaza")
	var m := world.mission as RoboPlazaMission
	check(m != null, "El capítulo 2 crea su misión")
	check(m.lives == 3 and world.hud._hearts.get_child_count() == 3, "Tres corazones")
	check(world.hud._cans_label.text == "×3", "El HUD muestra las latas (%s)" % world.hud._cans_label.text)
	check(m.officers.is_empty(), "De mañana no hay policía hasta que el ladrón grita")
	for e in m.evidence:
		check(not e.interactable.enabled, "Las pistas no aparecen antes de hablar con la testigo")
	m.rosa.interactable.interact(player)
	await frames(2)
	check(m.is_done("testigo"), "Habló con Doña Rosa")
	m.suspects[1].interactable.interact(player)
	check(not m.is_done("sospechoso") and m.wrong_answers == 0, "Sin pistas no se acusa a nadie")
	for e in m.evidence:
		e.interactable.interact(player)
	await frames(2)
	check(m.is_done("pistas") and m.inventory.has("boton"), "Encontró las tres pistas")
	m.suspects[1].interactable.interact(player)
	check(m.wrong_answers == 1 and not m.is_done("sospechoso"), "Señalar al del señor de chaqueta verde es un error")
	m.thief.interactable.interact(player)
	await frames(2)
	check(m.is_done("sospechoso"), "Identificó al ladrón")
	check(m.thief.mode == Suspect.Mode.WALK, "El ladrón se va caminando")
	check(not m.suspects[2].interactable.enabled, "Ya no se puede señalar a nadie más")
	check(not m.hud_meter().is_empty() and world.hud._meter_box.visible, "El HUD muestra la distancia al ladrón")
	check(await wait_for(func() -> bool: return m.thief.global_position.distance_to(RoboPlazaMission.THIEF_ROUTE[1]) < 3.0, 8.0),
			"El ladrón camina por su ruta")
	# Atajo: lo ponemos en el escondite.
	m.thief.place_at_hideout()
	m.thief.reached_hideout.emit()
	await frames(2)
	check(m.is_done("seguir"), "Llegar al escondite completa el seguimiento")
	await place(RoboPlazaMission.BIN + Vector3(1.0, 0, 1.0), 0.0)
	m._try_take_envelope(player)
	check(not m.envelope_taken, "Con el ladrón al lado no se puede sacar el sobre")
	EventBus.noise.emit(m.thief.global_position + Vector3(8, 0, 0), 16.0, "lata")
	check(m.thief.mode == Suspect.Mode.INVESTIGATE, "La lata lo distrae")
	check(await wait_for(func() -> bool: return m.thief.global_position.distance_to(RoboPlazaMission.BIN) > 5.0, 6.0),
			"Se aleja de la caneca")
	m._try_take_envelope(player)
	check(m.envelope_taken and m.inventory.has("sobre") and m.is_done("recuperar"), "Recupera el sobre")
	check(m.wanted.level >= 3, "El ladrón grita y llega la policía (nivel %d)" % m.wanted.level)
	await place(RoboPlazaMission.ROSA + Vector3(1.2, 0, 0), 0.0)
	m.rosa.interactable.interact(player)
	check(not m.finished, "Con la policía detrás, Doña Rosa pide perderla primero")
	m.wanted.clear()
	m.rosa.interactable.interact(player)
	await frames(2)
	check(m.finished and not m.failed, "Se gana el capítulo 2")
	check(PlayerProfile.is_chapter_done("robo_plaza"), "Queda superado en el perfil")
	check(world.overlay.is_showing() and world.overlay._next.visible, "Victoria con botón al capítulo 3")


func test_chapter2_follow_fails_when_far() -> void:
	await spawn_chapter("robo_plaza")
	var m := world.mission as RoboPlazaMission
	m.steps_done.append_array(["testigo", "pistas"])
	m.thief.interactable.interact(player)
	var checkpoint := m.respawn_point
	await place(Vector3(-50, 0.15, 50), 0.0)
	await seconds(RoboPlazaMission.LOST_TIME + 0.5)
	check(m.wrong_answers == 1, "Quedarse muy lejos hace perderlo")
	check(player.global_position.distance_to(checkpoint) < 1.5, "Vuelves al punto de control")
	check(m.thief.path_index <= 1, "El ladrón vuelve a empezar su ruta")
	check(not m.is_done("seguir"), "El seguimiento sigue pendiente")


func test_chapter2_lives_run_out() -> void:
	await spawn_chapter("robo_plaza")
	var m := world.mission
	for i in 2:
		EventBus.player_caught.emit(null)
		await frames(2)
		check(world.overlay.is_showing() and not m.finished, "Atrapado %d: pierde un corazón y sigue" % (i + 1))
		await seconds(MissionOverlay.CAUGHT_SECONDS + 0.3)
	check(m.lives == 1 and world.hud._hearts.get_child_count() == 3, "Queda un corazón")
	EventBus.player_caught.emit(null)
	await frames(2)
	check(m.finished and m.failed, "Sin corazones se pierde el capítulo")
	check(world.overlay._title.text == "Te atraparon demasiadas veces", "Pantalla de derrota (%s)" % world.overlay._title.text)
	check(world.overlay._again.text == "Reintentar", "Se puede reintentar")


func test_chapter3_bodega() -> void:
	await spawn_chapter("callejon")
	var m := world.mission as CallejonMission
	check(m != null, "El capítulo 3 crea su misión")
	check(m.officers.size() == 3 and m.officers.all(func(o: PoliceOfficer) -> bool: return o is Guard), "Tres vigilantes")
	check(m.cameras.size() == 2, "Dos cámaras")
	check(world.has_node("LucesFaroles") and world.get_node("LucesFaroles").get_child_count() > 10, "De noche se prenden los faroles")
	check(world.sun.light_energy < 0.5, "De noche el sol casi no alumbra")
	# El galpón tiene la puerta y la rejilla: se llega a la oficina desde la puerta.
	var map := world.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, world.points["bodega_door"], BodegaBuilder.LIBRO - Vector3(0, 0.8, -1.0), true)
	check(path.size() > 1 and path[-1].distance_to(BodegaBuilder.LIBRO - Vector3(0, 0.8, -1.0)) < 1.5, "Hay camino de la puerta a la oficina")
	await place(Vector3(30, 0.15, -30), 0.0)
	await frames(5)
	check(m.is_done("entrar"), "Entrar al patio cumple el objetivo")
	for e in m.evidence:
		e.interactable.interact(player)
	await frames(2)
	check(m.is_done("documentos") and m.is_done("libro"), "Fotos y libro")
	check(m.inventory.has("foto_placa") and m.inventory.has("libro"), "Van al inventario")
	check(m.exit_beacon.active, "Se prende el punto de encuentro")
	m.wanted.set_level(3)
	await place(CallejonMission.BUS_STOP, 0.0)
	await frames(3)
	check(not m.finished, "Con la búsqueda alta Buitrago no se acerca")
	for o in m.officers:
		o.active = false
	m.wanted.clear()
	await frames(3)
	check(m.finished and not m.failed, "Con la búsqueda baja, esperar en el paradero gana")


func test_security_camera_raises_alarm() -> void:
	await spawn_chapter("callejon", true)
	await seconds(Mission.GRACE_SECONDS + 0.2)
	var m := world.mission as CallejonMission
	for o in m.officers:
		o.active = false
	var cam := m.cameras[0]
	await place(cam.global_position + Vector3(0, -3.6, 6.0), 0.0)
	var alarmed := await wait_for(func() -> bool: return m.wanted.level >= 2, 4.0)
	check(alarmed, "La cámara te graba y suena la alarma (nivel %d, detect %.2f)" % [m.wanted.level, cam.detect])
	await crouch_in_place()
	check(m.wanted.level >= 2, "La alarma deja la búsqueda alta")


func test_chapter4_chase_and_disguise() -> void:
	await spawn_chapter("persecucion", true)
	var m := world.mission as PersecucionMission
	check(m != null and world.has_node("Lluvia"), "El capítulo 4 es de noche con lluvia")
	await seconds(Mission.GRACE_SECONDS + 0.3)
	check(m.wanted.level >= 3, "Empieza con la policía buscándote (nivel %d)" % m.wanted.level)
	for o in m.officers:
		o.active = false
	m._set_police_active(false)
	await place(world.points["tunnel_inside"], 0.0)
	await frames(5)
	check(m.is_done("tunel"), "Llegó al túnel")
	m.wanted.clear()
	await frames(3)
	check(m.is_done("perder") and m.backpack_beacon.active, "Perdió a la policía: aparece la mochila")
	await place(PersecucionMission.BACKPACK, 0.0)
	await frames(5)
	check(m.is_done("mochila") and m.inventory.has("impermeable"), "Recoge el impermeable")
	check(m.wanted.level == 2, "Al salir te ve una patrulla (nivel %d, calor %.1f)" % [m.wanted.level, m.wanted.heat])
	world.escape_ui.inventory.open()
	world.escape_ui.inventory._show("impermeable")
	check(world.escape_ui.inventory._use.visible and world.escape_ui.inventory._use.text == "Ponértelo", "El inventario ofrece ponérselo")
	world.escape_ui.inventory._use.pressed.emit()
	await frames(2)
	check(m.wanted.level == 0 and not m.inventory.has("impermeable"), "El impermeable baja la búsqueda y se gasta")
	await place(world.points["meeting_point"], 0.0)
	await frames(5)
	check(m.finished and not m.failed, "Llegar al refugio gana el capítulo 4")
	check(world.overlay.is_showing() and not world.overlay._next.visible, "Es el último capítulo por ahora")


func test_continue_saved_chapter() -> void:
	GameSession.save_enabled = true
	GameSession.new_game("explorador", "robo_plaza")
	await spawn_chapter("robo_plaza")
	var m := world.mission as RoboPlazaMission
	m.rosa.interactable.interact(player)
	m.evidence[0].interactable.interact(player)
	await frames(2)
	m.save_progress()
	check(GameSession.saved_summary().begins_with("Cap. 2"), "El resumen dice el capítulo (%s)" % GameSession.saved_summary())
	world.queue_free()
	world = null
	await get_tree().process_frame
	GameSession.chapter = Chapters.FIRST
	GameSession.continue_game()
	check(GameSession.chapter == "robo_plaza", "Continuar elige el capítulo guardado")
	await spawn_world(false)
	m = world.mission as RoboPlazaMission
	check(m != null and m.is_done("testigo"), "Se recupera el capítulo y el objetivo")
	check(m.clues_found.size() == 1 and not m.evidence[0].visible and m.evidence[1].interactable.enabled,
			"Se recuperan las pistas encontradas y las demás siguen a la vista")


func test_chapter_select_and_profile_pages() -> void:
	PlayerProfile.reset()
	var menu := MainMenu.new()
	add_child(menu)
	await frames(2)
	menu._show_page("chapters", false)
	await frames(2)
	var list: Node = (menu._pages["chapters"] as Node).get_node("Lista")
	check(list.get_child_count() == Chapters.LIST.size(), "Una tarjeta por capítulo")
	check(not (list.get_child(0) as Button).disabled and (list.get_child(1) as Button).disabled, "Solo el capítulo 1 está abierto")
	PlayerProfile.chapters["malentendido"] = {"done": true, "rank": Chapters.RANKS[0], "time": 400.0}
	menu._show_page("chapters", false)
	await frames(2)
	check(not (list.get_child(1) as Button).disabled, "Al terminar el 1 se abre el 2")
	menu._open_profile("shop")
	await frames(2)
	var profile := menu._pages["profile"] as ProfilePanel
	check(profile.visible and profile.tab == "shop", "Se abre la tienda")
	check(profile._list.get_child_count() == Chapters.SHOP.size(), "Todos los objetos de la tienda")
	var buy := profile._list.get_child(0).get_child(2) as Button
	check(buy.disabled and buy.tooltip_text == "No te alcanza la plata.", "Comprar sin plata está desactivado con el motivo")
	PlayerProfile.add_money(1000)
	await frames(1)
	buy = profile._list.get_child(0).get_child(2) as Button
	buy.pressed.emit()
	await frames(1)
	check(PlayerProfile.has_item(Chapters.SHOP.keys()[0]), "El botón compra")
	profile.show_tab("achievements")
	await frames(1)
	check(profile._list.get_child_count() >= Chapters.ACHIEVEMENTS.size() + 1, "La pestaña de logros los lista")
	menu.queue_free()
	await frames(1)


func test_victory_screen_rewards() -> void:
	PlayerProfile.reset()
	await spawn_world()
	var m := world.mission as EscapeMission
	await solve_everything_but_deduction()
	m.submit_deduction([1, 1, 2])
	await frames(2)
	check(world.overlay.is_showing(), "Pantalla de victoria")
	check(world.overlay._rewards.visible and world.overlay._rewards.get_child_count() >= 3, "Muestra las recompensas")
	check(world.overlay._next.visible and world.overlay._next.text == "Siguiente capítulo", "Botón al capítulo 2")
	check(PlayerProfile.money > 0 and PlayerProfile.xp > 0, "El perfil recibe XP y dinero")
	check(PlayerProfile.is_chapter_unlocked("robo_plaza"), "Se abre el capítulo 2")
