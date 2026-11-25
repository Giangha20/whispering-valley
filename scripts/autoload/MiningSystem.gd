extends Node
## Controlled Procedural 100-Floor Mine System with Biome Tiers, Ores, Gems, Monsters, and Bosses.

const MAX_FLOORS := 100
const FLOOR_WIDTH := 30
const FLOOR_HEIGHT := 22

var current_floor: int = 1
var max_floor_reached: int = 1
var _rng := RandomNumberGenerator.new()


func reset_mining() -> void:
	current_floor = 1
	max_floor_reached = 1


func get_tier_for_floor(floor_num: int) -> Dictionary:
	if floor_num <= 25:
		return {"name": "Earth Caverns", "floorTile": Vector2i(13, 0), "wallTile": Vector2i(10, 1), "ores": ["copper_ore", "coal", "quartz"]}
	if floor_num <= 50:
		return {"name": "Frozen Depths", "floorTile": Vector2i(9, 0), "wallTile": Vector2i(11, 1), "ores": ["iron_ore", "coal", "frozen_tear", "aquamarine"]}
	if floor_num <= 75:
		return {"name": "Ember Hollows", "floorTile": Vector2i(12, 0), "wallTile": Vector2i(8, 1), "ores": ["gold_ore", "coal", "fire_quartz", "ruby"]}
	return {"name": "Shadow Sanctum", "floorTile": Vector2i(14, 0), "wallTile": Vector2i(8, 1), "ores": ["iridium_ore", "gold_ore", "diamond", "amethyst"]}


func enter_floor(floor_num: int) -> void:
	current_floor = clampi(floor_num, 1, MAX_FLOORS)
	if current_floor > max_floor_reached:
		max_floor_reached = current_floor
	if current_floor >= 10:
		WorldSystem.unlock_region("forgotten_ruins")
	if current_floor >= 25:
		WorldSystem.unlock_region("hidden_sanctuary")
	EventBus.mine_floor_reached.emit(current_floor)


func generate_floor(floor_num: int) -> Dictionary:
	var fl := clampi(floor_num, 1, MAX_FLOORS)
	_rng.seed = fl * 9137 + TimeSystem.day * 31
	var tier := get_tier_for_floor(fl)
	var is_boss_floor := (fl in [25, 50, 75, 100])

	var rocks: Array = [] # {"tile": Vector2i, "kind": String, "itemId": String, "hp": int}
	var monster_spawns: Array = [] # {"monsterId": String, "tile": Vector2i}
	var spawn_tile := Vector2i(4, FLOOR_HEIGHT / 2)
	var ladder_tile := Vector2i(FLOOR_WIDTH - 5, FLOOR_HEIGHT / 2)

	# Generate rocks and ore nodes leaving clear spawn & ladder lanes
	var ore_pool: Array = tier["ores"]
	var node_count := 16 if is_boss_floor else (26 + (fl % 10))
	var used := {spawn_tile: true, ladder_tile: true}

	for _i in range(node_count):
		var tx := _rng.randi_range(3, FLOOR_WIDTH - 4)
		var ty := _rng.randi_range(3, FLOOR_HEIGHT - 4)
		var pos := Vector2i(tx, ty)
		if used.has(pos) or pos.distance_to(spawn_tile) < 3.0:
			continue
		used[pos] = true
		var roll := _rng.randf()
		var item_id := "stone"
		var kind := "stone"
		var hp := 2 + (fl / 30)
		if roll < 0.42:
			item_id = str(ore_pool[_rng.randi() % ore_pool.size()])
			kind = "ore"
			hp += 1
		rocks.append({"tile": pos, "kind": kind, "itemId": item_id, "hp": hp})

	# Select monsters valid for this floor
	var valid_monsters: Array = []
	var boss_def: Dictionary = {}
	for m in GameData.monsters_list:
		var fr: Array = m.get("floors", [1, 100])
		if fl >= int(fr[0]) and fl <= int(fr[1]):
			if bool(m.get("boss", false)):
				boss_def = m
			else:
				valid_monsters.append(m)

	if is_boss_floor and not boss_def.is_empty():
		monster_spawns.append({"monsterId": boss_def["id"], "tile": Vector2i(FLOOR_WIDTH / 2 + 4, FLOOR_HEIGHT / 2)})
	else:
		var m_count := clampi(2 + fl / 12, 2, 7)
		for _j in range(m_count):
			if valid_monsters.is_empty():
				break
			var m_def: Dictionary = valid_monsters[_rng.randi() % valid_monsters.size()]
			var mx := _rng.randi_range(8, FLOOR_WIDTH - 5)
			var my := _rng.randi_range(3, FLOOR_HEIGHT - 4)
			var mp := Vector2i(mx, my)
			if not used.has(mp):
				used[mp] = true
				monster_spawns.append({"monsterId": m_def["id"], "tile": mp})

	var treasure_item := ""
	if fl % 5 == 0:
		var treasures := ["emerald", "ruby", "diamond", "gold_bar", "iridium_bar", "equip_crystal_sabre", "special_mega_bomb"]
		treasure_item = treasures[(fl / 5) % treasures.size()]

	return {
		"floor": fl,
		"tier": tier,
		"isBossFloor": is_boss_floor,
		"spawnTile": spawn_tile,
		"ladderTile": ladder_tile,
		"rocks": rocks,
		"monsters": monster_spawns,
		"treasureItem": treasure_item
	}


func reward_mine_node(item_id: String) -> void:
	var qty := 1 + (1 if _rng.randf() < 0.25 else 0)
	InventorySystem.add_item(item_id, qty)
	if item_id != "stone" and _rng.randf() < 0.2:
		InventorySystem.add_item("coal", 1)
	PlayerState.add_xp("mining", 10 if item_id != "stone" else 4)
	AudioManager.play_sfx("pickaxe")


func record_monster_defeat(monster_id: String) -> void:
	var mon: Dictionary = GameData.monsters.get(monster_id, {})
	if mon.is_empty():
		return
	var is_boss := bool(mon.get("boss", false))
	PlayerState.add_xp("combat", int(mon.get("xp", 15)))
	var drops: Array = mon.get("drops", [])
	if not drops.is_empty():
		var drop_id := str(drops[0])
		InventorySystem.add_item(drop_id, 1)
		if is_boss and drops.size() > 1:
			for extra in drops.slice(1):
				InventorySystem.add_item(str(extra), 1)
			EventBus.ui_toast.emit("Boss %s defeated! Obtained legendary loot!" % mon["name"], "success")
	EventBus.monster_defeated.emit(monster_id, is_boss)


func serialize() -> Dictionary:
	return {"currentFloor": current_floor, "maxFloorReached": max_floor_reached}


func deserialize(data: Dictionary) -> void:
	current_floor = clampi(int(data.get("currentFloor", 1)), 1, MAX_FLOORS)
	max_floor_reached = clampi(int(data.get("maxFloorReached", 1)), 1, MAX_FLOORS)
