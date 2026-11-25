extends Node
## Unified Input Adapter bridging PC Keyboard/Mouse and Mobile Virtual Joystick/Buttons.

signal action_triggered(action_name: String)

var virtual_move: Vector2 = Vector2.ZERO
var virtual_running: bool = false
var modal_locks: Dictionary = {}
var auto_tool_enabled: bool = true
var touch_controls_mode: String = "auto" # "auto", "always", "off"
var _pending_actions: Dictionary = {}


func set_modal_locked(panel_name: String, locked: bool) -> void:
	if locked:
		modal_locks[panel_name] = true
	else:
		modal_locks.erase(panel_name)
	TimeSystem.set_paused("ui_modal", not modal_locks.is_empty())
	EventBus.modal_state_changed.emit(not modal_locks.is_empty(), panel_name)


func clear_modal_locks() -> void:
	modal_locks.clear()
	TimeSystem.set_paused("ui_modal", false)


func is_gameplay_locked() -> bool:
	return not modal_locks.is_empty()


func should_show_touch_controls() -> bool:
	if touch_controls_mode == "always":
		return true
	if touch_controls_mode == "off":
		return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]


func set_virtual_move(vec: Vector2) -> void:
	virtual_move = vec.limit_length(1.0)


func trigger_virtual_action(action_name: String) -> void:
	if is_gameplay_locked() and action_name not in ["menu", "close"]:
		return
	_pending_actions[action_name] = true
	action_triggered.emit(action_name)


func consume_action(action_name: String) -> bool:
	if _pending_actions.has(action_name):
		_pending_actions.erase(action_name)
		return true
	return false


func get_move_vector() -> Vector2:
	if is_gameplay_locked():
		return Vector2.ZERO
	var kb := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		kb.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		kb.y += 1.0
	if kb.length_squared() > 0.01:
		return kb.normalized()
	if virtual_move.length_squared() > 0.01:
		return virtual_move.normalized()
	return Vector2.ZERO


func is_running() -> bool:
	if is_gameplay_locked():
		return false
	return Input.is_key_pressed(KEY_SHIFT) or virtual_running
