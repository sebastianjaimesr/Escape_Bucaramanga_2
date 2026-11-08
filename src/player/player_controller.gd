class_name PlayerController
extends CharacterBody3D
## Sebastián: física, resistencia y ayudas de movimiento.
##
## El comportamiento de cada estado (quieto, caminar, correr, saltar, caer,
## agacharse) vive en src/player/states/ y lo coordina PlayerStateMachine.
## El movimiento es relativo a la cámara: camera_yaw lo actualiza la cámara.

signal landed(fall_speed: float)
## Pidió cambiarse de chaqueta (Q); lo resuelve la misión.
signal disguise_requested

# --- Velocidades (m/s) ---
const WALK_SPEED := 2.6
const RUN_SPEED := 5.8
const CROUCH_SPEED := 1.5

# --- Aceleraciones (m/s²) ---
const GROUND_ACCEL := 22.0
const GROUND_DECEL := 26.0
const AIR_ACCEL := 6.0

# --- Salto y gravedad ---
const GRAVITY := 9.8
const FALL_GRAVITY_MULT := 1.6
const MAX_FALL_SPEED := 40.0
const JUMP_VELOCITY := 4.8      ## Altura ≈ v²/2g ≈ 1,17 m.
const JUMP_CUT := 0.5           ## Soltar el salto antes reduce la altura.
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.15

# --- Cuerpo ---
const RADIUS := 0.3
const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.1
const STEP_HEIGHT := 0.36       ## Bordillos y escalones que se suben sin saltar.
const TURN_SPEED := 12.0        ## Qué tan rápido gira el cuerpo hacia donde se mueve.

# --- Resistencia ---
const MAX_STAMINA := 100.0
const STAMINA_DRAIN := 16.0      ## Por segundo corriendo (≈ 6 s de carrera).
const STAMINA_REGEN := 20.0
const STAMINA_REGEN_DELAY := 0.8
const STAMINA_RECOVER_RATIO := 0.3  ## Si se agota, no se vuelve a correr hasta el 30 %.

var camera_yaw := 0.0
var input_enabled := true
var stamina := MAX_STAMINA
var exhausted := false
var crouching := false
var coyote_timer := 0.0
var jump_buffer := 0.0
var facing_yaw := 0.0
var last_step_up := 0.0          ## Altura del último escalón subido (para pruebas y cámara).
var air_max_speed := WALK_SPEED  ## En el aire se conserva el impulso, sin acelerar más.
var cover_count := 0             ## Matorrales en los que está metido (HidingSpot).
var energy_timer := 0.0          ## Segundos de resistencia infinita (granizado).
var focused: Interactable        ## Lo que se puede usar con Interactuar ahora mismo.
var cans := 0                    ## Latas para distraer (las pone la misión al empezar).
var vault_target := Vector3.INF  ## Último borde encontrado por find_vault().
var vault_count := 0
var slide_count := 0

var body_shape: CapsuleShape3D
var visual: PrototypeBody
var state_machine: PlayerStateMachine

var _collision: CollisionShape3D
var _regen_delay := 0.0
var _was_on_floor := true
var _air_peak_speed := 0.0
var _interactor: Area3D
var _was_hidden := false
var _last_prompt := ""


func _ready() -> void:
	add_to_group("player")
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.CHARACTERS | PhysicsLayers.VEHICLES
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_block_on_wall = true
	safe_margin = 0.01
	body_shape = CapsuleShape3D.new()
	body_shape.radius = RADIUS
	body_shape.height = STAND_HEIGHT
	_collision = CollisionShape3D.new()
	_collision.name = "Collision"
	_collision.shape = body_shape
	_collision.position.y = STAND_HEIGHT * 0.5
	add_child(_collision)
	visual = PrototypeBody.new()
	visual.name = "Visual"
	add_child(visual)
	state_machine = PlayerStateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)
	state_machine.setup(self)
	_interactor = Area3D.new()
	_interactor.name = "Interactor"
	_interactor.collision_layer = 0
	_interactor.collision_mask = PhysicsLayers.INTERACTABLES
	_interactor.monitorable = false
	var reach := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	reach.shape = sphere
	reach.position.y = 0.9
	_interactor.add_child(reach)
	add_child(_interactor)
	facing_yaw = rotation.y
	rotation.y = 0.0


func _physics_process(delta: float) -> void:
	if input_enabled and Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER_TIME
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
	state_machine.physics_update(delta)
	_update_stamina(delta)
	if input_enabled and Input.is_action_just_pressed("throw"):
		throw_can()
	if input_enabled and Input.is_action_just_pressed("gadget"):
		disguise_requested.emit()
	if not is_on_floor():
		_air_peak_speed = maxf(_air_peak_speed, -velocity.y)
	else:
		air_max_speed = maxf(horizontal_speed(), WALK_SPEED)
	var desired := Vector3(velocity.x, 0.0, velocity.z)
	var was_grounded := is_on_floor()
	move_and_slide()
	last_step_up = 0.0
	if was_grounded and is_on_wall() and desired.length() > 0.1 \
			and get_wall_normal().dot(desired.normalized()) < -0.3:
		last_step_up = _try_step_up(desired, delta)
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(_air_peak_speed)
		if _air_peak_speed > 4.5 and is_inside_tree():
			Fx.dust(get_parent(), global_position, 0.6 + _air_peak_speed * 0.05)
			AudioManager.sfx("land", randf_range(0.9, 1.1))
		_air_peak_speed = 0.0
	_was_on_floor = on_floor
	visual.update_visual(self, delta)
	_update_interaction()
	var hidden := is_hidden()
	if hidden != _was_hidden:
		_was_hidden = hidden
		EventBus.hidden_changed.emit(hidden)


