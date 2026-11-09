class_name Hud
extends CanvasLayer
## HUD de los capítulos:
## - Arriba a la izquierda: objetivo actual y lista de objetivos (los que todavía
##   no se pueden hacer se ven como «· · ·»).
## - Arriba al centro: reloj (cuenta regresiva en contrarreloj), oportunidades
##   (corazones), latas, nivel de búsqueda de la policía y la barra especial
##   del capítulo (por ejemplo, la distancia al ladrón).
## - Arriba a la derecha: botones de inventario, pistas, sonido y pausa (sirven
##   con ratón y con el dedo) y el minimapa.
## - Abajo: ayuda de controles, resistencia, texto de interacción y avisos.
## - Abajo a la derecha: nivel, XP y dinero del perfil (con «+XP» al ganar).
## - Al centro: tarjeta animada cuando se descubre una prueba y aviso de nivel nuevo.

const HINT_TIME := 16.0
const DISCOVERY_TIME := 3.2

var mission: Mission
var escape_ui: EscapeUi

var stamina_bar: ProgressBar
var objective: Label
var progress_label: Label
var timer_label: Label
var alert_label: Label
var prompt_label: Label
var toast_label: Label
var hidden_label: Label
var energy_label: Label
var minimap: Minimap

var _root: Control
var _stamina_box: Control
var _hint: Label
var _capture: Label
var _portrait: Label
var _steps_box: VBoxContainer
var _step_rows: Dictionary = {}
var _timer_pill: PanelContainer
var _timer_icon: ItemIcon
var _toast_panel: PanelContainer
var _prompt_panel: PanelContainer
var _discovery: PanelContainer
var _discovery_icon: ItemIcon
var _discovery_name: Label
var _discovery_kind: Label
var _discovery_queue: Array[String] = []
var _discovery_timer := 0.0
var _vignette: TextureRect
var _sound_icon: ItemIcon
var _bag_badge: Label
var _hint_timer := HINT_TIME
var _stamina_visible_timer := 0.0
var _toast_timer := 0.0
var _toasts: Array[String] = []
var _last_alert := 0
var _hearts: HBoxContainer
var _cans_label: Label
var _cans_box: HBoxContainer
var _wanted_box: HBoxContainer
var _wanted_pips: Array[Panel] = []
var _wanted_name: Label
var _meter_box: VBoxContainer
var _meter_label: Label
var _meter_bar: ProgressBar
var _level_label: Label
var _xp_bar: ProgressBar
var _money_label: Label
var _xp_float: Label
var _banner: PanelContainer
var _banner_title: Label
var _banner_text: Label
var _last_lives := -99
var _last_wanted := -1
# Cinemáticas (franjas negras) y título de zona.
var _letterbox: Control
var _bars: Array[ColorRect] = []
var _caption: Label
var _skip_hint: Label
var _zone_card: VBoxContainer
var _zone_title: Label
var _zone_sub: Label
var _zone_line: ColorRect
var _zone_tween: Tween


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_vignette()
	_build_bottom_left()
	_build_objective()
	_build_timer()
	_build_top_right()
	_build_bottom_center()
	_build_discovery()
	_build_profile()
	_build_banner()
	_build_cinematic()
	_build_zone_card()
	_capture = _outlined("Haz clic para controlar la cámara", 18)
	UiStyle.place(_capture, Vector4(0.5, 1, 0.5, 1), Vector4(-250, -230, 250, -200))
	_capture.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_capture)
	_portrait = _outlined("Gira el teléfono: se juega mejor en horizontal.", 18, UiStyle.WARN)
	UiStyle.place(_portrait, Vector4(0, 0.5, 1, 0.5), Vector4(20, -20, -20, 20))
	_portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_portrait)
	add_child(PerformanceOverlay.new())
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.interaction_prompt_changed.connect(_on_prompt)
	EventBus.notify.connect(_on_notify)
	EventBus.hidden_changed.connect(_on_hidden)
	EventBus.cinematic_changed.connect(_on_cinematic)
	EventBus.zone_entered.connect(show_zone)
	# Con la pausa o un panel abiertos, los avisos flotantes no deben verse detrás.
	EventBus.pause_changed.connect(func(paused: bool) -> void:
		_discovery.visible = not paused and _discovery_timer > 0.0
		_toast_panel.visible = not paused and toast_label.text != "")
	InputConfig.bindings_changed.connect(_refresh_hint)
	Settings.changed.connect(func(section: String, _k: String, _v: Variant) -> void:
		if section == "audio":
			_sound_icon.set_kind("mute" if AudioManager.is_muted() else "sound"))
	PlayerProfile.xp_gained.connect(_on_xp)
	PlayerProfile.level_up.connect(_on_level_up)
	PlayerProfile.money_changed.connect(func(_m: int) -> void: _refresh_profile())
	PlayerProfile.achievement_unlocked.connect(_on_achievement)
	_refresh_profile()
	if mission != null:
		mission.checkpoint_reached.connect(func(_i: int) -> void:
			AudioManager.sfx("checkpoint")
			_on_notify("Punto de control guardado. Si te atrapan, vuelves aquí."))
		mission.discovered.connect(_on_discovered)
		mission.step_completed.connect(func(_id: String) -> void: _refresh_steps(true))
		mission.inventory.changed.connect(_refresh_badge)
		_refresh_steps(false)
		_refresh_badge()
	_refresh_hint()


