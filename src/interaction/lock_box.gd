class_name LockBox
extends Node3D
## Caja de grabación de la cámara de seguridad del túnel: una caja metálica con
## teclado y un piloto rojo. Al interactuar, la misión abre el teclado
## (CodeLockPanel). Con la clave correcta la tapa se abre y el piloto se pone verde.

var opened := false
var interactable: Interactable

var _lid: Node3D
var _led: MeshInstance3D
var _led_mat: StandardMaterial3D
var _screen: Label3D
var _t := 0.0
var _lid_open := 0.0


func _ready() -> void:
	name = "CajaDeGrabacion"
	add_to_group("lock_box")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.22, 0.25)
	metal.metallic = 0.6
	metal.roughness = 0.45
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.45, 0.32)
	body.mesh = box
	body.material_override = metal
	body.position.y = 0.225
	add_child(body)
	var solid := StaticBody3D.new()
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	shape.shape = bs
	shape.position.y = 0.225
	solid.add_child(shape)
	add_child(solid)
	# Tapa con bisagra en el borde de atrás.
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.45, -0.16)
	add_child(_lid)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.62, 0.05, 0.34)
	lid.mesh = lid_mesh
	lid.material_override = metal
	lid.position = Vector3(0, 0.025, 0.17)
	_lid.add_child(lid)
	# Cámara sobre la caja, mirando hacia la entrada del túnel.
	var cam := MeshInstance3D.new()
	var cam_mesh := CylinderMesh.new()
	cam_mesh.top_radius = 0.06
	cam_mesh.bottom_radius = 0.08
	cam_mesh.height = 0.22
	cam.mesh = cam_mesh
	cam.material_override = metal
	cam.rotation_degrees = Vector3(90, 0, 0)
	cam.position = Vector3(0.0, 1.15, -0.05)
	add_child(cam)
	_led_mat = StandardMaterial3D.new()
	_led_mat.emission_enabled = true
	_led_mat.albedo_color = Color(1, 0.15, 0.1)
	_led_mat.emission = Color(1, 0.15, 0.1)
	_led_mat.emission_energy_multiplier = 3.0
	_led = MeshInstance3D.new()
	var led_mesh := SphereMesh.new()
	led_mesh.radius = 0.025
	led_mesh.height = 0.05
	_led.mesh = led_mesh
	_led.material_override = _led_mat
	_led.position = Vector3(0.22, 0.36, 0.165)
	add_child(_led)
	_screen = Label3D.new()
	_screen.text = "REC  ----"
	_screen.font_size = 40
	_screen.pixel_size = 0.0035
	_screen.modulate = Color(1.0, 0.4, 0.3)
	_screen.outline_size = 0
	_screen.position = Vector3(-0.05, 0.3, 0.165)
	add_child(_screen)
	interactable = Interactable.new("Revisar la caja de grabación", 1.4)
	add_child(interactable)


func _process(delta: float) -> void:
	_t += delta
	if opened:
		_lid_open = move_toward(_lid_open, 1.0, delta * 1.5)
		_lid.rotation.x = -deg_to_rad(105.0) * ease(_lid_open, -2.0)
	else:
		_led.visible = fmod(_t, 1.0) < 0.6


func open() -> void:
	if opened:
		return
	opened = true
	interactable.enabled = false
	_led.visible = true
	_led_mat.albedo_color = Color(0.2, 1.0, 0.45)
	_led_mat.emission = Color(0.2, 1.0, 0.45)
	_screen.text = "OK  17:42"
	_screen.modulate = Color(0.4, 1.0, 0.6)


## Al cargar una partida: abierta sin animación.
func set_open_instant() -> void:
	open()
	_lid_open = 1.0
