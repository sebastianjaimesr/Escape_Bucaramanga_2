class_name HardLandState
extends PlayerState
## Aterrizaje duro (caída alta sin rodar): Sebastián se queda agachado un
## momento, sin poder moverse, con la cámara sacudida. Enseña a rodar.

const DURATION := 0.5

var _t := 0.0


func state_name() -> StringName:
	return &"HardLand"


func enter(_data: Dictionary) -> void:
	_t = 0.0
	player.hard_land_count += 1
	player.velocity.x *= 0.1
	player.velocity.z *= 0.1
	player.visual.land_impact(1.0)
	AudioManager.sfx("thud", randf_range(0.9, 1.0))
	if player.is_inside_tree():
		Fx.dust(player.get_parent(), player.global_position, 1.2)
	EventBus.camera_shake.emit(0.55)


func physics_update(delta: float) -> StringName:
	_t += delta
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, delta * 20.0)
	player.velocity.z = move_toward(player.velocity.z, 0.0, delta * 20.0)
	if _t >= DURATION:
		return locomotion_state()
	return &""
