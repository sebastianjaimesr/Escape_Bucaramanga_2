extends Node
## Configuración del jugador (gráficos, cámara, controles) guardada en
## user://settings.cfg. Es independiente de las partidas guardadas.
##
## Cada valor tiene un valor por defecto en DEFAULTS. Si el archivo no existe se
## usan los valores por defecto; si está dañado se avisa con push_warning, se usan
## los valores por defecto y el archivo dañado se conserva como .bad para revisarlo.

signal changed(section: String, key: String, value: Variant)

const DEFAULT_PATH := "user://settings.cfg"

const DEFAULTS := {
	"graphics": {
		"profile": "",          ## "" = elegir según la plataforma (ver default_profile()).
		"show_fps": false,
		"fullscreen": false,
	},
	"audio": {
		"master": 0.8,
		"music": 0.55,
		"ambient": 0.6,
		"sfx": 0.85,
		"muted": false,
	},
	"interface": {
		"touch_controls": "auto",  ## "auto" (si la pantalla es táctil), "on" u "off".
		"reduce_motion": false,     ## Menos animaciones y sin grano de película.
	},
	"camera": {
		"mouse_sensitivity": 0.25,  ## Grados por píxel de movimiento del ratón.
		"stick_sensitivity": 160.0,  ## Grados por segundo con la palanca derecha.
		"invert_y": false,
		"fov": 72.0,
	},
}

var config_path := DEFAULT_PATH
var last_error := ""
var _values: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_window_mode()
	changed.connect(func(section: String, key: String, _v: Variant) -> void:
		if section == "graphics" and key == "fullscreen":
			apply_window_mode())


## La pantalla completa solo se controla desde el juego en PC; en el navegador
## la maneja el propio navegador (F11) y en modo headless no hay ventana.
func supports_fullscreen() -> bool:
	return not OS.has_feature("web") and DisplayServer.get_name() != "headless"


func apply_window_mode() -> void:
	if not supports_fullscreen():
		return
	var fs := bool(get_value("graphics", "fullscreen"))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)


func default_profile() -> String:
	return "bajo" if OS.has_feature("web") else "medio"


func get_value(section: String, key: String) -> Variant:
	var sec: Dictionary = _values.get(section, {})
	if sec.has(key):
		return sec[key]
	var defaults: Dictionary = DEFAULTS.get(section, {})
	if defaults.has(key):
		return defaults[key]
	push_error("Configuración desconocida: %s/%s" % [section, key])
	return null


func set_value(section: String, key: String, value: Variant, save_now: bool = true) -> void:
	if not _values.has(section):
		_values[section] = {}
	_values[section][key] = value
	changed.emit(section, key, value)
	if save_now:
		save_settings()


func erase_section(section: String) -> void:
	_values.erase(section)


func get_section(section: String) -> Dictionary:
	return (_values.get(section, {}) as Dictionary).duplicate()


## Controles táctiles en pantalla: según el ajuste o si la pantalla es táctil.
func touch_controls_enabled() -> bool:
	match str(get_value("interface", "touch_controls")):
		"on":
			return true
		"off":
			return false
	return DisplayServer.is_touchscreen_available()


func quality_profile() -> String:
	var p: String = get_value("graphics", "profile")
	return p if QualityProfiles.PROFILES.has(p) else default_profile()


func reset_to_defaults() -> void:
	_values.clear()
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]:
			changed.emit(section, key, DEFAULTS[section][key])
	save_settings()


func save_settings() -> bool:
	var cfg := ConfigFile.new()
	for section: String in _values:
		for key: String in _values[section]:
			cfg.set_value(section, key, _values[section][key])
	var tmp := config_path + ".tmp"
	var err := cfg.save(tmp)
	if err != OK:
		last_error = "No se pudo guardar la configuración (%s)." % error_string(err)
		push_warning(last_error)
		return false
	# Reemplazo en dos pasos: si el juego se cierra a mitad, queda el archivo anterior.
	err = DirAccess.rename_absolute(tmp, config_path)
	if err != OK:
		last_error = "No se pudo reemplazar la configuración (%s)." % error_string(err)
		push_warning(last_error)
		return false
	last_error = ""
	return true


func load_settings() -> bool:
	_values.clear()
	if not FileAccess.file_exists(config_path):
		return false
	var cfg := ConfigFile.new()
	var err := cfg.load(config_path)
	if err != OK:
		last_error = "La configuración estaba dañada (%s); se usan los valores por defecto." % error_string(err)
		push_warning(last_error)
		DirAccess.rename_absolute(config_path, config_path + ".bad")
		return false
	for section in cfg.get_sections():
		_values[section] = {}
		for key in cfg.get_section_keys(section):
			_values[section][key] = cfg.get_value(section, key)
	return true
