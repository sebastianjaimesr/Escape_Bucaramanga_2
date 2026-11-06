class_name PatternLockPanel
extends ModalPanel
## Patrón de desbloqueo del celular de Diaz: cuadrícula de 3×3 puntos.
## Se dibuja arrastrando (ratón o dedo), tocando los puntos uno por uno o con
## las teclas 1-9 (y Enter para probar, Retroceso para borrar).

var mission: EscapeMission
var pad: PatternPad
var _message: Label
var _try: Button


func _init(w: PrototypeWorld, m: EscapeMission) -> void:
	super(w)
	mission = m


func build() -> void:
	subtitle_label.text = "CELULAR DE DIAZ"
	title_label.text = "Dibuja el patrón"
	card.custom_minimum_size = Vector2(420, 0)
	var info := UiStyle.label("Arrastra por los puntos, tócalos en orden o usa las teclas 1 a 9.", 15, UiStyle.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(360, 0)
	body.add_child(info)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.box(Color(0.02, 0.025, 0.04, 1), Color(1, 1, 1, 0.18), 26, 2))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(frame)
	pad = PatternPad.new()
	pad.finished.connect(_on_drawn)
	frame.add_child(pad)
	_message = UiStyle.label(" ", 16, UiStyle.TEXT_DIM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var clear := UiStyle.button("Borrar", 150)
	clear.pressed.connect(func() -> void: pad.clear())
	row.add_child(clear)
	_try = UiStyle.button("Desbloquear", 180, "primary")
	_try.pressed.connect(func() -> void: _on_drawn(pad.sequence))
	row.add_child(_try)


func refresh() -> void:
	pad.clear()
	pad.locked = false
	_message.text = "Diaz sabe cuál es su patrón." if not mission.diaz_told else "Diaz dijo: «la última letra del abecedario»."
	_message.add_theme_color_override("font_color", UiStyle.TEXT_DIM)


func first_focus() -> Control:
	return _try


func handle_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_9:
		pad.add_point(k.keycode - KEY_0)
	elif k.keycode >= KEY_KP_1 and k.keycode <= KEY_KP_9:
		pad.add_point(k.keycode - KEY_KP_0)
	elif k.keycode == KEY_BACKSPACE:
		pad.clear()
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_on_drawn(pad.sequence)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_drawn(seq: Array) -> void:
	if pad.locked:
		return
	if seq.size() < 4:
		_message.text = "El patrón une por lo menos 4 puntos."
		_message.add_theme_color_override("font_color", UiStyle.WARN)
		AudioManager.sfx("error")
		return
	if mission.try_pattern(seq):
		pad.locked = true
		pad.tint = UiStyle.OK
		pad.queue_redraw()
		_message.text = "Desbloqueado. Hay un video en la galería…"
		_message.add_theme_color_override("font_color", UiStyle.OK)
		AudioManager.sfx("unlock")
		flash(UiStyle.OK)
		var tw := create_tween()
		tw.tween_interval(1.3)
		tw.tween_callback(close)
		return
	pad.tint = UiStyle.DANGER
	pad.queue_redraw()
	_message.text = "Patrón incorrecto."
	_message.add_theme_color_override("font_color", UiStyle.DANGER)
	AudioManager.sfx("error")
	flash(UiStyle.DANGER)
	UiStyle.shake(pad)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(pad.clear)
