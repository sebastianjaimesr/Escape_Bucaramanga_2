class_name JournalPanel
extends ModalPanel
## Registro de misiones (J): la misión principal del capítulo con sus
## objetivos, las misiones secundarias del distrito (disponibles, en curso y
## terminadas, con su progreso y su recompensa) y lo que falta por descubrir
## (postales y cigarras pintadas). Funciona en todos los capítulos; las
## secundarias solo existen en el Centro (CentroMission).

var mission: Mission
var _list: VBoxContainer
var _scroll: ScrollContainer


func _init(w: PrototypeWorld, m: Mission) -> void:
	super(w)
	mission = m


func build() -> void:
	subtitle_label.text = "REGISTRO DE MISIONES"
	title_label.text = "Tu libreta"
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(640, 430)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)


func refresh() -> void:
	var vp := card.get_viewport_rect().size
	_scroll.custom_minimum_size = Vector2(minf(640.0, vp.x - 120.0), minf(430.0, vp.y - 220.0))
	for c in _list.get_children():
		c.queue_free()
	_section("Misión principal")
	var main := UiStyle.panel(16, Color(1, 1, 1, 0.04))
	_list.add_child(main)
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", 6)
	main.add_child(mcol)
	var head := HBoxContainer.new()
	mcol.add_child(head)
	var t := UiStyle.label(mission.title(), 20, UiStyle.ACCENT, 600)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiStyle.label(mission.progress_text(), 14, UiStyle.TEXT_DIM, 600))
	for s: Dictionary in mission.step_list():
		var id: String = s["id"]
		if mission.is_done(id):
			mcol.add_child(_row("check", UiStyle.OK, s["title"], Color(UiStyle.TEXT_DIM, 0.85)))
		elif mission.is_available(id):
			mcol.add_child(_row("dot", UiStyle.ACCENT, s["title"], UiStyle.TEXT))
		else:
			mcol.add_child(_row("lock", Color(UiStyle.TEXT_DIM, 0.6), "Todavía no lo sabes…", Color(UiStyle.TEXT_DIM, 0.6)))
	var tracker: QuestTracker = mission.get("quests") as QuestTracker
	if tracker != null:
		_section("Misiones secundarias")
		for qid: String in SideQuests.LIST:
			var data: Dictionary = SideQuests.LIST[qid]
			var st := tracker.state(qid)
			# Los eventos solo aparecen cuando pasan.
			if data.get("event", false) and st == "available":
				continue
			_list.add_child(_quest_card(tracker, qid, data, st))
	_section("Por descubrir")
	var extra := UiStyle.panel(16, Color(1, 1, 1, 0.04))
	_list.add_child(extra)
	var ecol := VBoxContainer.new()
	ecol.add_theme_constant_override("separation", 6)
	extra.add_child(ecol)
	ecol.add_child(_row("postcard", UiStyle.ACCENT, "Postales de Bucaramanga: %d de %d" % [PlayerProfile.collectibles.size(),
			Chapters.COLLECTIBLES.size()], UiStyle.TEXT))
	if tracker != null:
		var found := 0
		for sid: String in SideQuests.SECRETS:
			if PlayerProfile.secrets.has(sid):
				found += 1
		ecol.add_child(_row("eye", Color(0.3, 1.0, 0.55), "Cigarras pintadas: %d de %d" % [found, SideQuests.SECRETS.size()], UiStyle.TEXT))
		for sid: String in SideQuests.SECRETS:
			if not PlayerProfile.secrets.has(sid):
				var hint := UiStyle.label("· " + str(SideQuests.SECRETS[sid]), 14, UiStyle.TEXT_DIM)
				hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				ecol.add_child(hint)


func _section(text: String) -> void:
	_list.add_child(UiStyle.overline(text))


func _row(icon: String, icon_color: Color, text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(ItemIcon.new(icon, 18, icon_color))
	var l := UiStyle.label(text, 15, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _quest_card(tracker: QuestTracker, qid: String, data: Dictionary, st: String) -> PanelContainer:
	var accent: Color = {"available": UiStyle.ACCENT, "active": Color(0.45, 0.8, 1.0), "done": UiStyle.OK}[st]
	var p := UiStyle.panel(16, Color(1, 1, 1, 0.04))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	p.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := UiStyle.label(str(data["title"]), 18, UiStyle.TEXT, 600)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiStyle.label({"available": "Disponible", "active": "En curso", "done": "Completada"}[st], 13, accent, 700))
	var who := UiStyle.label("%s · %s" % [data["giver"], data["zone"]], 13, UiStyle.TEXT_DIM, 500)
	col.add_child(who)
	if st == "available":
		var s := UiStyle.label("Busca el «!» dorado sobre %s. %s" % [data["giver"], data["summary"]], 14, UiStyle.TEXT_DIM)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(s)
	else:
		for o: Dictionary in data["objectives"]:
			var done := st == "done" or tracker.is_objective_done(qid, o["id"])
			var total := int(o.get("count", 1))
			var suffix := "  %d/%d" % [total if st == "done" else tracker.count(qid, o["id"]), total] if total > 1 else ""
			col.add_child(_row("check" if done else "dot", UiStyle.OK if done else accent, str(o["text"]) + suffix,
					Color(UiStyle.TEXT_DIM, 0.85) if done else UiStyle.TEXT))
	var r: Dictionary = data["reward"]
	col.add_child(UiStyle.label("Recompensa: %d XP · $%d · +%d reputación" % [int(r.get("xp", 0)), int(r.get("money", 0)), int(r.get("rep", 0))],
			13, Color(UiStyle.ACCENT, 0.9), 500))
	return p
