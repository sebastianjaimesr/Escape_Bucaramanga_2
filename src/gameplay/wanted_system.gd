class_name WantedSystem
extends Node
## Nivel de búsqueda global (0 a 4), por encima de la IA de cada policía.
##
## Es un «calor» de 0 a 100 que sube cuando la policía sospecha o te persigue,
## cuando una cámara te graba o cuando alguien da aviso, y baja cuando nadie te
## ve (más rápido si estás escondido). Los niveles:
##   0 Tranquilo · 1 Sospecha · 2 Búsqueda · 3 Persecución · 4 Cerco
## Desde el nivel 3 llegan refuerzos (hasta MAX_REINFORCEMENTS); al volver a 0
## se van. Bajar de 3 o más a 0 da el logro «Escurridizo».

signal level_changed(level: int)

const NAMES := ["Tranquilo", "Sospecha", "Búsqueda", "Persecución", "Cerco"]
const THRESHOLDS := [10.0, 35.0, 60.0, 85.0]
const DECAY := 5.0               ## Por segundo cuando nadie te ve.
const HIDDEN_DECAY := 11.0       ## Por segundo escondido en un matorral.
const SUSPICION_RATE := 9.0      ## Mientras un policía sospecha (hasta el nivel 1).
const CHASE_RATE := 14.0         ## Mientras te persiguen.
const CHASE_FLOOR := 40.0        ## Una persecución te deja al menos en nivel 2.
const MAX_REINFORCEMENTS := 2
const REINFORCEMENT_COOLDOWN := 12.0

var mission: Mission
var heat := 0.0
var level := 0
var reinforcements: Array[PoliceOfficer] = []
## Llegó a 3 o más: bajar a 0 da el logro.
var _peaked := false
var _reinforce_timer := 0.0


func _init(m: Mission) -> void:
	mission = m
	name = "WantedSystem"


func _physics_process(delta: float) -> void:
	if mission.finished or get_tree().paused:
		return
	var seen := false
	var chased := false
	var suspicious := false
	for o in mission.officers:
		if not o.active:
			continue
		if o.state == PoliceOfficer.State.CHASE:
			chased = true
		elif o.state in [PoliceOfficer.State.SUSPICIOUS, PoliceOfficer.State.SEARCH]:
			suspicious = true
		if o.sees_player:
			seen = true
	if chased:
		heat = maxf(heat + CHASE_RATE * delta, CHASE_FLOOR)
	elif suspicious and heat < THRESHOLDS[1]:
		heat = minf(heat + SUSPICION_RATE * delta, THRESHOLDS[1] - 0.1)
	if not seen and not chased:
		var p := mission.world.player
		var rate := HIDDEN_DECAY if p.is_hidden() else DECAY
		heat = maxf(0.0, heat - rate * PlayerProfile.wanted_decay_mult() * delta)
	heat = clampf(heat, 0.0, 100.0)
	_update_level()
	_update_reinforcements(delta)


## Sube el calor de golpe (cámara, testigo, alarma). `at` = dónde te vieron.
func report(amount: float, at: Vector3 = Vector3.INF) -> void:
	heat = clampf(heat + amount, 0.0, 100.0)
	if at != Vector3.INF:
		EventBus.police_radio.emit(at, self)
	_update_level()


## Fija un nivel mínimo (por ejemplo, al empezar un capítulo de persecución).
func set_level(value: int) -> void:
	heat = maxf(heat, level_heat(value))
	_update_level()


## Cambiarse de chaqueta: baja dos niveles.
func disguise() -> void:
	heat = level_heat(maxi(0, level - 2))
	for o in mission.officers:
		if o.state == PoliceOfficer.State.CHASE:
			o.lose_track()
	_update_level()


func clear() -> void:
	heat = 0.0
	_update_level()


static func level_heat(value: int) -> float:
	return 0.0 if value <= 0 else THRESHOLDS[clampi(value, 1, 4) - 1] + 1.0


func _update_level() -> void:
	var lv := 0
	for i in THRESHOLDS.size():
		if heat >= THRESHOLDS[i]:
			lv = i + 1
	if lv == level:
		return
	level = lv
	if lv >= 3:
		_peaked = true
	elif lv == 0 and _peaked:
		_peaked = false
		PlayerProfile.unlock_achievement("escapista")
	level_changed.emit(lv)


## Desde el nivel 3 llegan refuerzos por los bordes de la manzana, directo a
## donde te vieron por última vez. Al volver a 0 se retiran.
func _update_reinforcements(delta: float) -> void:
	_reinforce_timer = maxf(0.0, _reinforce_timer - delta)
	if not mission.police_enabled:
		return
	if level >= 3 and reinforcements.size() < MAX_REINFORCEMENTS and _reinforce_timer <= 0.0:
		_reinforce_timer = REINFORCEMENT_COOLDOWN
		var p := mission.world.player.global_position
		var entries: Array = mission.points.get("reinforcement_entries",
				[Vector3(0.0, 0.15, -56.0), Vector3(56.0, 0.15, 0.0), Vector3(0.0, 0.15, 56.0), Vector3(-56.0, 0.15, 0.0)]).duplicate()
		entries.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(p) > b.distance_to(p))
		var start: Vector3 = entries[1]
		var o := mission.spawn_officer(PackedVector3Array([start, start.lerp(p, 0.5)]))
		o.add_to_group("reinforcement")
		o.last_known = p
		o.alert = 0.6
		o.investigate(p)
		reinforcements.append(o)
		EventBus.notify.emit("Radio: «Llegan refuerzos a la zona.»")
	elif level == 0 and not reinforcements.is_empty():
		for o in reinforcements:
			mission.officers.erase(o)
			o.queue_free()
		reinforcements.clear()
