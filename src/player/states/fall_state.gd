class_name FallState
extends PlayerState
## En el aire bajando. El tiempo de coyote permite saltar justo después de dejar el borde.


func state_name() -> StringName:
	return &"Fall"


func physics_update(delta: float) -> StringName:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.air_max_speed)
	if player.can_jump():
		return &"Jump"
	var climb := air_transitions()
	if climb != &"":
		return climb
	if player.is_on_floor():
		return &"Crouch" if player.crouching else locomotion_state()
	return &""
