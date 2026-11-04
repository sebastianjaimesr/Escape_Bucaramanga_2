class_name Hud
extends CanvasLayer
## HUD del prototipo: resistencia, ayuda de controles, aviso para capturar el
## ratón, objetivo de la misión, alerta de la policía, texto de interacción,
## avisos, indicador de escondite y minimapa.
## El HUD definitivo (mapa completo, diario, inventario…) llega en la Fase 9.

const HINT_TIME := 14.0

var stamina_bar: ProgressBar
var _stamina_box: Control
var _hint: Label
var _capture: Label
var _hint_timer := HINT_TIME
var _stamina_visible_timer := 0.0

var mission: EscapeMission
var objective: Label
var evidence_label: Label
var alert_label: Label
var prompt_label: Label
var toast_label: Label
var hidden_label: Label
var energy_label: Label
var minimap: Minimap
var _toast_timer := 0.0
var _toasts: Array[String] = []


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_stamina_box = VBoxContainer.new()
	UiStyle.place(_stamina_box, Vector4(0, 1, 0, 1), Vector4(28, -72, 260, -28))
	root.add_child(_stamina_box)
	_stamina_box.add_child(UiStyle.label("RESISTENCIA", 12, UiStyle.TEXT_DIM))
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(220, 8)
	stamina_bar.max_value = PlayerController.MAX_STAMINA
	stamina_bar.value = PlayerController.MAX_STAMINA
	stamina_bar.show_percentage = false
	UiStyle.style_bar(stamina_bar, UiStyle.OK)
	_stamina_box.add_child(stamina_bar)
	_stamina_box.modulate.a = 0.0

	_hint = UiStyle.label("", 15, UiStyle.TEXT)
	_hint.position = Vector2(28, 24)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	root.add_child(_hint)
	_refresh_hint()

	_capture = UiStyle.label("Haz clic para controlar la cámara", 18, UiStyle.TEXT)
	UiStyle.place(_capture, Vector4(0.5, 1, 0.5, 1), Vector4(-250, -150, 250, -110))
	_capture.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture.add_theme_constant_override("outline_size", 6)
	_capture.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	root.add_child(_capture)

	_build_mission_ui(root)
	add_child(PerformanceOverlay.new())
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.interaction_prompt_changed.connect(_on_prompt)
	EventBus.notify.connect(_on_notify)
	EventBus.hidden_changed.connect(_on_hidden)
	InputConfig.bindings_changed.connect(_refresh_hint)


func _refresh_hint() -> void:
	var move := "%s%s%s%s" % [InputConfig.key_name("move_forward"), InputConfig.key_name("move_left"),
			InputConfig.key_name("move_back"), InputConfig.key_name("move_right")]
	_hint.text = "%s  mover\n%s  correr\n%s  saltar\n%s  agacharse / esconderse\n%s  interactuar\nRatón  cámara\nEsc  pausa\n%s  rendimiento" % [
		move, InputConfig.key_name("run"), InputConfig.key_name("jump"),
		InputConfig.key_name("crouch"), InputConfig.key_name("interact"), InputConfig.key_name("toggle_fps")]


func _process(delta: float) -> void:
	_capture.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused
	if _hint_timer > 0.0:
		_hint_timer -= delta
		_hint.modulate.a = clampf(_hint_timer / 2.0, 0.0, 1.0)
	_stamina_visible_timer -= delta
	var target := 1.0 if _stamina_visible_timer > 0.0 else 0.0
	_stamina_box.modulate.a = move_toward(_stamina_box.modulate.a, target, delta * 3.0)
	_update_mission_ui(delta)


func _on_stamina_changed(value: float, max_value: float, exhausted: bool) -> void:
	stamina_bar.value = value
	UiStyle.style_bar(stamina_bar, UiStyle.WARN if exhausted else UiStyle.OK)
	# La barra solo aparece mientras cambia y un momento después de llenarse.
	_stamina_visible_timer = 1.5 if value >= max_value else 3.0


