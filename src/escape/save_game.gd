class_name SaveGame
extends RefCounted
## Guardado de la partida en curso en user://partida.cfg.
##
## Se guarda al conseguir cada objetivo, al pedir una pista, al pausar y al
## salir al menú. Como Settings, escribe primero en un archivo temporal y luego
## lo renombra, para que un cierre a mitad no deje el archivo dañado. Si el
## archivo está dañado o es de otra versión, se ignora (y se conserva como .bad).
## No guarda la posición del jugador: al continuar se empieza en el punto de
## inicio con todo lo que ya se había conseguido.

const VERSION := 1
const DEFAULT_PATH := "user://partida.cfg"

static var path := DEFAULT_PATH


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func save(data: Dictionary) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("partida", "version", VERSION)
	cfg.set_value("partida", "saved_at", Time.get_datetime_string_from_system())
	for key: String in data:
		cfg.set_value("partida", key, data[key])
	var tmp := path + ".tmp"
	if cfg.save(tmp) != OK:
		push_warning("No se pudo guardar la partida.")
		return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_warning("No se pudo reemplazar la partida guardada.")
		return false
	return true


## Devuelve los datos guardados o {} si no hay partida válida.
static func load_data() -> Dictionary:
	if not exists():
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or int(cfg.get_value("partida", "version", 0)) != VERSION:
		push_warning("La partida guardada no se pudo leer; se ignora.")
		DirAccess.rename_absolute(path, path + ".bad")
		return {}
	var data := {}
	for key in cfg.get_section_keys("partida"):
		data[key] = cfg.get_value("partida", key)
	return data


static func erase() -> void:
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
