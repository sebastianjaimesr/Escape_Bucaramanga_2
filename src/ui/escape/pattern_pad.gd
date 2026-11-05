class_name PatternPad
extends Control
## Cuadrícula de 3×3 puntos para dibujar un patrón (numerados 1-9 de izquierda
## a derecha y de arriba abajo). Emite `finished` al soltar después de arrastrar.

signal finished(sequence: Array)

const GRID := 3
const SIZE := 260.0
const DOT_RADIUS := 11.0
const HIT_RADIUS := 34.0

var sequence: Array = []
var tint := UiStyle.ACCENT
var locked := false
var _dragging := false
var _pointer := Vector2.INF


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func clear() -> void:
	sequence.clear()
	tint = UiStyle.ACCENT
	_pointer = Vector2.INF
	queue_redraw()


func dot_position(n: int) -> Vector2:
	var i := (n - 1) % GRID
	var j := (n - 1) / GRID
	var step := SIZE / GRID
	return Vector2(step * (i + 0.5), step * (j + 0.5))


func add_point(n: int) -> void:
	if locked or n < 1 or n > 9 or n in sequence:
		return
	if tint != UiStyle.ACCENT:
		clear()
	sequence.append(n)
	AudioManager.sfx("key", 0.9 + 0.05 * sequence.size())
	queue_redraw()


func _dot_at(pos: Vector2) -> int:
	for n in range(1, 10):
		if pos.distance_to(dot_position(n)) <= HIT_RADIUS:
			return n
	return 0


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var n := _dot_at(mb.position)
			if n > 0:
				if tint != UiStyle.ACCENT:
					clear()
				_dragging = true
				add_point(n)
		elif _dragging:
			_dragging = false
			_pointer = Vector2.INF
			queue_redraw()
			if sequence.size() > 1:
				finished.emit(sequence.duplicate())
		accept_event()
	var mm := event as InputEventMouseMotion
	if mm != null and _dragging:
		_pointer = mm.position
		var n := _dot_at(mm.position)
		if n > 0:
			add_point(n)
		queue_redraw()
		accept_event()


func _draw() -> void:
	for k in range(1, sequence.size()):
		draw_line(dot_position(sequence[k - 1]), dot_position(sequence[k]), Color(tint, 0.85), 6.0, true)
	if _dragging and not sequence.is_empty() and _pointer != Vector2.INF:
		draw_line(dot_position(sequence[-1]), _pointer, Color(tint, 0.4), 4.0, true)
	for n in range(1, 10):
		var c := dot_position(n)
		var on := n in sequence
		draw_circle(c, DOT_RADIUS * (1.25 if on else 1.0), tint if on else Color(1, 1, 1, 0.55))
		if on:
			draw_arc(c, DOT_RADIUS * 2.0, 0, TAU, 24, Color(tint, 0.35), 2.0, true)
