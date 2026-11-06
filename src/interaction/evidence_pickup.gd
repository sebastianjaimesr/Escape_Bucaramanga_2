class_name EvidencePickup
extends Node3D
## Una prueba para aclarar el malentendido. Flota, gira y tiene un haz de luz
## dorado para encontrarla de lejos. Se recoge con Interactuar (E).

var id := ""
var label := ""
var collected := false
## Si es false, la prueba todavía no aparece (la gorra, hasta ver el video del celular).
var revealed := true
var interactable: Interactable

var _item: Node3D
var _beam: MeshInstance3D
var _t := 0.0


func _init(evidence_id: String, evidence_label: String) -> void:
	id = evidence_id
	label = evidence_label
	name = "Prueba_" + evidence_id


func _ready() -> void:
	add_to_group("evidence")
	_item = Node3D.new()
	_item.position.y = 0.9
	add_child(_item)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_for(id)
	mi.material_override = MaterialLibrary.get_material("evidence_glow")
	_item.add_child(mi)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.32
	torus.outer_radius = 0.38
	ring.mesh = torus
	ring.material_override = MaterialLibrary.get_material("evidence_glow")
	ring.position.y = 0.04
	add_child(ring)
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.3
	cyl.height = 6.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	_beam.position.y = 3.0
	_beam.material_override = MaterialLibrary.get_material("evidence_beam")
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	interactable = Interactable.new("Recoger: %s" % label, 1.3)
	interactable.action = _collect
	add_child(interactable)
	_apply_visibility()


func _process(delta: float) -> void:
	_t += delta
	_item.rotation.y = _t * 1.6
	_item.position.y = 0.9 + sin(_t * 2.2) * 0.08


func _collect(_player: PlayerController) -> void:
	if collected or not revealed:
		return
	mark_collected()
	EventBus.evidence_collected.emit(id, label)


## Recogida sin aviso (al cargar una partida guardada).
func mark_collected() -> void:
	collected = true
	_apply_visibility()


func reveal() -> void:
	revealed = true
	_apply_visibility()


func _apply_visibility() -> void:
	var on := revealed and not collected
	visible = on
	set_process(on)
	if interactable != null:
		interactable.enabled = on


static func _mesh_for(kind: String) -> Mesh:
	match kind:
		"celular":
			var m := BoxMesh.new()
			m.size = Vector3(0.18, 0.34, 0.03)
			return m
		"usb":
			var m := BoxMesh.new()
			m.size = Vector3(0.1, 0.25, 0.05)
			return m
		"gorra":
			var m := SphereMesh.new()
			m.radius = 0.16
			m.height = 0.16
			m.is_hemisphere = true
			return m
		"recibo":
			var m := BoxMesh.new()
			m.size = Vector3(0.2, 0.32, 0.01)
			return m
	var photo := BoxMesh.new()
	photo.size = Vector3(0.3, 0.22, 0.01)
	return photo
