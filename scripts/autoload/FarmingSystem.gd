extends Node
## Grid-based Farming System: tilling, watering, fertilizing, planting, daily crop growth,
## quality computation, seasonal rules, greenhouse override, and sprinkler irrigation.

const FARMABLE_BOUNDS := {
	"greenfield_farm": Rect2i(14, 13, 22, 16),
	"greenhouse_interior": Rect2i(6, 6, 12, 8)
}

# key: "region_id:x,y" -> Dictionary tile state
var tiles: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	EventBus.day_ended.connect(_on_day_ended)


func reset_farm() -> void:
	tiles.clear()


func _tile_key(region_id: String, pos: Vector2i) -> String:
	return "%s:%d,%d" % [region_id, pos.x, pos.y]


func is_tillable(region_id: String, pos: Vector2i) -> bool:
	if not FARMABLE_BOUNDS.has(region_id):
		return false
	var rect: Rect2i = FARMABLE_BOUNDS[region_id]
	return rect.has_point(pos)


func get_tile(region_id: String, pos: Vector2i) -> Dictionary:
	return tiles.get(_tile_key(region_id, pos), {})


func get_region_tiles(region_id: String) -> Dictionary:
	var prefix := region_id + ":"
	var res := {}
	for k in tiles.keys():
		if str(k).begins_with(prefix):
			var parts := str(k).substr(prefix.length()).split(",")
			if parts.size() == 2:
				res[Vector2i(int(parts[0]), int(parts[1]))] = tiles[k]
	return res


func till_tile(region_id: String, pos: Vector2i, power: int = 1, facing: Vector2i = Vector2i.DOWN) -> bool:
	var did_any := false
	var targets := [pos]
	if power >= 2:
		targets.append(pos + facing)
		targets.append(pos + facing * 2)

	for tp in targets:
		if not is_tillable(region_id, tp):
			continue
		if BuildingSystem.is_tile_blocked(region_id, tp):
			continue
		var key := _tile_key(region_id, tp)
		if not tiles.has(key):
			tiles[key] = {
				"tilled": true,
				"watered": WeatherSystem.is_watering_weather() and region_id != "greenhouse_interior",
				"fertilizer": "",
				"cropId": "",
				"stage": 0,
				"daysGrowing": 0,
				"regrowthTimer": 0,
				"quality": 0,
				"withered": false,
				"lastUpdatedDay": TimeSystem.day
			}
			did_any = true
		elif not bool(tiles[key].get("tilled", false)):
			tiles[key]["tilled"] = true
			did_any = true
	if did_any:
		AudioManager.play_sfx("hoe")
		PlayerState.add_xp("farming", 3)
	return did_any


func water_tile(region_id: String, pos: Vector2i, power: int = 1, facing: Vector2i = Vector2i.DOWN) -> bool:
	var did_any := false
	var targets := [pos]
	if power >= 2:
		targets.append(pos + facing)
		targets.append(pos + facing * 2)

	for tp in targets:
		var key := _tile_key(region_id, tp)
		if tiles.has(key) and bool(tiles[key].get("tilled", false)):
			tiles[key]["watered"] = true
			tiles[key]["lastUpdatedDay"] = TimeSystem.day
			EventBus.crop_watered.emit(region_id, tp)
			did_any = true
	if did_any:
		AudioManager.play_sfx("water")
		PlayerState.add_xp("farming", 2)
	return did_any


func apply_fertilizer(region_id: String, pos: Vector2i, item_id: String) -> bool:
	var key := _tile_key(region_id, pos)
	if not tiles.has(key):
		return false
	var t: Dictionary = tiles[key]
	if not bool(t.get("tilled", false)) or str(t.get("fertilizer", "")) != "":
		return false
	var meta: Dictionary = GameData.get_item(item_id).get("metadata", {})
	var fert := str(meta.get("fertilizer", ""))
	if fert == "":
		return false
	if not InventorySystem.remove_item(item_id, 1):
		return false
	t["fertilizer"] = fert
	AudioManager.play_sfx("seed")
	return true


func plant_seed(region_id: String, pos: Vector2i, seed_item_id: String) -> bool:
	var item_def := GameData.get_item(seed_item_id)
	if item_def.is_empty() or str(item_def.get("category", "")) != "Seeds":
		return false
	var crop_id := str(item_def.get("metadata", {}).get("cropId", ""))
	var crop_def := GameData.get_crop(crop_id)
	if crop_def.is_empty():
		return false

	var key := _tile_key(region_id, pos)
	if not tiles.has(key) or not bool(tiles[key].get("tilled", false)):
		EventBus.ui_toast.emit("Till the soil with your Hoe before planting!", "info")
		return false
	var t: Dictionary = tiles[key]
	if str(t.get("cropId", "")) != "":
		return false

	# Season rule (Greenhouse ignores season restrictions!)
	var cur_season := TimeSystem.get_season()
	var valid_seasons: Array = crop_def.get("seasons", [])
	if region_id != "greenhouse_interior" and cur_season not in valid_seasons:
		EventBus.ui_toast.emit("%s only grows in %s!" % [crop_def["name"], ", ".join(valid_seasons)], "warning")
		return false

	if not InventorySystem.remove_item(seed_item_id, 1):
		return false

	t["cropId"] = crop_id
	t["stage"] = 0
	t["daysGrowing"] = 0
	t["regrowthTimer"] = 0
	t["withered"] = false
	t["quality"] = 0
	t["lastUpdatedDay"] = TimeSystem.day
	AudioManager.play_sfx("seed")
	PlayerState.add_xp("farming", 4)
	EventBus.crop_planted.emit(region_id, pos, crop_id)
	return true


