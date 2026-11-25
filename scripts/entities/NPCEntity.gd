extends CharacterBody2D
class_name NPCEntity
## Living NPC entity with animated directional walk, idle/work routines, and interaction prompt.

var npc_id: String = ""
var npc_name: String = ""
var home_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var _move_timer: float = 0.0
var _walk_timer: float = 0.0
var _facing: int = 0
var _rng := RandomNumberGenerator.new()

var sprite: Sprite2D
var name_label: Label


func setup(def: Dictionary, spawn_tile: Vector2i) -> void:
	npc_id = str(def.get("id", ""))
	npc_name = str(def.get("name", "Villager"))
	home_pos = Vector2(spawn_tile.x * 16 + 8, spawn_tile.y * 16 + 8)
	global_position = home_pos
	target_pos = home_pos
	_rng.randomize()

	collision_layer = 4
	collision_mask = 1

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 8)
	col.shape = shape
	col.position = Vector2(0, 6)
	add_child(col)

	sprite = Sprite2D.new()
	var tex_path := str(def.get("sprite", ""))
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path) as Texture2D
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 16, 24)
	sprite.position = Vector2(0, -2)
	add_child(sprite)

	name_label = Label.new()
	name_label.text = npc_name
	name_label.add_theme_font_size_override("font_size", 7)
	name_label.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	name_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.06))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.position = Vector2(-28, -24)
	name_label.size = Vector2(56, 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)


func _physics_process(delta: float) -> void:
	if InputAdapter.is_gameplay_locked():
		velocity = Vector2.ZERO
		return
	_move_timer -= delta
	if _move_timer <= 0.0:
		_move_timer = _rng.randf_range(2.2, 5.0)
		var off := Vector2(_rng.randf_range(-28.0, 28.0), _rng.randf_range(-22.0, 22.0))
		target_pos = home_pos + off

	var diff := target_pos - global_position
	var frame := 0
	if diff.length() > 3.0:
		var dir := diff.normalized()
		velocity = dir * 24.0
		if absf(dir.x) > absf(dir.y):
			_facing = 2 if dir.x < 0.0 else 3
		else:
			_facing = 1 if dir.y < 0.0 else 0
		_walk_timer += delta * 5.0
		frame = int(_walk_timer) % 4
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		_facing = 0

	if sprite != null:
		sprite.region_rect = Rect2(frame * 16, _facing * 24, 16, 24)
