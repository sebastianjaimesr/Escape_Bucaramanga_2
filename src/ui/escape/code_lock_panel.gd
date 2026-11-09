class_name CodeLockPanel
extends ModalPanel
## Teclado de cuatro dígitos. En el capítulo 1 es la caja de grabación de la
## cámara del túnel (busca el video por hora, HHMM); en el capítulo 5 es la caja
## fuerte de El Búho. Los textos los da la misión (Mission.code_panel()).
## Con ratón, toque o teclado (dígitos, Retroceso y Enter).

const DIGITS := 4
const DEFAULT_TEXTS := {
	"kind": "time",
	"subtitle": "CÁMARA DEL TÚNEL · CAJA DE GRABACIÓN",
	"title": "Buscar el video por hora",
	"info": "La caja pide la hora del video que quieres copiar a la USB, en formato de 24 horas (HHMM).",
	"hint": "Pista: piensa en qué momento pasó el robo.",
	"ok": "Video encontrado. Copiando a la memoria USB…",
	"button": "Buscar",
	"wrong": "No hay ningún robo grabado a las %s:%s.",
}

var mission: Mission
var texts: Dictionary = DEFAULT_TEXTS
var code := ""
var _slots: Array[Label] = []
var _display: PanelContainer
var _message: Label
var _keys: Array[Button] = []
var _locked_out := false


func _init(w: PrototypeWorld, m: Mission) -> void:
	super(w)
	mission = m
	if m != null and not m.code_panel().is_empty():
		texts = DEFAULT_TEXTS.merged(m.code_panel(), true)


func build() -> void:
	subtitle_label.text = texts["subtitle"]
	title_label.text = texts["title"]
	card.custom_minimum_size = Vector2(440, 0)
	var info := UiStyle.label(texts["info"], 16, UiStyle.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(380, 0)
	body.add_child(info)
	_display = PanelContainer.new()
	_display.add_theme_stylebox_override("panel", UiStyle.box(Color(0.02, 0.03, 0.03, 1), Color(UiStyle.OK, 0.3), 8))
	body.add_child(_display)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 10)
	_display.add_child(slots)
	for i in DIGITS:
		if i == 2 and texts["kind"] == "time":
			slots.add_child(_digit_label(":", UiStyle.TEXT_DIM))
		var l := _digit_label("_", UiStyle.OK)
		_slots.append(l)
		slots.add_child(l)
	_message = UiStyle.label(" ", 16, UiStyle.TEXT_DIM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for k: String in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Borrar", "0", "Buscar"]:
		var b := UiStyle.button(texts["button"] if k == "Buscar" else k, 120, "primary" if k == "Buscar" else "ghost")
		b.custom_minimum_size = Vector2(120, 58)
		b.add_theme_font_size_override("font_size", 22 if k.length() == 1 else 17)
		b.pressed.connect(_press.bind(k))
		grid.add_child(b)
		_keys.append(b)


func _digit_label(t: String, c: Color) -> Label:
	var l := UiStyle.label(t, 44, c, 600)
	l.custom_minimum_size = Vector2(36, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func refresh() -> void:
	code = ""
	_locked_out = false
	_message.text = texts["hint"]
	_message.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_update_slots(UiStyle.OK)


func first_focus() -> Control:
	return _keys[0]


func handle_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var code_key := k.keycode
	if code_key >= KEY_0 and code_key <= KEY_9:
		_press(str(code_key - KEY_0))
	elif code_key >= KEY_KP_0 and code_key <= KEY_KP_9:
		_press(str(code_key - KEY_KP_0))
	elif code_key == KEY_BACKSPACE:
		_press("Borrar")
	elif code_key == KEY_ENTER or code_key == KEY_KP_ENTER:
		_press("Buscar")
	else:
		return
	get_viewport().set_input_as_handled()


func _press(k: String) -> void:
	if _locked_out:
		return
	match k:
		"Borrar":
			code = code.substr(0, maxi(0, code.length() - 1))
			AudioManager.sfx("key", 0.8)
		"Buscar":
			_submit()
			return
		_:
			if code.length() < DIGITS:
				code += k
				AudioManager.sfx("key", 1.0 + 0.04 * code.length())
	_update_slots(UiStyle.OK)


func _update_slots(c: Color) -> void:
	for i in DIGITS:
		_slots[i].text = code[i] if i < code.length() else "_"
		_slots[i].add_theme_color_override("font_color", c)


func _submit() -> void:
	if code.length() < DIGITS:
		_message.text = "Faltan dígitos: la hora tiene cuatro (HHMM)." if texts["kind"] == "time" else "Faltan dígitos: la clave tiene cuatro."
		_message.add_theme_color_override("font_color", UiStyle.WARN)
		AudioManager.sfx("error")
		UiStyle.shake(_display)
		return
	if mission.try_code(code):
		_locked_out = true
		_update_slots(UiStyle.OK)
		_message.text = texts["ok"]
		_message.add_theme_color_override("font_color", UiStyle.OK)
		AudioManager.sfx("unlock" if texts["kind"] == "time" else "safe")
		flash(UiStyle.OK)
		var tw := create_tween()
		tw.tween_interval(1.3)
		tw.tween_callback(close)
		return
	var hh := int(code.substr(0, 2))
	var mm := int(code.substr(2, 2))
	if texts["kind"] != "time":
		_message.text = str(texts["wrong"]) % code if "%s" in str(texts["wrong"]) else str(texts["wrong"])
	elif hh > 23 or mm > 59:
		_message.text = "%s:%s no es una hora válida." % [code.substr(0, 2), code.substr(2, 2)]
	else:
		_message.text = str(texts["wrong"]) % [code.substr(0, 2), code.substr(2, 2)]
	_message.add_theme_color_override("font_color", UiStyle.DANGER)
	_update_slots(UiStyle.DANGER)
	AudioManager.sfx("error")
	flash(UiStyle.DANGER)
	UiStyle.shake(_display)
	code = ""
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void: _update_slots(UiStyle.OK))