# ---------------------------------------------------------------------------
# Construcción
# ---------------------------------------------------------------------------
func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(UiStyle.DANGER, 0.0))
	g.set_color(1, Color(UiStyle.DANGER, 0.55))
	g.set_offset(0, 0.55)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)


func _build_bottom_left() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.place(col, Vector4(0, 1, 0, 1), Vector4(28, -330, 360, -28))
	_root.add_child(col)
	_hint = _outlined("", 15, UiStyle.TEXT)
	col.add_child(_hint)
	energy_label = _outlined("", 14, Color(0.55, 0.85, 1.0))
	col.add_child(energy_label)
	_stamina_box = VBoxContainer.new()
	_stamina_box.add_child(UiStyle.overline("Resistencia", UiStyle.TEXT_DIM, 11))
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(220, 8)
	stamina_bar.max_value = PlayerController.MAX_STAMINA
	stamina_bar.value = PlayerController.MAX_STAMINA
	stamina_bar.show_percentage = false
	UiStyle.style_bar(stamina_bar, UiStyle.OK)
	_stamina_box.add_child(stamina_bar)
	_stamina_box.modulate.a = 0.0
	col.add_child(_stamina_box)


func _build_objective() -> void:
	var panel := UiStyle.panel(18, Color(0.04, 0.045, 0.065, 0.82))
	UiStyle.place(panel, Vector4(0, 0, 0, 0), Vector4(20, 20, 380, 20))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var over := UiStyle.overline("Objetivo")
	over.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(over)
	progress_label = UiStyle.label("", 13, UiStyle.TEXT_DIM, 600)
	head.add_child(progress_label)
	objective = UiStyle.label("", 18, UiStyle.TEXT, 600)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size = Vector2(320, 0)
	col.add_child(objective)
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(1, 1, 1, 0.1)
	sep.add_theme_stylebox_override("separator", line)
	col.add_child(sep)
	_steps_box = VBoxContainer.new()
	_steps_box.add_theme_constant_override("separation", 3)
	col.add_child(_steps_box)
	if mission == null:
		panel.visible = false
		return
	for s: Dictionary in mission.step_list():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var mark := ItemIcon.new("dot", 18, UiStyle.TEXT_DIM)
		row.add_child(mark)
		var l := UiStyle.label("", 14, UiStyle.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_steps_box.add_child(row)
		_step_rows[s["id"]] = [row, mark, l]


func _build_timer() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.place(col, Vector4(0.5, 0, 0.5, 0), Vector4(-210, 20, 210, 200))
	_root.add_child(col)
	_timer_pill = PanelContainer.new()
	var sb := UiStyle.box(Color(0.04, 0.045, 0.065, 0.82), UiStyle.PANEL_BORDER, 22)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_timer_pill.add_theme_stylebox_override("panel", sb)
	_timer_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_timer_pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_timer_pill.add_child(row)
	_timer_icon = ItemIcon.new("clock", 24)
	row.add_child(_timer_icon)
	timer_label = UiStyle.label("0:00", 22, UiStyle.TEXT, 600)
	row.add_child(timer_label)
	alert_label = _outlined("", 22)
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(alert_label)
	var status := HBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 14)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(status)
	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 2)
	_hearts.tooltip_text = "Oportunidades: si te atrapan pierdes una"
	status.add_child(_hearts)
	_cans_box = HBoxContainer.new()
	_cans_box.add_theme_constant_override("separation", 4)
	_cans_box.add_child(ItemIcon.new("can", 22))
	_cans_label = _outlined("", 16)
	_cans_box.add_child(_cans_label)
	status.add_child(_cans_box)
	_wanted_box = HBoxContainer.new()
	_wanted_box.add_theme_constant_override("separation", 3)
	_wanted_box.add_child(ItemIcon.new("star", 20, UiStyle.TEXT_DIM))
	for i in 4:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14, 10)
		pip.add_theme_stylebox_override("panel", UiStyle.box(Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.25), 3))
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wanted_pips.append(pip)
		_wanted_box.add_child(pip)
	_wanted_name = _outlined("", 14, UiStyle.TEXT_DIM)
	_wanted_box.add_child(_wanted_name)
	status.add_child(_wanted_box)
	_meter_box = VBoxContainer.new()
	_meter_box.add_theme_constant_override("separation", 3)
	_meter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_label = _outlined("", 15)
	_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meter_box.add_child(_meter_label)
	_meter_bar = ProgressBar.new()
	_meter_bar.custom_minimum_size = Vector2(260, 8)
	_meter_bar.max_value = 1.0
	_meter_bar.show_percentage = false
	_meter_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_bar(_meter_bar, UiStyle.OK)
	_meter_box.add_child(_meter_bar)
	_meter_box.visible = false
	col.add_child(_meter_box)
	hidden_label = _outlined("ESCONDIDO", 17, UiStyle.OK)
	hidden_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hidden_label.visible = false
	col.add_child(hidden_label)
	if mission == null:
		_timer_pill.visible = false
		status.visible = false


