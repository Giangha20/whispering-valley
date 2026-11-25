extends CharacterBody2D
class_name PlayerController
## Player entity with layered customization sprites, normalized 8-dir movement,
## camera clamping, facing tile target cursor, and tool/combat states.

signal interacted()
signal tool_used(target_tile: Vector2i, facing: Vector2i)
signal attacked(target_pos: Vector2, facing: Vector2i)

const WALK_SPEED := 78.0
const RUN_SPEED := 118.0
const ACCEL := 900.0
const TILE_SIZE := 16

var facing_dir: Vector2i = Vector2i.DOWN
var facing_index: int = 0 # 0=down, 1=up, 2=left, 3=right
var walk_timer: float = 0.0
var walk_frame: int = 0
var action_timer: float = 0.0
var is_sitting: bool = false
var touch_move_target: Vector2 = Vector2.ZERO
var has_touch_target: bool = false

var body_sprite: Sprite2D
var outfit_sprite: Sprite2D
var hair_sprite: Sprite2D
var acc_sprite: Sprite2D
var cursor_rect: ColorRect
var camera: Camera2D
var hit_cooldown: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 8)
	col.shape = shape
	col.position = Vector2(0, 6)
	add_child(col)

	_build_visual_layers()
	_build_cursor()

	camera = Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)

	EventBus.player_stats_changed.connect(apply_customization_visuals)
	apply_customization_visuals()


func _build_visual_layers() -> void:
	body_sprite = Sprite2D.new()
	body_sprite.texture = load("res://assets/sprites/player/base.png")
	body_sprite.region_enabled = true
	body_sprite.position = Vector2(0, -2)
	add_child(body_sprite)

	outfit_sprite = Sprite2D.new()
	outfit_sprite.texture = load("res://assets/sprites/player/outfit.png")
	outfit_sprite.region_enabled = true
	outfit_sprite.position = Vector2(0, -2)
	add_child(outfit_sprite)

	hair_sprite = Sprite2D.new()
	hair_sprite.texture = load("res://assets/sprites/player/hair.png")
	hair_sprite.region_enabled = true
	hair_sprite.position = Vector2(0, -2)
	add_child(hair_sprite)

	acc_sprite = Sprite2D.new()
	acc_sprite.texture = load("res://assets/sprites/player/accessory.png")
	acc_sprite.region_enabled = true
	acc_sprite.position = Vector2(0, -2)
	add_child(acc_sprite)


func _build_cursor() -> void:
	cursor_rect = ColorRect.new()
	cursor_rect.size = Vector2(16, 16)
	cursor_rect.color = Color(1.0, 0.95, 0.4, 0.25)
	cursor_rect.z_index = 5
	cursor_rect.top_level = true
	add_child(cursor_rect)


func apply_customization_visuals() -> void:
	var c: Dictionary = PlayerState.customization
	body_sprite.modulate = Color.html(str(c.get("skinTone", "#ebb896")))
	hair_sprite.modulate = Color.html(str(c.get("hairColor", "#6a3e26")))
	outfit_sprite.modulate = Color.html(str(c.get("outfitColor", "#4f8d4e")))
	_update_sprite_regions()


func set_camera_limits(map_pixel_size: Vector2i) -> void:
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = maxi(640, map_pixel_size.x)
	camera.limit_bottom = maxi(360, map_pixel_size.y)


func set_touch_move_target(world_pos: Vector2) -> void:
	touch_move_target = world_pos
	has_touch_target = true


func get_tile_pos() -> Vector2i:
	return Vector2i(int(floor(global_position.x / TILE_SIZE)), int(floor(global_position.y / TILE_SIZE)))


func get_target_tile() -> Vector2i:
	return get_tile_pos() + facing_dir


