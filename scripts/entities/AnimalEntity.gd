extends CharacterBody2D
class_name AnimalEntity
## Farm livestock entity with idle pasture wandering, product indicator, and pet/feed/collect interaction.

var animal_uid: String = ""
var species_id: String = ""
var home_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _anim_t: float = 0.0
var _rng := RandomNumberGenerator.new()

var sprite: Sprite2D
var ready_badge: Label


func setup(animal_data: Dictionary, spawn_pos: Vector2) -> void:
	animal_uid = str(animal_data.get("uid", ""))
	species_id = str(animal_data.get("speciesId", "chicken"))
	home_pos = spawn_pos
	global_position = spawn_pos
	target_pos = spawn_pos
	_rng.randomize()

	collision_layer = 8
	collision_mask = 1

	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 5.0
	col.shape = sh
	add_child(col)

	sprite = Sprite2D.new()
	sprite.texture = GameData.get_animal_texture(species_id, 0)
	add_child(sprite)

	ready_badge = Label.new()
	ready_badge.text = "!"
	ready_badge.add_theme_font_size_override("font_size", 8)
	ready_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	ready_badge.position = Vector2(-4, -18)
	ready_badge.visible = bool(animal_data.get("productReady", false))
	add_child(ready_badge)


func refresh_badge(product_ready: bool) -> void:
	if ready_badge != null:
		ready_badge.visible = product_ready


func _physics_process(delta: float) -> void:
	if InputAdapter.is_gameplay_locked():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(2.0, 4.5)
		target_pos = home_pos + Vector2(_rng.randf_range(-36.0, 36.0), _rng.randf_range(-24.0, 24.0))

	var diff := target_pos - global_position
	if diff.length() > 3.0:
		var dir := diff.normalized()
		velocity = dir * 18.0
		sprite.flip_h = dir.x < 0.0
		_anim_t += delta * 6.0
		sprite.texture = GameData.get_animal_texture(species_id, int(_anim_t) % 4)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		sprite.texture = GameData.get_animal_texture(species_id, 0)
