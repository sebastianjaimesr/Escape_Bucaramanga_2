class_name EscapeUi
extends Node
## Junta los paneles del escape room y decide cuál se abre: inventario (Tab),
## pistas (H), teclado de la caja, patrón del celular y reconstrucción final.
## Solo hay un panel abierto a la vez.

var world: PrototypeWorld
var mission: Mission
var inventory: InventoryPanel
var hints: HintPanel
var code_lock: CodeLockPanel
var pattern_lock: PatternLockPanel
var deduction: DeductionPanel


func _init(w: PrototypeWorld) -> void:
	world = w
	mission = w.mission
	name = "EscapeUi"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	inventory = InventoryPanel.new(world, mission)
	hints = HintPanel.new(world, mission)
	# Los acertijos del capítulo 1 solo existen en EscapeMission (en los demás
	# capítulos los paneles se crean, pero nunca se piden).
	var escape := mission as EscapeMission
	code_lock = CodeLockPanel.new(world, mission)
	pattern_lock = PatternLockPanel.new(world, escape)
	deduction = DeductionPanel.new(world, escape)
	inventory.toggle_action = "inventory"
	hints.toggle_action = "hint"
	for p: ModalPanel in [inventory, hints, code_lock, pattern_lock, deduction]:
		add_child(p)
	deduction.review_requested.connect(func() -> void:
		inventory.open()
		inventory.closed.connect(_back_to_deduction, CONNECT_ONE_SHOT))
	mission.panel_requested.connect(open_panel)


func open_panel(kind: String) -> void:
	if mission.finished or any_open() or world.pause_menu.visible:
		return
	if kind in ["phone", "deduction"] and not mission is EscapeMission:
		return
	if kind == "code" and not mission is EscapeMission and mission.code_panel().is_empty():
		return
	match kind:
		"code":
			code_lock.open()
		"phone":
			pattern_lock.open()
		"deduction":
			deduction.open()
		"inventory":
			inventory.open()
		"hints":
			hints.open()


func any_open() -> bool:
	for p: ModalPanel in [inventory, hints, code_lock, pattern_lock, deduction]:
		if p.is_open:
			return true
	return false


func _back_to_deduction() -> void:
	if not mission.finished and not mission.is_done("reconstruccion"):
		deduction.open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		if inventory.is_open:
			inventory.close()
		else:
			open_panel("inventory")
	elif event.is_action_pressed("hint"):
		get_viewport().set_input_as_handled()
		if hints.is_open:
			hints.close()
		else:
			open_panel("hints")
