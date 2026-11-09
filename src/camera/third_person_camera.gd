class_name ThirdPersonCamera
extends Node3D
## Cámara en tercera persona con ratón o palanca derecha.
##
## Estructura: este nodo (pivote, sigue al objetivo) → SpringArm3D (se acorta si
## hay una pared entre el jugador y la cámara) → Camera3D.
## Informa su orientación horizontal al jugador para que el movimiento sea
## relativo a la cámara.

const ARM_LENGTH := 3.6
const ARM_MARGIN := 0.2
const PROBE_RADIUS := 0.25
const STAND_PIVOT_HEIGHT := 1.55
const CROUCH_PIVOT_HEIGHT := 1.0
const SHOULDER_OFFSET := 0.35     ## Desplazamiento lateral (cámara sobre el hombro derecho).
const FOLLOW_SHARPNESS := 14.0
const MIN_PITCH := deg_to_rad(-65.0)
const MAX_PITCH := deg_to_rad(50.0)
const RUN_FOV_BONUS := 6.0

var target: PlayerController
var yaw := 0.0
var pitch := deg_to_rad(-12.0)
var camera: Camera3D
var arm: SpringArm3D

var _pivot_height := STAND_PIVOT_HEIGHT
## Sacudida (0..1): sube con los golpes y baja sola. Se aplica al cuadrado,
## así los golpes chicos casi no se notan y los grandes sí.
var trauma := 0.0
var _shake_t := 0.0


func _ready() -> void:
	top_level = true
	arm = SpringArm3D.new()
	arm.name = "SpringArm"
	arm.spring_length = ARM_LENGTH
	arm.margin = ARM_MARGIN
	arm.collision_mask = PhysicsLayers.CAMERA_BLOCKERS
	var probe := SphereShape3D.new()
	probe.radius = PROBE_RADIUS
	arm.shape = probe
	# El SpringArm coloca a sus hijos en su eje; el desplazamiento al hombro se
	# aplica al brazo mismo.
	arm.position = Vector3(SHOULDER_OFFSET, 0.0, 0.0)
	add_child(arm)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.05
	camera.fov = float(Settings.get_value("camera", "fov"))
	arm.add_child(camera)
	Settings.changed.connect(_on_setting_changed)
	EventBus.camera_shake.connect(add_trauma)


func add_trauma(amount: float) -> void:
	if Fx.reduced():
		amount *= 0.3
	trauma = clampf(trauma + amount, 0.0, 1.0)


func set_target(p: PlayerController) -> void:
	target = p
	arm.add_excluded_object(p.get_rid())
	yaw = p.facing_yaw
	snap()


## Coloca la cámara de inmediato detrás del objetivo (al aparecer o reaparecer).
func snap() -> void:
	if target == null:
		return
	_pivot_height = CROUCH_PIVOT_HEIGHT if target.crouching else STAND_PIVOT_HEIGHT
	global_position = target.global_position + Vector3.UP * _pivot_height
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := (event as InputEventMouseMotion).screen_relative
		var sens := deg_to_rad(float(Settings.get_value("camera", "mouse_sensitivity")))
		rotate_view(-motion.x * sens, -motion.y * sens)


func rotate_view(yaw_delta: float, pitch_delta: float) -> void:
	if bool(Settings.get_value("camera", "invert_y")):
		pitch_delta = -pitch_delta
	yaw = wrapf(yaw + yaw_delta, -PI, PI)
	pitch = clampf(pitch + pitch_delta, MIN_PITCH, MAX_PITCH)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.15:
		var rate := deg_to_rad(float(Settings.get_value("camera", "stick_sensitivity"))) * delta
		rotate_view(-stick.x * rate, -stick.y * rate)
	var wanted_height := CROUCH_PIVOT_HEIGHT if target.crouching else STAND_PIVOT_HEIGHT
	_pivot_height = lerpf(_pivot_height, wanted_height, clampf(delta * 8.0, 0.0, 1.0))
	var goal := target.global_position + Vector3.UP * _pivot_height
	var t := 1.0 - exp(-FOLLOW_SHARPNESS * delta)
	global_position = global_position.lerp(goal, t)
	# Los escalones suben al jugador de golpe; la cámara los suaviza sola con el lerp.
	_apply_rotation()
	target.camera_yaw = yaw
	var base_fov := float(Settings.get_value("camera", "fov"))
	var fov_goal := base_fov + (RUN_FOV_BONUS if target.is_running() else 0.0)
	camera.fov = lerpf(camera.fov, fov_goal, clampf(delta * 5.0, 0.0, 1.0))
	_update_shake(delta)


func _update_shake(delta: float) -> void:
	if trauma <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	_shake_t += delta * 30.0
	var k := trauma * trauma
	camera.h_offset = (sin(_shake_t * 1.13) + sin(_shake_t * 2.71) * 0.5) * 0.12 * k
	camera.v_offset = (cos(_shake_t * 1.37) + sin(_shake_t * 3.07) * 0.5) * 0.12 * k
	trauma = maxf(0.0, trauma - delta * 1.6)


func _apply_rotation() -> void:
	rotation = Vector3(pitch, yaw, 0.0)


## Distancia real entre el pivote y la cámara (menor que ARM_LENGTH si hay una pared).
func current_distance() -> float:
	return arm.get_hit_length()


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "camera" and key == "fov":
		camera.fov = float(value)