## Abajo a la derecha: nivel, barra de XP y dinero.
func _build_profile() -> void:
	var panel := UiStyle.panel(12, Color(0.04, 0.045, 0.065, 0.78))
	UiStyle.place(panel, Vector4(1, 1, 1, 1), Vector4(-250, -86, -20, -20))
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	_level_label = UiStyle.label("", 14, UiStyle.TEXT, 600)
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_level_label)
	row.add_child(ItemIcon.new("coin", 18))
	_money_label = UiStyle.label("", 14, UiStyle.ACCENT, 600)
	row.add_child(_money_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(200, 6)
	_xp_bar.max_value = 1.0
	_xp_bar.show_percentage = false
	UiStyle.style_bar(_xp_bar, UiStyle.ACCENT)
	col.add_child(_xp_bar)
	_xp_float = _outlined("", 16, UiStyle.ACCENT)
	UiStyle.place(_xp_float, Vector4(1, 1, 1, 1), Vector4(-250, -120, -20, -92))
	_xp_float.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xp_float.modulate.a = 0.0
	_root.add_child(_xp_float)


## Aviso grande al centro: nivel nuevo o logro.
func _build_banner() -> void:
	_banner = UiStyle.panel(22, Color(0.05, 0.055, 0.08, 0.95))
	(_banner.get_theme_stylebox("panel") as StyleBoxFlat).border_color = UiStyle.ACCENT
	UiStyle.place(_banner, Vector4(0.5, 0.42, 0.5, 0.42), Vector4(-220, -56, 220, 56))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_child(col)
	_banner_title = UiStyle.label("", 26, UiStyle.ACCENT, 700)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_banner_title)
	_banner_text = UiStyle.label("", 15, UiStyle.TEXT)
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.custom_minimum_size = Vector2(380, 0)
	col.add_child(_banner_text)
	_banner.visible = false