func is_harvest_ready(tile_data: Dictionary) -> bool:
	if tile_data.is_empty() or bool(tile_data.get("withered", false)):
		return false
	var cid := str(tile_data.get("cropId", ""))
	if cid == "":
		return false
	var crop := GameData.get_crop(cid)
	if crop.is_empty():
		return false
	return int(tile_data.get("stage", 0)) >= int(crop.get("growthStages", 5)) - 1 and int(tile_data.get("regrowthTimer", 0)) <= 0


func harvest_tile(region_id: String, pos: Vector2i) -> bool:
	var key := _tile_key(region_id, pos)
	if not tiles.has(key):
		return false
	var t: Dictionary = tiles[key]
	if not is_harvest_ready(t):
		return false
	var cid := str(t["cropId"])
	var crop := GameData.get_crop(cid)
	var harvest_item := str(crop.get("harvestItemId", cid))
	var quality := _compute_harvest_quality(str(t.get("fertilizer", "")))

	if not InventorySystem.can_fit(harvest_item, 1, quality):
		EventBus.ui_toast.emit("Inventory full! Make space before harvesting.", "warning")
		return false

	InventorySystem.add_item(harvest_item, 1, quality)
	AudioManager.play_sfx("harvest")
	PlayerState.add_xp("farming", 12)
	EventBus.crop_harvested.emit(cid, 1, quality)

	var regrowth := int(crop.get("regrowthDays", 0))
	if regrowth > 0:
		t["stage"] = 3
		t["regrowthTimer"] = regrowth
	else:
		t["cropId"] = ""
		t["stage"] = 0
		t["daysGrowing"] = 0
		t["regrowthTimer"] = 0
		t["fertilizer"] = ""
	t["lastUpdatedDay"] = TimeSystem.day
	return true


func clear_tile(region_id: String, pos: Vector2i) -> bool:
	var key := _tile_key(region_id, pos)
	if not tiles.has(key):
		return false
	var t: Dictionary = tiles[key]
	if bool(t.get("withered", false)):
		t["cropId"] = ""
		t["withered"] = false
		t["stage"] = 0
		t["daysGrowing"] = 0
		AudioManager.play_sfx("scythe")
		return true
	return false


func _compute_harvest_quality(fert: String) -> int:
	var farm_lv := PlayerState.get_skill_level("farming")
	var score := float(farm_lv) * 0.04
	if fert == "basic":
		score += 0.14
	elif fert == "quality":
		score += 0.30
	if PlayerState.active_buffs.has("farming") or PlayerState.active_buffs.has("luck"):
		score += 0.12

	var roll := _rng.randf()
	if roll < score * 0.25:
		return 3 # Iridium
	if roll < score * 0.65:
		return 2 # Gold
	if roll < score * 1.15:
		return 1 # Silver
	return 0 # Normal


func _on_day_ended(_year: int, _season: String, _day: int) -> void:
	# Predict next calendar day's season so we accurately check crop seasons after midnight
	var next_day := TimeSystem.day + 1
	var next_season_idx := TimeSystem.season_index
	if next_day > TimeSystem.DAYS_PER_SEASON:
		next_season_idx = (next_season_idx + 1) % TimeSystem.SEASONS.size()
	var next_season: String = TimeSystem.SEASONS[next_season_idx]
	var rain_water := WeatherSystem.is_watering_weather()

	# Gather sprinkler watered positions
	var sprinkler_watered := BuildingSystem.get_sprinkler_coverage()

	for key in tiles.keys():
		var t: Dictionary = tiles[key]
		if not bool(t.get("tilled", false)):
			continue
		var parts := str(key).split(":")
		var reg := parts[0]
		var coord_str := parts[1]

		var cid := str(t.get("cropId", ""))
		var was_watered := bool(t.get("watered", false)) or (rain_water and reg != "greenhouse_interior")
		if cid != "" and not bool(t.get("withered", false)):
			var crop := GameData.get_crop(cid)
			var valid_seasons: Array = crop.get("seasons", [])
			if reg != "greenhouse_interior" and next_season not in valid_seasons:
				t["withered"] = true
			elif was_watered or not bool(crop.get("waterRequired", true)):
				if int(t.get("regrowthTimer", 0)) > 0:
					t["regrowthTimer"] = maxi(0, int(t["regrowthTimer"]) - 1)
					if int(t["regrowthTimer"]) == 0:
						t["stage"] = int(crop.get("growthStages", 5)) - 1
				else:
					var growth_step := 2 if str(t.get("fertilizer", "")) == "speed" else 1
					t["daysGrowing"] = int(t.get("daysGrowing", 0)) + growth_step
					var total := maxi(1, int(crop.get("totalDays", 4)))
					var max_stage := int(crop.get("growthStages", 5)) - 1
					var ratio := clampf(float(t["daysGrowing"]) / float(total), 0.0, 1.0)
					t["stage"] = int(floor(ratio * float(max_stage)))
			t["lastUpdatedDay"] = TimeSystem.day

		# Reset daily watered flag, then immediately apply sprinklers for the new morning
		var is_sprinkled := sprinkler_watered.has(key)
		t["watered"] = is_sprinkled


func serialize() -> Dictionary:
	return {"tiles": tiles.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	tiles.clear()
	var t_raw: Variant = data.get("tiles", {})
	if t_raw is Dictionary:
		for k in t_raw.keys():
			if t_raw[k] is Dictionary:
				tiles[str(k)] = t_raw[k].duplicate(true)
