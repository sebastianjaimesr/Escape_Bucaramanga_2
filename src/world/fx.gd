class_name Fx
extends RefCounted
## Efectos de partículas cortos (CPUParticles3D: funcionan igual en PC y en la
## web). Cada efecto se borra solo al terminar.


## Estallido de chispas (recoger algo, subir de nivel, golpe de una lata).
static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 24, size: float = 1.0) -> CPUParticles3D:
	if parent == null or not parent.is_inside_tree() or Fx.reduced():
		return null
	var p := _make(amount, 0.9)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5 * size
	p.initial_velocity_max = 3.5 * size
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.04 * size
	p.scale_amount_max = 0.09 * size
	p.color = color
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	return p


## Polvo al aterrizar o deslizarse.
static func dust(parent: Node, pos: Vector3, size: float = 1.0) -> CPUParticles3D:
	if parent == null or not parent.is_inside_tree() or Fx.reduced():
		return null
	var p := _make(14, 0.7)
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 0.6 * size
	p.initial_velocity_max = 1.4 * size
	p.gravity = Vector3(0, 0.3, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.12 * size
	p.scale_amount_max = 0.25 * size
	p.color = Color(0.75, 0.7, 0.62, 0.55)
	parent.add_child(p)
	p.global_position = pos + Vector3.UP * 0.05
	p.emitting = true
	return p


## Anillo que sube (subir de nivel, punto de control).
static func ring(parent: Node, pos: Vector3, color: Color) -> CPUParticles3D:
	if parent == null or not parent.is_inside_tree() or Fx.reduced():
		return null
	var p := _make(48, 1.4)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.9
	p.emission_ring_inner_radius = 0.8
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.4
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.08
	p.color = color
	parent.add_child(p)
	p.global_position = pos + Vector3.UP * 0.1
	p.emitting = true
	return p


static func reduced() -> bool:
	return bool(Settings.get_value("interface", "reduce_motion"))


static func _make(amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = lifetime
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.finished.connect(p.queue_free)
	return p
