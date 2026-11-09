class_name PrototypeBody
extends HumanoidBody
## Cuerpo PROVISIONAL de Sebastián (camiseta roja, jeans, tenis blancos con
## rojo, mochila negra, pulsera), hecho con el cuerpo de primitivas compartido.
## Se reemplaza por el modelo animado de Sebastián en la Fase 3.

const SKIN := Color(0.72, 0.52, 0.4)
const HAIR := Color(0.09, 0.07, 0.06)
const SHIRT := Color(0.78, 0.09, 0.12)
const JEANS := Color(0.2, 0.3, 0.5)
const SHOE := Color(0.93, 0.93, 0.92)
const SHOE_ACCENT := Color(0.8, 0.1, 0.12)
const BAG := Color(0.06, 0.06, 0.07)


func _init() -> void:
	super({
		"skin": SKIN, "hair": HAIR, "shirt": SHIRT, "sleeves": false, "pants": JEANS,
		"shoes": SHOE, "shoe_accent": SHOE_ACCENT, "backpack": BAG, "bracelet": true,
	})


var _step_cycle := 0


func update_visual(p: PlayerController, delta: float) -> void:
	rotation.y = p.facing_yaw
	animate(p.horizontal_speed(), PlayerController.RUN_SPEED, p.is_on_floor(), p.crouching, p.is_running(), delta)
	# Un paso cada medio ciclo de la zancada. Agachado no suena (sigilo).
	var cycle := int(floor(_phase / PI))
	if cycle != _step_cycle:
		_step_cycle = cycle
		if p.is_on_floor() and p.horizontal_speed() > 0.8 and not p.crouching and p.is_inside_tree():
			AudioManager.step(p.is_running())
