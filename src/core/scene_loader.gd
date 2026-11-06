extends Node
## Cambio de escena con pantalla de carga y manejo de errores.
##
## Carga en segundo plano con ResourceLoader.load_threaded_request. En la versión
## web sin hilos Godot carga de forma síncrona por partes, y la barra avanza igual.
## Si la carga falla, la pantalla lo dice y ofrece volver al menú principal.

signal load_started(path: String)
signal load_finished(path: String)
signal load_failed(path: String, message: String)

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

var busy := false
var current_path := ""
var _screen: LoadingScreen


## Tamaño base de la interfaz: 1280×720 en horizontal y 720×1280 en vertical.
## Con el modo de estiramiento canvas_items la interfaz se escala a la pantalla
## (nítida en pantallas de alta densidad) y el 3D se dibuja a la resolución real.
const BASE_LANDSCAPE := Vector2i(1280, 720)
const BASE_PORTRAIT := Vector2i(720, 1280)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = UiStyle.theme()
	get_tree().root.size_changed.connect(_fit_ui)
	_fit_ui()
	_screen = LoadingScreen.new()
	add_child(_screen)
	_screen.back_requested.connect(func() -> void: change_scene(MAIN_MENU))


func _exit_tree() -> void:
	get_tree().root.theme = null
	UiStyle.clear_cache()


func _fit_ui() -> void:
	var root := get_tree().root
	var s := root.size
	root.content_scale_size = BASE_PORTRAIT if s.y > s.x else BASE_LANDSCAPE


func change_scene(path: String, title: String = "") -> void:
	if busy:
		push_warning("Ya hay una carga en curso; se ignora %s" % path)
		return
	busy = true
	current_path = path
	get_tree().paused = false
	load_started.emit(path)
	_screen.show_loading(title)
	if not ResourceLoader.exists(path):
		_fail(path, "No se encontró la escena:\n%s" % path)
		return
	var err := ResourceLoader.load_threaded_request(path, "PackedScene")
	if err != OK:
		_fail(path, "No se pudo empezar a cargar (%s)." % error_string(err))
		return
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_screen.set_progress(float(progress[0]) if progress.size() > 0 else 0.0)
				await get_tree().process_frame
			ResourceLoader.THREAD_LOAD_LOADED:
				break
			_:
				_fail(path, "Falló la carga de la escena (estado %d)." % status)
				return
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		_fail(path, "El archivo no es una escena válida.")
		return
	_screen.set_progress(1.0)
	err = get_tree().change_scene_to_packed(packed)
	if err != OK:
		_fail(path, "No se pudo abrir la escena (%s)." % error_string(err))
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_screen.hide_screen()
	busy = false
	load_finished.emit(path)


func _fail(path: String, message: String) -> void:
	push_error(message)
	busy = false
	_screen.show_error(message, path != MAIN_MENU)
	load_failed.emit(path, message)
