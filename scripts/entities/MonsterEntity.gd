extends CharacterBody2D
class_name MonsterEntity
## Mine enemy / floor boss with pursuit AI, damage cooldown, knockback, and loot drop trigger.

signal defeated(monster_id: String, is_boss: bool)

var monster_id: String = ""
var monster_name: String = ""
var is_boss: bool = false
var max_hp: int = 30
var hp: int = 30
var atk: int = 6
var move_speed: float = 42.0
var _anim_t: float = 0.0
var _atk_cooldown: float = 0.0
var _flash_timer: float = 0.0

var sprite: Sprite2D
var hp_bar: ColorRect


func setup(def: Dictionary, spawn_pos: Vector2, floor_num: int) -> void:
	monster_id = str(def.get("id", "green_slime"))
	monster_name = str(def.get("name", "Slime"))
	is_boss = bool(def.get("boss", false))
	var scale_hp := 1.0 + (0.0 if is_boss else float(floor_num) * 0.025)
	max_hp = int(round(float(def.get("hp", 32)) * scale_hp))
	hp = max_hp
	atk = int(def.get("atk", 6)) + (floor_num / 15)
	move_speed = float(def.get("speed", 42.0))
	global_position = spawn_pos

	collision_layer = 16
	collision_mask = 1 | 2

	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 10.0 if is_boss else 7.0
	col.shape = sh
	add_child(col)

	sprite = Sprite2D.new()
	sprite.texture = GameData.get_monster_texture(monster_id, 0)
	if is_boss:
		sprite.scale = Vector2(1.4, 1.4)
	add_child(sprite)

	var bg := ColorRect.new()
	bg.size = Vector2(24, 3)
	bg.position = Vector2(-12, -16)
	bg.color = Color(0.15, 0.1, 0.1, 0.85)
	add_child(bg)

	hp_bar = ColorRect.new()
	hp_bar.size = Vector2(24, 3)
	hp_bar.position = Vector2(-12, -16)
	hp_bar.color = Color(0.9, 0.25, 0.25)
	add_child(hp_bar)


func take_hit(dmg: int, knockback: Vector2) -> void:
	hp = maxi(0, hp - dmg)
	_flash_timer = 0.16
	velocity = knockback * 110.0
	AudioManager.play_sfx("hit")
	if hp_bar != null:
		hp_bar.size.x = 24.0 * (float(hp) / float(maxi(1, max_hp)))
	if hp <= 0:
		MiningSystem.record_monster_defeat(monster_id)
		defeated.emit(monster_id, is_boss)
		queue_free()


func _physics_process(delta: float) -> void:
	if InputAdapter.is_gameplay_locked():
		return
	if _atk_cooldown > 0.0:
		_atk_cooldown -= delta
	if _flash_timer > 0.0:
		_flash_timer -= delta
		sprite.modulate = Color(1.0, 0.35, 0.35) if _flash_timer > 0.0 else Color.WHITE

	_anim_t += delta * 6.0
	sprite.texture = GameData.get_monster_texture(monster_id, int(_anim_t) % 4)

	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player != null:
		var diff := player.global_position - global_position
		var dist := diff.length()
		if dist < (220.0 if is_boss else 140.0) and dist > 10.0:
			velocity = velocity.lerp(diff.normalized() * move_speed, 5.0 * delta)
		else:
			velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)
		if dist < 16.0 and _atk_cooldown <= 0.0:
			_atk_cooldown = 1.1
			PlayerState.take_damage(atk)
			AudioManager.play_sfx("hit")
	move_and_slide()