func _build_top_right() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	UiStyle.place(col, Vector4(1, 0, 1, 0), Vector4(-20 - Minimap.SIZE - 40, 20, -20, 300))
	_root.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var bag := _icon_button("bag", "Inventario (%s)" % InputConfig.key_name("inventory"), func() -> void:
		if escape_ui != null:
			escape_ui.open_panel("inventory"))
	row.add_child(bag)
	_bag_badge = UiStyle.label("", 12, UiStyle.INK, 700)
	_bag_badge.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 9))
	(_bag_badge.get_theme_stylebox("normal") as StyleBoxFlat).set_content_margin_all(2)
	_bag_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bag_badge.custom_minimum_size = Vector2(18, 18)
	_bag_badge.position = Vector2(34, -4)
	bag.add_child(_bag_badge)
	row.add_child(_icon_button("bulb", "Pedir una pista (%s)" % InputConfig.key_name("hint"), func() -> void:
		if escape_ui != null:
			escape_ui.open_panel("hints")))
	var sound := _icon_button("mute" if AudioManager.is_muted() else "sound", "Silenciar o activar el sonido", func() -> void:
		AudioManager.toggle_mute())
	_sound_icon = sound.get_child(0) as ItemIcon
	row.add_child(sound)
	row.add_child(_icon_button("pause", "Pausa (Esc)", func() -> void:
		var world := get_parent() as PrototypeWorld
		if world != null and not world.modal_open:
			world.pause_menu.open()))
	minimap = Minimap.new()
	minimap.mission = mission
	minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(minimap)
	if mission == null:
		row.visible = false
		minimap.visible = false


func _icon_button(kind: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(50, 50)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE   # Que no robe el teclado al jugar.
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var round := UiStyle.box(Color(0.04, 0.045, 0.065, 0.82), UiStyle.PANEL_BORDER, 25)
	b.add_theme_stylebox_override("normal", round)
	b.add_theme_stylebox_override("hover", UiStyle.box(Color(UiStyle.ACCENT, 0.25), UiStyle.ACCENT, 25))
	b.add_theme_stylebox_override("pressed", UiStyle.box(Color(UiStyle.ACCENT, 0.4), UiStyle.ACCENT, 25))
	var icon := ItemIcon.new(kind, 30)
	icon.position = Vector2(10, 10)
	b.add_child(icon)
	b.pressed.connect(func() -> void:
		AudioManager.sfx("click")
		action.call())
	return b


func _build_bottom_center() -> void:
	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.04, 0.045, 0.065, 0.85), Color(UiStyle.ACCENT, 0.6), 22))
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.place(_prompt_panel, Vector4(0.5, 1, 0.5, 1), Vector4(-300, -196, 300, -160))
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(_prompt_panel)
	prompt_label = UiStyle.label("", 18, UiStyle.TEXT, 500)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(prompt_label)
	_prompt_panel.visible = false

	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.04, 0.045, 0.065, 0.88), UiStyle.PANEL_BORDER, 10))
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.place(_toast_panel, Vector4(0.5, 1, 0.5, 1), Vector4(-380, -140, 380, -90))
	_root.add_child(_toast_panel)
	toast_label = UiStyle.label("", 17)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_panel.add_child(toast_label)
	_toast_panel.visible = false


