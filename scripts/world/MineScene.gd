extends Node2D
## 100-Floor Ancient Mine Scene: Controlled procedural ores, gems, treasure chests, monsters,
## Floor 25/50/75/100 Bosses, Bombs, and Exit/Descend Ladders.

const TILE_SIZE := 16

var tile_layer: TileMapLayer
var entities: Node2D
var player: PlayerController
var hud: HUDController
var floor_data: Dictionary = {}
var rock_objs: Array[InteractableObject] = []
var monster_nodes: Array[MonsterEntity] = []
var exit_ladder: InteractableObject
var descend_ladder: InteractableObject
var treasure_obj: InteractableObject


func _ready() -> void:
	WorldSystem.current_region = "mine_shaft"
	tile_layer = TileMapLayer.new()
	tile_layer.tile_set = RegionMapBuilder.get_shared_tileset()
	add_child(tile_layer)

	entities = Node2D.new()
	entities.z_index = 2
	add_child(entities)

	player = PlayerController.new()
	player.add_to_group("player")
	player.interacted.connect(_on_interact)
	player.tool_used.connect(_on_use_tool)
	player.attacked.connect(_on_attack)
	entities.add_child(player)

	hud = HUDController.new()
	hud.return_to_menu_requested.connect(func():
		SaveManager.autosave()
		TimeSystem.is_playing = false
		get_tree().change_scene_to_file("res://scenes/menu/MainMenuScene.tscn")
	)
	add_child(hud)

	_load_mine_floor(MiningSystem.current_floor)


func _load_mine_floor(fl: int) -> void:
	tile_layer.clear()
	for r in rock_objs:
		if is_instance_valid(r):
			r.queue_free()
	rock_objs.clear()
	for m in monster_nodes:
		if is_instance_valid(m):
			m.queue_free()
	monster_nodes.clear()
	if is_instance_valid(exit_ladder): exit_ladder.queue_free()
	if is_instance_valid(descend_ladder): descend_ladder.queue_free()
	if is_instance_valid(treasure_obj): treasure_obj.queue_free()

	MiningSystem.enter_floor(fl)
	floor_data = MiningSystem.generate_floor(fl)
	var tier: Dictionary = floor_data["tier"]
	var fl_tile: Vector2i = tier["floorTile"]
	var wl_tile: Vector2i = tier["wallTile"]

	for y in range(MiningSystem.FLOOR_HEIGHT):
		for x in range(MiningSystem.FLOOR_WIDTH):
			var tp := Vector2i(x, y)
			if x == 0 or y == 0 or x == MiningSystem.FLOOR_WIDTH - 1 or y == MiningSystem.FLOOR_HEIGHT - 1:
				tile_layer.set_cell(tp, 0, wl_tile)
			else:
				tile_layer.set_cell(tp, 0, fl_tile)

	var sp: Vector2i = floor_data["spawnTile"]
	var lp: Vector2i = floor_data["ladderTile"]
	player.set_camera_limits(Vector2i(MiningSystem.FLOOR_WIDTH * TILE_SIZE, MiningSystem.FLOOR_HEIGHT * TILE_SIZE))
	player.global_position = Vector2(sp.x * TILE_SIZE + 8, sp.y * TILE_SIZE + 8)

	exit_ladder = InteractableObject.new()
	exit_ladder.setup("exit_mine", Vector2((sp.x - 1) * TILE_SIZE + 8, sp.y * TILE_SIZE + 8), RegionMapBuilder.get_tile_from_atlas(Vector2i(11, 2)), {}, "Exit Mine")
	add_child(exit_ladder)

	descend_ladder = InteractableObject.new()
	descend_ladder.setup("next_floor", Vector2(lp.x * TILE_SIZE + 8, lp.y * TILE_SIZE + 8), RegionMapBuilder.get_tile_from_atlas(Vector2i(11, 2)), {}, "Floor %d" % mini(100, fl + 1) if fl < 100 else "Mine Cleared")
	add_child(descend_ladder)

	var t_item := str(floor_data.get("treasureItem", ""))
	if t_item != "":
		treasure_obj = InteractableObject.new()
		treasure_obj.setup("treasure", Vector2(lp.x * TILE_SIZE + 8, (lp.y - 2) * TILE_SIZE + 8), RegionMapBuilder.get_tile_from_atlas(Vector2i(2, 3)), {"itemId": t_item}, "Treasure")
		add_child(treasure_obj)

	for rk in floor_data.get("rocks", []):
		var iid := str(rk["itemId"])
		var tile_coord := Vector2i(6, 2)
		if "copper" in iid: tile_coord = Vector2i(7, 2)
		elif "iron" in iid or "frozen" in iid: tile_coord = Vector2i(8, 2)
		elif "gold" in iid or "fire" in iid: tile_coord = Vector2i(9, 2)
		elif "iridium" in iid or "diamond" in iid or "aquamarine" in iid: tile_coord = Vector2i(10, 2)
		var robj := InteractableObject.new()
		var rtile: Vector2i = rk["tile"]
		robj.setup("mine_rock", Vector2(rtile.x * TILE_SIZE + 8, rtile.y * TILE_SIZE + 8), RegionMapBuilder.get_tile_from_atlas(tile_coord), rk, "")
		add_child(robj)
		rock_objs.append(robj)

	for ms in floor_data.get("monsters", []):
		var mid := str(ms["monsterId"])
		var mdef: Dictionary = GameData.monsters.get(mid, {})
		if mdef.is_empty():
			continue
		var mon := MonsterEntity.new()
		var mt: Vector2i = ms["tile"]
		mon.setup(mdef, Vector2(mt.x * TILE_SIZE + 8, mt.y * TILE_SIZE + 8), fl)
		entities.add_child(mon)
		monster_nodes.append(mon)

	hud.refresh_all()
	EventBus.ui_toast.emit("Entered Floor %d (%s)" % [fl, tier["name"]], "info")


