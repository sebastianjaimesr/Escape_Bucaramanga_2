class_name SurveillanceDrone
extends Node3D
## Dron de vigilancia (ficticio): vuela sobre su ruta con un reflector que
## ilumina un círculo en el suelo. Si te quedas en la luz con línea de vista
## (sin estar escondido) se llena su detección; al completarse da la alarma por
## radio y te SIGUE un rato con la luz roja mientras te vea.
##
## Estados:
##   PATROL  recorre su ruta (puntos en el suelo; vuela ALTITUDE más arriba).
##   TRACK   te vio: te sigue y mantiene la alarma mientras estés en su luz.
##   SEARCH  te perdió: da vueltas sobre el último lugar donde te vio.
##   RETURN  vuelve al punto más cercano de su ruta.
##
## Se esquiva con techos (toldos, bajo los árboles no: es de noche y la luz los
## atraviesa), jardineras agachado o corriendo fuera del círculo.

enum State { PATROL, TRACK, SEARCH, RETURN }

const STATE_NAMES := ["Patrulla", "Siguiendo", "Buscando", "Regresando"]
const ALTITUDE := 8.5
const PATROL_SPEED := 3.2
const TRACK_SPEED := 5.0          ## Corriendo (5,8 m/s) se le gana.
const SPOT_RADIUS := 3.6
const DETECT_TIME := 0.9
const LOSE_TIME := 2.2
const SEARCH_TIME := 5.0
const ALARM_HEAT := 40.0
const TRACK_HEAT := 6.0           ## Por segundo mientras te sigue y te ve.
const AIM_AHEAD := 1.6

var route: PackedVector3Array = []
var route_index := 0
var state: State = State.PATROL
var active := true
var detect := 0.0
var sees_player := false
var wanted: WantedSystem
var alarms := 0
## Dónde está el centro de la luz en el suelo.
var spot := Vector3.ZERO

var _player: PlayerController
var _ray := PhysicsRayQueryParameters3D.new()
var _ground_ray := PhysicsRayQueryParameters3D.new()
var _ground_y := 0.0
var _ground_timer := 0.0
var _lost := 0.0
var _search := 0.0
var _last_known := Vector3.ZERO
var _rotors: Array[Node3D] = []
var _cone: MeshInstance3D
var _light: SpotLight3D
var _led: MeshInstance3D
var _t := 0.0
var _hum: AudioStreamPlayer3D
var _velocity := Vector3.ZERO


func _ready() -> void:
	add_to_group("drone")
	_t = randf() * 10.0
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.18, 0.6)
	body.mesh = bm
	body.material_override = MaterialLibrary.get_material("camera_body")
	add_child(body)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.16
	dm.height = 0.24
	dome.mesh = dm
	dome.material_override = MaterialLibrary.get_material("glass")
	dome.position = Vector3(0, -0.12, -0.18)
	add_child(dome)
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var dir := Vector3(cos(a), 0, sin(a))
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.06, 0.05, 0.62)
		arm.mesh = am
		arm.material_override = MaterialLibrary.get_material("camera_body")
		arm.basis = Basis.looking_at(dir, Vector3.UP)
		arm.position = dir * 0.31
		add_child(arm)
		var rotor := Node3D.new()
		rotor.position = dir * 0.6 + Vector3(0, 0.08, 0)
		add_child(rotor)
		var blade := MeshInstance3D.new()
		var blm := BoxMesh.new()
		blm.size = Vector3(0.5, 0.01, 0.05)
		blade.mesh = blm
		blade.material_override = MaterialLibrary.get_material("metal")
		rotor.add_child(blade)
		_rotors.append(rotor)
	_led = MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.05
	lm.height = 0.1
	_led.mesh = lm
	_led.material_override = MaterialLibrary.get_material("light_blue")
	_led.position = Vector3(0, -0.1, 0.3)
	add_child(_led)
	# Cono de luz visible hasta el suelo (se ajusta a la altura en cada cuadro).
	_cone = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = SPOT_RADIUS
	cm.height = 1.0
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 20
	_cone.mesh = cm
	_cone.material_override = MaterialLibrary.get_material("drone_light")
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.top_level = true
	add_child(_cone)
	_light = SpotLight3D.new()
	_light.light_color = Color(0.8, 0.9, 1.0)
	_light.light_energy = 6.0
	_light.spot_range = ALTITUDE + 4.0
	_light.spot_angle = 26.0
	_light.shadow_enabled = false
	_light.top_level = true
	add_child(_light)
	_ray.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.VEHICLES
	_ground_ray.collision_mask = PhysicsLayers.WORLD
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		_hum = AudioManager.loop_3d(self, "drone", -8.0)


func setup(path: PackedVector3Array) -> void:
	route = path
	route_index = 0
	if not route.is_empty():
		global_position = route[0] + Vector3.UP * ALTITUDE
		_ground_y = route[0].y


func reset() -> void:
	state = State.PATROL
	detect = 0.0
	_lost = 0.0
	if not route.is_empty():
		global_position = route[_nearest_route_point()] + Vector3.UP * ALTITUDE
	_set_alert_look(false)


func _physics_process(delta: float) -> void:
	_t += delta
	for r in _rotors:
		r.rotation.y += delta * 40.0
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if not active or _player == null or route.is_empty():
		sees_player = false
		_update_spot(delta)
		return
	match state:
		State.PATROL:
			_patrol(delta)
		State.TRACK:
			_track(delta)
		State.SEARCH:
			_search_state(delta)
		State.RETURN:
			_return(delta)
	_update_spot(delta)
	sees_player = can_see_player()
	if state == State.PATROL or state == State.RETURN or state == State.SEARCH:
		if sees_player:
			var rate := 0.6 if _player.crouching else 1.0
			detect = minf(1.0, detect + delta / DETECT_TIME * rate)
			if detect >= 1.0:
				_alarm()
		else:
			detect = maxf(0.0, detect - delta * 0.5)
	_led.visible = state != State.TRACK or int(_t * 6.0) % 2 == 0


