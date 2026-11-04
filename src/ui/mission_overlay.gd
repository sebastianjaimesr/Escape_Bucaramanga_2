class_name MissionOverlay
extends CanvasLayer
## Pantallas de la misión: "¡Te atraparon!" (vuelve con los amigos después de
## unos segundos) y la de victoria con el tiempo y las veces atrapado.

const CAUGHT_SECONDS := 2.8

var mission: EscapeMission
var _dim: ColorRect
var _box: VBoxContainer
var _title: Label
var _body: Label
var _buttons: HBoxContainer
var _timer := 0.0


func _init(m: EscapeMission) -> void:
	mission = m


func _ready() -> void:
	layer = 20
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.02, 0.02, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	center.add_child(_box)
	_title = UiStyle.label("", 52)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_title)
	_body = UiStyle.label("", 20, UiStyle.TEXT_DIM)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_body)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	_box.add_child(_buttons)
	var again := UiStyle.button("Jugar otra vez", 220)
	again.pressed.connect(func() -> void:
		SceneLoader.change_scene(MainMenu.PROTOTYPE_SCENE, "Manzana de prueba"))
	_buttons.add_child(again)
	var menu := UiStyle.button("Menú principal", 220)
	menu.pressed.connect(func() -> void: SceneLoader.change_scene(SceneLoader.MAIN_MENU, "Menú principal"))
	_buttons.add_child(menu)
	_dim.visible = false
	mission.caught.connect(_on_caught)
	mission.won.connect(_on_won)


func _on_caught(count: int) -> void:
	_title.text = "¡Te atraparon!"
	_title.add_theme_color_override("font_color", UiStyle.ACCENT)
	var extra := "" if count == 1 else "\n(Van %d veces)" % count
	_body.text = "Sebastián se escabulle y vuelve con sus amigos. Conserva las pruebas.%s" % extra
	_buttons.visible = false
	_dim.color = Color(0.12, 0.02, 0.02, 0.6)
	_dim.visible = true
	_timer = CAUGHT_SECONDS


func _on_won(time_seconds: float, caught_count: int) -> void:
	_title.text = "¡Malentendido aclarado!"
	_title.add_theme_color_override("font_color", UiStyle.OK)
	var mins := int(time_seconds) / 60
	var secs := int(time_seconds) % 60
	_body.text = "Entregaste las %d pruebas en %d:%02d.\nVeces atrapado: %d" % [mission.total, mins, secs, caught_count]
	_buttons.visible = true
	_dim.color = Color(0.02, 0.06, 0.03, 0.65)
	_dim.visible = true
	_timer = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_buttons.get_child(0) as Button).grab_focus()


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_dim.visible = false
			mission.resume_after_caught()


func is_showing() -> bool:
	return _dim.visible
