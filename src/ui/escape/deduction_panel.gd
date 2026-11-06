class_name DeductionPanel
extends ModalPanel
## Reconstrucción final con los amigos: tres preguntas cuyas respuestas están
## en las pruebas. Si alguna no cuadra, se marca cuál (sin decir la correcta)
## y en contrarreloj se suman 30 s. Se pueden revisar las pruebas sin perder
## lo que ya se había elegido.

signal review_requested

var mission: EscapeMission
var answers: Array = []
var _groups: Array = []           ## Por pregunta: Array[Button]
var _feedback: Array[Label] = []
var _blocks: Array[Control] = []
var _message: Label
var _submit: Button


func _init(w: PrototypeWorld, m: EscapeMission) -> void:
	super(w)
	mission = m


func build() -> void:
	subtitle_label.text = "BUITRAGO, DIAZ Y GORDO"
	title_label.text = "¿Qué pasó de verdad?"
	card.custom_minimum_size = Vector2(640, 0)
	var info := UiStyle.label("Arma con tus amigos la historia que le van a contar a la policía. Cada respuesta tiene que salir de una prueba.", 16, UiStyle.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(560, 0)
	body.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 360)
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)
	for qi in EscapeStory.DEDUCTION.size():
		var q: Dictionary = EscapeStory.DEDUCTION[qi]
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 8)
		list.add_child(block)
		_blocks.append(block)
		var ql := UiStyle.label("%d. %s" % [qi + 1, q["question"]], 18, UiStyle.TEXT, 600)
		ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(ql)
		var group := ButtonGroup.new()
		var buttons: Array[Button] = []
		for oi in (q["options"] as Array).size():
			var b := UiStyle.button(q["options"][oi], 0)
			b.toggle_mode = true
			b.button_group = group
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(540, 46)
			b.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.PANEL_SOFT, Color(1, 1, 1, 0.12), 8, 2))
			b.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.ACCENT_SOFT, Color(UiStyle.ACCENT, 0.6), 8, 2))
			b.add_theme_stylebox_override("pressed", UiStyle.box(Color(UiStyle.ACCENT, 0.22), UiStyle.ACCENT, 8, 2))
			b.add_theme_stylebox_override("hover_pressed", UiStyle.box(Color(UiStyle.ACCENT, 0.28), UiStyle.ACCENT, 8, 2))
			b.toggled.connect(func(on: bool) -> void:
				if on:
					answers[qi] = oi
					_feedback[qi].text = "")
			block.add_child(b)
			buttons.append(b)
		_groups.append(buttons)
		var fb := UiStyle.label("", 15, UiStyle.DANGER)
		block.add_child(fb)
		_feedback.append(fb)
	_message = UiStyle.label(" ", 16, UiStyle.TEXT_DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(row)
	var review := UiStyle.button("Revisar las pruebas", 220)
	review.pressed.connect(func() -> void:
		close()
		review_requested.emit())
	row.add_child(review)
	_submit = UiStyle.button("Contar lo que pasó", 240, "primary")
	_submit.pressed.connect(_on_submit)
	row.add_child(_submit)
	answers.resize(EscapeStory.DEDUCTION.size())
	answers.fill(-1)


func refresh() -> void:
	_message.text = " "


func first_focus() -> Control:
	for qi in answers.size():
		if int(answers[qi]) < 0:
			return _groups[qi][0]
	return _submit


func _on_submit() -> void:
	if -1 in answers:
		_message.text = "Falta responder %d pregunta(s)." % answers.count(-1)
		_message.add_theme_color_override("font_color", UiStyle.WARN)
		AudioManager.sfx("error")
		return
	var wrong := mission.submit_deduction(answers)
	if wrong.is_empty():
		AudioManager.sfx("unlock")
		flash(UiStyle.OK)
		close()
		return
	for qi in answers.size():
		_feedback[qi].text = "Eso no cuadra con las pruebas." if qi in wrong else ""
		if qi in wrong:
			UiStyle.shake(_blocks[qi])
	var penalty := " Se suman %d s al tiempo." % int(EscapeStory.WRONG_ANSWER_PENALTY) if mission.time_limit > 0.0 else ""
	_message.text = "Gordo: «Mmm, no. Así no nos van a creer.»%s" % penalty
	_message.add_theme_color_override("font_color", UiStyle.DANGER)
	AudioManager.sfx("error")
	flash(UiStyle.DANGER)
