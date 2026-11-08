class_name ThrownCan
extends RigidBody3D
## Lata para distraer. Al primer golpe hace ruido: la policía y los vigilantes
## que estén a menos de NOISE_RADIUS van a revisar ese punto.

const NOISE_RADIUS := 16.0
const LIFETIME := 6.0

var _noisy := true
var _life := LIFETIME


func _init() -> void:
	name = "Lata"
	add_to_group("thrown_can")
	mass = 0.2
	collision_layer = 0
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.VEHICLES | PhysicsLayers.CHARACTERS
	contact_monitor = true
	max_contacts_reported = 1
	continuous_cd = true
	var shape := CylinderShape3D.new()
	shape.radius = 0.04
	shape.height = 0.12
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = 0.04
	mesh.height = 0.12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MaterialLibrary.get_material("can")
	add_child(mi)


func _ready() -> void:
	body_entered.connect(_on_hit)


func _on_hit(_body: Node) -> void:
	if not _noisy:
		return
	_noisy = false
	EventBus.noise.emit(global_position, NOISE_RADIUS, "lata")
	AudioManager.sfx("can", randf_range(0.9, 1.15))
	Fx.burst(get_parent(), global_position, Color(1.0, 0.85, 0.4), 10, 0.5)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
