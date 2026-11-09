class_name ZoneTrigger
extends Area3D
## Zona con nombre del distrito ("Parque de las Palmas", "Terrazas de Cabecera"…).
## La primera vez que el jugador entra, el HUD muestra su título con un fundido
## (EventBus.zone_entered). Sirve para que el jugador sepa dónde está y para
## marcar el descubrimiento de cada lugar.

var title := ""
var subtitle := ""
var discovered := false


func _init(zone_title: String, zone_subtitle: String, box: AABB) -> void:
	title = zone_title
	subtitle = zone_subtitle
	name = "Zona_" + zone_title.replace(" ", "_")
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitorable = false
	var shape := BoxShape3D.new()
	shape.size = box.size
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	position = box.get_center()


func _ready() -> void:
	add_to_group("zone")
	body_entered.connect(func(b: Node3D) -> void:
		if discovered or not b is PlayerController:
			return
		discovered = true
		EventBus.zone_entered.emit(title, subtitle))
