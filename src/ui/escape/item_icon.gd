class_name ItemIcon
extends Control
## Iconos vectoriales dibujados con primitivas (sin imágenes): objetos del
## inventario y botones del HUD. Se escalan sin perder nitidez en cualquier pantalla.

var kind := "photo"
var color := UiStyle.TEXT
var accent := UiStyle.ACCENT


func _init(icon_kind: String = "photo", icon_size: float = 48.0, tint: Color = UiStyle.TEXT) -> void:
	kind = icon_kind
	color = tint
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_kind(k: String) -> void:
	kind = k
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var w := maxf(1.5, s * 0.055)
	var r := func(x: float, y: float, ww: float, hh: float) -> Rect2:
		return Rect2(o + Vector2(x, y) * s, Vector2(ww, hh) * s)
	var p := func(x: float, y: float) -> Vector2:
		return o + Vector2(x, y) * s
	match kind:
		"photo":
			draw_rect(r.call(0.14, 0.22, 0.72, 0.56), color, false, w)
			draw_rect(r.call(0.2, 0.28, 0.6, 0.36), Color(color, 0.18))
			draw_colored_polygon(PackedVector2Array([p.call(0.24, 0.6), p.call(0.42, 0.4), p.call(0.56, 0.56), p.call(0.64, 0.48), p.call(0.76, 0.6)]), Color(color, 0.6))
			draw_circle(p.call(0.68, 0.36), s * 0.05, accent)
		"receipt":
			var pts := PackedVector2Array([p.call(0.26, 0.12), p.call(0.74, 0.12), p.call(0.74, 0.86)])
			for i in 5:
				pts.append(p.call(0.74 - (i + 0.5) * 0.096, 0.86 - (0.05 if i % 2 == 0 else 0.0)))
			pts.append(p.call(0.26, 0.86))
			pts.append(p.call(0.26, 0.12))
			draw_polyline(pts, color, w, true)
			for i in 4:
				draw_line(p.call(0.34, 0.26 + i * 0.12), p.call(0.66 - (0.12 if i == 3 else 0.0), 0.26 + i * 0.12), Color(color, 0.55), w * 0.8)
			draw_line(p.call(0.52, 0.72), p.call(0.66, 0.72), accent, w * 1.2)
		"usb":
			draw_rect(r.call(0.34, 0.3, 0.32, 0.5), color, false, w)
			draw_rect(r.call(0.4, 0.14, 0.2, 0.16), color, false, w)
			draw_rect(r.call(0.44, 0.18, 0.04, 0.05), color)
			draw_rect(r.call(0.52, 0.18, 0.04, 0.05), color)
			draw_circle(p.call(0.5, 0.6), s * 0.05, accent)
		"phone", "phone_locked":
			draw_rect(r.call(0.3, 0.1, 0.4, 0.8), color, false, w)
			draw_line(p.call(0.44, 0.17), p.call(0.56, 0.17), color, w)
			if kind == "phone_locked":
				draw_rect(r.call(0.41, 0.5, 0.18, 0.16), accent)
				draw_arc(p.call(0.5, 0.5), s * 0.065, PI, TAU, 12, accent, w)
			else:
				for i in 3:
					for j in 3:
						draw_circle(p.call(0.4 + i * 0.1, 0.38 + j * 0.12), s * 0.025, accent)
		"cap":
			draw_arc(p.call(0.48, 0.6), s * 0.26, PI, TAU, 20, color, w)
			draw_line(p.call(0.22, 0.6), p.call(0.86, 0.6), color, w)
			draw_line(p.call(0.7, 0.6), p.call(0.88, 0.68), color, w)
			draw_colored_polygon(PackedVector2Array([p.call(0.25, 0.58), p.call(0.3, 0.44), p.call(0.4, 0.37), p.call(0.56, 0.36), p.call(0.66, 0.42), p.call(0.72, 0.58)]), Color(UiStyle.DANGER, 0.85))
		"bag":
			draw_rect(r.call(0.2, 0.36, 0.6, 0.48), color, false, w)
			draw_arc(p.call(0.5, 0.36), s * 0.14, PI, TAU, 14, color, w)
			draw_line(p.call(0.2, 0.52), p.call(0.8, 0.52), color, w * 0.8)
			draw_rect(r.call(0.45, 0.48, 0.1, 0.1), accent)
		"bulb":
			draw_arc(p.call(0.5, 0.4), s * 0.22, PI * 0.8, PI * 2.2, 22, color, w)
			draw_line(p.call(0.41, 0.6), p.call(0.41, 0.7), color, w)
			draw_line(p.call(0.59, 0.6), p.call(0.59, 0.7), color, w)
			draw_line(p.call(0.4, 0.72), p.call(0.6, 0.72), color, w)
			draw_line(p.call(0.43, 0.8), p.call(0.57, 0.8), color, w)
			draw_circle(p.call(0.5, 0.4), s * 0.06, accent)
		"pause":
			draw_rect(r.call(0.3, 0.24, 0.13, 0.52), color)
			draw_rect(r.call(0.57, 0.24, 0.13, 0.52), color)
		"sound", "mute":
			draw_colored_polygon(PackedVector2Array([p.call(0.16, 0.4), p.call(0.3, 0.4), p.call(0.48, 0.24), p.call(0.48, 0.76), p.call(0.3, 0.6), p.call(0.16, 0.6)]), color)
			if kind == "sound":
				draw_arc(p.call(0.5, 0.5), s * 0.14, -PI * 0.3, PI * 0.3, 10, color, w)
				draw_arc(p.call(0.5, 0.5), s * 0.27, -PI * 0.3, PI * 0.3, 14, color, w)
			else:
				draw_line(p.call(0.6, 0.38), p.call(0.82, 0.62), UiStyle.DANGER, w)
				draw_line(p.call(0.82, 0.38), p.call(0.6, 0.62), UiStyle.DANGER, w)
		"check":
			draw_polyline(PackedVector2Array([p.call(0.22, 0.52), p.call(0.42, 0.72), p.call(0.8, 0.3)]), color, w * 1.6, true)
		"dot":
			draw_arc(p.call(0.5, 0.5), s * 0.2, 0, TAU, 18, color, w * 1.2)
		"lock":
			draw_rect(r.call(0.3, 0.46, 0.4, 0.32), color, false, w)
			draw_arc(p.call(0.5, 0.46), s * 0.13, PI, TAU, 12, color, w)
		"box":
			draw_rect(r.call(0.16, 0.34, 0.68, 0.46), color, false, w)
			draw_line(p.call(0.16, 0.46), p.call(0.84, 0.46), color, w)
			draw_circle(p.call(0.72, 0.4), s * 0.03, UiStyle.DANGER)
			draw_rect(r.call(0.3, 0.56, 0.24, 0.12), Color(color, 0.5))
		"clock":
			draw_arc(p.call(0.5, 0.5), s * 0.32, 0, TAU, 28, color, w)
			draw_line(p.call(0.5, 0.5), p.call(0.5, 0.3), color, w)
			draw_line(p.call(0.5, 0.5), p.call(0.64, 0.58), accent, w)
		"close":
			draw_line(p.call(0.3, 0.3), p.call(0.7, 0.7), color, w * 1.3)
			draw_line(p.call(0.7, 0.3), p.call(0.3, 0.7), color, w * 1.3)
		"footprint":
			draw_colored_polygon(PackedVector2Array([p.call(0.4, 0.2), p.call(0.6, 0.18), p.call(0.66, 0.4), p.call(0.6, 0.62), p.call(0.62, 0.82), p.call(0.44, 0.84), p.call(0.38, 0.6), p.call(0.34, 0.4)]), Color(color, 0.25))
			for i in 4:
				draw_line(p.call(0.4, 0.3 + i * 0.14), p.call(0.6, 0.3 + i * 0.14), color, w)
			draw_circle(p.call(0.5, 0.74), s * 0.04, accent)
		"button":
			draw_arc(p.call(0.5, 0.5), s * 0.3, 0, TAU, 24, color, w)
			draw_circle(p.call(0.5, 0.5), s * 0.27, Color(0.2, 0.6, 0.3, 0.6))
			for v: Vector2 in [Vector2(0.43, 0.43), Vector2(0.57, 0.43), Vector2(0.43, 0.57), Vector2(0.57, 0.57)]:
				draw_circle(p.call(v.x, v.y), s * 0.035, color)
		"ticket":
			draw_rect(r.call(0.14, 0.32, 0.72, 0.36), color, false, w)
			draw_line(p.call(0.62, 0.32), p.call(0.62, 0.68), Color(color, 0.5), w * 0.7)
			draw_line(p.call(0.22, 0.44), p.call(0.54, 0.44), Color(color, 0.6), w * 0.8)
			draw_line(p.call(0.22, 0.56), p.call(0.46, 0.56), accent, w * 0.8)
		"envelope":
			draw_rect(r.call(0.16, 0.28, 0.68, 0.46), color, false, w)
			draw_polyline(PackedVector2Array([p.call(0.16, 0.28), p.call(0.5, 0.54), p.call(0.84, 0.28)]), color, w)
			draw_circle(p.call(0.5, 0.56), s * 0.06, accent)
		"doc", "camera":
			draw_rect(r.call(0.24, 0.14, 0.52, 0.72), color, false, w)
			for i in 4:
				draw_line(p.call(0.32, 0.3 + i * 0.12), p.call(0.68, 0.3 + i * 0.12), Color(color, 0.55), w * 0.8)
			draw_circle(p.call(0.62, 0.74), s * 0.06, accent)
		"book":
			draw_rect(r.call(0.22, 0.16, 0.56, 0.68), color, false, w)
			draw_line(p.call(0.3, 0.16), p.call(0.3, 0.84), color, w)
			draw_rect(r.call(0.4, 0.3, 0.28, 0.1), accent)
		"raincoat", "jacket":
			draw_colored_polygon(PackedVector2Array([p.call(0.36, 0.18), p.call(0.64, 0.18), p.call(0.84, 0.36), p.call(0.76, 0.48), p.call(0.7, 0.42), p.call(0.7, 0.84), p.call(0.3, 0.84), p.call(0.3, 0.42), p.call(0.24, 0.48), p.call(0.16, 0.36)]), Color(color, 0.3))
			draw_line(p.call(0.5, 0.22), p.call(0.5, 0.84), accent, w)
		"shoe":
			draw_polyline(PackedVector2Array([p.call(0.14, 0.7), p.call(0.16, 0.36), p.call(0.36, 0.36), p.call(0.48, 0.52), p.call(0.8, 0.58), p.call(0.86, 0.7), p.call(0.14, 0.7)]), color, w, true)
			draw_line(p.call(0.14, 0.76), p.call(0.86, 0.76), accent, w)
		"lungs":
			draw_arc(p.call(0.36, 0.56), s * 0.18, PI * 0.5, PI * 1.6, 14, color, w)
			draw_arc(p.call(0.64, 0.56), s * 0.18, -PI * 0.6, PI * 0.5, 14, color, w)
			draw_line(p.call(0.5, 0.16), p.call(0.5, 0.5), accent, w)
		"climb":
			draw_rect(r.call(0.5, 0.5, 0.36, 0.34), Color(color, 0.3))
			draw_polyline(PackedVector2Array([p.call(0.16, 0.84), p.call(0.3, 0.6), p.call(0.48, 0.44), p.call(0.66, 0.42)]), accent, w * 1.3, true)
			draw_circle(p.call(0.3, 0.32), s * 0.07, color)
		"can":
			draw_rect(r.call(0.34, 0.2, 0.32, 0.6), color, false, w)
			draw_line(p.call(0.34, 0.32), p.call(0.66, 0.32), accent, w)
			draw_line(p.call(0.34, 0.68), p.call(0.66, 0.68), accent, w)
		"eye":
			draw_arc(p.call(0.5, 0.78), s * 0.42, -PI * 0.78, -PI * 0.22, 18, color, w)
			draw_arc(p.call(0.5, 0.22), s * 0.42, PI * 0.22, PI * 0.78, 18, color, w)
			draw_circle(p.call(0.5, 0.5), s * 0.1, accent)
		"run":
			draw_circle(p.call(0.58, 0.2), s * 0.07, color)
			draw_polyline(PackedVector2Array([p.call(0.3, 0.84), p.call(0.44, 0.62), p.call(0.52, 0.36), p.call(0.66, 0.54), p.call(0.8, 0.5)]), color, w * 1.2, true)
			draw_line(p.call(0.44, 0.62), p.call(0.6, 0.84), color, w * 1.2)
			draw_line(p.call(0.1, 0.5), p.call(0.3, 0.5), accent, w)
		"cup":
			draw_colored_polygon(PackedVector2Array([p.call(0.3, 0.3), p.call(0.7, 0.3), p.call(0.62, 0.86), p.call(0.38, 0.86)]), Color(color, 0.25))
			draw_polyline(PackedVector2Array([p.call(0.3, 0.3), p.call(0.38, 0.86), p.call(0.62, 0.86), p.call(0.7, 0.3)]), color, w)
			draw_line(p.call(0.56, 0.3), p.call(0.66, 0.1), accent, w)
		"star", "trophy":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				var rr := 0.36 if i % 2 == 0 else 0.15
				pts.append(p.call(0.5 + cos(a) * rr, 0.53 + sin(a) * rr))
			draw_colored_polygon(pts, accent if kind == "star" else Color(accent, 0.8))
		"coin":
			draw_circle(p.call(0.5, 0.5), s * 0.32, Color(accent, 0.85))
			draw_arc(p.call(0.5, 0.5), s * 0.24, 0, TAU, 20, Color(0, 0, 0, 0.35), w)
		"heart", "heart_empty":
			var hp := PackedVector2Array([p.call(0.5, 0.84), p.call(0.16, 0.48), p.call(0.18, 0.28), p.call(0.34, 0.2), p.call(0.5, 0.32), p.call(0.66, 0.2), p.call(0.82, 0.28), p.call(0.84, 0.48)])
			if kind == "heart":
				draw_colored_polygon(hp, UiStyle.DANGER)
			else:
				hp.append(hp[0])
				draw_polyline(hp, Color(color, 0.5), w, true)
		"postcard":
			draw_rect(r.call(0.12, 0.24, 0.76, 0.52), color, false, w)
			draw_rect(r.call(0.62, 0.3, 0.18, 0.16), accent, false, w * 0.8)
			draw_colored_polygon(PackedVector2Array([p.call(0.18, 0.7), p.call(0.32, 0.46), p.call(0.44, 0.62), p.call(0.54, 0.52), p.call(0.6, 0.7)]), Color(color, 0.5))
		_:
			draw_circle(p.call(0.5, 0.5), s * 0.3, color)
