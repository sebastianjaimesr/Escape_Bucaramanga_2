class_name ProfilePanel
extends VBoxContainer
## Perfil del jugador, en la portada y en la pausa: nivel, XP, dinero,
## reputación y tres pestañas: Habilidades (gastar puntos), Tienda (comprar
## objetos con el dinero de los capítulos) y Logros (con las postales).
## Todo sale de PlayerProfile y Chapters; los botones están desactivados
## con el motivo cuando no se puede (falta nivel, puntos o plata).

signal closed

const TABS := ["skills", "shop", "achievements"]
const TAB_NAMES := {"skills": "Habilidades", "shop": "Tienda", "achievements": "Logros"}

var tab := "skills"
var _level: Label
var _xp_bar: ProgressBar
var _xp_text: Label
var _money: Label
var _rep: Label
var _points: Label
var _tab_buttons: Dictionary = {}
var _list: VBoxContainer
var _back: Button


func _init(start_tab: String = "skills") -> void:
	tab = start_tab if start_tab in TABS else "skills"


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	custom_minimum_size = Vector2(320, 0)
	add_child(UiStyle.overline("Tu perfil"))
	_level = UiStyle.label("", 28, UiStyle.TEXT, 700)
	add_child(_level)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(300, 8)
	_xp_bar.max_value = 1.0
	_xp_bar.show_percentage = false
	UiStyle.style_bar(_xp_bar, UiStyle.ACCENT)
	add_child(_xp_bar)
	_xp_text = UiStyle.label("", 14, UiStyle.TEXT_DIM)
	add_child(_xp_text)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 18)
	add_child(stats)
	_money = UiStyle.label("", 16, UiStyle.ACCENT, 600)
	stats.add_child(_money)
	_rep = UiStyle.label("", 16, UiStyle.TEXT, 500)
	_rep.tooltip_text = "Sube al terminar capítulos y baja un poco cada vez que te atrapan."
	stats.add_child(_rep)
	_points = UiStyle.label("", 16, UiStyle.OK, 600)
	stats.add_child(_points)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for t: String in TABS:
		var b := UiStyle.button(TAB_NAMES[t], 0)
		b.custom_minimum_size = Vector2(110, 40)
		b.toggle_mode = true
		# La pestaña elegida se ve ámbar (no solo con el foco).
		b.add_theme_stylebox_override("pressed", UiStyle.box(Color(UiStyle.ACCENT, 0.22), UiStyle.ACCENT, 8, 2))
		b.add_theme_color_override("font_pressed_color", UiStyle.ACCENT)
		b.pressed.connect(show_tab.bind(t))
		tabs.add_child(b)
		_tab_buttons[t] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_back = UiStyle.button("Volver", 160)
	_back.pressed.connect(func() -> void: closed.emit())
	add_child(_back)
	PlayerProfile.changed.connect(refresh)
	refresh()


func show_tab(t: String) -> void:
	tab = t
	refresh()


func refresh() -> void:
	if _level == null:
		return
	var lv := PlayerProfile.level()
	_level.text = "Nivel %d · %s" % [lv, PlayerProfile.level_name()]
	_xp_bar.value = PlayerProfile.level_progress()
	if lv >= Chapters.LEVELS.size():
		_xp_text.text = "%d XP · nivel máximo" % PlayerProfile.xp
	else:
		_xp_text.text = "%d / %d XP para el nivel %d" % [PlayerProfile.xp, Chapters.level_xp(lv + 1), lv + 1]
	_money.text = "$%d" % PlayerProfile.money
	_rep.text = "Reputación en el barrio: %d" % PlayerProfile.reputation
	_points.text = "Puntos de habilidad: %d" % PlayerProfile.skill_points
	for t: String in _tab_buttons:
		(_tab_buttons[t] as Button).set_pressed_no_signal(t == tab)
	for c in _list.get_children():
		c.queue_free()
	match tab:
		"skills":
			for id: String in Chapters.SKILLS:
				_skill_row(id)
		"shop":
			for id: String in Chapters.SHOP:
				_shop_row(id)
		"achievements":
			_achievements()


func _row(icon: String, title: String, text: String, done: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var ic := ItemIcon.new(icon, 40, UiStyle.TEXT if done else UiStyle.TEXT_DIM)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiStyle.label(title, 17, UiStyle.ACCENT if done else UiStyle.TEXT, 600))
	var d := UiStyle.label(text, 14, UiStyle.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(180, 0)
	col.add_child(d)
	_list.add_child(row)
	return row


func _skill_row(id: String) -> void:
	var s: Dictionary = Chapters.SKILLS[id]
	var has := PlayerProfile.has_skill(id)
	var row := _row(s["icon"], "%s · nivel %d" % [s["name"], int(s["level"])], s["text"], has)
	var b := UiStyle.button("Aprendida" if has else "Aprender", 120, "ghost" if has else "primary")
	var problem := PlayerProfile.learn_problem(id)
	b.disabled = problem != ""
	b.tooltip_text = problem
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		if PlayerProfile.learn(id):
			AudioManager.sfx("unlock")
			EventBus.notify.emit("Aprendiste: %s." % s["name"]))
	row.add_child(b)


func _shop_row(id: String) -> void:
	var s: Dictionary = Chapters.SHOP[id]
	var has := PlayerProfile.has_item(id)
	var row := _row(s["icon"], "%s · $%d" % [s["name"], int(s["price"])], s["text"], has)
	var b := UiStyle.button("Comprado" if has else "Comprar", 120, "ghost" if has else "primary")
	var problem := PlayerProfile.buy_problem(id)
	b.disabled = problem != ""
	b.tooltip_text = problem
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		if PlayerProfile.buy(id):
			AudioManager.sfx("buy"))
	row.add_child(b)


func _achievements() -> void:
	var got := PlayerProfile.achievements.size()
	_list.add_child(UiStyle.label("%d de %d logros · %d de %d postales de Bucaramanga" % [got, Chapters.ACHIEVEMENTS.size(),
			PlayerProfile.collectibles.size(), Chapters.COLLECTIBLES.size()], 15, UiStyle.TEXT_DIM))
	for id: String in Chapters.ACHIEVEMENTS:
		var a: Dictionary = Chapters.ACHIEVEMENTS[id]
		var has := PlayerProfile.has_achievement(id)
		_row("trophy" if has else "lock", a["name"], "%s · +%d XP" % [a["text"], int(a["xp"])], has)
	for c: Dictionary in Chapters.COLLECTIBLES:
		if PlayerProfile.has_collectible(c["id"]):
			_row("postcard", c["name"], c["fact"], true)


func first_focus() -> Control:
	return _tab_buttons[tab]
