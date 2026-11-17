class_name QuestTracker
extends RefCounted
## Estado de las misiones secundarias de una partida: cuáles se aceptaron,
## cuánto lleva cada objetivo y cuáles se terminaron. Lo que se cobra queda en
## PlayerProfile; aquí solo vive el progreso de la partida en curso (se guarda
## con la partida, así «Continuar» lo respeta).
##
## Estados: "available" (se puede aceptar), "active" (en curso), "done".

signal started(id: String)
signal updated(id: String)
signal completed(id: String, reward: Dictionary)

var progress: Dictionary = {}   ## id -> {obj_id: int}
var active: Array[String] = []
## La última aceptada o actualizada: es la que muestra el HUD.
var tracked := ""


func state(id: String) -> String:
	if PlayerProfile.is_quest_done(id):
		return "done"
	if id in active:
		return "active"
	return "available"


func start(id: String) -> bool:
	if state(id) != "available" or not SideQuests.LIST.has(id):
		return false
	active.append(id)
	progress[id] = {}
	tracked = id
	started.emit(id)
	return true


func count(id: String, obj_id: String) -> int:
	return int((progress.get(id, {}) as Dictionary).get(obj_id, 0))


func is_objective_done(id: String, obj_id: String) -> bool:
	return count(id, obj_id) >= int(SideQuests.objective(id, obj_id).get("count", 1))


## Suma `amount` a un objetivo (sin pasarse del total).
func advance(id: String, obj_id: String, amount: int = 1) -> void:
	if state(id) != "active":
		return
	var total := int(SideQuests.objective(id, obj_id).get("count", 1))
	var p: Dictionary = progress[id]
	p[obj_id] = clampi(int(p.get(obj_id, 0)) + amount, 0, total)
	tracked = id
	updated.emit(id)


## Todos los objetivos obligatorios cumplidos.
func ready_to_finish(id: String) -> bool:
	for o: Dictionary in SideQuests.LIST.get(id, {}).get("objectives", []):
		if not o.get("optional", false) and not is_objective_done(id, o["id"]):
			return false
	return true


## Se deja sin terminar (un evento que se perdió): vuelve a «available».
func abandon(id: String) -> void:
	if not id in active:
		return
	active.erase(id)
	progress.erase(id)
	if tracked == id:
		tracked = active[0] if not active.is_empty() else ""
	updated.emit(id)


## Solo falta volver con quien la dio (o ya se puede terminar): «?».
func ready_to_return(id: String) -> bool:
	if state(id) != "active":
		return false
	for o: Dictionary in SideQuests.LIST.get(id, {}).get("objectives", []):
		if not o.get("optional", false) and not o.get("return", false) and not is_objective_done(id, o["id"]):
			return false
	return true


## Termina y cobra (más el bono si se cumplieron los opcionales).
func finish(id: String) -> Dictionary:
	if state(id) != "active" or not ready_to_finish(id):
		return {}
	var reward := PlayerProfile.complete_quest(id).duplicate()
	var data: Dictionary = SideQuests.LIST[id]
	var bonus: Dictionary = data.get("bonus", {})
	var optional_done := true
	for o: Dictionary in data.get("objectives", []):
		if o.get("optional", false) and not is_objective_done(id, o["id"]):
			optional_done = false
	if not bonus.is_empty() and optional_done:
		PlayerProfile.add_money(int(bonus.get("money", 0)))
		PlayerProfile.add_xp(int(bonus.get("xp", 0)), "Bono")
		reward["bonus"] = bonus
	active.erase(id)
	if tracked == id:
		tracked = active[0] if not active.is_empty() else ""
	completed.emit(id, reward)
	return reward


## Texto corto para el HUD: título y el siguiente objetivo pendiente.
func tracked_text() -> Array:
	if tracked == "" or state(tracked) != "active":
		return []
	var data: Dictionary = SideQuests.LIST[tracked]
	for o: Dictionary in data["objectives"]:
		if o.get("optional", false) or is_objective_done(tracked, o["id"]):
			continue
		var total := int(o.get("count", 1))
		var suffix := " (%d/%d)" % [count(tracked, o["id"]), total] if total > 1 else ""
		return [data["title"], str(o["text"]) + suffix]
	return [data["title"], "Vuelve con %s" % data["giver"]]


func to_data() -> Dictionary:
	return {"active": active.duplicate(), "progress": progress.duplicate(true), "tracked": tracked}


## Carga segura: ignora misiones que no existen y contadores raros.
func from_data(data: Variant) -> void:
	active.clear()
	progress.clear()
	tracked = ""
	if not data is Dictionary:
		return
	for v: Variant in (data as Dictionary).get("active", []):
		var id := str(v)
		if SideQuests.LIST.has(id) and not PlayerProfile.is_quest_done(id) and not id in active:
			active.append(id)
			progress[id] = {}
	var prog: Variant = (data as Dictionary).get("progress", {})
	if prog is Dictionary:
		for id: Variant in prog:
			if str(id) in active and prog[id] is Dictionary:
				for o: Variant in prog[id]:
					var total := int(SideQuests.objective(str(id), str(o)).get("count", 0))
					if total > 0:
						progress[str(id)][str(o)] = clampi(int(prog[id][o]), 0, total)
	var t := str((data as Dictionary).get("tracked", ""))
	tracked = t if t in active else (active[0] if not active.is_empty() else "")
