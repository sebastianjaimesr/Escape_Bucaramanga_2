class_name UiStyle
extends RefCounted
## Dirección visual de la interfaz: paleta, tipografías y fábricas de controles.
##
## Paleta «atardecer en la meseta»: fondo tinta casi negro, ámbar de farol como
## acento principal, rojo de la camiseta de Sebastián para alertas y verde
## menta para aciertos. Los textos sobre BG y PANEL superan un contraste de
## 4,5:1 (TEXT_DIM ≈ 7:1, TEXT ≈ 16:1).
## Tipografías (SIL Open Font License, en assets/fonts): Cinzel para títulos y
## Outfit para todo lo demás.

const BG := Color(0.043, 0.051, 0.071, 1.0)
const BG_DEEP := Color(0.02, 0.024, 0.035, 1.0)
const PANEL := Color(0.07, 0.078, 0.105, 0.94)
const PANEL_SOFT := Color(1, 1, 1, 0.045)
const PANEL_BORDER := Color(1.0, 0.86, 0.62, 0.14)
const TEXT := Color(0.953, 0.929, 0.886)
const TEXT_DIM := Color(0.68, 0.66, 0.62)
const ACCENT := Color(0.914, 0.663, 0.271)      ## Ámbar de farol.
const ACCENT_SOFT := Color(0.914, 0.663, 0.271, 0.16)
const DANGER := Color(0.886, 0.282, 0.239)      ## Rojo de la camiseta de Sebastián.
const OK := Color(0.373, 0.827, 0.647)
const WARN := Color(0.949, 0.757, 0.306)
const INK := Color(0.08, 0.06, 0.03)            ## Texto sobre botones ámbar.

const TITLE_FONT_PATH := "res://assets/fonts/Cinzel.ttf"
const BODY_FONT_PATH := "res://assets/fonts/Outfit.ttf"

static var _theme: Theme
static var _fonts: Dictionary = {}


## Suelta el tema y las fuentes guardadas (al cerrar el juego).
static func clear_cache() -> void:
	_theme = null
	_fonts.clear()


## Fuente con peso (100-900) de las fuentes variables del juego.
static func font(kind: String = "body", weight: int = 400) -> Font:
	var key := "%s_%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var base := load(TITLE_FONT_PATH if kind == "title" else BODY_FONT_PATH) as FontFile
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[key] = f
	return f


static func label(text: String, size: int = 18, color: Color = TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight != 400:
		l.add_theme_font_override("font", font("body", weight))
	return l


## Título en Cinzel con espaciado entre letras.
static func title(text: String, size: int = 48, color: Color = TEXT, spacing: int = 4) -> Label:
	var l := Label.new()
	l.text = text
	var f := font("title", 700).duplicate() as FontVariation
	f.spacing_glyph = spacing
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Etiqueta pequeña en mayúsculas para encabezados de sección.
static func overline(text: String, color: Color = ACCENT, size: int = 13) -> Label:
	var l := label(text.to_upper(), size, color, 600)
	var f := font("body", 600).duplicate() as FontVariation
	f.spacing_glyph = 2
	l.add_theme_font_override("font", f)
	return l


## Botón. "primary" es ámbar macizo (la acción principal de cada pantalla);
## "ghost" es transparente con borde.
static func button(text: String, min_width: float = 280.0, kind: String = "ghost") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 50)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if kind == "primary":
		make_primary(b)
	b.mouse_entered.connect(func() -> void: AudioManager.sfx("hover"))
	b.pressed.connect(func() -> void: AudioManager.sfx("click"))
	return b


## Botón principal: ámbar macizo con texto oscuro (una sola acción principal por pantalla).
static func make_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(ACCENT, ACCENT.lightened(0.15)))
	b.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.12), Color(1, 0.92, 0.75)))
	b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.12), ACCENT))
	b.add_theme_stylebox_override("focus", _focus_ring())
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_font_override("font", font("body", 700))


## Ancla un control a su contenedor: anclas (0..1) y márgenes en píxeles.
static func place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


