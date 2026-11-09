class_name CinematicDirector
extends Node3D
## Cinemáticas cortas con la cámara del juego: planos que van de un punto a
## otro mirando a un objetivo, con franjas negras y un texto abajo.
##
## Se usan poco y con intención (al empezar un capítulo, al robar el contrato,
## al llegar al final). Siempre se pueden saltar con Interactuar, Saltar, Esc,
## clic o toque, y el jugador no se mueve mientras duran.
##
## Plano: {"from", "to", "look", "look_to" (opcional), "time", "caption"}.

signal finished

var world: PrototypeWorld
var playing := false
var camera: Camera3D
var _shots: Array = []
var _index := 0
var _t := 0.0
var _on_done: Callable
var _input_was := true


func _init(w: PrototypeWorld) -> void:
	world = w
	name = "CinematicDirector"
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "CinematicCamera"
	camera.near = 0.05
	camera.fov = 58.0
	add_child(camera)


## Reproduce los planos; on_done se llama al terminar o al saltarla.
func play(shots: Array, on_done: Callable = Callable()) -> void:
	_on_done = on_done
	if shots.is_empty() or not GameSession.cinematics_enabled:
		_finish.call_deferred()
		return
	_shots = shots
	_index = 0
	_t = 0.0
	playing = true
	_input_was = world.player.input_enabled
	world.player.input_enabled = false
	world.player.velocity = Vector3(0, world.player.velocity.y, 0)
	camera.make_current()
	_apply(0.0)
	EventBus.cinematic_changed.emit(true, str(_shots[0].get("caption", "")))


func skip() -> void:
	if playing:
		_finish()


func _process(delta: float) -> void:
	if not playing:
		return
	_t += delta
	var shot: Dictionary = _shots[_index]
	var dur := float(shot.get("time", 3.0))
	if _t >= dur:
		_index += 1
		_t = 0.0
		if _index >= _shots.size():
			_finish()
			return
		EventBus.cinematic_changed.emit(true, str(_shots[_index].get("caption", "")))
	_apply(_t / float(_shots[_index].get("time", 3.0)))


func _apply(k: float) -> void:
	var shot: Dictionary = _shots[_index]
	var e := smoothstep(0.0, 1.0, k)
	var from: Vector3 = shot["from"]
	var to: Vector3 = shot.get("to", from)
	var look: Vector3 = shot["look"]
	var look_to: Vector3 = shot.get("look_to", look)
	camera.global_position = from.lerp(to, e)
	var target := look.lerp(look_to, e)
	if camera.global_position.distance_to(target) > 0.01:
		camera.look_at(target, Vector3.UP)


func _finish() -> void:
	var was_playing := playing
	playing = false
	if was_playing:
		world.player.input_enabled = _input_was and not world.mission.finished
		world.camera_rig.camera.make_current()
		world.camera_rig.snap()
		EventBus.cinematic_changed.emit(false, "")
	if _on_done.is_valid():
		var cb := _on_done
		_on_done = Callable()
		cb.call()
	finished.emit()


func _input(event: InputEvent) -> void:
	if not playing:
		return
	var skip_it := event.is_action_pressed("interact") or event.is_action_pressed("jump") \
			or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip_it = true
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		skip_it = true
	if skip_it:
		get_viewport().set_input_as_handled()
		skip()
