class_name HintSystem
extends RefCounted
## Pistas por niveles: cada paso de la misión tiene tres. Se revelan de una en
## una cuando el jugador las pide, y se cuentan para la pantalla final.

signal hint_revealed(step_id: String, text: String)

## Paso -> cuántas pistas se revelaron (0..3).
var revealed: Dictionary = {}
## Devuelve el paso con sus pistas a partir de su id (lo pone la misión).
var lookup: Callable = EscapeStory.step


func revealed_count(step_id: String) -> int:
	return int(revealed.get(step_id, 0))


func available(step_id: String) -> int:
	return (lookup.call(step_id).get("hints", []) as Array).size()


func revealed_hints(step_id: String) -> PackedStringArray:
	var hints: Array = lookup.call(step_id).get("hints", [])
	return PackedStringArray(hints.slice(0, revealed_count(step_id)))


## Revela la siguiente pista del paso. Devuelve "" si ya no quedan.
func reveal_next(step_id: String) -> String:
	var hints: Array = lookup.call(step_id).get("hints", [])
	var n := revealed_count(step_id)
	if n >= hints.size():
		return ""
	revealed[step_id] = n + 1
	hint_revealed.emit(step_id, hints[n])
	return hints[n]


func total_used() -> int:
	var t := 0
	for k: String in revealed:
		t += int(revealed[k])
	return t


func to_data() -> Dictionary:
	return revealed.duplicate()


func from_data(data: Dictionary) -> void:
	revealed.clear()
	for k: Variant in data:
		var id := str(k)
		if not lookup.call(id).is_empty():
			revealed[id] = clampi(int(data[k]), 0, available(id))
