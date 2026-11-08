class_name VaultState
extends PlayerState
## Escalar un obstáculo bajo (muro, caja, baranda): sube el cuerpo hasta el
## borde y lo pasa hacia adelante, sin física, porque PlayerController.find_vault()
## ya comprobó que hay espacio. Al terminar conserva la velocidad hacia adelante.

const BASE_TIME := 0.22
const TIME_PER_METER := 0.16

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _duration := 0.3
var _speed := 0.0


func state_name() -> StringName:
	return &"Vault"


func enter(data: Dictionary) -> void:
	if player.crouching:
		player.set_crouching(false)
	player.consume_jump()
	_from = player.global_position
	_to = data.get("target", _from)
	var h := maxf(0.0, _to.y - _from.y)
	_duration = BASE_TIME + h * TIME_PER_METER
	_t = 0.0
	_speed = maxf(player.horizontal_speed(), PlayerController.WALK_SPEED)
	player.velocity = Vector3.ZERO
	player.vault_count += 1
	EventBus.player_vaulted.emit(h)
	AudioManager.sfx("jump", 1.15)


func physics_update(delta: float) -> StringName:
	_t += delta
	var k := clampf(_t / _duration, 0.0, 1.0)
	# Primero sube (hasta el 60 %), luego pasa por encima del borde.
	var up := clampf(k / 0.6, 0.0, 1.0)
	var fwd := clampf((k - 0.35) / 0.65, 0.0, 1.0)
	var y := lerpf(_from.y, _to.y, 1.0 - pow(1.0 - up, 2.0))
	var xz := Vector2(_from.x, _from.z).lerp(Vector2(_to.x, _to.z), fwd * fwd * (3.0 - 2.0 * fwd))
	player.global_position = Vector3(xz.x, y, xz.y)
	player.velocity = Vector3.ZERO
	if k >= 1.0:
		var dir := Vector3(_to.x - _from.x, 0.0, _to.z - _from.z).normalized()
		player.velocity = dir * _speed
		return &"Fall"
	return &""
