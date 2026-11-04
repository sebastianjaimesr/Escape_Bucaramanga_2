class_name NpcCharacter
extends CharacterBody3D
## Base de los personajes no jugables: cuerpo con colisión, gravedad,
## navegación con NavigationAgent3D y cuerpo visual (HumanoidBody).
##
## Las subclases deciden a dónde ir (go_to) y a qué velocidad; esta clase sigue
## la ruta, gira el cuerpo y anima.

const GRAVITY := 9.8
const TURN_SPEED := 8.0
const RADIUS := 0.3
const HEIGHT := 1.75
const STEP_HEIGHT := 0.36

var display_name := ""
var agent: NavigationAgent3D
var visual: HumanoidBody
var facing_yaw := 0.0
var move_speed := 0.0
var running := false

var _goal := Vector3.INF
var _look_target := Vector3.INF


func _init(look: Dictionary = {}) -> void:
	visual = HumanoidBody.new(look)


func _ready() -> void:
	add_to_group("npc")
	collision_layer = PhysicsLayers.CHARACTERS
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.VEHICLES | PhysicsLayers.PLAYER
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = HEIGHT * 0.5
	add_child(col)
	visual.name = "Visual"
	add_child(visual)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.5
	agent.path_max_distance = 2.0
	agent.radius = NavigationBuilder.AGENT_RADIUS
	agent.height = NavigationBuilder.AGENT_HEIGHT
	add_child(agent)


## Pide ir a un punto (recalcula la ruta solo si el destino cambió).
func go_to(point: Vector3) -> void:
	if _goal == Vector3.INF or _goal.distance_to(point) > 0.4:
		_goal = point
		agent.target_position = point


func stop() -> void:
	_goal = Vector3.INF
	move_speed = 0.0


func arrived() -> bool:
	if _goal == Vector3.INF:
		return true
	var flat := Vector2(global_position.x - _goal.x, global_position.z - _goal.z)
	return flat.length() < 0.7 or (agent.is_navigation_finished() and flat.length() < 1.5)


## Mira hacia un punto aunque esté quieto (por ejemplo, al jugador que le habla).
func face(point: Vector3) -> void:
	_look_target = point


func _physics_process(delta: float) -> void:
	think(delta)
	var desired := Vector3.ZERO
	if _goal != Vector3.INF and move_speed > 0.0 and not arrived():
		var next := agent.get_next_path_position()
		var to := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
		# Si la navegación todavía no está lista, camina directo al destino.
		if to.length() < 0.05:
			to = Vector3(_goal.x - global_position.x, 0.0, _goal.z - global_position.z)
		if to.length() > 0.05:
			desired = to.normalized() * move_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, 20.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var was_grounded := is_on_floor()
	move_and_slide()
	if was_grounded and desired.length() > 0.1 and is_on_wall() \
			and get_wall_normal().dot(desired.normalized()) < -0.3:
		_try_step_up(desired)
	var look_dir := Vector3.ZERO
	if desired.length() > 0.1:
		look_dir = desired
	elif _look_target != Vector3.INF:
		look_dir = _look_target - global_position
	look_dir.y = 0.0
	if look_dir.length() > 0.05:
		facing_yaw = lerp_angle(facing_yaw, atan2(-look_dir.x, -look_dir.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	visual.rotation.y = facing_yaw
	var speed := Vector2(velocity.x, velocity.z).length()
	visual.animate(speed, 5.5, is_on_floor(), false, running and speed > 3.0, delta)


## Sube bordillos y escalones (igual que el jugador, en versión corta):
## arriba, adelante, abajo; si hay suelo, sube el cuerpo a esa altura.
func _try_step_up(desired: Vector3) -> void:
	var step := Vector3.UP * STEP_HEIGHT
	var probe := desired.normalized() * RADIUS
	var result := PhysicsTestMotionResult3D.new()
	var from := global_transform
	if _test(from, step, result) or _test(from.translated(step), probe, result):
		return
	if not _test(from.translated(step + probe), -step, result):
		return
	if result.get_collision_normal().y < cos(floor_max_angle):
		return
	var rise := STEP_HEIGHT + result.get_travel().y
	if rise > 0.01:
		global_position.y += rise + 0.005
		velocity.x = desired.x
		velocity.z = desired.z


func _test(from: Transform3D, motion: Vector3, result: PhysicsTestMotionResult3D) -> bool:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	params.margin = safe_margin
	return PhysicsServer3D.body_test_motion(get_rid(), params, result)


## Las subclases ponen aquí su lógica (se llama antes de mover).
func think(_delta: float) -> void:
	pass


## Dirección hacia donde mira, en el plano XZ.
func forward() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


func place(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	facing_yaw = yaw
	stop()
