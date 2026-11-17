class_name QuestPickup
extends Node3D
## Algo que se toca para avanzar una misión secundaria (Interactuar).
##
## kind = "hoja": una hoja de cuaderno que flota y gira un poco; al tomarla
##                desaparece.
## kind = "canasta": una canasta de fruta; al usarla se tapa con un plástico
##                azul y se queda ahí.
##
## Solo se puede usar mientras `active` (la misión está en curso); fuera de
## eso la hoja no se ve y la canasta no responde.

signal used(pickup: QuestPickup)

var id := ""
var kind := "hoja"
var done := false
var active := false:
	set(v):
		active = v
		_refresh()
var interactable: Interactable

var _art: Node3D
var _cover: MeshInstance3D
var _t := 0.0


func _init(pickup_id: String, pickup_kind: String) -> void:
	id = pickup_id
	kind = pickup_kind
	name = "Pickup_" + pickup_id


func _ready() -> void:
	_art = Node3D.new()
	add_child(_art)
	if kind == "hoja":
		_build_page()
		_art.scale = Vector3.ONE * 1.7   # que se vea desde lejos
	else:
		_build_basket()
	var text := "Recoger la hoja" if kind == "hoja" else "Tapar la canasta"
	interactable = Interactable.new(text, 1.5)
	interactable.action = func(_p: PlayerController) -> void: use()
	add_child(interactable)
	_refresh()


func use() -> void:
	if done or not active:
		return
	mark_done()
	AudioManager.sfx("pickup")
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.8, Color(1.0, 0.95, 0.7) if kind == "hoja" else Color(0.4, 0.7, 1.0), 16)
	used.emit(self)


## Ya usada (también al cargar una partida).
func mark_done() -> void:
	done = true
	_refresh()


func _refresh() -> void:
	if interactable == null:
		return
	interactable.enabled = active and not done
	if kind == "hoja":
		visible = active and not done
	elif _cover != null:
		_cover.visible = done


func _process(delta: float) -> void:
	if kind != "hoja" or not visible:
		return
	_t += delta
	_art.position.y = 0.55 + sin(_t * 2.2) * 0.08
	_art.rotation.y += delta * 0.9


func _build_page() -> void:
	var sheet := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.012, 0.42)
	sheet.mesh = bm
	sheet.rotation = Vector3(0.35, 0, 0.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.97, 0.97, 0.93)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.75)
	mat.emission_energy_multiplier = 0.35
	sheet.material_override = mat
	_art.add_child(sheet)
	# Renglones azules y margen rojo, como una hoja de cuaderno.
	for k in 5:
		var line := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.28, 0.002, 0.008)
		line.mesh = lm
		line.position = Vector3(0, 0.008, -0.14 + k * 0.07)
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.45, 0.6, 0.9)
		lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.material_override = lmat
		sheet.add_child(line)
	var margin := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.006, 0.002, 0.4)
	margin.mesh = mm
	margin.position = Vector3(-0.11, 0.008, 0)
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.9, 0.3, 0.3)
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	margin.material_override = mmat
	sheet.add_child(margin)


func _build_basket() -> void:
	var crate := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.62, 0.32, 0.46)
	crate.mesh = cm
	crate.position.y = 0.16
	crate.material_override = MaterialLibrary.get_material("wood")
	_art.add_child(crate)
	var colors := [Color(0.95, 0.75, 0.1), Color(0.9, 0.3, 0.1), Color(0.35, 0.65, 0.2), Color(0.95, 0.55, 0.1), Color(0.75, 0.15, 0.2)]
	for k in 7:
		var fruit := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.16
		sm.radial_segments = 8
		sm.rings = 4
		fruit.mesh = sm
		fruit.position = Vector3(-0.2 + (k % 4) * 0.13, 0.35, -0.1 + (k / 4) * 0.18)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = colors[k % colors.size()]
		fm.roughness = 0.5
		fruit.material_override = fm
		_art.add_child(fruit)
	_cover = MeshInstance3D.new()
	var cov := BoxMesh.new()
	cov.size = Vector3(0.7, 0.14, 0.54)
	_cover.mesh = cov
	_cover.position.y = 0.4
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.15, 0.35, 0.8)
	pm.roughness = 0.25
	pm.metallic_specular = 0.8
	_cover.material_override = pm
	_cover.visible = false
	_art.add_child(_cover)
