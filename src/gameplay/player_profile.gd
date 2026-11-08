extends Node
## Perfil del jugador (autoload): lo que se conserva entre capítulos.
##
## Nivel y XP, dinero, reputación en el barrio, puntos y habilidades, objetos
## comprados, logros, postales y capítulos terminados. Se guarda en
## user://perfil.cfg (aparte de la partida en curso) escribiendo primero un
## archivo temporal, como Settings y SaveGame. Si el archivo está dañado se
## conserva como .bad y se empieza un perfil nuevo.
##
## Las habilidades y los objetos cambian el juego a través de los
## multiplicadores de abajo (noise_mult, visibility_mult…), que leen el
## jugador, la policía y el sistema de búsqueda.

signal xp_gained(amount: int, reason: String)
signal level_up(level: int)
signal money_changed(money: int)
signal achievement_unlocked(id: String)
signal collectible_found(id: String, count: int)
signal changed

const VERSION := 1
const DEFAULT_PATH := "user://perfil.cfg"
const START_REPUTATION := 50
## Al repetir un capítulo se gana esta fracción de la recompensa base.
const REPLAY_FACTOR := 0.25

var path := DEFAULT_PATH
var xp := 0
var money := 0
var reputation := START_REPUTATION
var skill_points := 0
var skills: Array[String] = []
var items: Array[String] = []
var achievements: Array[String] = []
var collectibles: Array[String] = []
## id del capítulo -> {"done": bool, "rank": String, "time": float}
var chapters: Dictionary = {}


func _ready() -> void:
	load_profile()


# ---------------------------------------------------------------------------
# Nivel y XP
# ---------------------------------------------------------------------------
func level() -> int:
	return Chapters.level_for_xp(xp)


func level_name() -> String:
	return Chapters.level_name(level())


## Avance dentro del nivel actual (0..1); 1 en el nivel máximo.
func level_progress() -> float:
	var lv := level()
	if lv >= Chapters.LEVELS.size():
		return 1.0
	var a := Chapters.level_xp(lv)
	var b := Chapters.level_xp(lv + 1)
	return clampf(float(xp - a) / float(b - a), 0.0, 1.0)


