class_name MissionOverlay
extends CanvasLayer
## Pantallas de la misión:
## - «¡Te atraparon!»: unos segundos y vuelves al último punto de control
##   (en los capítulos con corazones, dice cuántos quedan).
## - Victoria: tiempo, pistas, veces atrapado, errores, rango, recompensas
##   (XP, dinero, nivel nuevo, logros) y el botón al siguiente capítulo.
## - Derrota (se acabó el tiempo o los corazones): objetivos logrados y reintentar.
## Desde victoria y derrota se puede reintentar el capítulo o ir al menú.

const CAUGHT_SECONDS := 2.8

var mission: Mission
var _dim: ColorRect
var _box: VBoxContainer
var _over: Label
var _title: Label
var _body: Label
var _stats: GridContainer
var _buttons: HBoxContainer
var _again: Button
var _next: Button
var _rewards: VBoxContainer
var _timer := 0.0


func _init(m: Mission) -> void:
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
	_rewards = VBoxContainer.new()
	_rewards.add_theme_constant_override("separation", 4)
	_rewards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_rewards)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	_box.add_child(_buttons)
	_next = UiStyle.button("Siguiente capítulo", 230, "primary")
	_next.pressed.connect(func() -> void:
		var next := Chapters.next_id(mission.chapter_id)
		GameSession.new_game("explorador", next)
		SceneLoader.change_scene(MainMenu.PROTOTYPE_SCENE, Chapters.get_chapter(next).get("title", "")))
	_buttons.add_child(_next)
	_again = UiStyle.button("Jugar otra vez", 200)
	_again.pressed.connect(func() -> void:
		GameSession.new_game(mission.mode, mission.chapter_id)
		SceneLoader.change_scene(MainMenu.PROTOTYPE_SCENE, mission.title()))
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
	if mission.max_lives > 0:
		extra = "\nTe quedan %d de %d oportunidades." % [mission.lives, mission.max_lives]
		_body.text = "Sebastián se escabulle y vuelve al último punto de control. No pierde nada de lo que consiguió.%s" % extra
	else:
		_body.text = "Sebastián se escabulle y vuelve con sus amigos. No pierde ninguna prueba.%s" % extra
	_stats.visible = false
	_rewards.visible = false
	_buttons.visible = false
	_show(Color(0.14, 0.02, 0.02, 0.62))
	_timer = CAUGHT_SECONDS
	AudioManager.sfx("caught")


func _on_won(stats: Dictionary) -> void:
	var c := Chapters.get_chapter(mission.chapter_id)
	if mission is EscapeMission:
		_over.text = "CAPÍTULO 1 SUPERADO · %s" % EscapeStory.mode(str(stats["mode"]))["label"].to_upper()
	else:
		_over.text = "CAPÍTULO %d SUPERADO" % int(c.get("number", 0))
	_over.add_theme_color_override("font_color", UiStyle.OK)
	_title.text = str(c.get("win_title", "¡Capítulo superado!"))
	_title.add_theme_color_override("font_color", UiStyle.TEXT)
	_body.text = "%s\nRango: %s" % [mission.victory_text(), stats["rank"]]
	_fill_stats([
		["Tiempo", _clock(float(stats["time"]))],
		["Pistas", str(stats["hints"])],
		["Atrapado", str(stats["caught"])],
		["Errores", str(stats["wrong"])],
	])
	_fill_rewards(stats.get("reward", {}))
	var next := Chapters.next_id(mission.chapter_id)
	_next.visible = next != ""
	if next == "":
		_body.text += "\n" + Chapters.NEXT_TEASER
	_buttons.visible = true
	_show(Color(0.02, 0.05, 0.04, 0.8))
	_timer = 0.0
	_end_common()
	AudioManager.sfx("win")


func _on_lost(reason: String) -> void:
	if reason == "capturado":
		_over.text = "SIN OPORTUNIDADES"
		_title.text = "Te atraparon demasiadas veces"
		_body.text = "Esta vez no se pudo. Lograste %s objetivos. Muévete agachado, usa las latas (%s) y escóndete en los matorrales para que baje la búsqueda." % [
				mission.progress_text(), InputConfig.key_name("throw")]
	elif reason == "caida":
		_over.text = "SIN OPORTUNIDADES"
		_title.text = "Demasiados golpes"
		_body.text = "Las caídas altas cuestan un corazón. Pulsa %s justo al aterrizar para rodar y no hacerte daño. Lograste %s objetivos." % [
				InputConfig.key_name("crouch"), mission.progress_text()]
	elif reason == "amanecer":
		_over.text = "SALIÓ EL SOL"
		_title.text = "Lucía tuvo que irse"
		_body.text = "Amaneció antes de que llegaras al Puente de la Novena. Lograste %s objetivos. Desde el mirador, ve al sur por el andén del parque y evita el cruce vigilado." % [
				mission.progress_text()]
	else:
		_over.text = "CONTRARRELOJ"
		_title.text = "Se acabó el tiempo"
		_body.text = "La policía se llevó a Sebastián antes de que pudieran aclarar todo. Lograste %s objetivos. Las pistas (%s) ayudan si te atascas." % [
				mission.progress_text(), InputConfig.key_name("hint")]
	_over.add_theme_color_override("font_color", UiStyle.WARN)
	_title.add_theme_color_override("font_color", UiStyle.WARN)
	_rewards.visible = false
	_next.visible = false
	_again.text = "Reintentar"
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
	(_next if _next.visible else _again).grab_focus()


## Recompensas del capítulo: cada bono con su XP, el dinero, el nivel y los logros.
func _fill_rewards(r: Dictionary) -> void:
	for ch in _rewards.get_children():
		ch.queue_free()
	_rewards.visible = not r.is_empty()
	if r.is_empty():
		return
	for line: Array in r.get("lines", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		var k := UiStyle.label(str(line[0]), 16, UiStyle.TEXT)
		k.custom_minimum_size = Vector2(260, 0)
		row.add_child(k)
		row.add_child(UiStyle.label("+%d XP" % int(line[1]), 16, UiStyle.ACCENT, 600))
		_rewards.add_child(row)
	var total := UiStyle.label("Total: +%d XP · +$%d" % [int(r.get("xp", 0)), int(r.get("money", 0))], 18, UiStyle.OK, 700)
	_rewards.add_child(total)
	if int(r.get("level_after", 0)) > int(r.get("level_before", 0)):
		_rewards.add_child(UiStyle.label("¡Subiste al nivel %d · %s! Tienes puntos de habilidad para gastar." % [
				int(r["level_after"]), Chapters.level_name(int(r["level_after"]))], 16, UiStyle.ACCENT, 600))
	for id: String in r.get("achievements", []):
		var a: Dictionary = Chapters.ACHIEVEMENTS.get(id, {})
		_rewards.add_child(UiStyle.label("Logro: %s" % a.get("name", id), 15, UiStyle.WARN, 600))


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