func _build_discovery() -> void:
	_discovery = UiStyle.panel(20, Color(0.05, 0.055, 0.08, 0.95))
	(_discovery.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(UiStyle.ACCENT, 0.8)
	UiStyle.place(_discovery, Vector4(0.5, 0.28, 0.5, 0.28), Vector4(-210, -60, 210, 60))
	_discovery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_discovery)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_discovery.add_child(row)
	_discovery_icon = ItemIcon.new("photo", 64, UiStyle.TEXT)
	row.add_child(_discovery_icon)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_discovery_kind = UiStyle.overline("Prueba nueva")
	col.add_child(_discovery_kind)
	_discovery_name = UiStyle.label("", 20, UiStyle.TEXT, 600)
	_discovery_name.custom_minimum_size = Vector2(280, 0)
	_discovery_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_discovery_name)
	col.add_child(UiStyle.label("Revísala en el inventario (%s)" % InputConfig.key_name("inventory"), 13, UiStyle.TEXT_DIM))
	_discovery.visible = false


func _outlined(text: String, size: int, color: Color = UiStyle.TEXT) -> Label:
	var l := UiStyle.label(text, size, color, 500)
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ---------------------------------------------------------------------------
# Actualización
# ---------------------------------------------------------------------------
func _refresh_hint() -> void:
	var world := get_parent() as PrototypeWorld
	if world != null and world.uses_touch():
		_hint.text = ""
		return
	var move := "%s%s%s%s" % [InputConfig.key_name("move_forward"), InputConfig.key_name("move_left"),
			InputConfig.key_name("move_back"), InputConfig.key_name("move_right")]
	_hint.text = "%s  mover · %s  correr · %s  saltar / trepar\n%s  agacharse / deslizarse (corriendo) · %s  interactuar\n%s  lanzar lata · %s  disfraz · %s  inventario · %s  pista · Esc  pausa" % [
		move, InputConfig.key_name("run"), InputConfig.key_name("jump"),
		InputConfig.key_name("crouch"), InputConfig.key_name("interact"),
		InputConfig.key_name("throw"), InputConfig.key_name("gadget"),
		InputConfig.key_name("inventory"), InputConfig.key_name("hint")]


func _refresh_steps(animate: bool) -> void:
	if mission == null:
		return
	for s: Dictionary in mission.step_list():
		var id: String = s["id"]
		var parts: Array = _step_rows[id]
		var mark: ItemIcon = parts[1]
		var l: Label = parts[2]
		if mission.is_done(id):
			mark.set_kind("check")
			mark.color = UiStyle.OK
			l.text = s["title"]
			l.add_theme_color_override("font_color", Color(UiStyle.TEXT_DIM, 0.8))
		elif mission.is_available(id):
			mark.set_kind("dot")
			mark.color = UiStyle.ACCENT
			l.text = s["title"]
			l.add_theme_color_override("font_color", UiStyle.TEXT)
		else:
			mark.set_kind("lock")
			mark.color = Color(UiStyle.TEXT_DIM, 0.6)
			l.text = "· · ·"
			l.add_theme_color_override("font_color", Color(UiStyle.TEXT_DIM, 0.6))
		mark.queue_redraw()
	if animate:
		AudioManager.sfx("pickup")


func _refresh_badge() -> void:
	var n := mission.inventory.items.size()
	_bag_badge.text = str(n)
	_bag_badge.visible = n > 0


func _process(delta: float) -> void:
	var world := get_parent() as PrototypeWorld
	var touch := world != null and world.uses_touch()
	_capture.visible = not touch and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused \
			and mission != null and not mission.finished
	var vp := _root.get_viewport_rect().size
	_portrait.visible = touch and vp.y > vp.x
	if _hint_timer > 0.0:
		_hint_timer -= delta
		_hint.modulate.a = clampf(_hint_timer / 2.0, 0.0, 1.0)
	_stamina_visible_timer -= delta
	var target := 1.0 if _stamina_visible_timer > 0.0 else 0.0
	_stamina_box.modulate.a = move_toward(_stamina_box.modulate.a, target, delta * 3.0)
	_update_mission_ui(delta)
	_update_discovery(delta)


func _on_stamina_changed(value: float, max_value: float, exhausted: bool) -> void:
	stamina_bar.value = value
	UiStyle.style_bar(stamina_bar, UiStyle.WARN if exhausted else UiStyle.OK)
	# La barra solo aparece mientras cambia y un momento después de llenarse.
	_stamina_visible_timer = 1.5 if value >= max_value else 3.0


