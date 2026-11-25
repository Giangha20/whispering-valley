extends Node
## Event-Driven Quest (156), Achievement (64), Collection, and Annual Festival (12) System.

# quest_id -> {"status": "locked"|"active"|"completed"|"claimed", "progress": int}
var quest_states: Dictionary = {}
var unlocked_achievements: Dictionary = {}
var collections: Dictionary = {
	"crops": {},
	"fish": {},
	"minerals": {},
	"cooking": {},
	"crafting": {}
}
var metrics: Dictionary = {
	"crop_harvested": 0,
	"fish_caught": 0,
	"mine_floor_reached": 1,
	"monster_defeated": 0,
	"item_crafted": 0,
	"dish_cooked": 0,
	"gold_earned": 0,
	"region_discovered": 2,
	"item_sold": 0,
	"animal_product_collected": 0,
	"building_placed": 0,
	"npc_talked_unique": {}
}
var festivals_attended: Dictionary = {}


func _ready() -> void:
	reset_progression()
	_connect_events()


func _connect_events() -> void:
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.fish_caught.connect(_on_fish_caught)
	EventBus.mine_floor_reached.connect(_on_mine_floor_reached)
	EventBus.monster_defeated.connect(_on_monster_defeated)
	EventBus.item_crafted.connect(_on_item_crafted)
	EventBus.dish_cooked.connect(_on_dish_cooked)
	EventBus.gold_earned.connect(_on_gold_earned)
	EventBus.region_discovered.connect(_on_region_discovered)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.npc_talked.connect(_on_npc_talked)
	EventBus.gift_given.connect(_on_gift_given)
	EventBus.animal_product_collected.connect(_on_animal_product)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.day_started.connect(_on_day_started)


func reset_progression() -> void:
	quest_states.clear()
	for q in GameData.quests_list:
		var qid := str(q["id"])
		var unlock := str(q.get("unlockCondition", ""))
		quest_states[qid] = {
			"status": "active" if unlock == "" else "locked",
			"progress": 0
		}
	unlocked_achievements.clear()
	collections = {"crops": {}, "fish": {}, "minerals": {}, "cooking": {}, "crafting": {}}
	metrics = {
		"crop_harvested": 0,
		"fish_caught": 0,
		"mine_floor_reached": 1,
		"monster_defeated": 0,
		"item_crafted": 0,
		"dish_cooked": 0,
		"gold_earned": 0,
		"region_discovered": 2,
		"item_sold": 0,
		"animal_product_collected": 0,
		"building_placed": 0,
		"npc_talked_unique": {}
	}
	festivals_attended.clear()


func check_condition(cond: String) -> bool:
	if cond == "":
		return true
	if cond == "reach_mine_floor_10":
		return MiningSystem.max_floor_reached >= 10
	if cond == "reach_mine_floor_25":
		return MiningSystem.max_floor_reached >= 25
	if quest_states.has(cond):
		return str(quest_states[cond]["status"]) in ["completed", "claimed"]
	return false


func _advance_quests(obj_type: String, target: String, amount: int, absolute: bool = false) -> void:
	for q in GameData.quests_list:
		var qid := str(q["id"])
		var st: Dictionary = quest_states.get(qid, {})
		if str(st.get("status", "locked")) != "active":
			continue
		var objs: Array = q.get("objectives", [])
		if objs.is_empty():
			continue
		var obj: Dictionary = objs[0]
		if str(obj.get("type", "")) != obj_type:
			continue
		var otarget := str(obj.get("target", "any"))
		if otarget != "any" and otarget != target:
			continue

		var req := int(obj.get("required", 1))
		var cur := int(st["progress"])
		var nxt := maxi(cur, amount) if absolute else (cur + amount)
		st["progress"] = mini(req, nxt)
		EventBus.quest_updated.emit(qid, st["progress"], req)
		if int(st["progress"]) >= req:
			_complete_quest(q, st)


