class_name LoadingScreen
extends CanvasLayer
## Pantalla de carga y de error de carga. La usa SceneLoader. Muestra un
## consejo del juego mientras carga y se desvanece al terminar.

signal back_requested

const TIPS := [
	"Las pruebas brillan en dorado. Examínalas en el inventario: sus detalles abren cerraduras.",
	"Agachado entre los matorrales, la policía no te ve.",
	"Si corres cerca de un policía, te oye aunque esté de espaldas.",
	"Un granizado da resistencia sin límite durante un rato.",
	"Tus amigos saben cosas. Vuelve a hablar con ellos cuando consigas algo nuevo.",
	"¿Atascado? Cada objetivo tiene tres pistas; la última da la solución.",
]

var _root: ColorRect
var _title: Label
var _bar: ProgressBar
var _message: Label
var _tip: Label
var _back: Button
var _box: VBoxContainer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = ColorRect.new()
	_root.color = UiStyle.BG_DEEP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_box = VBoxContainer.new()
	_box.custom_minimum_size = Vector2(440, 0)
	_box.add_theme_constant_override("separation", 16)
	center.add_child(_box)
	var over := UiStyle.overline("Escape de Bucaramanga")
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(over)
	_title = UiStyle.title("Cargando…", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_title)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(440, 6)
	UiStyle.style_bar(_bar, UiStyle.ACCENT)
	_box.add_child(_bar)
	_tip = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_tip)
	_message = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_message)
	_back = UiStyle.button("Volver al menú principal")
	_back.pressed.connect(func() -> void: back_requested.emit())
	_box.add_child(_back)
	visible = false


func show_loading(title: String) -> void:
	visible = true
	_root.modulate.a = 1.0
	_title.text = title if title != "" else "Cargando…"
	_bar.visible = true
	_bar.value = 0.0
	_message.text = ""
	_tip.text = TIPS[randi() % TIPS.size()]
	_tip.visible = true
	_back.visible = false


func set_progress(value: float) -> void:
	_bar.value = clampf(value, 0.0, 1.0)


func show_error(message: String, allow_back: bool) -> void:
	visible = true
	_root.modulate.a = 1.0
	_title.text = "No se pudo cargar"
	_bar.visible = false
	_tip.visible = false
	_message.text = message
	_back.visible = allow_back
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Se desvanece (o se oculta de una vez si el jugador pidió menos animaciones).
func hide_screen() -> void:
	if not visible or bool(Settings.get_value("interface", "reduce_motion")):
		visible = false
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: visible = false)
