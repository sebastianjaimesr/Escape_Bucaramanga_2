class_name Beacon
extends Area3D
## Marcador de objetivo: una columna de luz azul que se ve de lejos y un área
## que avisa cuando el jugador entra (puntos de control, lugares de encuentro).
## Se apaga con `active = false`.

signal reached(player: PlayerController)

var radius := 2.2
var label := ""
var active := true:
	set(value):
		active = value
		visible = value
		# Puede cambiar dentro de la señal de entrada: se aplica al final del cuadro.
		set_deferred("monitoring", value)
var _column: MeshInstance3D
var _t := 0.0


func _init(text: String = "", r: float = 2.2) -> void:
	label = text
	radius = r
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = 3.0
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 1.5
	add_child(col)


func _ready() -> void:
	add_to_group("beacon")
	_column = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.35
	cyl.bottom_radius = radius * 0.55
	cyl.height = 10.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	_column.mesh = cyl
	_column.position.y = 5.0
	_column.material_override = MaterialLibrary.get_material("beacon")
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_column)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	ring.mesh = torus
	ring.material_override = MaterialLibrary.get_material("beacon")
	ring.position.y = 0.05
	add_child(ring)
	if label != "":
		var l := Label3D.new()
		l.text = label
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 64
		l.pixel_size = 0.006
		l.outline_size = 14
		l.modulate = Color(0.75, 0.95, 1.0)
		l.position.y = 3.2
		add_child(l)
	body_entered.connect(func(b: Node3D) -> void:
		if active and b is PlayerController:
			reached.emit(b))


func _process(delta: float) -> void:
	_t += delta
	_column.rotation.y = _t * 0.6


## El jugador está dentro ahora mismo (por si ya estaba al activarlo).
func has_player() -> bool:
	if not active or not monitoring:
		return false
	for b in get_overlapping_bodies():
		if b is PlayerController:
			return true
	return false
