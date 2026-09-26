class_name UI
## Tema visual y piezas de interfaz reutilizables (menús y paneles).

const C_PANEL := Color(0.08, 0.06, 0.18, 0.94)
const C_BORDER := Color(0.55, 0.5, 1.0)
const C_ACCENT := Color(0.45, 1.0, 0.9)
const C_MUTED := Color(0.72, 0.7, 0.88)
const SECONDARY := &"SecondaryButton"


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 30

	theme.set_stylebox("normal", "Button", _box(Color(0.2, 0.14, 0.42, 0.95), C_BORDER))
	theme.set_stylebox("hover", "Button", _box(Color(0.28, 0.2, 0.55, 0.97), Color(0.75, 0.9, 1.0)))
	theme.set_stylebox("pressed", "Button", _box(Color(0.12, 0.42, 0.48, 0.97), C_ACCENT))
	theme.set_stylebox("disabled", "Button", _box(Color(0.12, 0.1, 0.22, 0.75), Color(0.3, 0.28, 0.45)))
	var focus := _box(Color(0, 0, 0, 0), C_ACCENT)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.48, 0.62))

	# Botón secundario (acciones que no conviene pulsar sin querer, como salir de la sala)
	theme.set_type_variation(SECONDARY, "Button")
	theme.set_stylebox("normal", SECONDARY, _box(Color(0.08, 0.06, 0.18, 0.7), Color(0.45, 0.42, 0.62)))
	theme.set_stylebox("hover", SECONDARY, _box(Color(0.14, 0.1, 0.28, 0.85), Color(0.7, 0.68, 0.9)))
	theme.set_stylebox("pressed", SECONDARY, _box(Color(0.3, 0.1, 0.16, 0.9), Color(1.0, 0.55, 0.5)))
	theme.set_color("font_color", SECONDARY, UI.C_MUTED)
	theme.set_font_size("font_size", SECONDARY, 24)

	theme.set_stylebox("normal", "LineEdit", _box(Color(0.06, 0.04, 0.14, 0.95), C_BORDER))
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", Color.WHITE)
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.6, 0.58, 0.75))
	theme.set_color("caret_color", "LineEdit", C_ACCENT)

	theme.set_stylebox("panel", "PanelContainer", _box(C_PANEL, C_BORDER, 26, 40))

	theme.set_color("font_outline_color", "Label", Color(0.02, 0.0, 0.06))
	theme.set_constant("outline_size", "Label", 8)
	return theme


## Encoge `control` (anclado a pantalla completa) para que no quede bajo el notch,
## la cámara perforada o las esquinas redondeadas. Se reajusta si cambia el tamaño.
static func fit_safe_area(control: Control) -> void:
	var apply := func() -> void:
		var margins := _safe_margins(control.get_viewport())
		control.offset_left = margins.position.x
		control.offset_top = margins.position.y
		control.offset_right = -margins.size.x
		control.offset_bottom = -margins.size.y
	apply.call()
	control.get_viewport().size_changed.connect(apply)


## Márgenes seguros en unidades de la interfaz: position = izquierda/arriba, size = derecha/abajo.
static func _safe_margins(viewport: Viewport) -> Rect2:
	# En escritorio el área segura es la de todo el monitor, no la de la ventana: no aplica.
	if not OS.has_feature("mobile"):
		return Rect2()
	return margins_from(Vector2(DisplayServer.window_get_size()),
		Rect2(DisplayServer.get_display_safe_area()), viewport.get_visible_rect().size)


## Convierte el área segura (en píxeles de pantalla) a márgenes en unidades de la interfaz.
static func margins_from(window: Vector2, safe: Rect2, visible: Vector2) -> Rect2:
	if window.x <= 0.0 or safe.size.x <= 0.0:
		return Rect2()
	var scale := visible / window
	var left_top := safe.position * scale
	var right_bottom := (window - safe.end) * scale
	return Rect2(left_top.max(Vector2.ZERO), right_bottom.max(Vector2.ZERO))


static func button(text: String, on_pressed: Callable, min_width := 380.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 88)
	b.pressed.connect(on_pressed)
	return b


## Botón pequeño y discreto que pide confirmación: el primer toque cambia el texto
## a "¿…? Pulsa otra vez" durante unos segundos y solo el segundo ejecuta la acción.
static func confirm_button(text: String, question: String, on_confirmed: Callable, min_width := 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = SECONDARY
	b.custom_minimum_size = Vector2(min_width, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var armed := {value = false}
	b.pressed.connect(func() -> void:
		if armed.value:
			armed.value = false
			b.text = text
			on_confirmed.call()
			return
		armed.value = true
		b.text = question
		b.get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(b) and armed.value:
				armed.value = false
				b.text = text
		)
	)
	return b


static func label(text: String, size := 30, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Panel centrado sobre un fondo oscurecido. `buttons` es una lista de [texto, Callable].
static func overlay(title: String, subtitle: String, buttons: Array) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.08, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	box.add_child(label(title, 56, C_ACCENT))
	if subtitle != "":
		box.add_child(label(subtitle, 30, C_MUTED))
	box.add_child(spacer(8))
	var first: Button = null
	for entry in buttons:
		var b := button(entry[0], entry[1])
		box.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.call_deferred("grab_focus")
	return root


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func _box(bg: Color, border: Color, radius := 18, margin := 24) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.55
	s.content_margin_bottom = margin * 0.55
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	return s
