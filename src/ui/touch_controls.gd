class_name TouchControls
extends CanvasLayer
## Controles táctiles para celulares y tabletas (multitáctil):
## - Mitad izquierda: palanca virtual que aparece donde apoyas el dedo.
## - Mitad derecha: arrastrar mueve la cámara.
## - Botones: Usar (interactuar), Saltar, Agacharse, Correr (se queda activo),
##   Lata (lanzar para distraer) y Disfraz.
## Pulsan las mismas acciones del InputMap que el teclado, así que el jugador
## no distingue entre uno y otro. Se activan solos en pantallas táctiles o desde
## Configuración → Interfaz.

const STICK_RADIUS := 78.0
const DEAD_ZONE := 0.18
const TOP_RESERVED := 120.0     ## Franja superior para los botones del HUD.
const LOOK_SENSITIVITY := 0.0055 ## Radianes por píxel.

var world: PrototypeWorld
var active := false
var _canvas: Control
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_touch := -1
var _look_last := Vector2.ZERO
var _button_touch: Dictionary = {}   ## índice de toque -> nombre de botón
var _run_on := false
var _buttons: Dictionary = {}       ## nombre -> {center, radius, label, action}


func _init(w: PrototypeWorld) -> void:
	world = w
	name = "TouchControls"


func _ready() -> void:
	layer = 12
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	set_active(Settings.touch_controls_enabled())
	Settings.changed.connect(func(section: String, key: String, _v: Variant) -> void:
		if section == "interface" and key == "touch_controls":
			set_active(Settings.touch_controls_enabled()))
	get_viewport().size_changed.connect(_layout)
	EventBus.pause_changed.connect(func(_p: bool) -> void: release_all())
	_layout()


func set_active(value: bool) -> void:
	active = value
	visible = value
	if world.hud != null:
		world.hud._refresh_hint()
	if not value:
		release_all()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _layout() -> void:
	var s := _canvas.get_viewport_rect().size
	var m := 34.0
	var big := 54.0
	var small := 40.0
	var base := Vector2(s.x - m - big, s.y - m - big)
	_buttons = {
		"interact": {"center": base, "radius": big, "label": "Usar", "action": "interact"},
		"jump": {"center": base + Vector2(-big - small - 22, 10), "radius": small, "label": "Saltar", "action": "jump"},
		"crouch": {"center": base + Vector2(-big * 0.5 - 6, -big - small - 18), "radius": small, "label": "Agachar", "action": "crouch"},
		"run": {"center": base + Vector2(-big - small * 2.6 - 40, -small * 0.6), "radius": small * 0.86, "label": "Correr", "action": "run"},
		"throw": {"center": base + Vector2(10, -big - small * 2.0 - 40), "radius": small * 0.8, "label": "Lata", "action": "throw"},
		"gadget": {"center": base + Vector2(-big - small - 22, -big - small * 2.0 - 30), "radius": small * 0.8, "label": "Disfraz", "action": "gadget"},
	}
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not active:
		# En modo automático, el primer toque real enciende los controles.
		if event is InputEventScreenTouch and str(Settings.get_value("interface", "touch_controls")) == "auto":
			set_active(true)
		else:
			return
	if get_tree().paused or world.mission.finished:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		if drag.index == _stick_touch:
			_stick_pos = drag.position
			_apply_stick()
		elif drag.index == _look_touch:
			var d := drag.position - _look_last
			_look_last = drag.position
			world.camera_rig.rotate_view(-d.x * LOOK_SENSITIVITY, -d.y * LOOK_SENSITIVITY)


func _on_press(index: int, pos: Vector2) -> void:
	var s := _canvas.get_viewport_rect().size
	for bname: String in _buttons:
		var b: Dictionary = _buttons[bname]
		if pos.distance_to(b["center"]) <= float(b["radius"]) * 1.25:
			_button_touch[index] = bname
			if bname == "run":
				_run_on = not _run_on
				_set_action("run", _run_on)
			else:
				_set_action(b["action"], true)
			_canvas.queue_redraw()
			return
	if pos.y < TOP_RESERVED:
		return
	if pos.x < s.x * 0.45 and _stick_touch < 0:
		_stick_touch = index
		_stick_origin = pos
		_stick_pos = pos
		_apply_stick()
	elif pos.x >= s.x * 0.45 and _look_touch < 0:
		_look_touch = index
		_look_last = pos


func _on_release(index: int) -> void:
	if _button_touch.has(index):
		var bname: String = _button_touch[index]
		_button_touch.erase(index)
		if bname != "run":
			_set_action(_buttons[bname]["action"], false)
		_canvas.queue_redraw()
	elif index == _stick_touch:
		_stick_touch = -1
		_apply_stick()
	elif index == _look_touch:
		_look_touch = -1


func _apply_stick() -> void:
	var v := Vector2.ZERO
	if _stick_touch >= 0:
		v = (_stick_pos - _stick_origin) / STICK_RADIUS
		if v.length() > 1.0:
			v = v.normalized()
		if v.length() < DEAD_ZONE:
			v = Vector2.ZERO
	_axis("move_left", "move_right", v.x)
	_axis("move_forward", "move_back", v.y)
	# Con la palanca casi al tope se corre aunque Correr no esté activo.
	if not _run_on:
		_set_action("run", v.length() > 0.97)
	_canvas.queue_redraw()


func _axis(neg: String, pos: String, value: float) -> void:
	if value < 0.0:
		Input.action_press(neg, -value)
		Input.action_release(pos)
	elif value > 0.0:
		Input.action_press(pos, value)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _set_action(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func release_all() -> void:
	for a: String in ["move_left", "move_right", "move_forward", "move_back", "interact", "jump", "crouch", "run"]:
		Input.action_release(a)
	_stick_touch = -1
	_look_touch = -1
	_button_touch.clear()
	_run_on = false
	if _canvas != null:
		_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if active:
		_canvas.queue_redraw()


func _draw_controls() -> void:
	if not active or world.mission.finished:
		return
	var font := UiStyle.font("body", 600)
	var can_use := world.player.focused != null
	for bname: String in _buttons:
		var b: Dictionary = _buttons[bname]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var pressed := bname in _button_touch.values() or (bname == "run" and _run_on)
		var hot := bname == "interact" and can_use
		var fill := Color(UiStyle.ACCENT, 0.55) if (pressed or hot) else Color(0.05, 0.06, 0.09, 0.5)
		_canvas.draw_circle(c, r, fill)
		_canvas.draw_arc(c, r, 0, TAU, 40, Color(1, 0.92, 0.78, 0.75 if hot else 0.4), 2.0, true)
		var fs := 17 if r > 45.0 else 14
		var text: String = b["label"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_canvas.draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UiStyle.INK if (pressed or hot) else UiStyle.TEXT)
	if _stick_touch >= 0:
		_canvas.draw_circle(_stick_origin, STICK_RADIUS, Color(0.05, 0.06, 0.09, 0.35))
		_canvas.draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
		_canvas.draw_circle(knob, 30.0, Color(UiStyle.ACCENT, 0.7))
	else:
		# Indicación de dónde poner el pulgar.
		var s := _canvas.get_viewport_rect().size
		var hint := Vector2(130, s.y - 140)
		_canvas.draw_arc(hint, STICK_RADIUS * 0.8, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0, true)
		_canvas.draw_string(font, hint + Vector2(-34, 6), "Mover", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.45))
