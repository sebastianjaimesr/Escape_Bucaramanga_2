class_name HintPanel
extends ModalPanel
## Pistas del objetivo actual. Se revelan de una en una (tres por objetivo):
## la primera orienta, la segunda acerca y la tercera dice la solución.
## No restan tiempo; se cuentan en el resultado final.

var mission: Mission
var _step: Label
var _list: VBoxContainer
var _reveal: Button
var _note: Label


func _init(w: PrototypeWorld, m: Mission) -> void:
	super(w)
	mission = m


func build() -> void:
	subtitle_label.text = "PISTAS"
	title_label.text = "¿Necesitas una ayuda?"
	card.custom_minimum_size = Vector2(560, 0)
	_step = UiStyle.label("", 18, UiStyle.ACCENT, 600)
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_step)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	body.add_child(_list)
	_note = UiStyle.label("Las pistas no restan tiempo, pero se cuentan en el resultado final.", 14, UiStyle.TEXT_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(500, 0)
	body.add_child(_note)
	_reveal = UiStyle.button("Ver una pista", 260, "primary")
	_reveal.pressed.connect(_on_reveal)
	body.add_child(_reveal)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var step := mission.current_step()
	if step.is_empty():
		_step.text = "No hay nada pendiente."
		_reveal.visible = false
		return
	var id: String = step["id"]
	_step.text = "Objetivo: %s" % step["title"]
	var shown := mission.hints.revealed_hints(id)
	for i in shown.size():
		_list.add_child(_hint_row(i + 1, shown[i]))
	var total := mission.hints.available(id)
	_reveal.visible = shown.size() < total
	_reveal.text = "Ver la pista %d de %d" % [shown.size() + 1, total] + (" (la solución)" if shown.size() + 1 == total else "")
	if shown.is_empty():
		_list.add_child(UiStyle.label("Todavía no has pedido pistas para este objetivo.", 16, UiStyle.TEXT_DIM))


func first_focus() -> Control:
	return _reveal if _reveal.visible else close_button


func _hint_row(n: int, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var num := UiStyle.label(str(n), 18, UiStyle.INK, 700)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.custom_minimum_size = Vector2(30, 30)
	num.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 15))
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(num)
	var l := UiStyle.label(text, 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(440, 0)
	row.add_child(l)
	return row


func _on_reveal() -> void:
	if mission.request_hint() != "":
		AudioManager.sfx("hint")
	refresh()
	if _list.get_child_count() > 0:
		UiStyle.fade_in(_list.get_child(_list.get_child_count() - 1), 0.0, 0.0, 0.35)
	_focus_first.call_deferred()
