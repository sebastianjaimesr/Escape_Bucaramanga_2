class_name MainMenu
extends Control
## Portada del escape room «Las pruebas del malentendido».
##
## Fondo animado por shader (atardecer sobre una ciudad entre montañas), título,
## introducción, botón principal, continuar la partida guardada, cómo se juega,
## configuración y el expediente del caso (las pruebas que hay que encontrar,
## todavía sin revelar). Solo se muestran datos que corresponden al juego real:
## 1 jugador, 7 objetivos, 3 acertijos y el contrarreloj de 15 minutos.
## En pantallas verticales todo queda en una sola columna.

const PROTOTYPE_SCENE := "res://scenes/world/prototype/prototype_world.tscn"
const BACKDROP_SHADER := "res://src/ui/shaders/title_backdrop.gdshader"
const NARROW := 980.0

var _backdrop: ColorRect
var _backdrop_mat: ShaderMaterial
var _layout: HBoxContainer
var _left: VBoxContainer
var _pages: Dictionary = {}
var _case_file: Control
var _continue: Button
var _play: Button
var _settings: SettingsPanel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = UiStyle.BG
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = load(BACKDROP_SHADER)
	_backdrop.material = _backdrop_mat
	add_child(_backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_layout = HBoxContainer.new()
	_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation", 48)
	scroll.add_child(_layout)

	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.custom_minimum_size = Vector2(520, 0)
	_left.add_theme_constant_override("separation", 0)
	_layout.add_child(_left)
	_pages["home"] = _build_home()
	_pages["modes"] = _build_modes()
	_pages["howto"] = _build_howto()
	_settings = SettingsPanel.new()
	_settings.closed.connect(func() -> void: _show_page("home"))
	_pages["settings"] = _settings
	for k: String in _pages:
		_left.add_child(_pages[k])
	_case_file = _build_case_file()
	_layout.add_child(_case_file)
	_show_page("home", false)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	AudioManager.play_music("menu")
	Settings.changed.connect(func(section: String, key: String, _v: Variant) -> void:
		if section == "interface" and key == "reduce_motion":
			_apply_motion())
	_apply_motion()
	_intro()


func _apply_motion() -> void:
	_backdrop_mat.set_shader_parameter("reduce_motion", 1.0 if bool(Settings.get_value("interface", "reduce_motion")) else 0.0)


func _on_resize() -> void:
	var s := get_viewport_rect().size
	_backdrop_mat.set_shader_parameter("resolution", s)
	_case_file.visible = s.x >= NARROW
	_left.custom_minimum_size.x = minf(560.0, s.x - 64.0) if s.x < NARROW else 520.0


# ---------------------------------------------------------------------------
# Páginas
# ---------------------------------------------------------------------------
func _build_home() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.add_child(UiStyle.overline("Bucaramanga · Santander · Colombia"))
	var t1 := UiStyle.title("Escape de", 30, UiStyle.TEXT_DIM, 6)
	col.add_child(t1)
	var t2 := UiStyle.title("Bucaramanga", 70, UiStyle.TEXT, 3)
	t2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	t2.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(t2)
	var sub := UiStyle.label("Las pruebas del malentendido", 24, UiStyle.ACCENT, 500)
	col.add_child(sub)
	var intro := UiStyle.label("Son las 17:42 y alguien acaba de robar en la manzana. Una foto borrosa, una gorra roja… y tu camiseta también es roja. La policía cree que fuiste tú, Sebastián. Encuentra las pruebas, abre lo que está cerrado y reconstruye con tus amigos lo que de verdad pasó, sin dejarte atrapar.", 18, UiStyle.TEXT_DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(300, 0)
	col.add_child(intro)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	col.add_child(gap)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(buttons)
	_play = UiStyle.button("Comenzar la aventura", 340, "primary")
	_play.add_theme_font_size_override("font_size", 20)
	_play.custom_minimum_size.y = 58
	_play.pressed.connect(func() -> void: _show_page("modes"))
	buttons.add_child(_play)
	_continue = UiStyle.button("Continuar", 340)
	_continue.pressed.connect(_continue_game)
	buttons.add_child(_continue)
	_refresh_continue()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	buttons.add_child(row)
	var howto := UiStyle.button("Cómo se juega", 165)
	howto.pressed.connect(func() -> void: _show_page("howto"))
	row.add_child(howto)
	var settings := UiStyle.button("Configuración", 165)
	settings.pressed.connect(func() -> void: _show_page("settings"))
	row.add_child(settings)
	if not OS.has_feature("web"):
		howto.custom_minimum_size.x = 120
		settings.custom_minimum_size.x = 130
		var quit := UiStyle.button("Salir", 70)
		quit.pressed.connect(func() -> void: get_tree().quit())
		row.add_child(quit)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	col.add_child(chips)
	for c: String in ["1 jugador", "7 objetivos · 3 acertijos", "Libre o contrarreloj de 15 min", "Teclado, mando o táctil"]:
		chips.add_child(_chip(c))
	var foot := UiStyle.label("Versión %s · Hecho con Godot · Lugares inspirados en Bucaramanga, no reproducciones exactas. Policía y nombres comerciales ficticios." % ProjectSettings.get_setting("application/config/version"), 13, Color(UiStyle.TEXT_DIM, 0.85))
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(foot)
	return col


func _chip(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiStyle.box(Color(1, 1, 1, 0.05), UiStyle.PANEL_BORDER, 14)
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(UiStyle.label(text, 14, UiStyle.TEXT, 500))
	return p


func _build_modes() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.add_child(UiStyle.overline("Nueva partida"))
	col.add_child(UiStyle.title("Elige cómo jugar", 40))
	if SaveGame.exists():
		var warn := UiStyle.label("Empezar una partida nueva reemplaza la que tienes guardada.", 15, UiStyle.WARN)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	for id: String in EscapeStory.MODES:
		var m: Dictionary = EscapeStory.MODES[id]
		var b := UiStyle.button("", 0)
		b.custom_minimum_size = Vector2(300, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 20
		inner.offset_right = -20
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		var mode_name := UiStyle.label(m["label"], 22, UiStyle.ACCENT, 700)
		mode_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(mode_name)
		var d := UiStyle.label(m["description"], 15, UiStyle.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(d)
		b.add_child(inner)
		b.pressed.connect(_start.bind(id))
		col.add_child(b)
	var back := UiStyle.button("Volver", 160)
	back.pressed.connect(func() -> void: _show_page("home"))
	col.add_child(back)
	return col


func _build_howto() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.add_child(UiStyle.overline("Instrucciones"))
	col.add_child(UiStyle.title("Cómo se juega", 40))
	var sections := [
		["El caso", "Recorre la manzana y busca los brillos dorados: son pruebas. Examínalas en el inventario, porque sus detalles abren cerraduras. Cuando tengas todo, habla con tus amigos en la zona verde y reconstruyan lo que pasó."],
		["Acertijos", "Una caja de grabación con clave, el patrón del celular de Diaz y la reconstrucción final. Todo lo que necesitas está en las pruebas o en lo que te dicen tus amigos."],
		["La policía", "Si te ven, te persiguen. Agáchate entre los matorrales para esconderte; corriendo cerca te oyen. Si te atrapan, vuelves con tus amigos sin perder nada."],
		["Pistas", "Si te atascas, pide una pista (H o el bombillo). Cada objetivo tiene tres: la última da la solución. No restan tiempo, pero cuentan en el resultado."],
		["Teclado y ratón", "WASD mover · Shift correr · Espacio saltar · C agacharse · E interactuar · Tab inventario · H pista · Esc pausa. Las teclas se pueden cambiar en Configuración."],
		["Pantalla táctil", "Mitad izquierda: mover. Mitad derecha: girar la cámara. Botones Usar, Saltar, Agachar y Correr. Arriba: inventario, pistas, sonido y pausa."],
		["Guardado", "La partida se guarda sola al lograr cada objetivo y al pausar. «Continuar» la retoma desde el punto de inicio con todo lo conseguido."],
	]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for s: Array in sections:
		var head := UiStyle.label(s[0], 18, UiStyle.ACCENT, 600)
		list.add_child(head)
		var body := UiStyle.label(s[1], 16, UiStyle.TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(300, 0)
		list.add_child(body)
	var back := UiStyle.button("Volver", 160)
	back.pressed.connect(func() -> void: _show_page("home"))
	col.add_child(back)
	return col


## Expediente del caso: las pruebas que faltan, como tarjetas sin revelar.
func _build_case_file() -> Control:
	var wrap := CenterContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := UiStyle.panel(24, Color(0.05, 0.055, 0.08, 0.72))
	panel.custom_minimum_size = Vector2(380, 0)
	wrap.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var over := UiStyle.overline("Expediente del caso")
	over.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(over)
	head.add_child(UiStyle.label("17:42", 14, UiStyle.DANGER, 700))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for kind: String in ["photo", "receipt", "box", "usb", "phone_locked", "cap"]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiStyle.box(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.08), 10))
		card.custom_minimum_size = Vector2(102, 102)
		var icon := ItemIcon.new(kind, 54, Color(UiStyle.TEXT, 0.4))
		icon.accent = Color(UiStyle.ACCENT, 0.6)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.add_child(icon)
		grid.add_child(card)
	var note := UiStyle.label("Cinco pruebas repartidas en una manzana. Una cámara que lo grabó todo. Un celular bloqueado. Y tres amigos que te esperan en la zona verde.", 15, UiStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(330, 0)
	col.add_child(note)
	return wrap


func _show_page(id: String, animate: bool = true) -> void:
	for k: String in _pages:
		(_pages[k] as Control).visible = k == id
	var page := _pages[id] as Control
	if animate and not bool(Settings.get_value("interface", "reduce_motion")):
		UiStyle.fade_in(page, 0.0, 0.0, 0.3)
	if id == "home":
		_refresh_continue()
		(_continue if _continue.visible else _play).grab_focus.call_deferred()
	else:
		_focus_first_button.call_deferred(page)


func _focus_first_button(page: Control) -> void:
	for b in page.find_children("*", "BaseButton", true, false):
		if (b as Control).is_visible_in_tree() and (b as Control).focus_mode != Control.FOCUS_NONE:
			(b as Control).grab_focus()
			return


func _intro() -> void:
	if bool(Settings.get_value("interface", "reduce_motion")):
		return
	var home := _pages["home"] as VBoxContainer
	var i := 0
	for c in home.get_children():
		UiStyle.fade_in(c as CanvasItem, 0.15 + i * 0.07, 0.0, 0.6)
		i += 1
	UiStyle.fade_in(_case_file, 0.6, 0.0, 0.9)


func _refresh_continue() -> void:
	var summary := GameSession.saved_summary()
	_continue.visible = summary != ""
	_continue.text = "Continuar · %s" % summary


func _continue_game() -> void:
	GameSession.continue_game()
	SceneLoader.change_scene(PROTOTYPE_SCENE, "Las pruebas del malentendido")


func _start(mode_id: String) -> void:
	GameSession.new_game(mode_id)
	SceneLoader.change_scene(PROTOTYPE_SCENE, "Las pruebas del malentendido")