func _on_interact() -> void:
	if is_instance_valid(exit_ladder) and exit_ladder.global_position.distance_to(player.global_position) < 26.0:
		WorldSystem.current_region = "ancient_mine"
		WorldSystem.player_spawn_tile = Vector2i(23, 14)
		get_tree().change_scene_to_file("res://scenes/world/WorldScene.tscn")
		return

	if is_instance_valid(treasure_obj) and treasure_obj.global_position.distance_to(player.global_position) < 26.0:
		var tid := str(treasure_obj.data_dict["itemId"])
		if InventorySystem.add_item(tid, 1):
			EventBus.ui_toast.emit("Found %s in Treasure Chest!" % GameData.get_item(tid)["name"], "success")
			treasure_obj.queue_free()
		return

	if is_instance_valid(descend_ladder) and descend_ladder.global_position.distance_to(player.global_position) < 26.0:
		if bool(floor_data.get("isBossFloor", false)) and _has_living_boss():
			EventBus.ui_toast.emit("Defeat the Floor Boss before descending!", "warning")
			return
		if MiningSystem.current_floor < MiningSystem.MAX_FLOORS:
			_load_mine_floor(MiningSystem.current_floor + 1)
		else:
			EventBus.ui_toast.emit("You conquered Floor 100 of the Ancient Mine!", "success")


func _has_living_boss() -> bool:
	for m in monster_nodes:
		if is_instance_valid(m) and m.is_boss:
			return true
	return false


func _on_use_tool(target_tile: Vector2i, _facing: Vector2i) -> void:
	var sel_id := InventorySystem.get_selected_item_id()
	if sel_id in ["special_cherry_bomb", "special_mega_bomb"]:
		if InventorySystem.remove_item(sel_id, 1):
			var radius := 48.0 if sel_id == "special_cherry_bomb" else 88.0
			for r in rock_objs:
				if is_instance_valid(r) and r.global_position.distance_to(player.global_position) <= radius:
					MiningSystem.reward_mine_node(str(r.data_dict["itemId"]))
					r.queue_free()
			AudioManager.play_sfx("hit")
		return

	var def := GameData.get_item(sel_id)
	var tool_type := str(def.get("metadata", {}).get("toolType", ""))
	if tool_type == "pickaxe":
		var wp := Vector2(target_tile.x * TILE_SIZE + 8, target_tile.y * TILE_SIZE + 8)
		for r in rock_objs:
			if is_instance_valid(r) and r.global_position.distance_to(wp) < 22.0:
				if not PlayerState.consume_energy(int(def["metadata"].get("energyCost", 2))):
					return
				r.hp -= int(def["metadata"].get("power", 1))
				AudioManager.play_sfx("pickaxe")
				if r.hp <= 0:
					MiningSystem.reward_mine_node(str(r.data_dict["itemId"]))
					r.queue_free()
				return
	else:
		InventorySystem.use_item_in_slot(InventorySystem.selected_slot)


func _on_attack(hit_center: Vector2, facing: Vector2i) -> void:
	var dmg := PlayerState.get_attack()
	for m in monster_nodes:
		if is_instance_valid(m) and m.global_position.distance_to(hit_center) < 30.0:
			m.take_hit(dmg, Vector2(facing))