# ---------------------------------------------------------------------------
# Misión, policía e interacción
# ---------------------------------------------------------------------------
func _build_mission_ui(root: Control) -> void:
	var panel := UiStyle.panel()
	UiStyle.place(panel, Vector4(1, 0, 1, 0), Vector4(-420, 20, -20, 20))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(UiStyle.label("OBJETIVO", 12, UiStyle.ACCENT))
	objective = UiStyle.label("", 16)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size = Vector2(350, 0)
	col.add_child(objective)
	evidence_label = UiStyle.label("", 14, UiStyle.WARN)
	col.add_child(evidence_label)

	alert_label = _outlined("", 24)
	UiStyle.place(alert_label, Vector4(0.5, 0, 0.5, 0), Vector4(-300, 22, 300, 60))
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(alert_label)

	hidden_label = _outlined("ESCONDIDO", 18, UiStyle.OK)
	UiStyle.place(hidden_label, Vector4(0.5, 0, 0.5, 0), Vector4(-150, 62, 150, 90))
	hidden_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hidden_label.visible = false
	root.add_child(hidden_label)

	prompt_label = _outlined("", 20)
	UiStyle.place(prompt_label, Vector4(0.5, 1, 0.5, 1), Vector4(-300, -200, 300, -168))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_label)

	toast_label = _outlined("", 18)
	UiStyle.place(toast_label, Vector4(0.5, 1, 0.5, 1), Vector4(-420, -110, 420, -60))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(toast_label)

	energy_label = _outlined("", 14, Color(0.5, 0.85, 1.0))
	UiStyle.place(energy_label, Vector4(0, 1, 0, 1), Vector4(28, -100, 300, -78))
	root.add_child(energy_label)

	minimap = Minimap.new()
	minimap.mission = mission
	UiStyle.place(minimap, Vector4(1, 1, 1, 1), Vector4(-20 - Minimap.SIZE, -20 - Minimap.SIZE, -20, -20))
	root.add_child(minimap)
	if mission == null:
		panel.visible = false
		minimap.visible = false


func _outlined(text: String, size: int, color: Color = UiStyle.TEXT) -> Label:
	var l := UiStyle.label(text, size, color)
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _update_mission_ui(delta: float) -> void:
	if mission == null:
		return
	objective.text = mission.objective_text()
	var names: Array[String] = []
	for e in mission.evidence:
		names.append(("[x] " if e.collected else "[  ] ") + e.label)
	evidence_label.text = "\n".join(names)
	match mission.alert_level():
		2:
			alert_label.text = "¡TE ESTÁN PERSIGUIENDO!"
			alert_label.add_theme_color_override("font_color", UiStyle.ACCENT)
			alert_label.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		1:
			alert_label.text = "La policía sospecha…"
			alert_label.add_theme_color_override("font_color", UiStyle.WARN)
			alert_label.modulate.a = 1.0
		_:
			alert_label.text = ""
	var p := mission.world.player
	if p.energy_timer > 0.0:
		energy_label.text = "Granizado: resistencia sin límite (%d s)" % ceili(p.energy_timer)
	else:
		energy_label.text = ""
	if not hidden_label.visible and p.in_cover() and not p.crouching and prompt_label.text == "":
		prompt_label.text = "%s  agáchate para esconderte" % InputConfig.key_name("crouch")
		prompt_label.set_meta("cover_hint", true)
	elif prompt_label.has_meta("cover_hint") and (not p.in_cover() or p.crouching):
		prompt_label.text = ""
		prompt_label.remove_meta("cover_hint")
	if _toast_timer > 0.0:
		_toast_timer -= delta
		toast_label.modulate.a = clampf(_toast_timer / 0.6, 0.0, 1.0)
		if _toast_timer <= 0.0:
			_next_toast()


func _on_prompt(text: String) -> void:
	prompt_label.remove_meta("cover_hint")
	prompt_label.text = "" if text == "" else "%s  %s" % [InputConfig.key_name("interact"), text]


func _on_notify(text: String) -> void:
	_toasts.append(text)
	if _toast_timer <= 0.0:
		_next_toast()


func _next_toast() -> void:
	if _toasts.is_empty():
		toast_label.text = ""
		return
	toast_label.text = _toasts.pop_front()
	_toast_timer = 4.5


func _on_hidden(value: bool) -> void:
	hidden_label.visible = value