# ---------------------------------------------------------------------------
# Interacción y escondites
# ---------------------------------------------------------------------------
## Escondido: agachado dentro de un matorral.
func is_hidden() -> bool:
	return cover_count > 0 and crouching


func in_cover() -> bool:
	return cover_count > 0


## Elige el Interactable más cercano que se pueda usar y responde a la tecla E.
func _update_interaction() -> void:
	var best: Interactable = null
	var best_d := INF
	if input_enabled:
		for area in _interactor.get_overlapping_areas():
			var it := area as Interactable
			if it == null or not it.can_interact(self):
				continue
			var d := global_position.distance_squared_to(it.global_position)
			if d < best_d:
				best_d = d
				best = it
	focused = best
	var text := best.get_prompt() if best != null else ""
	if text != _last_prompt:
		_last_prompt = text
		EventBus.interaction_prompt_changed.emit(text)
	if best != null and Input.is_action_just_pressed("interact"):
		best.interact(self)


## Granizado: llena la resistencia y la deja infinita un rato.
func drink_granizado(seconds: float) -> void:
	stamina = MAX_STAMINA
	exhausted = false
	energy_timer = seconds
	EventBus.stamina_changed.emit(stamina, MAX_STAMINA, exhausted)


# ---------------------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------------------
## Dirección deseada en el plano XZ, relativa a la cámara, con magnitud 0..1.
func move_input() -> Vector3:
	if not input_enabled:
		return Vector3.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, camera_yaw)
	return dir.limit_length(1.0)


func wants_run() -> bool:
	return input_enabled and Input.is_action_pressed("run")


func can_run() -> bool:
	return not exhausted and stamina > 0.0


func crouch_pressed() -> bool:
	return input_enabled and Input.is_action_just_pressed("crouch")


func can_jump() -> bool:
	return jump_buffer > 0.0 and coyote_timer > 0.0


func consume_jump() -> void:
	jump_buffer = 0.0
	coyote_timer = 0.0


func jump_held() -> bool:
	return input_enabled and Input.is_action_pressed("jump")


# ---------------------------------------------------------------------------
# Física usada por los estados
# ---------------------------------------------------------------------------
func apply_gravity(delta: float) -> void:
	var g := GRAVITY * (FALL_GRAVITY_MULT if velocity.y < 0.0 else 1.0)
	velocity.y = maxf(velocity.y - g * delta, -MAX_FALL_SPEED)


## Acelera hacia la dirección de entrada con la velocidad máxima indicada.
func apply_horizontal(delta: float, max_speed: float) -> void:
	var dir := move_input()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := dir * max_speed
	var rate: float
	if is_on_floor():
		rate = GROUND_ACCEL if dir.length() > 0.01 else GROUND_DECEL
	else:
		rate = AIR_ACCEL
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if dir.length() > 0.05:
		var target_yaw := atan2(-dir.x, -dir.z)
		facing_yaw = lerp_angle(facing_yaw, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


# ---------------------------------------------------------------------------
# Agacharse
# ---------------------------------------------------------------------------
func set_crouching(value: bool) -> bool:
	if value == crouching:
		return true
	if not value and not has_room_to_stand():
		return false
	crouching = value
	var h := CROUCH_HEIGHT if value else STAND_HEIGHT
	body_shape.height = h
	_collision.position.y = h * 0.5
	return true


func has_room_to_stand() -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = RADIUS - 0.02
	probe.height = STAND_HEIGHT - CROUCH_HEIGHT
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = probe
	params.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.VEHICLES
	params.exclude = [get_rid()]
	# La cápsula de prueba ocupa la parte que falta entre agachado y de pie.
	var y := CROUCH_HEIGHT + probe.height * 0.5 + 0.02
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, y, 0.0))
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


# ---------------------------------------------------------------------------
# Resistencia
# ---------------------------------------------------------------------------
func is_running() -> bool:
	return state_machine.current_name == &"Run"


func _update_stamina(delta: float) -> void:
	var before := stamina
	if energy_timer > 0.0:
		energy_timer = maxf(0.0, energy_timer - delta)
	if energy_timer > 0.0:
		stamina = MAX_STAMINA
		exhausted = false
	elif is_running() and horizontal_speed() > WALK_SPEED + 0.2:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN / PlayerProfile.stamina_mult() * delta)
		_regen_delay = STAMINA_REGEN_DELAY
		if stamina <= 0.0:
			exhausted = true
	elif _regen_delay > 0.0:
		_regen_delay -= delta
	else:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
		if exhausted and stamina >= MAX_STAMINA * STAMINA_RECOVER_RATIO:
			exhausted = false
	if not is_equal_approx(before, stamina):
		EventBus.stamina_changed.emit(stamina, MAX_STAMINA, exhausted)


