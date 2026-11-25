extends Area2D
class_name InteractableObject
## Generic world object: Forageables, Trees, Rocks, Ores, Chests, Shipping Bin, Doors, Portals, Beds, Stoves, Machines, Ladders.

var kind: String = "" # forage, tree, rock, ore, shipping_bin, portal, interior_door, bed, stove, workbench, chest, machine, well, sign, festival_booth, mine_ladder, mine_treasure
var data_dict: Dictionary = {}
var hp: int = 3
var sprite: Sprite2D
var label: Label


func setup(obj_kind: String, pos: Vector2, tex: Texture2D, payload: Dictionary = {}, show_tag: String = "") -> void:
	kind = obj_kind
	data_dict = payload
	hp = int(payload.get("hp", 3))
	global_position = pos

	collision_layer = 8
	collision_mask = 0

	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(16, 16)
	col.shape = sh
	add_child(col)

	if tex != null:
		sprite = Sprite2D.new()
		sprite.texture = tex
		add_child(sprite)

	if show_tag != "":
		label = Label.new()
		label.text = show_tag
		label.add_theme_font_size_override("font_size", 7)
		label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.80))
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
		label.add_theme_constant_override("outline_size", 2)
		label.position = Vector2(-36, -20)
		label.size = Vector2(72, 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
