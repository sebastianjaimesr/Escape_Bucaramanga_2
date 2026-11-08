class_name PauseMenu
extends CanvasLayer
## Pausa (Esc o el botón del HUD): continuar, perfil (habilidades, tienda y
## logros), configuración, volver al punto de control, reiniciar el capítulo y
## guardar y salir al menú. Al abrirse se guarda la partida.

signal respawn_requested
signal opened

var _dim: ColorRect
var _menu: VBoxContainer
var _settings: SettingsPanel
var _profile: ProfilePanel
var _center: CenterContainer
var _status: Label
var _restart: Button
var _confirm_restart := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.012, 0.02, 0.78)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_center.add_child(_menu)
	_menu.add_child(UiStyle.title("Pausa", 40))
	var resume := UiStyle.button("Continuar", 320, "primary")
	resume.pressed.connect(close)
	_menu.add_child(resume)
	_status = UiStyle.label("", 15, UiStyle.TEXT_DIM)
	_menu.add_child(_status)
	_menu.move_child(_status, 1)
	var profile := UiStyle.button("Perfil, habilidades y tienda", 320)
	profile.pressed.connect(_show_profile)
	_menu.add_child(profile)
	var settings := UiStyle.button("Configuración", 320)
	settings.pressed.connect(_show_settings)
	_menu.add_child(settings)
	var respawn := UiStyle.button("Volver al punto de control", 320)
	respawn.tooltip_text = "Por si te quedas atascado. No pierdes nada."
	respawn.pressed.connect(func() -> void:
		respawn_requested.emit()
		close())
	_menu.add_child(respawn)
	_restart = UiStyle.button("Reiniciar el capítulo", 320)
	_restart.pressed.connect(_on_restart)
	_menu.add_child(_restart)
	var menu := UiStyle.button("Guardar y salir al menú", 320)
	menu.pressed.connect(func() -> void:
		opened.emit()   # Guarda otra vez antes de salir.
		SceneLoader.change_scene(SceneLoader.MAIN_MENU, "Menú principal"))
	_menu.add_child(menu)
	_settings = SettingsPanel.new()
	_settings.closed.connect(_hide_settings)
	_settings.visible = false
	_center.add_child(_settings)
	_profile = ProfilePanel.new()
	_profile.closed.connect(_hide_settings)
	_profile.visible = false
	_profile.custom_minimum_size = Vector2(560, 520)
	_center.add_child(_profile)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if not visible:
		open()
	elif _settings.visible or _profile.visible:
		_hide_settings()
	else:
		close()


func open() -> void:
	if visible:
		return
	visible = true
	_hide_settings()
	_confirm_restart = false
	_restart.text = "Reiniciar el capítulo"
	var mission := _mission()
	if mission != null:
		_status.text = "Objetivos %s · %s" % [mission.progress_text(),
				"partida guardada" if GameSession.save_enabled else "sin guardado"]
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.pause_changed.emit(true)
	opened.emit()
	AudioManager.sfx("open")
	(_menu.get_child(2) as Button).grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	EventBus.pause_changed.emit(false)
	# En el navegador, capturar el ratón solo funciona dentro de un clic del jugador:
	# el clic en "Continuar" lo es; si no, el HUD pide hacer clic.
	var world := get_parent() as PrototypeWorld
	if world != null:
		world.capture_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _mission() -> Mission:
	var world := get_parent() as PrototypeWorld
	return world.mission if world != null else null


func _on_restart() -> void:
	if not _confirm_restart:
		_confirm_restart = true
		_restart.text = "¿Seguro? Pulsa otra vez para empezar de cero"
		return
	GameSession.new_game(GameSession.mode, GameSession.chapter)
	SceneLoader.change_scene(MainMenu.PROTOTYPE_SCENE, Chapters.get_chapter(GameSession.chapter).get("title", ""))


func _show_settings() -> void:
	_menu.visible = false
	_settings.visible = true


func _show_profile() -> void:
	_menu.visible = false
	_profile.visible = true
	_profile.refresh()
	_profile.first_focus().grab_focus.call_deferred()


func _hide_settings() -> void:
	_settings.visible = false
	_profile.visible = false
	_menu.visible = true
