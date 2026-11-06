class_name Minimap
extends Control
## Minimapa (norte arriba) de la manzana: calles, edificios, pruebas, amigos,
## vendedor y policías. Los policías se ven en azul y en rojo si te persiguen,
## con su cono de visión. El jugador es la flecha roja.

const SIZE := 190.0

var mission: EscapeMission
var _footprints: Array = []
var _half := 60.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mission != null:
		_footprints = mission.points.get("footprints", [])
		_half = PrototypeBlockBuilder.HALF_SIZE


func _process(_delta: float) -> void:
	queue_redraw()


func to_map(p: Vector3) -> Vector2:
	return Vector2((p.x + _half) / (_half * 2.0), (p.z + _half) / (_half * 2.0)) * SIZE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(0.3, 0.3, 0.3, 0.85))
	# Calles (las dos que se cruzan en el centro).
	var street := PrototypeBlockBuilder.STREET_HALF / (_half * 2.0) * SIZE
	draw_rect(Rect2(0, SIZE * 0.5 - street, SIZE, street * 2.0), Color(0.16, 0.16, 0.18))
	draw_rect(Rect2(SIZE * 0.5 - street, 0, street * 2.0, SIZE), Color(0.16, 0.16, 0.18))
	for r: Rect2 in _footprints:
		var a := to_map(Vector3(r.position.x, 0, r.position.y))
		var b := to_map(Vector3(r.end.x, 0, r.end.y))
		draw_rect(Rect2(a, b - a), Color(0.75, 0.68, 0.58))
	if mission == null:
		return
	# Zona verde (punto de encuentro).
	var meet := to_map(mission.points["meeting_point"])
	draw_circle(meet, 9.0, Color(0.3, 0.8, 0.4, 0.35))
	for f in mission.friends:
		draw_circle(to_map(f.global_position), 3.0, Color(0.3, 0.95, 0.45))
	if mission.vendor != null:
		draw_circle(to_map(mission.vendor.global_position), 3.5, Color(0.3, 0.8, 1.0))
	var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	if mission.lock_box != null and not mission.lock_box.opened:
		var lb := to_map(mission.lock_box.global_position)
		draw_rect(Rect2(lb - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.8, 0.2, blink))
	for e in mission.evidence:
		if e.revealed and not e.collected:
			var c := to_map(e.global_position)
			draw_circle(c, 4.5, Color(1.0, 0.8, 0.2, blink))
			draw_arc(c, 6.5, 0, TAU, 16, Color(1.0, 0.85, 0.3, 0.7), 1.2)
	for o in mission.officers:
		var c := to_map(o.global_position)
		var chasing := o.state == PoliceOfficer.State.CHASE
		var col := Color(1.0, 0.2, 0.2) if chasing else (Color(1.0, 0.8, 0.2) if o.alert > 0.0 else Color(0.35, 0.55, 1.0))
		var fwd := Vector2(o.view_direction().x, o.view_direction().z)
		var reach := PoliceOfficer.VIEW_RANGE / (_half * 2.0) * SIZE
		var half_fov := PoliceOfficer.VIEW_FOV * 0.5
		var cone := PackedVector2Array([c, c + fwd.rotated(-half_fov) * reach, c + fwd * reach * 1.05, c + fwd.rotated(half_fov) * reach])
		draw_colored_polygon(cone, Color(col, 0.18))
		draw_circle(c, 4.0, col)
	var p := mission.world.player
	var pc := to_map(p.global_position)
	var dir := Vector2(-sin(p.facing_yaw), -cos(p.facing_yaw))
	var tri := PackedVector2Array([pc + dir * 8.0, pc + dir.rotated(2.5) * 6.0, pc + dir.rotated(-2.5) * 6.0])
	draw_colored_polygon(tri, UiStyle.DANGER)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.WHITE, 1.2)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(1, 1, 1, 0.35), false, 1.5)
	draw_string(UiStyle.font("body", 700), Vector2(SIZE * 0.5 - 4, 13), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
