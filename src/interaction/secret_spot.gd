class_name SecretSpot
extends Node3D
## Una cigarra pintada (secreto de la versión 2.0). Es un grafiti verde que
## brilla un poco sobre un muro; al acercarse y pulsar Interactuar se
## fotografía y cuenta en PlayerProfile.secrets. No tiene columna de luz: hay
## que encontrarla mirando.

signal found(id: String)

var id := ""
var interactable: Interactable
var taken := false


func _init(secret_id: String) -> void:
	id = secret_id
	name = "Secreto_" + secret_id


func _ready() -> void:
	add_to_group("secret")
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(1.3, 1.3, 0.08)
	wall.mesh = wm
	wall.position = Vector3(0, 1.3, 0)
	wall.material_override = MaterialLibrary.get_material("concrete")
	add_child(wall)
	# Cigarra: cuerpo, cabeza y dos pares de alas, pintada sobre el muro.
	var g := MaterialLibrary.get_material("graffiti")
	var parts := [
		[Vector3(0.16, 0.5, 0.02), Vector3(0, 1.28, -0.05), 0.0],
		[Vector3(0.24, 0.14, 0.02), Vector3(0, 1.58, -0.05), 0.0],
		[Vector3(0.14, 0.5, 0.02), Vector3(-0.2, 1.3, -0.055), 0.5],
		[Vector3(0.14, 0.5, 0.02), Vector3(0.2, 1.3, -0.055), -0.5],
		[Vector3(0.1, 0.34, 0.02), Vector3(-0.17, 1.12, -0.055), -0.4],
		[Vector3(0.1, 0.34, 0.02), Vector3(0.17, 1.12, -0.055), 0.4],
	]
	for p: Array in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.position = p[1]
		mi.rotation.z = p[2]
		mi.material_override = g
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	interactable = Interactable.new("Fotografiar la cigarra pintada", 1.8)
	interactable.position = Vector3(0, 0.9, -0.8)
	interactable.action = _take
	add_child(interactable)
	if PlayerProfile.secrets.has(id):
		_mark_taken()


func _take(_p: PlayerController) -> void:
	if taken:
		return
	_mark_taken()
	Fx.burst(get_parent(), global_position + Vector3(0, 1.3, 0) - global_basis.z * 0.3, Color(0.3, 1.0, 0.55), 30)
	AudioManager.sfx("camera")
	PlayerProfile.find_secret(id)
	EventBus.notify.emit("¡Una cigarra pintada! (%d/%d) %s" % [PlayerProfile.secrets.size(), SideQuests.SECRETS.size(),
			"Las encontraste todas." if PlayerProfile.secrets.size() >= SideQuests.SECRETS.size() else "Hay más escondidas en el Centro."])
	found.emit(id)


func _mark_taken() -> void:
	taken = true
	interactable.enabled = false