func _patrol(delta: float) -> void:
	var target := route[route_index] + Vector3.UP * ALTITUDE
	if _fly_to(target, PATROL_SPEED, delta):
		route_index = (route_index + 1) % route.size()


func _track(delta: float) -> void:
	if sees_player:
		_last_known = _player.global_position
		_lost = 0.0
		if wanted != null:
			wanted.report(TRACK_HEAT * delta)
	else:
		_lost += delta
		if _lost >= LOSE_TIME:
			state = State.SEARCH
			_search = 0.0
			_set_alert_look(false)
			EventBus.notify.emit("El dron te perdió de vista.")
			return
	_fly_to(_last_known + Vector3.UP * ALTITUDE, TRACK_SPEED, delta)


func _search_state(delta: float) -> void:
	_search += delta
	var orbit := _last_known + Vector3(cos(_search * 1.3) * 4.0, ALTITUDE, sin(_search * 1.3) * 4.0)
	_fly_to(orbit, PATROL_SPEED, delta)
	if _search >= SEARCH_TIME:
		state = State.RETURN
		route_index = _nearest_route_point()


func _return(delta: float) -> void:
	if _fly_to(route[route_index] + Vector3.UP * ALTITUDE, PATROL_SPEED * 1.3, delta):
		state = State.PATROL


## Vuela hacia un punto con un poco de inercia; true al llegar.
func _fly_to(target: Vector3, speed: float, delta: float) -> bool:
	var to := target - global_position
	var desired := to.normalized() * minf(speed, to.length() / maxf(delta, 0.001)) if to.length() > 0.01 else Vector3.ZERO
	_velocity = _velocity.lerp(desired, clampf(delta * 3.0, 0.0, 1.0))
	global_position += _velocity * delta
	# Se inclina hacia donde va y flota un poco.
	var flat := Vector3(_velocity.x, 0, _velocity.z)
	if flat.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), clampf(delta * 4.0, 0.0, 1.0))
	rotation.x = lerpf(rotation.x, -clampf(flat.length() * 0.05, 0.0, 0.25), clampf(delta * 4.0, 0.0, 1.0))
	position.y += sin(_t * 2.0) * 0.004
	return to.length() < 0.6


## Coloca el cono y la luz: del dron al suelo, un poco adelante.
func _update_spot(delta: float) -> void:
	_ground_timer -= delta
	var ahead := -global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() * (AIM_AHEAD if state != State.TRACK else 0.0)
	var probe := global_position + ahead
	if _ground_timer <= 0.0 and is_inside_tree():
		_ground_timer = 0.15
		_ground_ray.from = probe
		_ground_ray.to = probe + Vector3.DOWN * 30.0
		var hit := get_world_3d().direct_space_state.intersect_ray(_ground_ray)
		if not hit.is_empty():
			_ground_y = (hit["position"] as Vector3).y
	spot = Vector3(probe.x, _ground_y, probe.z)
	var top := global_position + Vector3.DOWN * 0.15
	var h := maxf(0.5, top.y - _ground_y)
	# El cilindro va en Y (punta angosta arriba): Y local = del suelo al dron.
	var up_dir := (top - spot).normalized()
	var side := up_dir.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up_dir.cross(Vector3.RIGHT)
	side = side.normalized()
	_cone.global_transform = Transform3D(Basis(side, up_dir * top.distance_to(spot), side.cross(up_dir)), (top + spot) * 0.5)
	_light.global_position = top
	if top.distance_to(spot) > 0.01:
		_light.look_at(spot, Vector3.FORWARD)
	_light.spot_range = h + 3.0


func can_see_player() -> bool:
	if _player == null or _player.is_hidden():
		return false
	var p := _player.global_position
	var r := SPOT_RADIUS * PlayerProfile.visibility_mult() * (1.25 if state == State.TRACK else 1.0)
	if Vector2(p.x - spot.x, p.z - spot.z).length() > r:
		return false
	if absf(p.y - spot.y) > 2.5:
		return false
	_ray.from = global_position + Vector3.DOWN * 0.3
	_ray.to = p + Vector3.UP * (0.7 if _player.crouching else 1.2)
	return get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


func _alarm() -> void:
	detect = 0.0
	alarms += 1
	state = State.TRACK
	_lost = 0.0
	_last_known = _player.global_position
	_set_alert_look(true)
	if wanted != null:
		wanted.report(ALARM_HEAT, _last_known)
	else:
		EventBus.police_radio.emit(_last_known, self)
	EventBus.noise.emit(_last_known, 25.0, "dron")
	EventBus.notify.emit("¡Un dron te iluminó! La policía ya sabe dónde estás.")
	EventBus.camera_shake.emit(0.2)
	AudioManager.sfx("drone_alert")


func _set_alert_look(alert: bool) -> void:
	_cone.material_override = MaterialLibrary.get_material("drone_light_alert" if alert else "drone_light")
	_led.material_override = MaterialLibrary.get_material("light_red" if alert else "light_blue")
	_light.light_color = Color(1.0, 0.35, 0.3) if alert else Color(0.8, 0.9, 1.0)


func _nearest_route_point() -> int:
	var best := 0
	var best_d := INF
	for i in route.size():
		var d := global_position.distance_squared_to(route[i] + Vector3.UP * ALTITUDE)
		if d < best_d:
			best_d = d
			best = i
	return best
