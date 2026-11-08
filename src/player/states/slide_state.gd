class_name SlideState
extends PlayerState
## Deslizarse: agacharse mientras se corre. Lleva el impulso por el suelo, pasa
## por debajo de vallas y túneles bajos y termina agachado (o corriendo si se
## sigue pulsando Correr y hay espacio para pararse).

const DURATION := 0.75
const BOOST := 1.15
const MIN_SPEED := 2.2

var _dir := Vector3.ZERO
var _speed := 0.0
var _t := 0.0


func state_name() -> StringName:
	return &"Slide"


func enter(_data: Dictionary) -> void:
	player.set_crouching(true)
	var h := Vector3(player.velocity.x, 0.0, player.velocity.z)
	_dir = h.normalized() if h.length() > 0.1 else Vector3(-sin(player.facing_yaw), 0, -cos(player.facing_yaw))
	_speed = maxf(h.length(), PlayerController.RUN_SPEED) * BOOST
	_t = 0.0
	player.slide_count += 1
	AudioManager.sfx("slide")


func physics_update(delta: float) -> StringName:
	_t += delta
	player.apply_gravity(delta)
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var speed := lerpf(_speed, PlayerController.CROUCH_SPEED, k * k)
	player.velocity.x = _dir.x * speed
	player.velocity.z = _dir.z * speed
	if not player.is_on_floor():
		return &"Fall"
	if k >= 1.0 or speed < MIN_SPEED:
		if player.wants_run() and player.move_input().length() > 0.05 and player.set_crouching(false):
			return &"Run"
		return &"Crouch"
	return &""
