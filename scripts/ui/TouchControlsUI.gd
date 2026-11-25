extends Control
class_name TouchControlsUI
## Responsive Mobile Virtual Joystick (left) and Action Buttons (right) with Safe Area padding.

signal panel_requested(panel_name: String)

const JOYSTICK_RADIUS := 36.0

var joystick_center := Vector2(64, -64)
var joystick_touch_id: int = -1
var joy_base: Control
var joy_knob: ColorRect
var action_cluster: Control


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = UIThemeHelper.get_theme()
	_build_controls()
	refresh_visibility()


func refresh_visibility() -> void:
	visible = InputAdapter.should_show_touch_controls()


func _build_controls() -> void:
	# Left Virtual Joystick container (bottom-left with safe margin)
	joy_base = Panel.new()
	joy_base.custom_minimum_size = Vector2(84, 84)
	joy_base.set_anchors_preset(PRESET_BOTTOM_LEFT)
	joy_base.position = Vector2(18, -106)
	joy_base.size = Vector2(84, 84)
	joy_base.add_theme_stylebox_override("panel", UIThemeHelper.make_wood_style("#3a4a38aa", "#e8d9b5cc"))
	joy_base.mouse_filter = MOUSE_FILTER_PASS
	add_child(joy_base)

	joy_knob = ColorRect.new()
	joy_knob.size = Vector2(28, 28)
	joy_knob.position = Vector2(28, 28)
	joy_knob.color = Color("#f5e8ccdd")
	joy_knob.mouse_filter = MOUSE_FILTER_IGNORE
	joy_base.add_child(joy_knob)

	# Right Action Buttons cluster (bottom-right)
	action_cluster = Control.new()
	action_cluster.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	action_cluster.position = Vector2(-176, -124)
	action_cluster.size = Vector2(166, 114)
	action_cluster.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(action_cluster)

	_make_touch_btn(action_cluster, "Use", Vector2(106, 56), Vector2(54, 46), func(): InputAdapter.trigger_virtual_action("tool"))
	_make_touch_btn(action_cluster, "Talk/Act", Vector2(44, 56), Vector2(56, 46), func(): InputAdapter.trigger_virtual_action("interact"))
	_make_touch_btn(action_cluster, "Atk", Vector2(106, 6), Vector2(54, 42), func(): InputAdapter.trigger_virtual_action("attack"))

	var sprint_btn := Button.new()
	sprint_btn.text = "Run"
	sprint_btn.toggle_mode = true
	sprint_btn.position = Vector2(44, 6)
	sprint_btn.size = Vector2(56, 42)
	sprint_btn.toggled.connect(func(on: bool): InputAdapter.virtual_running = on)
	action_cluster.add_child(sprint_btn)

	# Quick Menu buttons (Bag / Map / Menu)
	_make_touch_btn(action_cluster, "Bag", Vector2(-12, 56), Vector2(48, 36), func(): panel_requested.emit("inventory"))
	_make_touch_btn(action_cluster, "Map", Vector2(-12, 12), Vector2(48, 36), func(): panel_requested.emit("map"))


func _make_touch_btn(parent: Control, lbl: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = lbl
	b.position = pos
	b.size = sz
	b.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		cb.call()
	)
	parent.add_child(b)
	return b


func _input(event: InputEvent) -> void:
	if not visible or InputAdapter.is_gameplay_locked():
		InputAdapter.set_virtual_move(Vector2.ZERO)
		return
	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		var rect := joy_base.get_global_rect()
		if ev.pressed and rect.has_point(ev.position) and joystick_touch_id == -1:
			joystick_touch_id = ev.index
			_update_joystick(ev.position)
		elif not ev.pressed and ev.index == joystick_touch_id:
			joystick_touch_id = -1
			joy_knob.position = Vector2(28, 28)
			InputAdapter.set_virtual_move(Vector2.ZERO)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joystick_touch_id:
			_update_joystick(drag.position)


func _update_joystick(screen_pos: Vector2) -> void:
	var center := joy_base.get_global_rect().get_center()
	var diff := (screen_pos - center)
	if diff.length() > JOYSTICK_RADIUS:
		diff = diff.normalized() * JOYSTICK_RADIUS
	joy_knob.position = Vector2(28, 28) + diff
	InputAdapter.set_virtual_move(diff / JOYSTICK_RADIUS)
