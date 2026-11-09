class_name ZiplineState
extends PlayerState
## Colgado de la tirolesa: baja por el cable sin gravedad, acelerando un poco
## al principio. Al llegar (o al pulsar Saltar) se suelta con el impulso.

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _speed := 13.0
var _t := 0.0
var _len := 1.0
var _v := 0.0
var _line: Zipline
var _sound: AudioStreamPlayer3D


func state_name() -> StringName:
	return &"Zipline"


func enter(data: Dictionary) -> void:
	if player.crouching:
		player.set_crouching(false)
	_from = data.get("from", player.global_position)
	_to = data.get("to", player.global_position)
	_speed = float(data.get("speed", 13.0))
	_line = data.get("line", null)
	_len = maxf(0.1, _from.distance_to(_to))
	_t = 0.0
	_v = 3.0
	player.velocity = Vector3.ZERO
	player.global_position = _from
	var flat := Vector3(_to.x - _from.x, 0, _to.z - _from.z)
	player.facing_yaw = atan2(-flat.x, -flat.z)
	player.visual.pose = "hang"
	player.consume_jump()
	if player.is_inside_tree():
		_sound = AudioManager.loop_3d(player, "zipline", -6.0)


func exit() -> void:
	player.visual.pose = ""
	if _sound != null:
		_sound.queue_free()
		_sound = null


func physics_update(delta: float) -> StringName:
	_v = move_toward(_v, _speed, delta * 9.0)
	_t += _v * delta / _len
	var dir := (_to - _from).normalized()
	var pos := _from.lerp(_to, clampf(_t, 0.0, 1.0))
	# Se mueve con la física para que choque si algo se interpone.
	player.velocity = (pos - player.global_position) / maxf(delta, 0.001)
	if _t >= 1.0 or (player.input_enabled and Input.is_action_just_pressed("jump") and _t > 0.15):
		player.velocity = dir * _v * 0.55 + Vector3.UP * 1.5
		player.air_max_speed = maxf(PlayerController.RUN_SPEED, Vector2(player.velocity.x, player.velocity.z).length())
		if _t >= 1.0 and _line != null:
			_line.arrived.emit(player)
		EventBus.camera_shake.emit(0.25)
		return &"Fall"
	return &""
