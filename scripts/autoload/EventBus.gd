extends Node
## Global event-driven signal hub decoupling gameplay systems, entities, quests, and UI.

signal time_ticked(hour: int, minute: int)
signal day_started(year: int, season: String, day: int)
signal day_ended(year: int, season: String, day: int)
signal season_changed(new_season: String, year: int)
signal weather_changed(new_weather: String)

signal player_stats_changed()
signal inventory_changed()
signal hotbar_selection_changed(slot_index: int)

signal crop_planted(region_id: String, tile: Vector2i, crop_id: String)
signal crop_watered(region_id: String, tile: Vector2i)
signal crop_harvested(crop_id: String, quantity: int, quality: int)

signal animal_product_collected(species_id: String, item_id: String, quality: int)
signal item_bought(shop_id: String, item_id: String, quantity: int, total_cost: int)
signal item_sold(item_id: String, quantity: int, total_earned: int)
signal gold_earned(amount: int)

signal npc_talked(npc_id: String, first_today: bool)
signal gift_given(npc_id: String, item_id: String, delta: int)
signal relationship_changed(npc_id: String, new_points: int)

signal fish_caught(fish_id: String, perfect: bool)
signal mine_floor_reached(floor_num: int)
signal monster_defeated(monster_id: String, is_boss: bool)

signal item_crafted(recipe_id: String, item_id: String, count: int)
signal dish_cooked(dish_id: String, item_id: String)
signal building_placed(building_id: String, region_id: String, tile: Vector2i)
signal building_removed(building_id: String, region_id: String, tile: Vector2i)

signal region_changed(new_region_id: String)
signal region_discovered(region_id: String)

signal quest_updated(quest_id: String, progress: int, required: int)
signal quest_completed(quest_id: String)
signal achievement_unlocked(achievement_id: String)
signal festival_triggered(festival_id: String)

signal ui_toast(message: String, kind: String)
signal modal_state_changed(is_open: bool, panel_name: String)
signal game_saved(slot_id: int)
signal game_loaded(slot_id: int)
