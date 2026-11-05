class_name ModalPanel
extends CanvasLayer
## Base de los paneles del escape room (inventario, pistas, cerraduras,
## reconstrucción): oscurece el juego, congela el mundo mientras está abierto
## (el reloj de la misión sigue), se cierra con Esc o con el botón Cerrar y
## devuelve el foco al juego. Las subclases llenan `body`.

signal closed

var world: PrototypeWorld
var card: PanelContainer
var body: VBoxContainer
var header: HBoxContainer
var title_label: Label
var subtitle_label: Label
var close_button: Button
var is_open := false
## Acción que abre este panel y que también lo cierra (Tab el inventario, H las
## pistas). Se atiende en _input para que Tab no se pierda moviendo el foco.
var toggle_action := ""
var _dim: ColorRect


func _init(w: PrototypeWorld) -> void:
	world = w


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.012, 0.02, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	card = UiStyle.panel(28)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	col.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)
	subtitle_label = UiStyle.overline("")
	titles.add_child(subtitle_label)
	title_label = UiStyle.title("", 28, UiStyle.TEXT, 2)
	titles.add_child(title_label)
	close_button = UiStyle.button("Cerrar", 120)
	close_button.tooltip_text = "Cerrar (Esc)"
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(close)
	header.add_child(close_button)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)
	build()
	visible = false


## Las subclases construyen su contenido aquí.
func build() -> void:
	pass


## Las subclases actualizan su contenido aquí antes de mostrarse.
func refresh() -> void:
	pass


func open() -> void:
	if is_open:
		return
	is_open = true
	refresh()
	visible = true
	world.open_modal(self)
	AudioManager.sfx("open")
	if not bool(Settings.get_value("interface", "reduce_motion")):
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.96, 0.96)
		card.modulate.a = 0.0
		var tw := card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.22)
		tw.tween_property(card, "modulate:a", 1.0, 0.18)
	_focus_first.call_deferred()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	world.close_modal(self)
	closed.emit()


func _focus_first() -> void:
	var f := first_focus()
	if f != null and f.is_visible_in_tree():
		f.grab_focus()


func first_focus() -> Control:
	return close_button


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and not event.echo
			and (event as InputEventKey).keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()
		return
	if toggle_action != "" and event.is_action_pressed(toggle_action) and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()
		return
	handle_input(event)


## Teclas propias de cada panel (dígitos del teclado, etc.).
func handle_input(_event: InputEvent) -> void:
	pass


## Destello de color sobre la tarjeta: verde al acertar, rojo al fallar.
func flash(c: Color) -> void:
	var sb := (card.get_theme_stylebox("panel") as StyleBoxFlat)
	if sb == null:
		return
	var base := UiStyle.PANEL_BORDER
	sb.border_color = c
	sb.set_border_width_all(2)
	var tw := card.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		sb.border_color = base
		sb.set_border_width_all(1))
