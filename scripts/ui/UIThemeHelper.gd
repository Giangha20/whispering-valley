extends RefCounted
class_name UIThemeHelper
## Cozy Pixel RPG Theme Factory: warm wood borders, parchment panels, sage buttons,
## crisp hover/pressed/disabled states, and responsive window wrapper.

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("#f3e6c8")
	panel_sb.border_color = Color("#5c3a21")
	panel_sb.set_border_width_all(3)
	panel_sb.set_corner_radius_all(4)
	panel_sb.content_margin_left = 8
	panel_sb.content_margin_right = 8
	panel_sb.content_margin_top = 8
	panel_sb.content_margin_bottom = 8
	th.set_stylebox("panel", "PanelContainer", panel_sb)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color("#74a852")
	btn_normal.border_color = Color("#3e5e2a")
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(3)
	btn_normal.content_margin_left = 8
	btn_normal.content_margin_right = 8
	btn_normal.content_margin_top = 4
	btn_normal.content_margin_bottom = 4

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color("#88bd64")
	btn_hover.border_color = Color("#f5d76e")

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color("#558239")

	var btn_disabled := btn_normal.duplicate()
	btn_disabled.bg_color = Color("#9e9a8d")
	btn_disabled.border_color = Color("#69655c")

	th.set_stylebox("normal", "Button", btn_normal)
	th.set_stylebox("hover", "Button", btn_hover)
	th.set_stylebox("focus", "Button", btn_hover)
	th.set_stylebox("pressed", "Button", btn_pressed)
	th.set_stylebox("disabled", "Button", btn_disabled)

	th.set_color("font_color", "Button", Color("#fff9e6"))
	th.set_color("font_hover_color", "Button", Color("#ffffff"))
	th.set_color("font_disabled_color", "Button", Color("#ddd6c5"))
	th.set_font_size("font_size", "Button", 11)

	th.set_color("font_color", "Label", Color("#3b2516"))
	th.set_font_size("font_size", "Label", 11)

	var line_sb := StyleBoxFlat.new()
	line_sb.bg_color = Color("#fff7e2")
	line_sb.border_color = Color("#7a5032")
	line_sb.set_border_width_all(2)
	line_sb.content_margin_left = 6
	line_sb.content_margin_right = 6
	th.set_stylebox("normal", "LineEdit", line_sb)
	th.set_color("font_color", "LineEdit", Color("#2d1b0e"))
	th.set_font_size("font_size", "LineEdit", 11)

	_theme = th
	return _theme


static func make_window_frame(title_text: String, min_size: Vector2 = Vector2(460, 280)) -> Dictionary:
	var overlay := ColorRect.new()
	overlay.color = Color(0.06, 0.08, 0.07, 0.58)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.theme = get_theme()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("#4a2d18"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(26, 22)
	header.add_child(close_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	vbox.add_child(body)

	return {"root": overlay, "panel": panel, "title": title, "closeBtn": close_btn, "body": body}


static func make_wood_style(bg_hex: String = "#d9c298", border_hex: String = "#5c3a21") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg_hex)
	sb.border_color = Color(border_hex)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb
