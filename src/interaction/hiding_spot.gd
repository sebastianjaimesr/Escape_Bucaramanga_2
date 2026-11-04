class_name HidingSpot
extends Area3D
## Matorral donde esconderse: si el jugador está adentro y agachado, la
## policía no lo ve (PlayerController.is_hidden()).


func _init(size: Vector3) -> void:
	add_to_group("hiding_spot")
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, size.z)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = size.y * 0.5
	add_child(col)


func _ready() -> void:
	body_entered.connect(func(b: Node3D) -> void:
		if b is PlayerController:
			(b as PlayerController).cover_count += 1)
	body_exited.connect(func(b: Node3D) -> void:
		if b is PlayerController:
			(b as PlayerController).cover_count = maxi(0, (b as PlayerController).cover_count - 1))
