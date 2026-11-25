extends Node
## Manages 32 NPCs: daily schedules, weather overrides, friendship caps, gifting, and branching dialogue.

const MAX_FRIENDSHIP := 1000
const MAX_WEEKLY_GIFTS := 2

var states: Dictionary = {} # npc_id -> Dictionary
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset_npcs()
	EventBus.day_started.connect(_on_day_started)


func reset_npcs() -> void:
	states.clear()
	for npc in GameData.npcs_list:
		var nid := str(npc["id"])
		states[nid] = {
			"friendship": 50,
			"talkedToday": false,
			"giftedToday": false,
			"giftsThisWeek": 0,
			"choiceToday": false
		}


func _on_day_started(_year: int, _season: String, day: int) -> void:
	var is_monday := ((day - 1) % 7) == 0
	for nid in states.keys():
		states[nid]["talkedToday"] = false
		states[nid]["giftedToday"] = false
		states[nid]["choiceToday"] = false
		if is_monday:
			states[nid]["giftsThisWeek"] = 0


func get_npc_location(npc_id: String, hour: int = -1, weather: String = "") -> Dictionary:
	var npc: Dictionary = GameData.npcs.get(npc_id, {})
	if npc.is_empty():
		return {}
	var h := hour if hour >= 0 else TimeSystem.hour
	var w := weather if weather != "" else WeatherSystem.current_weather
	if w in ["rainy", "stormy"] and npc.has("rainySchedule"):
		var rs: Dictionary = npc["rainySchedule"]
		return {"region": str(rs["region"]), "tile": Vector2i(rs["tile"][0], rs["tile"][1]), "activity": str(rs["activity"])}

	var chosen: Dictionary = {}
	for wp in npc.get("schedule", []):
		if int(wp.get("hour", 6)) <= h:
			chosen = wp
	if chosen.is_empty() and npc.get("schedule", []).size() > 0:
		chosen = npc["schedule"][0]
	var t_arr: Array = chosen.get("tile", [20, 18])
	return {"region": str(chosen.get("region", npc["homeLocation"])), "tile": Vector2i(t_arr[0], t_arr[1]), "activity": str(chosen.get("activity", "idle"))}


func get_npcs_in_region(region_id: String) -> Array:
	var out := []
	for npc in GameData.npcs_list:
		var nid := str(npc["id"])
		var loc := get_npc_location(nid)
		if str(loc.get("region", "")) == region_id:
			out.append({"npc": npc, "loc": loc, "state": states.get(nid, {})})
	return out


func talk_to_npc(npc_id: String) -> Dictionary:
	var npc: Dictionary = GameData.npcs.get(npc_id, {})
	if npc.is_empty():
		return {}
	var st: Dictionary = states[npc_id]
	var first_today := not bool(st.get("talkedToday", false))
	if first_today:
		st["talkedToday"] = true
		_add_friendship(npc_id, 20)
	EventBus.npc_talked.emit(npc_id, first_today)

	var text := _pick_dialogue(npc, st)
	var exp_idx := 1 if int(st["friendship"]) >= 300 else 0
	return {
		"npc": npc,
		"text": text,
		"expression": exp_idx,
		"friendship": int(st["friendship"]),
		"hearts": get_hearts(npc_id),
		"choices": npc.get("dialogues", {}).get("choices", []),
		"canChoice": not bool(st.get("choiceToday", false))
	}


func answer_dialogue_choice(npc_id: String, choice_idx: int) -> Dictionary:
	var npc: Dictionary = GameData.npcs.get(npc_id, {})
	if npc.is_empty():
		return {}
	var choices: Array = npc.get("dialogues", {}).get("choices", [])
	if choice_idx < 0 or choice_idx >= choices.size():
		return {}
	var ch: Dictionary = choices[choice_idx]
	var st: Dictionary = states[npc_id]
	if not bool(st.get("choiceToday", false)):
		st["choiceToday"] = true
		_add_friendship(npc_id, int(ch.get("friendshipDelta", 10)))
	return {"reply": str(ch.get("reply", "")), "expression": 1, "hearts": get_hearts(npc_id)}


