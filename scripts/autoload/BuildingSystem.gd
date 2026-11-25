extends Node
## Handles placing, moving, demolishing buildings/machines/decorations, collision checks,
## irrigation sprinklers, and artisan processing machines.

var placed_buildings: Array = [] # [{"uid": String, "buildingId": String, "region": String, "tile": [x,y], "readyItem": String, "daysLeft": int}]
var _next_uid: int = 1


func _ready() -> void:
	EventBus.day_ended.connect(_on_day_ended)


func reset_buildings() -> void:
	placed_buildings.clear()
	_next_uid = 1


func get_building_rect(bldg: Dictionary) -> Rect2i:
	var def: Dictionary = GameData.buildings.get(str(bldg.get("buildingId", "")), {})
	var sz: Array = def.get("size", [1, 1])
	var t: Array = bldg.get("tile", [0, 0])
	return Rect2i(int(t[0]), int(t[1]), int(sz[0]), int(sz[1]))


func is_tile_blocked(region_id: String, tile: Vector2i) -> bool:
	for b in placed_buildings:
		if str(b.get("region", "")) != region_id:
			continue
		var def: Dictionary = GameData.buildings.get(str(b.get("buildingId", "")), {})
		if str(def.get("id", "")) in ["cobble_path", "wood_path"]:
			continue
		if get_building_rect(b).has_point(tile):
			return true
	return false


func can_place(building_id: String, region_id: String, tile: Vector2i, ignore_uid: String = "") -> Dictionary:
	var def: Dictionary = GameData.buildings.get(building_id, {})
	if def.is_empty():
		return {"ok": false, "reason": "Unknown building."}
	if region_id not in ["greenfield_farm", "greenhouse_interior"]:
		return {"ok": false, "reason": "Buildings can only be placed on Greenfield Farm!"}

	var reg: Dictionary = GameData.regions.get(region_id, {})
	var rw := int(reg.get("width", 52))
	var rh := int(reg.get("height", 38))
	var sz: Array = def.get("size", [1, 1])
	var rect := Rect2i(tile.x, tile.y, int(sz[0]), int(sz[1]))

	if rect.position.x < 3 or rect.position.y < 5 or rect.end.x > rw - 3 or rect.end.y > rh - 3:
		return {"ok": false, "reason": "Too close to map border."}

	# Protect Farmhouse & Shipping Bin footprint
	var farmhouse_zone := Rect2i(7, 5, 6, 6)
	if rect.intersects(farmhouse_zone):
		return {"ok": false, "reason": "Cannot build over your Farmhouse."}

	# Check existing buildings & crops
	for b in placed_buildings:
		if str(b.get("uid", "")) == ignore_uid or str(b.get("region", "")) != region_id:
			continue
		if rect.intersects(get_building_rect(b)):
			return {"ok": false, "reason": "Space occupied by another building."}

	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var ft := FarmingSystem.get_tile(region_id, Vector2i(x, y))
			if str(ft.get("cropId", "")) != "":
				return {"ok": false, "reason": "Clear planted crops before building here."}

	return {"ok": true, "reason": ""}


func place_from_inventory(building_id: String, region_id: String, tile: Vector2i) -> Dictionary:
	var def: Dictionary = GameData.buildings.get(building_id, {})
	if def.is_empty():
		return {"ok": false, "reason": "Invalid building."}
	var chk := can_place(building_id, region_id, tile)
	if not bool(chk["ok"]):
		return chk
	var item_id := str(def.get("itemId", ""))
	if not InventorySystem.remove_item(item_id, 1):
		return {"ok": false, "reason": "Building item not in inventory."}
	return _commit_place(building_id, region_id, tile)


func construct_via_carpenter(building_id: String, region_id: String, tile: Vector2i) -> Dictionary:
	var def: Dictionary = GameData.buildings.get(building_id, {})
	if def.is_empty():
		return {"ok": false, "reason": "Invalid building."}
	var chk := can_place(building_id, region_id, tile)
	if not bool(chk["ok"]):
		return chk
	var cost_gold := int(def.get("buildCostGold", 0))
	if PlayerState.gold < cost_gold:
		return {"ok": false, "reason": "Need %dG to construct %s." % [cost_gold, def["name"]]}
	for m in def.get("materials", []):
		if InventorySystem.count_item(str(m["itemId"])) < int(m["count"]):
			return {"ok": false, "reason": "Need %dx %s." % [int(m["count"]), GameData.get_item(str(m["itemId"]))["name"]]}

	if not PlayerState.spend_gold(cost_gold):
		return {"ok": false, "reason": "Payment failed."}
	for m in def.get("materials", []):
		InventorySystem.remove_item(str(m["itemId"]), int(m["count"]))
	return _commit_place(building_id, region_id, tile)


func _commit_place(building_id: String, region_id: String, tile: Vector2i) -> Dictionary:
	var uid := "bldg_%d" % _next_uid
	_next_uid += 1
	var entry := {
		"uid": uid,
		"buildingId": building_id,
		"region": region_id,
		"tile": [tile.x, tile.y],
		"readyItem": "",
		"daysLeft": 0
	}
	placed_buildings.append(entry)
	AudioManager.play_sfx("axe")
	EventBus.building_placed.emit(building_id, region_id, tile)
	return {"ok": true, "uid": uid}