func add_xp(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	var before := level()
	xp += amount
	xp_gained.emit(amount, reason)
	var after := level()
	if after > before:
		skill_points += after - before
		for lv in range(before + 1, after + 1):
			level_up.emit(lv)
		if after >= 5:
			unlock_achievement("nivel_5")
	changed.emit()
	save()


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	money_changed.emit(money)
	changed.emit()
	save()


func change_reputation(delta: int) -> void:
	reputation = clampi(reputation + delta, 0, 100)
	changed.emit()


# ---------------------------------------------------------------------------
# Habilidades y tienda
# ---------------------------------------------------------------------------
func has_skill(id: String) -> bool:
	return id in skills


## "" si se puede aprender; si no, el motivo.
func learn_problem(id: String) -> String:
	if not Chapters.SKILLS.has(id):
		return "Esa habilidad no existe."
	if has_skill(id):
		return "Ya la tienes."
	if level() < int(Chapters.SKILLS[id]["level"]):
		return "Necesitas nivel %d." % int(Chapters.SKILLS[id]["level"])
	if skill_points <= 0:
		return "No tienes puntos de habilidad."
	return ""


func learn(id: String) -> bool:
	if learn_problem(id) != "":
		return false
	skill_points -= 1
	skills.append(id)
	changed.emit()
	save()
	return true


func has_item(id: String) -> bool:
	return id in items


## "" si se puede comprar; si no, el motivo.
func buy_problem(id: String) -> String:
	if not Chapters.SHOP.has(id):
		return "Ese objeto no existe."
	if has_item(id):
		return "Ya lo tienes."
	if money < int(Chapters.SHOP[id]["price"]):
		return "No te alcanza la plata."
	return ""


func buy(id: String) -> bool:
	if buy_problem(id) != "":
		return false
	money -= int(Chapters.SHOP[id]["price"])
	items.append(id)
	money_changed.emit(money)
	unlock_achievement("cliente")
	changed.emit()
	save()
	return true


## Latas para distraer con las que se empieza cada capítulo.
func cans_per_chapter() -> int:
	return 3 + (3 if has_item("latas") else 0) + (2 if has_skill("buen_brazo") else 0)


## Distancia a la que te oyen correr (1 = normal).
func noise_mult() -> float:
	return (0.5 if has_skill("paso_ligero") else 1.0) * (0.7 if has_item("tenis") else 1.0)


## Distancia a la que te ven (1 = normal).
func visibility_mult() -> float:
	return 0.75 if has_skill("sombra") else 1.0


func stamina_mult() -> float:
	return 1.4 if has_skill("pulmones") else 1.0


## Altura máxima de lo que se puede escalar.
func vault_height() -> float:
	return 1.9 if has_skill("parkour") else 1.3


func throw_mult() -> float:
	return 1.35 if has_skill("buen_brazo") else 1.0


## Qué tan rápido baja el nivel de búsqueda cuando no te ven.
func wanted_decay_mult() -> float:
	return 2.0 if has_skill("escapista") else 1.0


# ---------------------------------------------------------------------------
# Logros, postales y capítulos
# ---------------------------------------------------------------------------
func has_achievement(id: String) -> bool:
	return id in achievements


func unlock_achievement(id: String) -> bool:
	if has_achievement(id) or not Chapters.ACHIEVEMENTS.has(id):
		return false
	achievements.append(id)
	achievement_unlocked.emit(id)
	add_xp(int(Chapters.ACHIEVEMENTS[id]["xp"]), "Logro")
	changed.emit()
	save()
	return true


func has_collectible(id: String) -> bool:
	return id in collectibles


func find_collectible(id: String) -> bool:
	if has_collectible(id):
		return false
	collectibles.append(id)
	collectible_found.emit(id, collectibles.size())
	add_money(20)
	add_xp(50, "Postal")
	if collectibles.size() % 5 == 0:
		skill_points += 1
	if collectibles.size() >= 5:
		unlock_achievement("postales_5")
	if collectibles.size() >= Chapters.COLLECTIBLES.size():
		unlock_achievement("postales_10")
	changed.emit()
	save()
	return true


func is_chapter_done(id: String) -> bool:
	return bool((chapters.get(id, {}) as Dictionary).get("done", false))


func is_chapter_unlocked(id: String) -> bool:
	var i := Chapters.index_of(id)
	if i <= 0:
		return i == 0
	return is_chapter_done(Chapters.LIST[i - 1]["id"])


## Primer capítulo sin terminar (o el último si ya se terminaron todos).
func next_chapter() -> String:
	for c: Dictionary in Chapters.LIST:
		if not is_chapter_done(c["id"]):
			return c["id"]
	return Chapters.LIST[-1]["id"]


## Da las recompensas de un capítulo terminado y devuelve el detalle para la
## pantalla de victoria: {"lines": [[texto, xp]], "xp", "money", "level_before",
## "level_after", "achievements": [ids], "first": bool}.
func complete_chapter(id: String, stats: Dictionary) -> Dictionary:
	var data := Chapters.get_chapter(id)
	var first := not is_chapter_done(id)
	var factor := 1.0 if first else REPLAY_FACTOR
	var lines: Array = []
	lines.append(["Capítulo superado" if first else "Capítulo repetido", int(int(data.get("xp", 0)) * factor)])
	if int(stats.get("hints", 0)) == 0:
		lines.append(["Sin pedir pistas", 100])
	if int(stats.get("caught", 0)) == 0:
		lines.append(["Sin que te atraparan", 150])
	if not bool(stats.get("chased", true)):
		lines.append(["Nadie te persiguió", 200])
	var gained := 0
	for l: Array in lines:
		gained += int(l[1])
	var cash := int(int(data.get("money", 0)) * factor)
	if str(stats.get("rank", "")) == Chapters.RANKS[0]:
		cash += 50
	var level_before := level()
	var before_achievements := achievements.duplicate()
	var record: Dictionary = chapters.get(id, {})
	record["done"] = true
	var t := float(stats.get("time", 0.0))
	if not record.has("time") or t < float(record["time"]):
		record["time"] = t
	record["rank"] = _better_rank(str(record.get("rank", "")), str(stats.get("rank", "")))
	chapters[id] = record
	change_reputation(5 if first else 1)
	add_money(cash)
	add_xp(gained, "Capítulo")
	var chapter_achievement := {"malentendido": "caso_cerrado", "robo_plaza": "natillera",
			"callejon": "sombra_noche", "persecucion": "a_salvo"}
	if chapter_achievement.has(id):
		unlock_achievement(chapter_achievement[id])
	if not bool(stats.get("chased", true)):
		unlock_achievement("fantasma")
	if str(stats.get("rank", "")) == Chapters.RANKS[0]:
		unlock_achievement("impecable")
	var new_achievements: Array = []
	for a: String in achievements:
		if not a in before_achievements:
			new_achievements.append(a)
	save()
	return {"lines": lines, "xp": gained, "money": cash, "level_before": level_before,
			"level_after": level(), "achievements": new_achievements, "first": first}


func _better_rank(a: String, b: String) -> String:
	var ia := Chapters.RANKS.find(a)
	var ib := Chapters.RANKS.find(b)
	if ia < 0:
		return b
	if ib < 0:
		return a
	return a if ia <= ib else b


# ---------------------------------------------------------------------------
# Guardado
# ---------------------------------------------------------------------------
func reset() -> void:
	xp = 0
	money = 0
	reputation = START_REPUTATION
	skill_points = 0
	skills.clear()
	items.clear()
	achievements.clear()
	collectibles.clear()
	chapters.clear()
	changed.emit()


func save() -> bool:
	if not GameSession.save_enabled:
		return false
	var cfg := ConfigFile.new()
	cfg.set_value("perfil", "version", VERSION)
	for key: String in ["xp", "money", "reputation", "skill_points", "skills", "items",
			"achievements", "collectibles", "chapters"]:
		cfg.set_value("perfil", key, get(key))
	var tmp := path + ".tmp"
	if cfg.save(tmp) != OK:
		push_warning("No se pudo guardar el perfil.")
		return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_warning("No se pudo reemplazar el perfil guardado.")
		return false
	return true


func load_profile() -> void:
	reset()
	if not FileAccess.file_exists(path):
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or int(cfg.get_value("perfil", "version", 0)) != VERSION:
		push_warning("El perfil guardado no se pudo leer; se empieza uno nuevo.")
		DirAccess.rename_absolute(path, path + ".bad")
		return
	xp = maxi(0, int(cfg.get_value("perfil", "xp", 0)))
	money = maxi(0, int(cfg.get_value("perfil", "money", 0)))
	reputation = clampi(int(cfg.get_value("perfil", "reputation", START_REPUTATION)), 0, 100)
	skill_points = maxi(0, int(cfg.get_value("perfil", "skill_points", 0)))
	_load_ids(skills, cfg.get_value("perfil", "skills", []), Chapters.SKILLS)
	_load_ids(items, cfg.get_value("perfil", "items", []), Chapters.SHOP)
	_load_ids(achievements, cfg.get_value("perfil", "achievements", []), Chapters.ACHIEVEMENTS)
	var known_collectibles := {}
	for c: Dictionary in Chapters.COLLECTIBLES:
		known_collectibles[c["id"]] = true
	_load_ids(collectibles, cfg.get_value("perfil", "collectibles", []), known_collectibles)
	var ch: Variant = cfg.get_value("perfil", "chapters", {})
	if ch is Dictionary:
		for k: Variant in ch:
			if Chapters.index_of(str(k)) >= 0 and ch[k] is Dictionary:
				chapters[str(k)] = ch[k]
	changed.emit()


func _load_ids(target: Array[String], value: Variant, known: Dictionary) -> void:
	target.clear()
	if not value is Array:
		return
	for v: Variant in value:
		if known.has(str(v)) and not str(v) in target:
			target.append(str(v))