func give_gift(npc_id: String, item_id: String) -> Dictionary:
	var npc: Dictionary = GameData.npcs.get(npc_id, {})
	if npc.is_empty():
		return {"ok": false, "message": "NPC not found."}
	var st: Dictionary = states[npc_id]
	if bool(st.get("giftedToday", false)):
		return {"ok": false, "message": "You already gave %s a gift today." % npc["name"]}
	if int(st.get("giftsThisWeek", 0)) >= MAX_WEEKLY_GIFTS:
		return {"ok": false, "message": "%s has received 2 gifts already this week!" % npc["name"]}
	var item := GameData.get_item(item_id)
	if item.is_empty():
		return {"ok": false, "message": "Invalid item."}
	if str(item.get("category", "")) == "Tools":
		return {"ok": false, "message": "You shouldn't give away your tools!"}
	if not InventorySystem.remove_item(item_id, 1):
		return {"ok": false, "message": "Item missing from bag."}

	st["giftedToday"] = true
	st["giftsThisWeek"] = int(st.get("giftsThisWeek", 0)) + 1

	var delta := 20
	var reaction := "Oh, thank you! That's very thoughtful."
	var exp := 0
	if item_id == "special_friendship_bouquet":
		delta = 100
		reaction = "A Valley Bouquet! You've completely made my whole week!"
		exp = 1
	elif item_id in npc.get("favoriteGifts", []):
		delta = 80
		reaction = "Whoa, %s! This is my absolute favorite! Thank you!" % item["name"]
		exp = 1
	elif item_id in npc.get("likedGifts", []):
		delta = 45
		reaction = "I really like %s—thanks so much!" % item["name"]
		exp = 1
	elif item_id in npc.get("dislikedGifts", []):
		delta = -20
		reaction = "Oh... uh, thanks, though %s isn't really my thing." % item["name"]
		exp = 2

	_add_friendship(npc_id, delta)
	EventBus.gift_given.emit(npc_id, item_id, delta)
	return {"ok": true, "message": reaction, "delta": delta, "expression": exp, "hearts": get_hearts(npc_id)}


func _add_friendship(npc_id: String, delta: int) -> void:
	if not states.has(npc_id):
		return
	var cur := int(states[npc_id].get("friendship", 0))
	var nxt := clampi(cur + delta, 0, MAX_FRIENDSHIP)
	states[npc_id]["friendship"] = nxt
	EventBus.relationship_changed.emit(npc_id, nxt)


func get_hearts(npc_id: String) -> int:
	return int(states.get(npc_id, {}).get("friendship", 0)) / 100


func _pick_dialogue(npc: Dictionary, st: Dictionary) -> String:
	var dlg: Dictionary = npc.get("dialogues", {})
	var fest := QuestSystem.get_today_festival()
	if not fest.is_empty():
		return "Happy %s! Isn't the valley lively today?" % fest["name"]

	var w := WeatherSystem.current_weather
	if w in ["rainy", "stormy", "snowy"] and dlg.has(w):
		var warr: Array = dlg[w]
		if not warr.is_empty():
			return str(warr[0])

	var s := TimeSystem.get_season()
	var pool: Array = []
	if dlg.has(s):
		pool.append_array(dlg[s])
	pool.append_array(dlg.get("daily", []))
	var fr := int(st.get("friendship", 50))
	var f_map: Dictionary = dlg.get("friendship", {})
	if fr >= 600 and f_map.has("high"):
		pool.append(str(f_map["high"]))
	elif fr >= 250 and f_map.has("mid"):
		pool.append(str(f_map["mid"]))
	elif f_map.has("low"):
		pool.append(str(f_map["low"]))
	if pool.is_empty():
		return "Hello there, neighbor!"
	return str(pool[_rng.randi() % pool.size()])


func serialize() -> Dictionary:
	return {"states": states.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	reset_npcs()
	var raw: Variant = data.get("states", {})
	if raw is Dictionary:
		for nid in raw.keys():
			if states.has(nid) and raw[nid] is Dictionary:
				for k in ["friendship", "talkedToday", "giftedToday", "giftsThisWeek", "choiceToday"]:
					if raw[nid].has(k):
						states[nid][k] = raw[nid][k]
				states[nid]["friendship"] = clampi(int(states[nid]["friendship"]), 0, MAX_FRIENDSHIP)