func _update_mission_ui(delta: float) -> void:
	if mission == null:
		return
	objective.text = mission.objective_text()
	progress_label.text = mission.progress_text()
	_update_timer()
	_update_status()
	var level := mission.alert_level()
	match level:
		2:
			alert_label.text = "¡TE ESTÁN PERSIGUIENDO!"
			alert_label.add_theme_color_override("font_color", UiStyle.DANGER)
			alert_label.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		1:
			alert_label.text = "Te están buscando…"
			alert_label.add_theme_color_override("font_color", UiStyle.WARN)
			alert_label.modulate.a = 1.0
		_:
			alert_label.text = ""
	if level != _last_alert:
		if level == 2:
			AudioManager.sfx("alert")
		AudioManager.set_chase(level)
		_last_alert = level
	var vig := 0.0 if level < 2 else 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	_vignette.modulate.a = move_toward(_vignette.modulate.a, vig, delta * 2.0)
	var p := mission.world.player
	if p.energy_timer > 0.0:
		energy_label.text = "Granizado: resistencia sin límite (%d s)" % ceili(p.energy_timer)
	else:
		energy_label.text = ""
	if not hidden_label.visible and p.in_cover() and not p.crouching and prompt_label.text == "":
		_set_prompt("%s  agáchate para esconderte" % _key("crouch"))
		prompt_label.set_meta("cover_hint", true)
	elif prompt_label.has_meta("cover_hint") and (not p.in_cover() or p.crouching):
		_set_prompt("")
		prompt_label.remove_meta("cover_hint")
	if _toast_timer > 0.0:
		_toast_timer -= delta
		_toast_panel.modulate.a = clampf(_toast_timer / 0.6, 0.0, 1.0)
		if _toast_timer <= 0.0:
			_next_toast()


func _update_timer() -> void:
	var secs: float
	if mission.time_limit > 0.0:
		secs = ceilf(mission.time_left())
		var c := UiStyle.TEXT
		if secs <= 60.0:
			c = UiStyle.DANGER
			timer_label.modulate.a = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
		elif secs <= 180.0:
			c = UiStyle.WARN
		timer_label.add_theme_color_override("font_color", c)
		_timer_icon.color = c
	else:
		secs = mission.total_time()
	timer_label.text = "%d:%02d" % [int(secs) / 60, int(secs) % 60]


func _key(action: String) -> String:
	var world := get_parent() as PrototypeWorld
	if world != null and world.uses_touch():
		return {"interact": "Usar", "crouch": "Agachar"}.get(action, "")
	return InputConfig.key_name(action)


func _set_prompt(text: String) -> void:
	prompt_label.text = text
	_prompt_panel.visible = text != ""


func _on_prompt(text: String) -> void:
	prompt_label.remove_meta("cover_hint")
	_set_prompt("" if text == "" else "[%s]  %s" % [_key("interact"), text])


func _on_notify(text: String) -> void:
	_toasts.append(text)
	if _toast_timer <= 0.0:
		_next_toast()


func _next_toast() -> void:
	if _toasts.is_empty():
		toast_label.text = ""
		_toast_panel.visible = false
		return
	toast_label.text = _toasts.pop_front()
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_timer = clampf(2.5 + toast_label.text.length() * 0.035, 3.5, 7.0)


func _on_hidden(value: bool) -> void:
	hidden_label.visible = value


func _on_discovered(item_id: String) -> void:
	_discovery_queue.append(item_id)
	if _discovery_timer <= 0.0:
		_show_next_discovery()