func _complete_quest(q: Dictionary, st: Dictionary) -> void:
	var qid := str(q["id"])
	st["status"] = "completed"
	var rew: Dictionary = q.get("rewards", {})
	var rgold := int(rew.get("gold", 0))
	if rgold > 0:
		PlayerState.add_gold(rgold)
	for ri in rew.get("items", []):
		InventorySystem.add_item(str(ri["itemId"]), int(ri["count"]))
	PlayerState.add_xp("farming", int(rew.get("xp", 25)) / 2)
	st["status"] = "claimed"

	# Unlock chained quests
	for other in GameData.quests_list:
		var oid := str(other["id"])
		if str(other.get("unlockCondition", "")) == qid and quest_states.has(oid):
			if quest_states[oid]["status"] == "locked":
				quest_states[oid]["status"] = "active"

	AudioManager.play_sfx("level_up")
	EventBus.quest_completed.emit(qid)
	EventBus.ui_toast.emit("Quest Completed: %s (+%dG)!" % [q["title"], rgold], "success")


func _check_achievements(metric: String, value: int) -> void:
	for ach in GameData.achievements_list:
		var aid := str(ach["id"])
		if unlocked_achievements.has(aid):
			continue
		if str(ach.get("metric", "")) == metric and value >= int(ach.get("threshold", 1)):
			unlocked_achievements[aid] = true
			var rg := int(ach.get("rewardGold", 100))
			PlayerState.add_gold(rg)
			EventBus.achievement_unlocked.emit(aid)
			EventBus.ui_toast.emit("Achievement Unlocked: %s (+%dG)!" % [ach["name"], rg], "success")


func _on_crop_harvested(crop_id: String, qty: int, _q: int) -> void:
	collections["crops"][crop_id] = true
	metrics["crop_harvested"] = int(metrics["crop_harvested"]) + qty
	_advance_quests("crop_harvested", crop_id, qty)
	_check_achievements("crop_harvested", int(metrics["crop_harvested"]))


func _on_fish_caught(fish_id: String, _perfect: bool) -> void:
	collections["fish"][fish_id] = true
	metrics["fish_caught"] = int(metrics["fish_caught"]) + 1
	_advance_quests("fish_caught", fish_id, 1)
	_check_achievements("fish_caught", int(metrics["fish_caught"]))


func _on_mine_floor_reached(floor_num: int) -> void:
	metrics["mine_floor_reached"] = maxi(int(metrics["mine_floor_reached"]), floor_num)
	_advance_quests("mine_floor_reached", "any", floor_num, true)
	_check_achievements("mine_floor_reached", int(metrics["mine_floor_reached"]))


func _on_monster_defeated(monster_id: String, _is_boss: bool) -> void:
	metrics["monster_defeated"] = int(metrics["monster_defeated"]) + 1
	_advance_quests("monster_defeated", monster_id, 1)
	_check_achievements("monster_defeated", int(metrics["monster_defeated"]))


func _on_item_crafted(_recipe_id: String, item_id: String, count: int) -> void:
	collections["crafting"][item_id] = true
	metrics["item_crafted"] = int(metrics["item_crafted"]) + count
	_advance_quests("item_crafted", item_id, count)
	_check_achievements("item_crafted", int(metrics["item_crafted"]))


func _on_dish_cooked(dish_id: String, _item_id: String) -> void:
	collections["cooking"][dish_id] = true
	metrics["dish_cooked"] = int(metrics["dish_cooked"]) + 1
	_advance_quests("dish_cooked", dish_id, 1)
	_check_achievements("dish_cooked", int(metrics["dish_cooked"]))


func _on_gold_earned(total_earned: int) -> void:
	metrics["gold_earned"] = total_earned
	_check_achievements("gold_earned", total_earned)


func _on_region_discovered(region_id: String) -> void:
	metrics["region_discovered"] = WorldSystem.discovered_regions.size()
	_advance_quests("region_discovered", region_id, 1, true)
	_check_achievements("region_discovered", int(metrics["region_discovered"]))


func _on_item_sold(item_id: String, qty: int, _earned: int) -> void:
	var def := GameData.get_item(item_id)
	if str(def.get("category", "")) == "Minerals":
		collections["minerals"][item_id] = true
	metrics["item_sold"] = int(metrics["item_sold"]) + qty
	_advance_quests("item_sold", item_id, qty)