static func panel(margin: int = 24, bg: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(bg, PANEL_BORDER, 12)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	p.add_theme_stylebox_override("panel", sb)
	return p


static func style_bar(bar: ProgressBar, fill: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)


static func box(bg: Color, border: Color, radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.anti_aliasing = true
	return sb


## Tema de toda la interfaz. Se asigna a la ventana raíz (SceneLoader) y lo
## heredan todos los controles, también los de CanvasLayer.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font("body", 450)
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)

	# Botones normales (borde fino, se iluminan en ámbar).
	t.set_stylebox("normal", "Button", box(PANEL_SOFT, PANEL_BORDER))
	t.set_stylebox("hover", "Button", box(ACCENT_SOFT, Color(ACCENT, 0.8)))
	t.set_stylebox("pressed", "Button", box(Color(ACCENT, 0.3), ACCENT))
	t.set_stylebox("focus", "Button", _focus_ring())
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.05)))
	for c: String in ["font_color", "font_focus_color"]:
		t.set_color(c, "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(TEXT_DIM, 0.5))
	t.set_font("font", "Button", font("body", 500))
	t.set_font_size("font_size", "Button", 18)

	# Listas desplegables, casillas y deslizadores.
	for s: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(s, "OptionButton", t.get_stylebox(s, "Button"))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(PANEL, PANEL_BORDER, 8))
	t.set_stylebox("hover", "PopupMenu", box(ACCENT_SOFT, Color(0, 0, 0, 0), 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_stylebox("focus", "CheckBox", _focus_ring())
	t.set_icon("checked", "CheckBox", _check_icon(true))
	t.set_icon("unchecked", "CheckBox", _check_icon(false))
	t.set_icon("checked_disabled", "CheckBox", _check_icon(true))
	t.set_icon("unchecked_disabled", "CheckBox", _check_icon(false))
	t.set_stylebox("focus", "CheckButton", _focus_ring())
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(1, 1, 1, 0.12)
	slider_bg.set_corner_radius_all(3)
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_bg)
	var slider_fill := slider_bg.duplicate() as StyleBoxFlat
	slider_fill.bg_color = ACCENT
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	t.set_stylebox("focus", "HSlider", _focus_ring())
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, PANEL_BORDER, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(1, 1, 1, 0.18)
	scroll.set_corner_radius_all(3)
	scroll.content_margin_left = 4
	scroll.content_margin_right = 4
	t.set_stylebox("grabber", "VScrollBar", scroll)
	var scroll_hi := scroll.duplicate() as StyleBoxFlat
	scroll_hi.bg_color = Color(ACCENT, 0.7)
	t.set_stylebox("grabber_highlight", "VScrollBar", scroll_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", scroll_hi)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t


## Casilla de 24 px bien visible: borde claro y relleno ámbar con marca al activarse.
static func _check_icon(on: bool) -> ImageTexture:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var edge := x < 2 or y < 2 or x >= n - 2 or y >= n - 2
			var corner := (x < 2 or x >= n - 2) and (y < 2 or y >= n - 2)
			if corner:
				continue
			if on:
				img.set_pixel(x, y, ACCENT)
			elif edge:
				img.set_pixel(x, y, Color(TEXT, 0.75))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0.06))
	if on:
		# Marca de verificación.
		var pts := [Vector2(6, 12), Vector2(10, 16), Vector2(18, 7)]
		for k in 2:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			for i in 24:
				var p := a.lerp(b, i / 23.0)
				for dx in 2:
					for dy in 2:
						img.set_pixel(clampi(int(p.x) + dx, 0, n - 1), clampi(int(p.y) + dy, 0, n - 1), INK)
	return ImageTexture.create_from_image(img)


## Anillo de foco bien visible para teclado y mando (accesibilidad).
static func _focus_ring() -> StyleBoxFlat:
	var sb := box(Color(0, 0, 0, 0), Color(1.0, 0.9, 0.7, 0.95), 8, 2)
	sb.expand_margin_left = 3
	sb.expand_margin_right = 3
	sb.expand_margin_top = 3
	sb.expand_margin_bottom = 3
	sb.draw_center = false
	return sb


## Animación de entrada: aparece desde abajo con un fundido.
static func fade_in(c: CanvasItem, delay: float = 0.0, rise: float = 16.0, time: float = 0.5) -> void:
	c.modulate.a = 0.0
	var ctrl := c as Control
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, time).set_delay(delay)
	if ctrl != null and rise != 0.0:
		var to := ctrl.position.y
		ctrl.position.y += rise
		tw.tween_property(ctrl, "position:y", to, time).set_delay(delay)


## Sacude un control a los lados (respuesta equivocada).
static func shake(c: Control) -> void:
	var x := c.position.x
	var tw := c.create_tween()
	for d: float in [12.0, -10.0, 8.0, -5.0, 2.0, 0.0]:
		tw.tween_property(c, "position:x", x + d, 0.045)
