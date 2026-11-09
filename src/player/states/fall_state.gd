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
		var impact := player.last_landing_speed
		if impact >= PlayerController.ROLL_MIN_SPEED and (player.crouch_held() \
				or (player.horizontal_speed() > PlayerController.WALK_SPEED + 1.0 and impact < PlayerController.HARD_LAND_SPEED + 2.0)):
			return &"Roll"
		if impact >= PlayerController.HARD_LAND_SPEED:
			return &"HardLand"
		if impact > 4.5:
			player.visual.land_impact(clampf(impact / PlayerController.HARD_LAND_SPEED, 0.2, 0.8))
		return &"Crouch" if player.crouching else locomotion_state()
	return &""