func _on_npc_talked(npc_id: String, _first_today: bool) -> void:
	var uniq: Dictionary = metrics["npc_talked_unique"]
	if not uniq.has(npc_id):
		uniq[npc_id] = true
		_advance_quests("npc_talked", "unique", uniq.size(), true)
	_advance_quests("npc_talked", npc_id, 1)


func _on_gift_given(npc_id: String, _item_id: String, _delta: int) -> void:
	_advance_quests("gift_given", npc_id, 1)


func _on_animal_product(species_id: String, _item_id: String, _q: int) -> void:
	metrics["animal_product_collected"] = int(metrics["animal_product_collected"]) + 1
	_advance_quests("animal_product_collected", species_id, 1)


func _on_building_placed(building_id: String, _region_id: String, _tile: Vector2i) -> void:
	metrics["building_placed"] = int(metrics["building_placed"]) + 1
	_advance_quests("building_placed", building_id, 1)


func _on_day_started(_year: int, season: String, day: int) -> void:
	var fest := get_today_festival(season, day)
	if not fest.is_empty():
		EventBus.festival_triggered.emit(str(fest["id"]))
		EventBus.ui_toast.emit("Festival Today: %s at %s!" % [fest["name"], GameData.regions[fest["region"]]["name"]], "success")


func get_today_festival(season: String = "", day: int = -1) -> Dictionary:
	var s := season if season != "" else TimeSystem.get_season()
	var d := day if day >= 0 else TimeSystem.day
	for f in GameData.festivals_list:
		if str(f.get("season", "")) == s and int(f.get("day", -1)) == d:
			return f
	return {}


func participate_in_festival(fest_id: String) -> Dictionary:
	var fest: Dictionary = GameData.festivals.get(fest_id, {})
	if fest.is_empty():
		return {"ok": false, "message": "Festival not found."}
	var key := "%d:%s" % [TimeSystem.year, fest_id]
	if festivals_attended.has(key):
		return {"ok": false, "message": "You already collected this year's %s prize!" % fest["name"]}
	festivals_attended[key] = true
	var rg := int(fest.get("rewardGold", 250))
	var ritem := str(fest.get("rewardItem", "special_golden_seed_pack"))
	PlayerState.add_gold(rg)
	InventorySystem.add_item(ritem, 1)
	AudioManager.play_sfx("level_up")
	return {"ok": true, "message": "Celebrated %s! Won %dG & %s!" % [fest["name"], rg, GameData.get_item(ritem)["name"]]}


func get_active_quests() -> Array:
	var res := []
	for q in GameData.quests_list:
		var qid := str(q["id"])
		var st: Dictionary = quest_states.get(qid, {})
		if str(st.get("status", "locked")) == "active":
			res.append({"quest": q, "state": st})
	return res


func serialize() -> Dictionary:
	return {
		"questStates": quest_states.duplicate(true),
		"achievements": unlocked_achievements.duplicate(true),
		"collections": collections.duplicate(true),
		"metrics": metrics.duplicate(true),
		"festivalsAttended": festivals_attended.duplicate(true)
	}


func deserialize(data: Dictionary) -> void:
	reset_progression()
	var qs: Variant = data.get("questStates", {})
	if qs is Dictionary:
		for qid in qs.keys():
			if quest_states.has(qid) and qs[qid] is Dictionary:
				quest_states[qid]["status"] = str(qs[qid].get("status", quest_states[qid]["status"]))
				quest_states[qid]["progress"] = maxi(0, int(qs[qid].get("progress", 0)))
	var ua: Variant = data.get("achievements", {})
	if ua is Dictionary:
		for aid in ua.keys():
			if GameData.achievements.has(aid):
				unlocked_achievements[aid] = true
	var cols: Variant = data.get("collections", {})
	if cols is Dictionary:
		for ckey in collections.keys():
			if cols.has(ckey) and cols[ckey] is Dictionary:
				collections[ckey] = cols[ckey].duplicate(true)
	var mt: Variant = data.get("metrics", {})
	if mt is Dictionary:
		for mk in metrics.keys():
			if mt.has(mk):
				metrics[mk] = mt[mk]
	var fa: Variant = data.get("festivalsAttended", {})
	if fa is Dictionary:
		festivals_attended = fa.duplicate(true)
