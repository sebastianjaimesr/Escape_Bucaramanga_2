extends Node
## Qué partida se va a jugar: modo elegido en la portada y si se continúa la
## partida guardada. La lee EscapeMission al crearse.

## "explorador" o "contrarreloj" (ver EscapeStory.MODES).
var mode := "explorador"
## Si es true, la misión carga SaveGame al empezar.
var continue_saved := false
## Las pruebas lo apagan para no escribir la partida del jugador.
var save_enabled := true


func new_game(mode_id: String) -> void:
	mode = mode_id if EscapeStory.MODES.has(mode_id) else "explorador"
	continue_saved = false
	if save_enabled:
		SaveGame.erase()


func continue_game() -> void:
	continue_saved = true


## Resumen corto para el botón «Continuar» de la portada, o "" si no hay partida.
func saved_summary() -> String:
	var data := SaveGame.load_data()
	if data.is_empty():
		return ""
	var done: int = (data.get("steps_done", []) as Array).size()
	var secs := int(data.get("elapsed", 0.0))
	return "%s · %d/%d objetivos · %d:%02d" % [EscapeStory.mode(str(data.get("mode", ""))).get("label", ""),
			done, EscapeStory.STEPS.size(), secs / 60, secs % 60]
