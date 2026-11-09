extends Node
## Qué partida se va a jugar: capítulo y modo elegidos en la portada, y si se
## continúa la partida guardada. La leen PrototypeWorld y la misión al crearse.

## Capítulo a jugar (ver Chapters.LIST).
var chapter := Chapters.FIRST
## "explorador" o "contrarreloj" (ver EscapeStory.MODES; solo en el capítulo 1).
var mode := "explorador"
## Si es true, la misión carga SaveGame al empezar.
var continue_saved := false
## Las pruebas lo apagan para no escribir la partida del jugador.
var save_enabled := true
## Cinemáticas cortas al empezar un capítulo y en los momentos clave (las
## pruebas automáticas las apagan para no esperar).
var cinematics_enabled := true


func new_game(mode_id: String, chapter_id: String = Chapters.FIRST) -> void:
	mode = mode_id if EscapeStory.MODES.has(mode_id) else "explorador"
	chapter = chapter_id if Chapters.index_of(chapter_id) >= 0 else Chapters.FIRST
	continue_saved = false
	if save_enabled:
		SaveGame.erase()


func continue_game() -> void:
	var data := SaveGame.load_data()
	var saved := str(data.get("chapter", Chapters.FIRST))
	chapter = saved if Chapters.index_of(saved) >= 0 else Chapters.FIRST
	mode = str(data.get("mode", mode)) if EscapeStory.MODES.has(str(data.get("mode", ""))) else mode
	continue_saved = true


## Resumen corto para el botón «Continuar» de la portada, o "" si no hay partida.
func saved_summary() -> String:
	var data := SaveGame.load_data()
	if data.is_empty():
		return ""
	var id := str(data.get("chapter", Chapters.FIRST))
	var c := Chapters.get_chapter(id)
	if c.is_empty():
		return ""
	var done: int = (data.get("steps_done", []) as Array).size()
	var total := (EscapeStory.STEPS if id == Chapters.FIRST else ChapterStory.steps(id)).size()
	var secs := int(data.get("elapsed", 0.0))
	return "Cap. %d · %d/%d objetivos · %d:%02d" % [int(c["number"]), done, total, secs / 60, secs % 60]
