class_name MissionOverlay
extends CanvasLayer
## Pantallas de la misión:
## - «¡Te atraparon!»: unos segundos y vuelves con tus amigos.
## - Victoria: tiempo, pistas, veces atrapado, errores y rango final.
## - Derrota (contrarreloj): se acabó el tiempo, con cuántos objetivos se lograron.
## Desde victoria y derrota se puede jugar otra vez (mismo modo) o ir al menú.

const CAUGHT_SECONDS := 2.8

var mission: EscapeMission
var _dim: ColorRect
var _box: VBoxContainer
var _over: Label
var _title: Label
var _body: Label
var _stats: GridContainer
var _buttons: HBoxContainer
var _again: Button
var _timer := 0.0


func _init(m: EscapeMission) -> void:
	mission = m


func _ready() -> void:
	layer = 20

	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.02, 0.02, 0.7)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 16)
	_box.custom_minimum_size = Vector2(minf(760.0, get_viewport().get_visible_rect().size.x - 40.0), 0)
	center.add_child(_box)
	_over = UiStyle.overline("")
	_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_over)
	_title = UiStyle.title("", 42)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_title)
	_body = UiStyle.label("", 19, UiStyle.TEXT_DIM)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_body)
	_stats = GridContainer.new()
	_stats.columns = 4
	_stats.add_theme_constant_override("h_separation", 12)
	_stats.add_theme_constant_override("v_separation", 12)
	_stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_stats)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	_box.add_child(_buttons)
	_again = UiStyle.button("Jugar otra vez", 230, "primary")
	_again.pressed.connect(func() -> void:
		GameSession.new_game(mission.mode)
		SceneLoader.change_scene(MainMenu.PROTOTYPE_SCENE, "Las pruebas del malentendido"))
	_buttons.add_child(_again)
	var menu := UiStyle.button("Menú principal", 230)
	menu.pressed.connect(func() -> void: SceneLoader.change_scene(SceneLoader.MAIN_MENU, "Menú principal"))
	_buttons.add_child(menu)
	_dim.visible = false
	mission.caught.connect(_on_caught)
	mission.won.connect(_on_won)
	mission.lost.connect(_on_lost)


func _show(dim: Color) -> void:
	_dim.color = dim
	_dim.visible = true
	_box.modulate.a = 0.0
	_box.create_tween().tween_property(_box, "modulate:a", 1.0, 0.45)


func _on_caught(count: int) -> void:
	_over.text = "LA POLICÍA TE ALCANZÓ"
	_over.add_theme_color_override("font_color", UiStyle.DANGER)
	_title.text = "¡Te atraparon!"
	_title.add_theme_color_override("font_color", UiStyle.DANGER)
	var extra := "" if count == 1 else "\n(Van %d veces)" % count
	_body.text = "Sebastián se escabulle y vuelve con sus amigos. No pierde ninguna prueba.%s" % extra
	_stats.visible = false
	_buttons.visible = false
	_show(Color(0.14, 0.02, 0.02, 0.62))
	_timer = CAUGHT_SECONDS
	AudioManager.sfx("caught")


func _on_won(stats: Dictionary) -> void:
	_over.text = "CASO RESUELTO · %s" % EscapeStory.mode(str(stats["mode"]))["label"].to_upper()
	_over.add_theme_color_override("font_color", UiStyle.OK)
	_title.text = "¡Malentendido aclarado!"
	_title.add_theme_color_override("font_color", UiStyle.TEXT)
	_body.text = "La foto, el video, tu recibo y la gorra cuentan lo que pasó a las 17:42: tú estabas pagando en la Tienda Doña Rosa y el ladrón era otro, con gorra roja.\nRango: %s" % stats["rank"]
	_fill_stats([
		["Tiempo", _clock(float(stats["time"]))],
		["Pistas", str(stats["hints"])],
		["Atrapado", str(stats["caught"])],
		["Errores", str(stats["wrong"])],
	])
	_buttons.visible = true
	_show(Color(0.02, 0.05, 0.04, 0.8))
	_timer = 0.0
	_end_common()
	AudioManager.sfx("win")


func _on_lost(_reason: String) -> void:
	_over.text = "CONTRARRELOJ"
	_over.add_theme_color_override("font_color", UiStyle.WARN)
	_title.text = "Se acabó el tiempo"
	_title.add_theme_color_override("font_color", UiStyle.WARN)
	_body.text = "La policía se llevó a Sebastián antes de que pudieran aclarar todo. Lograste %s objetivos. Las pistas (%s) ayudan si te atascas." % [
			mission.progress_text(), InputConfig.key_name("hint")]
	_fill_stats([["Objetivos", mission.progress_text()], ["Pistas", str(mission.hints.total_used())],
			["Atrapado", str(mission.caught_count)], ["Errores", str(mission.wrong_answers)]])
	_buttons.visible = true
	_show(Color(0.08, 0.05, 0.02, 0.82))
	_timer = 0.0
	_end_common()
	AudioManager.sfx("lose")


func _end_common() -> void:
	var world := mission.world
	if world != null and world.hud != null:
		world.hud.visible = false
	AudioManager.set_chase(0)
	AudioManager.play_music("menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_again.grab_focus()


func _fill_stats(rows: Array) -> void:
	for c in _stats.get_children():
		c.queue_free()
	for r: Array in rows:
		var p := UiStyle.panel(14, Color(1, 1, 1, 0.04))
		p.custom_minimum_size = Vector2(136, 0)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		p.add_child(col)
		var v := UiStyle.label(r[1], 28, UiStyle.TEXT, 600)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(v)
		var k := UiStyle.overline(r[0], UiStyle.TEXT_DIM, 11)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(k)
		_stats.add_child(p)
	_stats.visible = true


static func _clock(secs: float) -> String:
	return "%d:%02d" % [int(secs) / 60, int(secs) % 60]


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_dim.visible = false
			mission.resume_after_caught()


func is_showing() -> bool:
	return _dim.visible
