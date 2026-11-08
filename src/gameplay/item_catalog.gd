class_name ItemCatalog
extends RefCounted
## Todos los objetos del inventario: los del capítulo 1 (EscapeStory.ITEMS) y
## los de los demás capítulos (ChapterStory.ITEMS). Cada uno tiene nombre,
## texto al examinarlo e icono (ItemIcon).


static func item(id: String) -> Dictionary:
	if EscapeStory.ITEMS.has(id):
		return EscapeStory.ITEMS[id]
	return ChapterStory.ITEMS.get(id, {})


static func has(id: String) -> bool:
	return EscapeStory.ITEMS.has(id) or ChapterStory.ITEMS.has(id)
