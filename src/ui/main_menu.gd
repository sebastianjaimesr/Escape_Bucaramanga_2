class_name MainMenu
extends Control
## Portada de la aventura «Escape de Bucaramanga».
##
## Fondo animado por shader (atardecer sobre una ciudad entre montañas), título,
## introducción y las páginas: selección de capítulo (los bloqueados dicen qué
## falta), modo del capítulo 1 (libre o contrarreloj), perfil con habilidades,
## tienda y logros, cómo se juega y configuración. A la derecha, la campaña:
## el avance en cada capítulo y el perfil. Solo se muestran datos reales del
## juego. En pantallas verticales todo queda en una sola columna.

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
	_pages["chapters"] = _build_chapters()
	_pages["modes"] = _build_modes()
	var profile := ProfilePanel.new()
	profile.closed.connect(func() -> void: _show_page("home"))
	_pages["profile"] = profile
	_pages["howto"] = _build_howto()
	_pages["credits"] = _build_credits()
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
	var sub := UiStyle.label("Una aventura urbana en cinco capítulos", 24, UiStyle.ACCENT, 500)
	col.add_child(sub)
	var intro := UiStyle.label("Todo empezó a las 17:42, cuando la policía confundió a Sebastián con un ladrón. Aclararlo fue solo el comienzo: detrás de los robos del barrio hay una red. Investiga, sigue sospechosos, entra de noche a una bodega, escapa bajo la lluvia y cruza las terrazas de Cabecera hasta el Puente de la Novena antes del amanecer.", 18, UiStyle.TEXT_DIM)
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
	_play = UiStyle.button("Jugar", 340, "primary")
	_play.add_theme_font_size_override("font_size", 20)
	_play.custom_minimum_size.y = 58
	_play.pressed.connect(func() -> void: _show_page("chapters"))
	buttons.add_child(_play)
	_continue = UiStyle.button("Continuar", 340)
	_continue.pressed.connect(_continue_game)
	buttons.add_child(_continue)
	_refresh_continue()
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	buttons.add_child(prow)
	for spec: Array in [["Perfil y habilidades", "skills", 165], ["Tienda", "shop", 80], ["Logros", "achievements", 85]]:
		var pb := UiStyle.button(spec[0], spec[2])
		pb.pressed.connect(_open_profile.bind(spec[1]))
		prow.add_child(pb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	buttons.add_child(row)
	var stats := UiStyle.button("Estadísticas", 130)
	stats.pressed.connect(_open_profile.bind("stats"))
	row.add_child(stats)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	buttons.add_child(row2)
	var credits := UiStyle.button("Créditos", 110)
	credits.pressed.connect(func() -> void: _show_page("credits"))
	row2.add_child(credits)
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
		row2.add_child(quit)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	col.add_child(chips)
	for c: String in ["%d capítulos" % Chapters.LIST.size(), "%d niveles · %d habilidades" % [Chapters.LEVELS.size(), Chapters.SKILLS.size()],
			"%d logros · %d postales" % [Chapters.ACHIEVEMENTS.size(), Chapters.COLLECTIBLES.size()], "Teclado, mando o táctil"]:
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


## Selección de capítulo: cada tarjeta dice dónde y cuándo pasa, su mejor
## resultado y, si está bloqueado, qué hay que terminar antes.
func _build_chapters() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.add_child(UiStyle.overline("Campaña"))
	col.add_child(UiStyle.title("Elige un capítulo", 40))
	if SaveGame.exists():
		var warn := UiStyle.label("Empezar un capítulo reemplaza la partida que tienes guardada.", 15, UiStyle.WARN)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	var list := VBoxContainer.new()
	list.name = "Lista"
	list.add_theme_constant_override("separation", 10)
	col.add_child(list)
	var teaser := UiStyle.label(Chapters.NEXT_TEASER, 14, UiStyle.TEXT_DIM)
	teaser.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(teaser)
	var back := UiStyle.button("Volver", 160)
	back.pressed.connect(func() -> void: _show_page("home"))
	col.add_child(back)
	return col


func _refresh_chapters() -> void:
	var list := (_pages["chapters"] as Node).get_node("Lista") as VBoxContainer
	for c in list.get_children():
		c.queue_free()
	var times := {"manana": "De mañana", "tarde": "Al atardecer", "noche": "De noche", "madrugada": "De madrugada"}
	for c: Dictionary in Chapters.LIST:
		var id: String = c["id"]
		var unlocked := PlayerProfile.is_chapter_unlocked(id)
		var record: Dictionary = PlayerProfile.chapters.get(id, {})
		var b := UiStyle.button("", 0)
		b.custom_minimum_size = Vector2(300, 112)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not unlocked
		b.name = "Capitulo_" + id
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 20
		inner.offset_right = -20
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		var head := UiStyle.label("Capítulo %d · %s" % [int(c["number"]), c["title"]], 20, UiStyle.ACCENT if unlocked else UiStyle.TEXT_DIM, 700)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(head)
		var when: String = times.get(c["time"], "")
		if c.get("rain", false):
			when += ", con lluvia"
		var meta := "%s · %s · %s" % [c["place"], when, " · ".join(c["tags"])]
		if not unlocked:
			meta = "Bloqueado: termina el capítulo %d para jugarlo." % (int(c["number"]) - 1)
		elif record.get("done", false):
			var t := int(record.get("time", 0.0))
			meta = "Superado · %s · mejor tiempo %d:%02d" % [record.get("rank", ""), t / 60, t % 60]
		var d := UiStyle.label(meta, 14, UiStyle.OK if record.get("done", false) else UiStyle.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(d)
		var sm := UiStyle.label(c["summary"], 14, UiStyle.TEXT if unlocked else Color(UiStyle.TEXT_DIM, 0.6))
		sm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(sm)
		b.add_child(inner)
		b.pressed.connect(_choose_chapter.bind(id))
		list.add_child(b)


func _choose_chapter(id: String) -> void:
	if not PlayerProfile.is_chapter_unlocked(id):
		return
	if id == Chapters.FIRST:
		_show_page("modes")
	else:
		_start("explorador", id)


func _open_profile(t: String) -> void:
	var profile := _pages["profile"] as ProfilePanel
	profile.show_tab(t)
	_show_page("profile")
	profile.first_focus().grab_focus.call_deferred()


func _build_modes() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.add_child(UiStyle.overline("Capítulo 1 · Las pruebas del malentendido"))
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
		b.pressed.connect(_start.bind(id, Chapters.FIRST))
		col.add_child(b)
	var back := UiStyle.button("Volver", 160)
	back.pressed.connect(func() -> void: _show_page("chapters"))
	col.add_child(back)
	return col


func _build_howto() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.add_child(UiStyle.overline("Instrucciones"))
	col.add_child(UiStyle.title("Cómo se juega", 40))
	var sections := [
		["La campaña", "Cinco capítulos que se desbloquean en orden: aclarar el malentendido, recuperar la plata robada de la natillera, entrar de noche a la bodega de la red, escapar bajo la lluvia y, en Cabecera, la gran huida hasta el Puente de la Novena. Cada capítulo tiene sus objetivos arriba a la izquierda."],
		["Pruebas y acertijos", "Los brillos dorados son pruebas u objetos: examínalos en el inventario, porque sus detalles abren cerraduras y señalan culpables."],
		["La policía y la búsqueda", "Los cuadritos de arriba son el nivel de búsqueda: Tranquilo, Sospecha, Búsqueda, Persecución y Cerco. Sube si te ven o si una cámara te graba, y baja cuando nadie te ve (el doble de rápido escondido en un matorral, agachado). Desde Persecución llegan refuerzos."],
		["Oportunidades y puntos de control", "Desde el capítulo 2 tienes tres corazones: cada vez que te atrapan pierdes uno y vuelves al último punto de control. Sin corazones, se reintenta el capítulo."],
		["Moverse por la ciudad", "Salta contra un muro bajo para treparlo. Agáchate mientras corres para deslizarte. Lanza una lata (G) para que los guardias vayan a mirar el ruido. Con la chaqueta de la tienda o el impermeable, Q te disfraza."],
		["Parkour en las terrazas", "Los saltos largos entre terrazas solo salen corriendo. Si caes de alto, pulsa Agacharse al aterrizar para rodar: sin rodar te aturdes, y desde muy alto pierdes un corazón. En las tirolesas, Interactuar para colgarte y Saltar para soltarte."],
		["Drones", "Los drones alumbran un círculo en el suelo. Si te quedas en la luz te descubren y te siguen; corre fuera del círculo, métete bajo un toldo o agáchate en una jardinera."],
		["Progreso", "Cada objetivo, logro y postal da XP. Al subir de nivel ganas un punto de habilidad. Con el dinero de los capítulos compras objetos en la tienda. Hay 15 postales escondidas con datos de Bucaramanga. En Perfil → Estadísticas ves tus récords."],
		["Pistas", "Si te atascas, pide una pista (H o el bombillo). Cada objetivo tiene tres: la última da la solución. No restan tiempo, pero cuentan en el resultado."],
		["Teclado y ratón", "WASD mover · Shift correr · Espacio saltar o trepar · C agacharse o deslizarse · E interactuar · G lanzar lata · Q disfraz · Tab inventario · H pista · Esc pausa. Las teclas se pueden cambiar en Configuración."],
		["Pantalla táctil", "Mitad izquierda: mover. Mitad derecha: girar la cámara. Botones Usar, Saltar, Agachar, Correr, Lata y Disfraz. Arriba: inventario, pistas, sonido y pausa."],
		["Guardado", "La partida se guarda sola al lograr cada objetivo y al pausar. «Continuar» la retoma con todo lo conseguido. El perfil (nivel, dinero, logros) se guarda aparte y nunca se pierde."],
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


func _build_credits() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.add_child(UiStyle.overline("Créditos"))
	col.add_child(UiStyle.title("Escape de Bucaramanga", 36))
	var sections := [
		["Idea, historia y dirección", "sebastianjaimesr (GitHub)"],
		["Personajes", "Sebastián, Buitrago, Diaz y Gordo. Lucía Rangel, Doña Rosa, A. Pabón y «El Búho» son personajes ficticios."],
		["Motor", "Godot Engine 4.7 (licencia MIT) con física Jolt."],
		["Arte", "Toda la geometría, las texturas y los íconos se generan con código dentro del juego."],
		["Música y sonido", "Sintetizados desde cero con tools/generate_audio.py (sin muestras de terceros)."],
		["Tipografías", "Cinzel y Outfit, bajo SIL Open Font License."],
		["Desarrollo asistido", "Programación y diseño con ayuda de Claude (Anthropic)."],
		["Aviso", "Lugares inspirados en Bucaramanga, no reproducciones exactas. La policía, los vigilantes, los drones y los nombres comerciales son ficticios y nadie sale herido."],
	]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for s: Array in sections:
		list.add_child(UiStyle.label(s[0], 17, UiStyle.ACCENT, 600))
		var body := UiStyle.label(s[1], 16, UiStyle.TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(300, 0)
		list.add_child(body)
	var back := UiStyle.button("Volver", 160)
	back.pressed.connect(func() -> void: _show_page("home"))
	col.add_child(back)
	return col


## Campaña: el avance en cada capítulo y un resumen del perfil.
func _build_case_file() -> Control:
	var wrap := CenterContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := UiStyle.panel(24, Color(0.05, 0.055, 0.08, 0.72))
	panel.custom_minimum_size = Vector2(380, 0)
	wrap.add_child(panel)
	var col := VBoxContainer.new()
	col.name = "Campana"
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	return wrap


func _refresh_case_file() -> void:
	var col := _case_file.find_child("Campana", true, false) as VBoxContainer
	for c in col.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	col.add_child(head)
	var over := UiStyle.overline("Tu campaña")
	over.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(over)
	head.add_child(UiStyle.label("17:42", 14, UiStyle.DANGER, 700))
	for c: Dictionary in Chapters.LIST:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var done := PlayerProfile.is_chapter_done(c["id"])
		var open := PlayerProfile.is_chapter_unlocked(c["id"])
		row.add_child(ItemIcon.new("check" if done else ("dot" if open else "lock"), 22,
				UiStyle.OK if done else (UiStyle.ACCENT if open else UiStyle.TEXT_DIM)))
		var l := UiStyle.label("%d. %s" % [int(c["number"]), c["title"]], 16, UiStyle.TEXT if open else UiStyle.TEXT_DIM, 500)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		col.add_child(row)
	var sep := HSeparator.new()
	col.add_child(sep)
	col.add_child(UiStyle.label("Nivel %d · %s" % [PlayerProfile.level(), PlayerProfile.level_name()], 18, UiStyle.ACCENT, 600))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 6)
	bar.max_value = 1.0
	bar.value = PlayerProfile.level_progress()
	bar.show_percentage = false
	UiStyle.style_bar(bar, UiStyle.ACCENT)
	col.add_child(bar)
	var points := "1 punto de habilidad" if PlayerProfile.skill_points == 1 else "%d puntos de habilidad" % PlayerProfile.skill_points
	var stats := UiStyle.label("$%d · %d/%d logros · %d/%d postales · %s" % [PlayerProfile.money,
			PlayerProfile.achievements.size(), Chapters.ACHIEVEMENTS.size(), PlayerProfile.collectibles.size(),
			Chapters.COLLECTIBLES.size(), points], 14, UiStyle.TEXT_DIM)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(330, 0)
	col.add_child(stats)
	var next := Chapters.get_chapter(PlayerProfile.next_chapter())
	var note := UiStyle.label("Siguiente: %s. %s" % [next.get("title", ""), next.get("summary", "")], 15, UiStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(330, 0)
	col.add_child(note)


func _show_page(id: String, animate: bool = true) -> void:
	for k: String in _pages:
		(_pages[k] as Control).visible = k == id
	var page := _pages[id] as Control
	if animate and not bool(Settings.get_value("interface", "reduce_motion")):
		UiStyle.fade_in(page, 0.0, 0.0, 0.3)
	if id == "chapters":
		_refresh_chapters()
	if id == "home":
		_refresh_continue()
		_refresh_case_file()
		(_continue if _continue.visible else _play).grab_focus.call_deferred()
	else:
		_focus_first_button.call_deferred(page)


## Esc (o el botón B del control) vuelve a la portada desde cualquier página.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not (_pages["home"] as Control).visible:
		get_viewport().set_input_as_handled()
		_show_page("home")


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
	SceneLoader.change_scene(PROTOTYPE_SCENE, Chapters.get_chapter(GameSession.chapter).get("title", ""))


func _start(mode_id: String, chapter_id: String = Chapters.FIRST) -> void:
	GameSession.new_game(mode_id, chapter_id)
	SceneLoader.change_scene(PROTOTYPE_SCENE, Chapters.get_chapter(chapter_id).get("title", ""))
