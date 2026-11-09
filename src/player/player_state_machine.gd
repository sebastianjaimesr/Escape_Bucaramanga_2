class_name PlayerStateMachine
extends Node
## Máquina de estados del jugador. Cada estado es un PlayerState que decide, en
## physics_update(), si sigue activo o devuelve el nombre del siguiente estado.

var player: PlayerController
var states: Dictionary = {}
var current: PlayerState
var current_name: StringName = &""


func setup(p: PlayerController) -> void:
	player = p
	for state: PlayerState in [
		IdleState.new(), WalkState.new(), RunState.new(),
		JumpState.new(), FallState.new(), CrouchState.new(), VaultState.new(), SlideState.new(),
		ZiplineState.new(), RollState.new(), HardLandState.new(),
	]:
		state.player = p
		states[state.state_name()] = state
	change_state(&"Idle")


func change_state(state_name: StringName, data: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_error("Estado del jugador desconocido: %s" % state_name)
		return
	if current != null:
		current.exit()
	current = states[state_name]
	current_name = state_name
	current.enter(data)
	EventBus.player_state_changed.emit(state_name)


func physics_update(delta: float) -> void:
	if current == null:
		return
	var next: StringName = current.physics_update(delta)
	if next == &"Vault":
		change_state(next, {"target": player.vault_target})
	elif next != &"" and next != current_name:
		change_state(next)