# ---------------------------------------------------------------------------
# Subir escalones y bordillos
# ---------------------------------------------------------------------------
## Tras chocar con algo bajo (bordillo, escalón), prueba subir: arriba, adelante
## y abajo. La prueba hacia abajo se hace un radio por delante, para que la base
## redondeada de la cápsula quede sobre la huella del escalón y no sobre su borde.
## Si cabe y hay suelo plano, sube el cuerpo a esa altura y conserva la velocidad.
## Devuelve la altura subida (0 si no se pudo).
func _try_step_up(desired: Vector3, _delta: float) -> float:
	var probe := desired.normalized() * RADIUS
	var result := PhysicsTestMotionResult3D.new()
	var from := global_transform
	var up := Vector3.UP * STEP_HEIGHT
	if _test_motion(from, up, result):
		return 0.0  # Techo encima.
	var raised := from.translated(up)
	if _test_motion(raised, probe, result):
		return 0.0  # También bloqueado arriba: es una pared.
	var ahead := raised.translated(probe)
	if not _test_motion(ahead, -up, result):
		return 0.0  # No hay suelo donde apoyarse.
	if result.get_collision_normal().y < cos(floor_max_angle):
		return 0.0  # Lo que hay arriba es demasiado inclinado.
	var rise := STEP_HEIGHT + result.get_travel().y
	if rise <= 0.01:
		return 0.0
	# Comprobar que el cuerpo cabe a la nueva altura sin avanzar.
	if _test_motion(from, Vector3.UP * rise, result):
		return 0.0
	global_position.y += rise + 0.005
	velocity.x = desired.x
	velocity.z = desired.z
	return rise


func _test_motion(from: Transform3D, motion: Vector3, result: PhysicsTestMotionResult3D) -> bool:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	params.margin = safe_margin
	return PhysicsServer3D.body_test_motion(get_rid(), params, result)


# ---------------------------------------------------------------------------
# Escalar y lanzar
# ---------------------------------------------------------------------------
## Busca un borde para escalar justo delante (hacia donde se mueve o mira).
## Devuelve el punto de llegada encima del obstáculo, o Vector3.INF si no hay
## nada escalable: tiene que haber algo bloqueando a menos de 0,7 m, de entre
## 0,45 m y la altura máxima (PlayerProfile.vault_height() por factor), espacio
## libre encima y suelo plano donde apoyarse (o caída al otro lado de un muro delgado).
func find_vault(factor: float = 1.0) -> Vector3:
	vault_target = Vector3.INF
	var dir := move_input()
	var fwd := dir.normalized() if dir.length() > 0.1 else Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))
	var from := global_transform
	var result := PhysicsTestMotionResult3D.new()
	if not _test_motion(from, fwd * 0.7, result):
		return Vector3.INF  # Nada delante.
	if result.get_collision_normal().y > 0.5:
		return Vector3.INF  # Es una rampa o suelo, no un borde.
	var max_h := PlayerProfile.vault_height() * factor
	var h := 0.45
	while h <= max_h + 0.001:
		if _test_motion(from, Vector3.UP * h, result):
			return Vector3.INF  # Techo encima.
		var raised := from.translated(Vector3.UP * h)
		if not _test_motion(raised, fwd * 0.85, result):
			var ahead := raised.translated(fwd * 0.85)
			if _test_motion(ahead, Vector3.DOWN * (h + 0.3), result):
				if result.get_collision_normal().y < 0.7:
					return Vector3.INF
				var top := h + result.get_travel().y
				if top < 0.4:
					return Vector3.INF  # Lo de adelante es bajo: basta con caminar o saltar.
				vault_target = global_position + fwd * 0.85 + Vector3.UP * (top + 0.03)
			else:
				vault_target = global_position + fwd * 0.85 + Vector3.UP * h
			return vault_target
		h += 0.1
	return Vector3.INF


## Lanza una lata hacia donde mira la cámara. Al caer hace ruido (EventBus.noise)
## y la policía y los vigilantes cercanos van a revisar.
func throw_can() -> bool:
	if cans <= 0 or not is_inside_tree():
		return false
	cans -= 1
	var can := ThrownCan.new()
	get_parent().add_child(can)
	var fwd := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	can.global_position = global_position + Vector3.UP * 1.5 + fwd * 0.5
	can.linear_velocity = (fwd * 10.0 + Vector3.UP * 4.5) * PlayerProfile.throw_mult()
	can.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	AudioManager.sfx("throw")
	return true


## Coloca al jugador en un punto, sin velocidad (reaparición y pruebas).
func teleport(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	facing_yaw = yaw
	camera_yaw = yaw
	state_machine.change_state(&"Fall")
