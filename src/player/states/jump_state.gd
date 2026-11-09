class_name JumpState
extends PlayerState
## Impulso del salto. Si se suelta el botón pronto, el salto es más bajo.

var _cut := false


func state_name() -> StringName:
	return &"Jump"


func enter(_data: Dictionary) -> void:
	if player.crouching:
		player.set_crouching(false)
	player.consume_jump()
	player.velocity.y = PlayerController.JUMP_VELOCITY
	player.jump_count += 1
	AudioManager.sfx("jump", randf_range(0.95, 1.08))
	_cut = false


func physics_update(delta: float) -> StringName:
	if not _cut and not player.jump_held() and player.velocity.y > 0.0:
		player.velocity.y *= PlayerController.JUMP_CUT
		_cut = true
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.air_max_speed)
	if player.is_on_ceiling():
		player.velocity.y = minf(player.velocity.y, 0.0)
	var climb := air_transitions()
	if climb != &"":
		return climb
	if player.velocity.y <= 0.0:
		return &"Fall"
	return &""