func _show_next_discovery() -> void:
	if _discovery_queue.is_empty():
		_discovery.visible = false
		return
	var id: String = _discovery_queue.pop_front()
	var data := mission.item_data(id)
	_discovery_icon.set_kind(data.get("icon", ""))
	_discovery_name.text = data.get("name", id)
	_discovery_kind.text = "DESBLOQUEADO" if id == "celular" else ("PRUEBA NUEVA" if mission is EscapeMission else "OBJETO NUEVO")
	_discovery.visible = true
	_discovery_timer = DISCOVERY_TIME
	AudioManager.sfx("discover")
	_discovery.pivot_offset = _discovery.size * 0.5
	if not bool(Settings.get_value("interface", "reduce_motion")):
		_discovery.scale = Vector2(0.85, 0.85)
		_discovery.modulate.a = 0.0
		var tw := _discovery.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_discovery, "scale", Vector2.ONE, 0.4)
		tw.tween_property(_discovery, "modulate:a", 1.0, 0.25)
	else:
		_discovery.modulate.a = 1.0


func _update_discovery(delta: float) -> void:
	if _discovery_timer <= 0.0:
		return
	_discovery_timer -= delta
	if _discovery_timer < 0.4:
		_discovery.modulate.a = clampf(_discovery_timer / 0.4, 0.0, 1.0)
	if _discovery_timer <= 0.0:
		_show_next_discovery()


# ---------------------------------------------------------------------------
# Estado del capítulo y del perfil
# ---------------------------------------------------------------------------
func _update_status() -> void:
	# Corazones: solo en los capítulos con oportunidades limitadas.
	if mission.lives != _last_lives:
		_last_lives = mission.lives
		for c in _hearts.get_children():
			c.queue_free()
		_hearts.visible = mission.max_lives > 0
		for i in maxi(0, mission.max_lives):
			var full := i < mission.lives
			_hearts.add_child(ItemIcon.new("heart" if full else "heart_empty", 22, UiStyle.DANGER if full else UiStyle.TEXT_DIM))
	var p := mission.world.player
	_cans_label.text = "×%d" % p.cans
	_cans_box.tooltip_text = "Latas para distraer (%s)" % InputConfig.key_name("throw")
	_cans_box.modulate.a = 1.0 if p.cans > 0 else 0.45
	var wl := mission.wanted.level if mission.wanted != null else 0
	if wl != _last_wanted:
		_last_wanted = wl
		var colors := [UiStyle.OK, UiStyle.WARN, UiStyle.WARN, UiStyle.DANGER, UiStyle.DANGER]
		for i in _wanted_pips.size():
			var on := i < wl
			_wanted_pips[i].add_theme_stylebox_override("panel", UiStyle.box(
					Color(colors[wl], 0.9) if on else Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.25), 3))
		_wanted_name.text = WantedSystem.NAMES[wl]
		_wanted_name.add_theme_color_override("font_color", colors[wl] if wl > 0 else UiStyle.TEXT_DIM)
	var meter := mission.hud_meter()
	_meter_box.visible = not meter.is_empty()
	if not meter.is_empty():
		_meter_label.text = str(meter.get("label", ""))
		_meter_bar.value = float(meter.get("value", 0.0))
		var danger := float(meter.get("danger", 0.0))
		UiStyle.style_bar(_meter_bar, UiStyle.DANGER if danger > 0.5 else (UiStyle.WARN if danger > 0.0 else UiStyle.OK))


func _refresh_profile() -> void:
	_level_label.text = "Nv %d · %s" % [PlayerProfile.level(), PlayerProfile.level_name()]
	_money_label.text = "$%d" % PlayerProfile.money
	_xp_bar.value = PlayerProfile.level_progress()


func _on_xp(amount: int, _reason: String) -> void:
	_refresh_profile()
	_xp_float.text = "+%d XP" % amount
	_xp_float.modulate.a = 1.0
	var tw := _xp_float.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_xp_float, "modulate:a", 0.0, 0.6)


func _on_level_up(level: int) -> void:
	_refresh_profile()
	AudioManager.sfx("levelup")
	_show_banner("¡NIVEL %d!" % level, "Ahora eres %s. Ganaste un punto de habilidad: úsalo en el menú de la pausa o en la portada." % Chapters.level_name(level))


