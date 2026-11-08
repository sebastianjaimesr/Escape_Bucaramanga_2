class_name Guard
extends PoliceOfficer
## Vigilante de la bodega (capítulo 3): la misma IA que la policía, con otro
## uniforme y la vista más corta de noche. Si te alcanza, te saca a la calle
## (cuenta como «atrapado»). Tampoco es violento.

const NIGHT_VIEW := 12.5


func _init() -> void:
	super()
	# Cambia el uniforme de la policía (que ya creó PoliceOfficer._init) por
	# uno azul oscuro, sin chaleco, con gorra negra.
	visual.free()
	visual = HumanoidBody.new({
		"skin": Color(0.55, 0.4, 0.3), "shirt": Color(0.12, 0.14, 0.24), "pants": Color(0.1, 0.1, 0.12),
		"shoes": Color(0.05, 0.05, 0.05), "shoe_accent": Color(0.05, 0.05, 0.05),
		"cap": Color(0.06, 0.06, 0.07),
	})
	view_range = NIGHT_VIEW


func _ready() -> void:
	super()
	add_to_group("guard")
	display_name = "Vigilante"