func _physics_process(delta: float) -> void:
	if hit_cooldown > 0.0:
		hit_cooldown = maxf(0.0, hit_cooldown - delta)
	if action_timer > 0.0:
		action_timer = maxf(0.0, action_timer - delta)
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
		move_and_slide()
		_update_cursor()
		return

	if InputAdapter.is_gameplay_locked():
		velocity = Vector2.ZERO
		has_touch_target = false
		_update_cursor()
		return

	var move_vec: Vector2 = InputAdapter.get_move_vector()
	if move_vec.length_squared() > 0.01:
		has_touch_target = false
		is_sitting = false
	elif has_touch_target:
		var diff := touch_move_target - global_position
		if diff.length() < 6.0:
			has_touch_target = false
		else:
			move_vec = diff.normalized()

	var spd := (RUN_SPEED if InputAdapter.is_running() else WALK_SPEED) * PlayerState.get_speed_multiplier()
	if move_vec.length_squared() > 0.01:
		velocity = velocity.move_toward(move_vec * spd, ACCEL * delta)
		_update_facing(move_vec)
		walk_timer += delta * (10.0 if InputAdapter.is_running() else 7.0)
		walk_frame = int(walk_timer) % 4
	else:
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
		walk_frame = 0
		walk_timer = 0.0

	move_and_slide()
	_update_sprite_regions()
	_update_cursor()
	_check_actions()


func _check_actions() -> void:
	if Input.is_action_just_pressed("ui_accept") and false:
		pass # handled via explicit keys below so Enter doesn't clash awkwardly

	if Input.is_key_pressed(KEY_E) or InputAdapter.consume_action("interact"):
		if _debounce("e", 0.22):
			interacted.emit()
	elif Input.is_key_pressed(KEY_SPACE) or InputAdapter.consume_action("tool"):
		if _debounce("space", 0.24):
			_perform_primary_action()
	elif InputAdapter.consume_action("attack"):
		if _debounce("atk", 0.24):
			_perform_attack()


var _debounce_map: Dictionary = {}


func _debounce(key: String, cooldown: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var last: float = float(_debounce_map.get(key, 0.0))
	if now - last < cooldown:
		return false
	_debounce_map[key] = now
	return true


func _perform_primary_action() -> void:
	var sel_id := InventorySystem.get_selected_item_id()
	var item_def := GameData.get_item(sel_id)
	var tool_type := str(item_def.get("metadata", {}).get("toolType", ""))
	if tool_type == "sword":
		_perform_attack()
	else:
		action_timer = 0.16
		tool_used.emit(get_target_tile(), facing_dir)


func _perform_attack() -> void:
	action_timer = 0.18
	AudioManager.play_sfx("sword")
	attacked.emit(global_position + Vector2(facing_dir) * 18.0, facing_dir)


func _update_facing(v: Vector2) -> void:
	if absf(v.x) > absf(v.y):
		if v.x < 0.0:
			facing_dir = Vector2i.LEFT
			facing_index = 2
		else:
			facing_dir = Vector2i.RIGHT
			facing_index = 3
	else:
		if v.y < 0.0:
			facing_dir = Vector2i.UP
			facing_index = 1
		else:
			facing_dir = Vector2i.DOWN
			facing_index = 0


func _update_sprite_regions() -> void:
	var c: Dictionary = PlayerState.customization
	var h_style := clampi(int(c.get("hairStyle", 0)), 0, 11)
	var o_style := clampi(int(c.get("outfitStyle", 0)), 0, 13)
	var a_style := clampi(int(c.get("accessory", 0)), 0, 11)
	var col_idx := facing_index * 4 + walk_frame

	body_sprite.region_rect = Rect2(walk_frame * 16, facing_index * 24, 16, 24)
	hair_sprite.region_rect = Rect2(col_idx * 16, h_style * 24, 16, 24)
	outfit_sprite.region_rect = Rect2(col_idx * 16, o_style * 24, 16, 24)
	acc_sprite.visible = a_style > 0
	if a_style > 0:
		acc_sprite.region_rect = Rect2(col_idx * 16, a_style * 24, 16, 24)


func _update_cursor() -> void:
	if cursor_rect == null:
		return
	var tt := get_target_tile()
	cursor_rect.global_position = Vector2(tt.x * TILE_SIZE, tt.y * TILE_SIZE)
	cursor_rect.visible = not InputAdapter.is_gameplay_locked()
