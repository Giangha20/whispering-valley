extends Node
## Biome/Season/Weather/Time-aware Fishing System across 84 fish species.

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func get_available_fish(biome: String, season: String = "", hour: int = -1, weather: String = "") -> Array:
	var s := season if season != "" else TimeSystem.get_season()
	var h := hour if hour >= 0 else TimeSystem.hour
	var w := weather if weather != "" else WeatherSystem.current_weather
	var matches: Array = []

	for f in GameData.fish_list:
		if str(f.get("biome", "")) != biome:
			continue
		var seasons: Array = f.get("seasons", [])
		if s not in seasons:
			continue
		var tr: Array = f.get("timeRange", [6, 26])
		if h < int(tr[0]) or h > int(tr[1]):
			continue
		var fw := str(f.get("weather", "any"))
		if fw != "any" and fw != w:
			continue
		matches.append(f)

	# Fallback to any fish in biome if strict filter matches none
	if matches.is_empty():
		for f in GameData.fish_list:
			if str(f.get("biome", "")) == biome:
				matches.append(f)
	return matches


func roll_fish_for_biome(biome: String) -> Dictionary:
	var pool := get_available_fish(biome)
	if pool.is_empty():
		pool = GameData.fish_list
	var fish_lv := PlayerState.get_skill_level("fishing")
	var has_iridium_rod := InventorySystem.has_item("tool_fishing_iridium", 1)
	var bait_bonus := 0
	if InventorySystem.has_item("quality_bait", 1):
		bait_bonus = 2
	elif InventorySystem.has_item("bait", 1):
		bait_bonus = 1

	var weights: Array = []
	var total_w := 0.0
	for f in pool:
		var rar := str(f.get("rarity", "common"))
		var w := 50.0
		match rar:
			"common": w = 55.0
			"uncommon": w = 28.0 + fish_lv * 1.5
			"rare": w = 12.0 + fish_lv * 2.0 + bait_bonus * 4.0
			"epic": w = 4.0 + fish_lv * 1.2 + (6.0 if has_iridium_rod else 0.0)
			"legendary": w = 1.2 + fish_lv * 0.6 + (3.0 if has_iridium_rod else 0.0)
		weights.append(w)
		total_w += w

	var r := _rng.randf() * total_w
	var acc := 0.0
	for i in range(pool.size()):
		acc += float(weights[i])
		if r <= acc:
			return pool[i]
	return pool[0]


func consume_bait_if_available() -> int:
	if InventorySystem.remove_item("quality_bait", 1):
		return 2
	if InventorySystem.remove_item("bait", 1):
		return 1
	return 0


func complete_catch(fish_id: String, perfect: bool = false) -> bool:
	var f: Dictionary = GameData.fish.get(fish_id, {})
	if f.is_empty():
		return false
	var quality := 0
	var flv := PlayerState.get_skill_level("fishing")
	if perfect and flv >= 4:
		quality = 3
	elif perfect:
		quality = 2
	elif flv >= 3 and _rng.randf() < 0.35:
		quality = 1

	if not InventorySystem.add_item(fish_id, 1, quality):
		return false

	var diff := int(f.get("difficulty", 30))
	PlayerState.add_xp("fishing", 15 + diff / 4 + (10 if perfect else 0))
	AudioManager.play_sfx("fish_catch")
	EventBus.fish_caught.emit(fish_id, perfect)
	EventBus.ui_toast.emit("Caught %s%s!" % [f["name"], " (Perfect!)" if perfect else ""], "success")
	return true
