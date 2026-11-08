class_name PlayerState
extends RefCounted
## Base de los estados del jugador.

var player: PlayerController


func state_name() -> StringName:
	return &""


func enter(_data: Dictionary) -> void:
	pass


func exit() -> void:
	pass


## Devuelve el nombre del siguiente estado, o &"" para seguir en este.
func physics_update(_delta: float) -> StringName:
	return &""


## Transiciones comunes a los estados en el suelo.
func ground_transitions() -> StringName:
	if player.can_jump():
		if player.move_input().length() > 0.3 and player.find_vault() != Vector3.INF:
			return &"Vault"
		return &"Jump"
	if not player.is_on_floor():
		return &"Fall"
	if player.crouch_pressed():
		return &"Crouch"
	return &""


## En el aire contra un borde, con Saltar pulsado: se agarra y sube.
func air_transitions() -> StringName:
	if player.jump_held() and player.move_input().length() > 0.3 and player.velocity.y < 1.5:
		var target := player.find_vault(0.8)
		if target != Vector3.INF:
			return &"Vault"
	return &""


## Estado de suelo según la entrada actual.
func locomotion_state() -> StringName:
	if player.move_input().length() < 0.05:
		return &"Idle"
	if player.wants_run() and player.can_run():
		return &"Run"
	return &"Walk"
