class_name SafeBox
extends Node3D
## Caja fuerte de la oficina de El Búho (capítulo 5): un cubo de acero con
## teclado y piloto. Al interactuar, la misión abre el teclado (CodeLockPanel).
## Con la clave correcta la puerta gira y el piloto se pone verde.

var opened := false
var interactable: Interactable

var _door: Node3D
var _led_mat: StandardMaterial3D
var _open := 0.0


func _ready() -> void:
	name = "CajaFuerte"
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22, 0.24, 0.27)
	steel.metallic = 0.75
	steel.roughness = 0.35
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.9, 0.7)
	body.mesh = bm
	body.material_override = steel
	body.position.y = 0.45
	add_child(body)
	var solid := StaticBody3D.new()
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	col.shape = bs
	col.position.y = 0.45
	solid.add_child(col)
	add_child(solid)
	# Puerta con bisagra a la izquierda; mira hacia -X (hacia la entrada de la caseta).
	_door = Node3D.new()
	_door.position = Vector3(-0.36, 0.45, 0.3)
	add_child(_door)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.06, 0.78, 0.58)
	door.mesh = dm
	door.material_override = steel
	door.position = Vector3(-0.03, 0, -0.29)
	_door.add_child(door)
	var dial := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.09
	cyl.height = 0.05
	dial.mesh = cyl
	dial.material_override = MaterialLibrary.get_material("metal")
	dial.rotation.z = PI * 0.5
	dial.position = Vector3(-0.08, 0.05, -0.3)
	_door.add_child(dial)
	_led_mat = StandardMaterial3D.new()
	_led_mat.emission_enabled = true
	_led_mat.albedo_color = Color(1, 0.15, 0.1)
	_led_mat.emission = Color(1, 0.15, 0.1)
	_led_mat.emission_energy_multiplier = 3.0
	var led := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.025
	lm.height = 0.05
	led.mesh = lm
	led.material_override = _led_mat
	led.position = Vector3(-0.08, 0.28, -0.1)
	_door.add_child(led)
	interactable = Interactable.new("Abrir la caja fuerte", 1.5)
	add_child(interactable)


func _process(delta: float) -> void:
	if opened and _open < 1.0:
		_open = move_toward(_open, 1.0, delta * 1.2)
		_door.rotation.y = -deg_to_rad(110.0) * ease(_open, -2.0)


func open() -> void:
	if opened:
		return
	opened = true
	interactable.enabled = false
	_led_mat.albedo_color = Color(0.2, 1.0, 0.45)
	_led_mat.emission = Color(0.2, 1.0, 0.45)


func set_open_instant() -> void:
	open()
	_open = 1.0
	_door.rotation.y = -deg_to_rad(110.0)
