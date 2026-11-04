class_name Interactable
extends Area3D
## Algo con lo que el jugador puede interactuar con la tecla de Interactuar (E).
## El jugador detecta el Interactable más cercano (PlayerController) y muestra
## su texto de ayuda. Quien lo crea conecta la señal `interacted` o pasa una
## función en `action`.

signal interacted(player: PlayerController)

var prompt := "Interactuar"
var enabled := true
var action: Callable


func _init(text: String = "Interactuar", radius: float = 1.6) -> void:
	prompt = text
	collision_layer = PhysicsLayers.INTERACTABLES
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := SphereShape3D.new()
	shape.radius = radius
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)


func can_interact(_player: PlayerController) -> bool:
	return enabled


func get_prompt() -> String:
	return prompt


func interact(player: PlayerController) -> void:
	if not can_interact(player):
		return
	if action.is_valid():
		action.call(player)
	interacted.emit(player)
