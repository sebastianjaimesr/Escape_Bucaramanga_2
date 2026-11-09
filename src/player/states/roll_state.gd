class_name RollState
extends PlayerState
## Rodada de parkour al caer de alto: conserva el impulso, no aturde y levanta
## polvo. Se hace pulsando Agacharse al caer, o sola si vienes corriendo y la
## caída no es demasiado alta.

const DURATION := 0.55

var _t := 0.0
var _dir := Vector3.ZERO
var _speed := 0.0


func state_name() -> StringName:
	return &"Roll"


func enter(_data: Dictionary) -> void:
	_t = 0.0
	var h := Vector3(player.velocity.x, 0.0, player.velocity.z)
	_dir = h.normalized() if h.length() > 0.2 else Vector3(-sin(player.facing_yaw), 0, -cos(player.facing_yaw))
	_speed = clampf(h.length(), PlayerController.WALK_SPEED, PlayerController.RUN_SPEED)
	player.roll_count += 1
	player.set_crouching(true)
	player.visual.pose = "roll"
	AudioManager.sfx("roll", randf_range(0.95, 1.05))
	if player.is_inside_tree():
		Fx.dust(player.get_parent(), player.global_position, 0.9)
	EventBus.camera_shake.emit(0.18)


func exit() -> void:
	player.visual.pose = ""


func physics_update(delta: float) -> StringName:
	_t += delta
	player.apply_gravity(delta)
	var speed := lerpf(_speed, _speed * 0.8, _t / DURATION)
	player.velocity.x = _dir.x * speed
	player.velocity.z = _dir.z * speed
	if not player.is_on_floor() and _t > 0.1:
		return &"Fall"
	if _t >= DURATION:
		if player.set_crouching(false):
			return locomotion_state()
		return &"Crouch"
	return &""
