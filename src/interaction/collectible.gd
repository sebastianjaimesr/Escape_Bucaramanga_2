class_name Collectible
extends Node3D
## Postal coleccionable de Bucaramanga. Están escondidas en sitios a los que
## hay que querer llegar (callejones, patios, encima de cajas); no tienen haz
## de luz como las pruebas, solo un brillo azul que se ve de cerca. Se conservan
## entre capítulos (PlayerProfile).

var id := ""
var title := ""
var fact := ""
var interactable: Interactable
var _card: Node3D
var _t := 0.0


func _init(postal_id: String, postal_title: String, postal_fact: String) -> void:
	id = postal_id
	title = postal_title
	fact = postal_fact
	name = "Postal_" + postal_id


func _ready() -> void:
	add_to_group("collectible")
	_card = Node3D.new()
	_card.position.y = 0.75
	add_child(_card)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.32, 0.22, 0.015)
	mi.mesh = box
	mi.material_override = MaterialLibrary.get_material("clue")
	_card.add_child(mi)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.85, 1.0)
	glow.light_energy = 0.6
	glow.omni_range = 2.2
	glow.shadow_enabled = false
	glow.position.y = 0.8
	add_child(glow)
	interactable = Interactable.new("Recoger postal: %s" % title, 1.2)
	interactable.action = _collect
	add_child(interactable)


func _process(delta: float) -> void:
	_t += delta
	_card.rotation.y = _t * 2.0
	_card.position.y = 0.75 + sin(_t * 3.0) * 0.06


func _collect(_player: PlayerController) -> void:
	if not PlayerProfile.find_collectible(id):
		return
	EventBus.notify.emit("Postal «%s» (%d/%d): %s" % [title, PlayerProfile.collectibles.size(),
			Chapters.COLLECTIBLES.size(), fact])
	AudioManager.sfx("coin")
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.75, Color(0.45, 0.9, 1.0), 30)
	queue_free()