func move_building(uid: String, new_tile: Vector2i) -> Dictionary:
	for b in placed_buildings:
		if b["uid"] == uid:
			var chk := can_place(str(b["buildingId"]), str(b["region"]), new_tile, uid)
			if not bool(chk["ok"]):
				return chk
			b["tile"] = [new_tile.x, new_tile.y]
			AudioManager.play_sfx("ui_click")
			return {"ok": true}
	return {"ok": false, "reason": "Building not found."}


func demolish_building(uid: String) -> bool:
	for i in range(placed_buildings.size()):
		if placed_buildings[i]["uid"] == uid:
			var b: Dictionary = placed_buildings[i]
			var def: Dictionary = GameData.buildings.get(str(b["buildingId"]), {})
			var item_id := str(def.get("itemId", ""))
			if item_id != "" and InventorySystem.can_fit(item_id, 1):
				InventorySystem.add_item(item_id, 1)
			placed_buildings.remove_at(i)
			EventBus.building_removed.emit(str(b["buildingId"]), str(b["region"]), Vector2i(b["tile"][0], b["tile"][1]))
			return true
	return false


func interact_machine(uid: String) -> bool:
	for b in placed_buildings:
		if b["uid"] != uid:
			continue
		var bid := str(b["buildingId"])
		var ready := str(b.get("readyItem", ""))
		if ready != "":
			if InventorySystem.add_item(ready, 1):
				b["readyItem"] = ""
				b["daysLeft"] = 0
				AudioManager.play_sfx("harvest")
				EventBus.ui_toast.emit("Collected %s!" % GameData.get_item(ready)["name"], "success")
				return true
			return false
		if int(b.get("daysLeft", 0)) > 0:
			EventBus.ui_toast.emit("Processing... ready in %d day(s)." % int(b["daysLeft"]), "info")
			return true

		# Input matching recipes for machines
		var sel := InventorySystem.get_selected_item_id()
		var product := ""
		var need_coal := false
		if bid == "furnace":
			var smelt := {"copper_ore": "copper_bar", "iron_ore": "iron_bar", "gold_ore": "gold_bar", "iridium_ore": "iridium_bar"}
			if smelt.has(sel) and InventorySystem.count_item(sel) >= 5 and InventorySystem.has_item("coal", 1):
				InventorySystem.remove_item(sel, 5)
				InventorySystem.remove_item("coal", 1)
				product = smelt[sel]
				need_coal = true
		elif bid == "cheese_press" and sel in ["milk", "goat_milk"]:
			InventorySystem.remove_item(sel, 1)
			product = "goat_cheese" if sel == "goat_milk" else "cheese"
		elif bid == "mayo_machine" and sel in ["egg", "duck_egg", "quail_egg"]:
			InventorySystem.remove_item(sel, 1)
			product = "mayonnaise"
		elif bid == "loom" and sel in ["wool", "alpaca_wool"]:
			InventorySystem.remove_item(sel, 1)
			product = "cloth"
		elif bid == "oil_maker" and sel == "truffle":
			InventorySystem.remove_item(sel, 1)
			product = "truffle_oil"
		elif bid in ["preserve_jar", "keg"] and sel != "":
			var idef := GameData.get_item(sel)
			if str(idef.get("category", "")) == "Crops":
				InventorySystem.remove_item(sel, 1)
				product = "apple_cider" if bid == "keg" else "cherry_jam_toast"

		if product != "":
			b["readyItem"] = product
			b["daysLeft"] = 1
			AudioManager.play_sfx("ui_click")
			EventBus.ui_toast.emit("Started processing %s!" % GameData.get_item(product)["name"], "info")
			return true
		elif need_coal == false and bid in ["furnace", "cheese_press", "mayo_machine", "loom", "oil_maker", "preserve_jar", "keg"]:
			EventBus.ui_toast.emit("Select raw material in your hotbar to load this machine.", "info")
			return true
	return false


func get_sprinkler_coverage() -> Dictionary:
	var covered := {}
	for b in placed_buildings:
		var bid := str(b["buildingId"])
		var reg := str(b["region"])
		var cx := int(b["tile"][0])
		var cy := int(b["tile"][1])
		if bid == "sprinkler_basic":
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				covered["%s:%d,%d" % [reg, cx + off.x, cy + off.y]] = true
		elif bid == "sprinkler_quality":
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx != 0 or dy != 0:
						covered["%s:%d,%d" % [reg, cx + dx, cy + dy]] = true
		elif bid == "sprinkler_iridium":
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					if dx != 0 or dy != 0:
						covered["%s:%d,%d" % [reg, cx + dx, cy + dy]] = true
	return covered


func _on_day_ended(_year: int, _season: String, _day: int) -> void:
	for b in placed_buildings:
		if int(b.get("daysLeft", 0)) > 0:
			b["daysLeft"] = maxi(0, int(b["daysLeft"]) - 1)
		if str(b.get("buildingId", "")) == "bee_house" and str(b.get("readyItem", "")) == "" and TimeSystem.get_season() != "winter":
			b["readyItem"] = "honey"
			b["daysLeft"] = 0


func serialize() -> Dictionary:
	return {"nextUid": _next_uid, "placed": placed_buildings.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	_next_uid = maxi(1, int(data.get("nextUid", 1)))
	placed_buildings.clear()
	var arr: Variant = data.get("placed", [])
	if arr is Array:
		for b in arr:
			if b is Dictionary and GameData.buildings.has(str(b.get("buildingId", ""))):
				placed_buildings.append(b.duplicate(true))
