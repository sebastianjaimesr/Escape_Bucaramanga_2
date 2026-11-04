extends Node
## Acciones de entrada del juego y reasignación de teclas.
##
## Las acciones se crean por código (no en project.godot) para tener un solo
## lugar con los valores por defecto. Las teclas reasignadas por el jugador se
## guardan en Settings, sección "controls" (acción -> physical_keycode).

signal bindings_changed

## Acción -> [etiqueta visible, teclas por defecto (physical keycodes)].
const ACTIONS := {
	"move_forward": ["Avanzar", [KEY_W, KEY_UP]],
	"move_back": ["Retroceder", [KEY_S, KEY_DOWN]],
	"move_left": ["Izquierda", [KEY_A, KEY_LEFT]],
	"move_right": ["Derecha", [KEY_D, KEY_RIGHT]],
	"run": ["Correr", [KEY_SHIFT]],
	"jump": ["Saltar", [KEY_SPACE]],
	"crouch": ["Agacharse", [KEY_C]],
	"interact": ["Interactuar", [KEY_E]],
	"vehicle": ["Entrar o salir del vehículo", [KEY_F]],
	"inventory": ["Inventario", [KEY_TAB]],
	"map": ["Mapa", [KEY_M]],
	"pause": ["Pausa", [KEY_ESCAPE]],
	"toggle_fps": ["Medidor de rendimiento", [KEY_F3]],
}

## Acciones que el jugador puede reasignar (la pausa queda fija en Esc).
const REBINDABLE := [
	"move_forward", "move_back", "move_left", "move_right",
	"run", "jump", "crouch", "interact", "vehicle", "inventory", "map", "toggle_fps",
]

## Acciones que ya hacen algo en el juego. Solo estas se muestran en el panel de
## controles, para no ofrecer teclas de funciones que todavía no existen.
## Se amplía en cada fase (interactuar, vehículo, inventario, mapa…).
const IN_USE := [
	"move_forward", "move_back", "move_left", "move_right",
	"run", "jump", "crouch", "interact", "toggle_fps",
]

const JOY_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"crouch": [JOY_BUTTON_B],
	"interact": [JOY_BUTTON_X],
	"vehicle": [JOY_BUTTON_Y],
	"run": [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_LEFT_SHOULDER],
	"pause": [JOY_BUTTON_START],
	"map": [JOY_BUTTON_BACK],
}

const JOY_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
}

const SETTINGS_SECTION := "controls"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_all()


func label(action: String) -> String:
	return ACTIONS.get(action, [action])[0]


## Tecla principal actual de la acción (la reasignada o la primera por defecto).
func primary_key(action: String) -> Key:
	var saved: Variant = Settings.get_section(SETTINGS_SECTION).get(action)
	if saved != null:
		return int(saved) as Key
	var keys: Array = ACTIONS[action][1]
	return keys[0]


func key_name(action: String) -> String:
	var key := primary_key(action)
	# Con distribución de teclado distinta (AZERTY…) se muestra la letra real.
	# Los servidores headless y web no conocen la distribución: se usa el nombre físico.
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		var text := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key))
		if text != "":
			return text
	return OS.get_keycode_string(key)


## Acción que ya usa esa tecla como principal, o "" si está libre.
func action_using_key(key: Key) -> String:
	for action: String in ACTIONS:
		if primary_key(action) == key:
			return action
	return ""


## Reasigna la tecla principal. Si otra acción la usaba, intercambia las teclas
## para que ninguna acción quede sin tecla.
func rebind(action: String, key: Key) -> void:
	if not REBINDABLE.has(action):
		push_error("La acción %s no se puede reasignar." % action)
		return
	var previous := primary_key(action)
	var other := action_using_key(key)
	if other != "" and other != action:
		if not REBINDABLE.has(other):
			push_warning("La tecla está reservada para %s." % label(other))
			return
		Settings.set_value(SETTINGS_SECTION, other, int(previous), false)
	Settings.set_value(SETTINGS_SECTION, action, int(key), false)
	Settings.save_settings()
	apply_all()


func reset_defaults() -> void:
	Settings.erase_section(SETTINGS_SECTION)
	Settings.save_settings()
	apply_all()


## Reconstruye el InputMap desde los valores por defecto y lo guardado.
func apply_all() -> void:
	var saved := Settings.get_section(SETTINGS_SECTION)
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		var keys: Array = (ACTIONS[action][1] as Array).duplicate()
		if saved.has(action):
			# La tecla reasignada reemplaza a la principal; las secundarias por
			# defecto (flechas) se mantienen salvo que choquen con otra acción.
			keys[0] = int(saved[action])
		for key: int in keys:
			if key != keys[0] and _key_taken_by_other(key, action, saved):
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
		for button: int in JOY_BUTTONS.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = button as JoyButton
			InputMap.action_add_event(action, jb)
		if JOY_AXES.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = JOY_AXES[action][0]
			jm.axis_value = JOY_AXES[action][1]
			InputMap.action_add_event(action, jm)
	bindings_changed.emit()


func _key_taken_by_other(key: int, action: String, saved: Dictionary) -> bool:
	for other: String in saved:
		if other != action and int(saved[other]) == key:
			return true
	return false
