class_name Hud
extends CanvasLayer
## HUD del escape room:
## - Arriba a la izquierda: objetivo actual y lista de objetivos (los que todavía
##   no se pueden hacer se ven como «· · ·»).
## - Arriba al centro: reloj (cuenta regresiva en contrarreloj) y alerta de la policía.
## - Arriba a la derecha: botones de inventario, pistas, sonido y pausa (sirven
##   con ratón y con el dedo) y el minimapa.
## - Abajo: ayuda de controles, resistencia, texto de interacción y avisos.
## - Al centro: tarjeta animada cuando se descubre una prueba.

const HINT_TIME := 16.0
const DISCOVERY_TIME := 3.2

var mission: EscapeMission
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
	# Con la pausa o un panel abiertos, los avisos flotantes no deben verse detrás.
	EventBus.pause_changed.connect(func(paused: bool) -> void:
		_discovery.visible = not paused and _discovery_timer > 0.0
		_toast_panel.visible = not paused and toast_label.text != "")
	InputConfig.bindings_changed.connect(_refresh_hint)
	Settings.changed.connect(func(section: String, _k: String, _v: Variant) -> void:
		if section == "audio":
			_sound_icon.set_kind("mute" if AudioManager.is_muted() else "sound"))
	if mission != null:
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
	for s: Dictionary in EscapeStory.STEPS:
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
	UiStyle.place(col, Vector4(0.5, 0, 0.5, 0), Vector4(-210, 20, 210, 140))
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
	hidden_label = _outlined("ESCONDIDO", 17, UiStyle.OK)
	hidden_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hidden_label.visible = false
	col.add_child(hidden_label)
	if mission == null:
		_timer_pill.visible = false


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
	_hint.text = "%s  mover · %s  correr · %s  saltar\n%s  agacharse / esconderse · %s  interactuar\n%s  inventario · %s  pista · Esc  pausa" % [
		move, InputConfig.key_name("run"), InputConfig.key_name("jump"),
		InputConfig.key_name("crouch"), InputConfig.key_name("interact"),
		InputConfig.key_name("inventory"), InputConfig.key_name("hint")]


func _refresh_steps(animate: bool) -> void:
	if mission == null:
		return
	for s: Dictionary in EscapeStory.STEPS:
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
	var level := mission.alert_level()
	match level:
		2:
			alert_label.text = "¡TE ESTÁN PERSIGUIENDO!"
			alert_label.add_theme_color_override("font_color", UiStyle.DANGER)
			alert_label.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		1:
			alert_label.text = "La policía sospecha…"
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
	var data := EscapeStory.item(id)
	_discovery_icon.set_kind(data.get("icon", ""))
	_discovery_name.text = data.get("name", id)
	_discovery_kind.text = "DESBLOQUEADO" if id == "celular" else "PRUEBA NUEVA"
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