func _on_achievement(id: String) -> void:
	var a: Dictionary = Chapters.ACHIEVEMENTS.get(id, {})
	AudioManager.sfx("achievement")
	_on_notify("Logro: %s · %s" % [a.get("name", id), a.get("text", "")])


# ---------------------------------------------------------------------------
# Cinemáticas y zonas
# ---------------------------------------------------------------------------
func _build_cinematic() -> void:
	_letterbox = Control.new()
	_letterbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letterbox.visible = false
	add_child(_letterbox)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if top:
			UiStyle.place(bar, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 0))
		else:
			UiStyle.place(bar, Vector4(0, 1, 1, 1), Vector4(0, 0, 0, 0))
		_letterbox.add_child(bar)
		_bars.append(bar)
	_caption = _outlined("", 22)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.place(_caption, Vector4(0.5, 1, 0.5, 1), Vector4(-460, -150, 460, -96))
	_letterbox.add_child(_caption)
	_skip_hint = UiStyle.label("Interactuar, Saltar o clic para saltar", 13, UiStyle.TEXT_DIM)
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.place(_skip_hint, Vector4(1, 1, 1, 1), Vector4(-360, -40, -24, -16))
	_letterbox.add_child(_skip_hint)


func _on_cinematic(active: bool, caption: String) -> void:
	var bar_h := 84.0
	if active:
		_root.visible = false
		if not _letterbox.visible:
			_letterbox.visible = true
			for i in _bars.size():
				var b := _bars[i]
				b.offset_top = 0.0 if i == 0 else 0.0
				b.offset_bottom = 0.0
				var tw := b.create_tween()
				if i == 0:
					tw.tween_property(b, "offset_bottom", bar_h, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				else:
					tw.tween_property(b, "offset_top", -bar_h, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_caption.text = caption
		_caption.modulate.a = 0.0
		_caption.create_tween().tween_property(_caption, "modulate:a", 1.0, 0.5)
	else:
		_letterbox.visible = false
		_root.visible = true


func _build_zone_card() -> void:
	_zone_card = VBoxContainer.new()
	_zone_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_zone_card.add_theme_constant_override("separation", 6)
	UiStyle.place(_zone_card, Vector4(0.5, 0.2, 0.5, 0.2), Vector4(-360, -50, 360, 70))
	_root.add_child(_zone_card)
	_zone_sub = UiStyle.overline("", UiStyle.ACCENT, 14)
	_zone_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_card.add_child(_zone_sub)
	_zone_title = UiStyle.title("", 44, UiStyle.TEXT, 3)
	_zone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_title.add_theme_constant_override("outline_size", 10)
	_zone_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_zone_card.add_child(_zone_title)
	_zone_line = ColorRect.new()
	_zone_line.color = UiStyle.ACCENT
	_zone_line.custom_minimum_size = Vector2(0, 2)
	_zone_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_zone_card.add_child(_zone_line)
	_zone_card.modulate.a = 0.0
	_zone_card.visible = false


## Título grande al descubrir un lugar («Parque de las Palmas»).
func show_zone(title: String, subtitle: String) -> void:
	_zone_title.text = title.to_upper()
	_zone_sub.text = subtitle.to_upper()
	_zone_card.visible = true
	_zone_card.modulate.a = 0.0
	_zone_line.custom_minimum_size.x = 0.0
	AudioManager.sfx("zone")
	if _zone_tween != null:
		_zone_tween.kill()
	_zone_tween = _zone_card.create_tween()
	_zone_tween.tween_property(_zone_card, "modulate:a", 1.0, 0.6)
	_zone_tween.parallel().tween_property(_zone_line, "custom_minimum_size:x", 260.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zone_tween.tween_interval(2.4)
	_zone_tween.tween_property(_zone_card, "modulate:a", 0.0, 0.8)
	_zone_tween.tween_callback(func() -> void: _zone_card.visible = false)


func _show_banner(title: String, text: String) -> void:
	_banner_title.text = title
	_banner_text.text = text
	_banner.visible = true
	_banner.modulate.a = 1.0
	var tw := _banner.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void: _banner.visible = false)
