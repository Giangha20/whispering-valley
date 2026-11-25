extends Node
## Manages 12 regions, discovery fog-of-war, region locks, interiors, daily forage, and scene transitions.

var current_region: String = "greenfield_farm"
var player_spawn_tile: Vector2i = Vector2i(12, 13)
var return_region: String = "greenfield_farm"
var return_tile: Vector2i = Vector2i(10, 11)

var discovered_regions: Dictionary = {"greenfield_farm": true, "willow_village": true}
var unlocked_regions: Dictionary = {}
var daily_forage: Dictionary = {} # region_id -> Array of {"itemId": String, "tile": [x, y]}
var harvested_nodes: Dictionary = {} # "region:x,y" -> days_until_respawn

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset_world()
	EventBus.day_started.connect(_on_day_started)


func reset_world() -> void:
	current_region = "greenfield_farm"
	player_spawn_tile = Vector2i(12, 13)
	return_region = "greenfield_farm"
	return_tile = Vector2i(10, 11)
	discovered_regions = {"greenfield_farm": true, "willow_village": true}
	unlocked_regions.clear()
	for r in GameData.regions_list:
		if not bool(r.get("locked", false)):
			unlocked_regions[str(r["id"])] = true
	harvested_nodes.clear()
	_spawn_daily_forage()


func _on_day_started(_y: int, _s: String, _d: int) -> void:
	var to_restore := []
	for k in harvested_nodes.keys():
		harvested_nodes[k] = int(harvested_nodes[k]) - 1
		if int(harvested_nodes[k]) <= 0:
			to_restore.append(k)
	for k in to_restore:
		harvested_nodes.erase(k)
	_spawn_daily_forage()


func _spawn_daily_forage() -> void:
	daily_forage.clear()
	for r in GameData.regions_list:
		var rid := str(r["id"])
		var pool: Array = r.get("foragePool", [])
		if pool.is_empty():
			continue
		var rw := int(r.get("width", 48))
		var rh := int(r.get("height", 36))
		var items_arr := []
		var count := 4
		for _i in range(count):
			var iid := str(pool[_rng.randi() % pool.size()])
			var tx := _rng.randi_range(6, rw - 7)
			var ty := _rng.randi_range(6, rh - 7)
			if rid == "greenfield_farm" and Rect2i(14, 13, 22, 16).has_point(Vector2i(tx, ty)):
				tx = 6 + _rng.randi_range(0, 6)
			items_arr.append({"itemId": iid, "tile": [tx, ty]})
		daily_forage[rid] = items_arr


func is_region_unlocked(region_id: String) -> bool:
	if unlocked_regions.has(region_id):
		return true
	var r: Dictionary = GameData.regions.get(region_id, {})
	if r.is_empty():
		return false
	if not bool(r.get("locked", false)):
		return true
	var cond := str(r.get("unlockCondition", ""))
	if cond != "" and QuestSystem.check_condition(cond):
		unlocked_regions[region_id] = true
		return true
	return false


func unlock_region(region_id: String) -> void:
	if not unlocked_regions.has(region_id):
		unlocked_regions[region_id] = true
		var r: Dictionary = GameData.regions.get(region_id, {})
		if not r.is_empty():
			EventBus.ui_toast.emit("New Region Unlocked: %s!" % r["name"], "success")


func travel_to(region_id: String, spawn_tile: Vector2i) -> bool:
	if not is_region_unlocked(region_id):
		var r: Dictionary = GameData.regions.get(region_id, {})
		var cond := str(r.get("unlockCondition", "")).replace("_", " ")
		EventBus.ui_toast.emit("%s is locked (%s)." % [r.get("name", region_id), cond], "warning")
		return false

	current_region = region_id
	player_spawn_tile = spawn_tile
	if not discovered_regions.has(region_id):
		discovered_regions[region_id] = true
		EventBus.region_discovered.emit(region_id)
		var reg_name := str(GameData.regions.get(region_id, {}).get("name", region_id))
		EventBus.ui_toast.emit("Discovered %s!" % reg_name, "success")

	EventBus.region_changed.emit(region_id)
	var reg: Dictionary = GameData.regions.get(region_id, {})
	if not reg.is_empty():
		AudioManager.play_music(str(reg.get("music", "spring")))
		AudioManager.play_ambient(str(reg.get("ambient", "forest")))
	return true


func collect_forage(region_id: String, index: int) -> bool:
	if not daily_forage.has(region_id):
		return false
	var arr: Array = daily_forage[region_id]
	if index < 0 or index >= arr.size():
		return false
	var iid := str(arr[index]["itemId"])
	if not InventorySystem.add_item(iid, 1):
		return false
	arr.remove_at(index)
	PlayerState.add_xp("foraging", 8)
	AudioManager.play_sfx("harvest")
	return true


func serialize() -> Dictionary:
	return {
		"currentRegion": current_region,
		"spawnTile": [player_spawn_tile.x, player_spawn_tile.y],
		"returnRegion": return_region,
		"returnTile": [return_tile.x, return_tile.y],
		"discovered": discovered_regions.duplicate(true),
		"unlocked": unlocked_regions.duplicate(true),
		"dailyForage": daily_forage.duplicate(true),
		"harvestedNodes": harvested_nodes.duplicate(true)
	}


func deserialize(data: Dictionary) -> void:
	current_region = str(data.get("currentRegion", "greenfield_farm"))
	if not GameData.regions.has(current_region) and current_region not in ["farmhouse", "greenhouse_interior", "general_store", "blacksmith_shop", "tavern", "clinic"]:
		current_region = "greenfield_farm"
	var st: Variant = data.get("spawnTile", [12, 13])
	if st is Array and st.size() == 2:
		player_spawn_tile = Vector2i(int(st[0]), int(st[1]))
	return_region = str(data.get("returnRegion", "greenfield_farm"))
	var rt: Variant = data.get("returnTile", [10, 11])
	if rt is Array and rt.size() == 2:
		return_tile = Vector2i(int(rt[0]), int(rt[1]))
	var disc: Variant = data.get("discovered", {})
	if disc is Dictionary:
		discovered_regions = disc.duplicate(true)
	var unl: Variant = data.get("unlocked", {})
	if unl is Dictionary:
		unlocked_regions = unl.duplicate(true)
	var df: Variant = data.get("dailyForage", {})
	if df is Dictionary:
		daily_forage = df.duplicate(true)
	var hn: Variant = data.get("harvestedNodes", {})
	if hn is Dictionary:
		harvested_nodes = hn.duplicate(true)
