class_name Inventory
extends RefCounted
## Objetos que lleva Sebastián. Guarda solo identificadores; los nombres y
## textos están en ItemCatalog (EscapeStory.ITEMS y ChapterStory.ITEMS).

signal changed
signal item_added(id: String)

var items: Array[String] = []
## Dice si un identificador es un objeto válido (para ignorar datos viejos o dañados).
var catalog: Callable = ItemCatalog.has


func add(id: String) -> bool:
	if id in items:
		return false
	items.append(id)
	changed.emit()
	item_added.emit(id)
	return true


func has(id: String) -> bool:
	return id in items


func remove(id: String) -> void:
	if id in items:
		items.erase(id)
		changed.emit()


## Cambia un objeto por otro en el mismo lugar (el celular bloqueado por el desbloqueado).
func replace(old_id: String, new_id: String) -> void:
	var i := items.find(old_id)
	if i < 0:
		add(new_id)
		return
	items[i] = new_id
	changed.emit()


func clear() -> void:
	items.clear()
	changed.emit()


func to_data() -> Array:
	return items.duplicate()


func from_data(data: Array) -> void:
	items.clear()
	for id: Variant in data:
		if catalog.call(str(id)) and not str(id) in items:
			items.append(str(id))
	changed.emit()
