class_name InventoryPanel
extends ModalPanel
## Inventario: las pruebas que lleva Sebastián. Al elegir una se ve su
## descripción (ahí están las pistas de los acertijos) y, si se puede usar,
## el botón Usar (el celular bloqueado abre el patrón).

var mission: EscapeMission
var _grid: GridContainer
var _detail_icon: ItemIcon
var _detail_name: Label
var _detail_text: Label
var _use: Button
var _empty: Label
var _selected := ""
var _cards: Dictionary = {}
var _row: BoxContainer
var _detail: PanelContainer


func _init(w: PrototypeWorld, m: EscapeMission) -> void:
	super(w)
	mission = m


func build() -> void:
	subtitle_label.text = "INVENTARIO"
	title_label.text = "Tus pruebas"
	var row := BoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	body.add_child(row)
	_row = row
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	row.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	left.add_child(_grid)
	_empty = UiStyle.label("Todavía no tienes pruebas. Explora la manzana: busca brillos dorados.", 16, UiStyle.TEXT_DIM)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size = Vector2(320, 0)
	left.add_child(_empty)
	var detail := UiStyle.panel(20, Color(1, 1, 1, 0.03))
	detail.custom_minimum_size = Vector2(360, 300)
	_detail = detail
	row.add_child(detail)
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 12)
	detail.add_child(dcol)
	_detail_icon = ItemIcon.new("photo", 84, UiStyle.TEXT)
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dcol.add_child(_detail_icon)
	_detail_name = UiStyle.label("", 20, UiStyle.ACCENT, 600)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dcol.add_child(_detail_name)
	_detail_text = UiStyle.label("", 16, UiStyle.TEXT)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(320, 0)
	dcol.add_child(_detail_text)
	_use = UiStyle.button("Usar", 160, "primary")
	_use.pressed.connect(func() -> void:
		var id := _selected
		close()
		mission.use_item(id))
	dcol.add_child(_use)
	mission.inventory.changed.connect(func() -> void:
		if is_open:
			refresh())


func refresh() -> void:
	# En pantallas angostas (celular en vertical) la descripción va debajo.
	var narrow := card.get_viewport_rect().size.x < 820.0
	_row.vertical = narrow
	_detail.custom_minimum_size = Vector2(360, 0 if narrow else 300)
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	var items := mission.inventory.items
	_empty.visible = items.is_empty()
	for id: String in items:
		var b := _item_card(id)
		_grid.add_child(b)
		_cards[id] = b
	if not _selected in items:
		_selected = items[-1] if not items.is_empty() else ""
	_show(_selected)


func first_focus() -> Control:
	return _cards.get(_selected, close_button)


func _item_card(id: String) -> Button:
	var data := EscapeStory.item(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(102, 102)
	b.tooltip_text = data.get("name", id)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("pressed", UiStyle.box(Color(UiStyle.ACCENT, 0.18), UiStyle.ACCENT, 10, 2))
	var icon := ItemIcon.new(data.get("icon", ""), 56)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.position -= Vector2(28, 28)
	b.add_child(icon)
	b.pressed.connect(func() -> void: _show(id))
	b.focus_entered.connect(func() -> void: _show(id))
	return b


func _show(id: String) -> void:
	_selected = id
	for k: String in _cards:
		(_cards[k] as Button).set_pressed_no_signal(k == id)
	var data := EscapeStory.item(id)
	_detail_icon.visible = id != ""
	_detail_icon.set_kind(data.get("icon", ""))
	_detail_name.text = data.get("name", "Nada seleccionado")
	_detail_text.text = data.get("text", "Elige una prueba para examinarla.")
	_use.visible = data.has("use") and not mission.is_done("desbloqueo")
	_use.text = "Desbloquear" if data.get("use", "") == "phone" else "Usar"
