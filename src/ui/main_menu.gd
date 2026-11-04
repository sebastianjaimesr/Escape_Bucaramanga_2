class_name MainMenu
extends Control
## Menú principal del prototipo de la Fase 2.
## Solo muestra opciones que funcionan: las partidas guardadas, créditos y el
## resto del menú definitivo llegan en la Fase 9.

const PROTOTYPE_SCENE := "res://scenes/world/prototype/prototype_world.tscn"

var _menu: VBoxContainer
var _settings: SettingsPanel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiStyle.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = UiStyle.ACCENT
	stripe.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	stripe.custom_minimum_size = Vector2(6, 0)
	add_child(stripe)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	col.add_child(_menu)
	_menu.add_child(UiStyle.label("ESCAPE DE", 22, UiStyle.TEXT_DIM))
	_menu.add_child(UiStyle.label("BUCARAMANGA", 56))
	var tag := UiStyle.label("Prototipo 3D · Policía, pruebas y escondites", 16, UiStyle.ACCENT)
	_menu.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	_menu.add_child(spacer)
	var play := UiStyle.button("Jugar: las pruebas del malentendido")
	play.pressed.connect(func() -> void: SceneLoader.change_scene(PROTOTYPE_SCENE, "Manzana de prueba"))
	_menu.add_child(play)
	var settings := UiStyle.button("Configuración")
	settings.pressed.connect(_show_settings)
	_menu.add_child(settings)
	if not OS.has_feature("web"):
		var quit := UiStyle.button("Salir")
		quit.pressed.connect(func() -> void: get_tree().quit())
		_menu.add_child(quit)
	var version := UiStyle.label("Versión %s" % ProjectSettings.get_setting("application/config/version"), 13, UiStyle.TEXT_DIM)
	_menu.add_child(version)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_hide_settings)
	col.add_child(_settings)
	play.grab_focus()


func _show_settings() -> void:
	_menu.visible = false
	_settings.visible = true


func _hide_settings() -> void:
	_settings.visible = false
	_menu.visible = true
