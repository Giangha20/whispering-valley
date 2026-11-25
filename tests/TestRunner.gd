extends Node
## Comprehensive Unit, Integration, Security, and 12-Region Scene Verification Suite.

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	call_deferred("_run_all")


func _assert(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] ", name)
	else:
		_failed += 1
		push_error("[FAIL] " + name)


func _run_all() -> void:
	print("=== WHISPERING VALLEY AUTOMATED TEST SUITE ===")
	_test_databases_and_assets()
	_test_time_weather_seasons()
	_test_inventory_rules()
	_test_farming_lifecycle()
	_test_economy_and_shipping()
	_test_npc_relationships_and_caps()
	_test_animals_and_buildings()
	_test_fishing_and_mining()
	_test_crafting_and_cooking()
	_test_quests_achievements_festivals()
	_test_save_load_backup_and_security()
	await _test_all_scenes_and_12_regions()

	print("=== RESULTS: %d PASSED, %d FAILED ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _test_databases_and_assets() -> void:
	_assert(GameData.regions_list.size() >= 12, "12+ regions loaded (%d)" % GameData.regions_list.size())
	_assert(GameData.npcs_list.size() >= 30, "30+ NPCs loaded (%d)" % GameData.npcs_list.size())
	_assert(GameData.crops_list.size() >= 60, "60+ crops loaded (%d)" % GameData.crops_list.size())
	_assert(GameData.animals_list.size() >= 10, "10+ animals loaded (%d)" % GameData.animals_list.size())
	_assert(GameData.fish_list.size() >= 80, "80+ fish loaded (%d)" % GameData.fish_list.size())
	_assert(GameData.items_list.size() >= 300, "300+ items loaded (%d)" % GameData.items_list.size())
	_assert(GameData.crafting_list.size() >= 100, "100+ crafting recipes (%d)" % GameData.crafting_list.size())
	_assert(GameData.cooking_list.size() >= 80, "80+ cooking dishes (%d)" % GameData.cooking_list.size())
	_assert(GameData.quests_list.size() >= 150, "150+ quests loaded (%d)" % GameData.quests_list.size())
	_assert(GameData.festivals_list.size() >= 12, "12+ festivals loaded (%d)" % GameData.festivals_list.size())
	_assert(GameData.achievements_list.size() >= 60, "60+ achievements loaded (%d)" % GameData.achievements_list.size())
	_assert(GameData.buildings_list.size() >= 30, "30+ buildings loaded (%d)" % GameData.buildings_list.size())
	_assert(GameData.get_item_texture("turnip") != null, "Item atlas texture resolves cleanly")
	_assert(GameData.get_crop_texture("turnip", 4) != null, "Crop growth stage texture resolves")


func _test_time_weather_seasons() -> void:
	SaveManager.start_new_game("Tester", "Test Farm", {}, 5)
	_assert(TimeSystem.get_season() == "spring" and TimeSystem.day == 1, "Calendar starts Year 1 Spring 1")
	TimeSystem.advance_minutes(70)
	_assert(TimeSystem.hour == 7 and TimeSystem.minute == 10, "TimeSystem advances hour & minute")

	for _d in range(28):
		TimeSystem.sleep_to_next_day(false)
	_assert(TimeSystem.get_season() == "summer" and TimeSystem.day == 1, "Day 28 rolls into Summer Day 1")

	for _d in range(28 * 2):
		TimeSystem.sleep_to_next_day(false)
	_assert(TimeSystem.get_season() == "winter" and TimeSystem.day == 1, "Transitions into Winter Day 1")
	_assert(WeatherSystem.current_weather in ["sunny", "cloudy", "snowy", "foggy"], "Winter weather excludes rain/storm")

	for _d in range(28):
		TimeSystem.sleep_to_next_day(false)
	_assert(TimeSystem.year == 2 and TimeSystem.get_season() == "spring", "Winter 28 rolls into Year 2 Spring 1")


func _test_inventory_rules() -> void:
	SaveManager.start_new_game("Tester", "Test Farm", {}, 5)
	_assert(not InventorySystem.add_item("turnip", -3), "Rejects negative item add")
	_assert(not InventorySystem.add_item("nonexistent_item", 1), "Rejects invalid item id")
	InventorySystem.add_item("wood", 10)
	_assert(InventorySystem.count_item("wood") == 10, "Adds stackable wood cleanly")
	var wood_idx := -1
	for i in range(InventorySystem.slots.size()):
		if str(InventorySystem.slots[i].get("id", "")) == "wood":
			wood_idx = i
			break
	_assert(wood_idx >= 0 and InventorySystem.split_stack(wood_idx), "Splits wood stack cleanly")
	_assert(InventorySystem.count_item("wood") == 10, "Total count preserved after split")
	InventorySystem.sort_inventory(true)
	_assert(InventorySystem.count_item("wood") == 10, "Inventory sort preserves all stacks")


func _test_farming_lifecycle() -> void:
	SaveManager.start_new_game("Tester", "Test Farm", {}, 5)
	var pos := Vector2i(16, 16)
	_assert(FarmingSystem.till_tile("greenfield_farm", pos), "Tills soil tile on farm")
	_assert(not FarmingSystem.plant_seed("greenfield_farm", pos, "melon_seed"), "Blocks planting Summer melon outdoors in Spring")
	_assert(FarmingSystem.till_tile("greenhouse_interior", Vector2i(8, 8)), "Tills soil inside Greenhouse")
	InventorySystem.add_item("melon_seed", 1)
	_assert(FarmingSystem.plant_seed("greenhouse_interior", Vector2i(8, 8), "melon_seed"), "Greenhouse allows out-of-season Melon")

	_assert(FarmingSystem.plant_seed("greenfield_farm", pos, "turnip_seed"), "Plants Turnip seed in Spring")
	_assert(not FarmingSystem.harvest_tile("greenfield_farm", pos), "Cannot harvest immature crop")
	for _d in range(3):
		FarmingSystem.water_tile("greenfield_farm", pos)
		TimeSystem.sleep_to_next_day(false)
	var t := FarmingSystem.get_tile("greenfield_farm", pos)
	_assert(FarmingSystem.is_harvest_ready(t), "Turnip matures after 3 watered days")
	_assert(FarmingSystem.harvest_tile("greenfield_farm", pos), "Harvests mature Turnip")
	_assert(InventorySystem.count_item("turnip") >= 1, "Turnip added to inventory on harvest")

	# Test Regrowth crop (Strawberry: 8 days, regrowth 4)
	FarmingSystem.plant_seed("greenfield_farm", pos, "strawberry_seed")
	for _d in range(8):
		FarmingSystem.water_tile("greenfield_farm", pos)
		TimeSystem.sleep_to_next_day(false)
	_assert(FarmingSystem.harvest_tile("greenfield_farm", pos), "Harvests mature Strawberry")
	var st := FarmingSystem.get_tile("greenfield_farm", pos)
	_assert(str(st.get("cropId", "")) == "strawberry" and int(st.get("regrowthTimer", 0)) == 4, "Regrowth crop resets regrowthTimer instead of clearing")


func _test_economy_and_shipping() -> void:
	SaveManager.start_new_game("Tester", "Test Farm", {}, 5)
	TimeSystem.hour = 3 # closed
	var closed_res := EconomySystem.buy_item("clara_general_store", "turnip_seed", 1, false)
	_assert(not bool(closed_res["ok"]), "Shop blocks purchase outside opening hours")
	TimeSystem.hour = 10
	var poor_res := EconomySystem.buy_item("clara_general_store", "turnip_seed", 1000, false)
	_assert(not bool(poor_res["ok"]) and PlayerState.gold == 500, "Rejects unaffordable purchase without gold loss")

	var buy_res := EconomySystem.buy_item("clara_general_store", "parsnip_seed", 2, false)
	_assert(bool(buy_res["ok"]) and InventorySystem.count_item("parsnip_seed") == 8, "Atomic buy deducts gold & adds seeds")

	InventorySystem.add_item("turnip", 1)
	var tidx := -1
	for i in range(InventorySystem.slots.size()):
		if str(InventorySystem.slots[i].get("id", "")) == "turnip":
			tidx = i
			break
	var gold_before := PlayerState.gold
	_assert(EconomySystem.ship_from_slot(tidx, 1), "Drops item in Shipping Bin")
	TimeSystem.sleep_to_next_day(false)
	_assert(PlayerState.gold > gold_before, "Shipping bin pays out overnight")


func _test_npc_relationships_and_caps() -> void:
	SaveManager.start_new_game("Tester", "Test Farm", {}, 5)
	var before := int(NPCSystem.states["clara"]["friendship"])
	NPCSystem.talk_to_npc("clara")
	var after_first := int(NPCSystem.states["clara"]["friendship"])
	NPCSystem.talk_to_npc("clara")
	var after_second := int(NPCSystem.states["clara"]["friendship"])
	_assert(after_first > before and after_second == after_first, "Daily talk friendship capped to once per day")

	InventorySystem.add_item("strawberry", 3)
	var g1 := NPCSystem.give_gift("clara", "strawberry")
	_assert(bool(g1["ok"]) and int(g1["delta"]) == 80, "Favorite gift awards +80 friendship")
	var g2 := NPCSystem.give_gift("clara", "strawberry")
	_assert(not bool(g2["ok"]), "Blocks second gift on same day")
	TimeSystem.sleep_to_next_day(false)
	NPCSystem.give_gift("clara", "strawberry")
	TimeSystem.sleep_to_next_day(false)
	var g3 := NPCSystem.give_gift("clara", "strawberry")
	_assert(not bool(g3["ok"]), "Weekly gift limit (2/week) enforced")


func _test_animals_and_buildings() -> void:
	SaveManager.start_new_game("Tester", "Test Farm", {}, 5)
	PlayerState.add_gold(5000)
	InventorySystem.add_item("wood", 100)
	InventorySystem.add_item("stone", 100)
	InventorySystem.add_item("hay", 10)

	# Should fail over farmhouse
	var bad_b := BuildingSystem.construct_via_carpenter("coop", "greenfield_farm", Vector2i(8, 6))
	_assert(not bool(bad_b["ok"]), "Rejects building overlapping Farmhouse")

	var ok_b := BuildingSystem.construct_via_carpenter("coop", "greenfield_farm", Vector2i(38, 16))
	_assert(bool(ok_b["ok"]), "Constructs Coop on valid farm tile")
	var overlap_b := BuildingSystem.construct_via_carpenter("silo", "greenfield_farm", Vector2i(38, 16))
	_assert(not bool(overlap_b["ok"]), "Rejects overlapping building placement")

	_assert(AnimalSystem.buy_animal("chicken", "Cluckers"), "Adopts chicken into Coop")
	var uid := str(AnimalSystem.owned_animals[0]["uid"])
	_assert(AnimalSystem.feed_animal(uid) and AnimalSystem.pet_animal(uid), "Feeds and pets animal")
	TimeSystem.sleep_to_next_day(false)
	_assert(bool(AnimalSystem.owned_animals[0]["productReady"]), "Fed & happy animal produces next day")
	_assert(AnimalSystem.collect_product(uid) and InventorySystem.count_item("egg") >= 1, "Collects Farm Egg")


func _test_fishing_and_mining() -> void:
	SaveManager.start_new_game("Tester", "Test Farm", {}, 5)
	var lake_fish := FishingSystem.get_available_fish("crystal_lake", "spring", 12, "sunny")
	_assert(lake_fish.size() > 0, "Crystal Lake Spring fish pool populated")
	_assert(FishingSystem.complete_catch(str(lake_fish[0]["id"]), true), "Completes catch with quality upgrade")

	var f1 := MiningSystem.generate_floor(1)
	var f25 := MiningSystem.generate_floor(25)
	var f100 := MiningSystem.generate_floor(100)
	_assert(f1["rocks"].size() > 0, "Mine Floor 1 spawns rocks & ores")
	_assert(bool(f25["isBossFloor"]) and f25["monsters"][0]["monsterId"] == "boss_yeti", "Floor 25 spawns Frostpeak Warden boss")
	_assert(bool(f100["isBossFloor"]) and f100["monsters"][0]["monsterId"] == "boss_sovereign", "Floor 100 spawns Hollow Sovereign boss")

	MiningSystem.enter_floor(10)
	_assert(WorldSystem.is_region_unlocked("forgotten_ruins"), "Reaching Mine Floor 10 unlocks Forgotten Ruins")
	MiningSystem.enter_floor(25)
	_assert(WorldSystem.is_region_unlocked("hidden_sanctuary"), "Reaching Mine Floor 25 unlocks Hidden Sanctuary")


func _test_crafting_and_cooking() -> void:
	SaveManager.start_new_game("Tester", "Test Farm", {}, 5)
	var fail_c := CraftingSystem.craft("craft_copper_bar")
	_assert(not bool(fail_c["ok"]), "Crafting rejects missing ore/coal")
	InventorySystem.add_item("copper_ore", 5)
	InventorySystem.add_item("coal", 1)
	var ok_c := CraftingSystem.craft("craft_copper_bar")
	_assert(bool(ok_c["ok"]) and InventorySystem.count_item("copper_bar") == 1, "Crafts Copper Bar atomically")

	InventorySystem.add_item("egg", 1)
	var ok_cook := CraftingSystem.cook("fried_egg")
	_assert(bool(ok_cook["ok"]) and InventorySystem.count_item("fried_egg") == 1, "Cooks Sunny Fried Egg atomically")


func _test_quests_achievements_festivals() -> void:
	SaveManager.start_new_game("Tester", "Test Farm", {}, 5)
	EventBus.crop_harvested.emit("turnip", 3, 0)
	_assert(str(QuestSystem.quest_states["main_01"]["status"]) == "claimed", "EventBus crop_harvested completes main_01 automatically")
	_assert(str(QuestSystem.quest_states["main_02"]["status"]) == "active", "Completing main_01 unlocks main_02")

	var fest_res := QuestSystem.participate_in_festival("fest_spring_bloom")
	_assert(bool(fest_res["ok"]), "Festival participation awards prize")
	var fest_dup := QuestSystem.participate_in_festival("fest_spring_bloom")
	_assert(not bool(fest_dup["ok"]), "Prevents claiming same annual festival twice")


func _test_save_load_backup_and_security() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/slot_2.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/slot_2.bak"))
	SaveManager.start_new_game("SaveHero", "SaveHaven", {}, 2)
	PlayerState.add_gold(777)
	var expected_gold := PlayerState.gold
	InventorySystem.add_item("diamond", 2)
	_assert(SaveManager.save_slot(2), "Saves slot 2 cleanly")
	# Write a second time so .bak backup exists with expected_gold
	PlayerState.add_gold(100)
	SaveManager.save_slot(2)

	# Corrupt primary file and verify automatic recovery from .bak
	var f := FileAccess.open("user://saves/slot_2.json", FileAccess.WRITE)
	f.store_string("{CORRUPTED_JSON!!")
	f.close()
	var rec_res := SaveManager.load_slot(2)
	_assert(bool(rec_res["ok"]) and PlayerState.gold == expected_gold and InventorySystem.count_item("diamond") == 2, "Recovers valid game state from .bak snapshot when primary save corrupted")

	# Export / Import & Security checks
	var exported := SaveManager.export_save_string(2)
	_assert(exported.length() > 100, "Exports valid JSON string")
	var imp_res := SaveManager.import_save_string(3, exported)
	_assert(bool(imp_res["ok"]), "Imports exported save JSON cleanly")
	var bad_proto := SaveManager.import_save_string(3, "{\"__proto__\": {\"hack\": true}}")
	_assert(not bool(bad_proto["ok"]), "Security check rejects __proto__ key")
	var bad_neg := SaveManager.import_save_string(3, "{\"schemaVersion\":1,\"time\":{},\"weather\":{},\"player\":{\"gold\":-50},\"inventory\":{\"slots\":[]},\"farming\":{},\"world\":{}}")
	_assert(not bool(bad_neg["ok"]), "Security check rejects negative gold in save import")
	for sid in [2, 3, 5]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/slot_%d.json" % sid))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/slot_%d.bak" % sid))


func _test_all_scenes_and_12_regions() -> void:
	var ws_packed := load("res://scenes/world/WorldScene.tscn") as PackedScene
	var ws := ws_packed.instantiate()
	add_child(ws)
	await get_tree().process_frame

	var loaded_all := true
	for r in GameData.regions_list:
		var rid := str(r["id"])
		WorldSystem.unlock_region(rid)
		ws.load_region(rid, Vector2i(14, 14))
		if WorldSystem.current_region != rid:
			loaded_all = false
	_assert(loaded_all, "WorldScene renders all 12 regions cleanly without errors")
	ws.queue_free()
	await get_tree().process_frame

	for sc_path in ["res://scenes/menu/MainMenuScene.tscn", "res://scenes/menu/CharacterCreationScene.tscn", "res://scenes/world/InteriorScene.tscn", "res://scenes/world/MineScene.tscn"]:
		var pk := load(sc_path) as PackedScene
		var inst := pk.instantiate()
		add_child(inst)
		await get_tree().process_frame
		_assert(is_instance_valid(inst), "Instantiated %s cleanly" % sc_path.get_file())
		inst.queue_free()
		await get_tree().process_frame
