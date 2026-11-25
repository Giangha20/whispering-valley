extends Node
## Handles Crafting (104 recipes) and Cooking (84 dishes) with atomic ingredient checks.


func is_unlocked(cond: String) -> bool:
	if cond == "" or cond == "starter":
		return true
	# Format: "<skill>_lv_<n>"
	var parts := cond.split("_lv_")
	if parts.size() == 2:
		var sk := parts[0]
		var req_lv := int(parts[1])
		return PlayerState.get_skill_level(sk) >= req_lv
	return true


func has_ingredients(ingredients: Array) -> bool:
	for ing in ingredients:
		var iid := str(ing.get("itemId", ""))
		var cnt := int(ing.get("count", 1))
		if InventorySystem.count_item(iid) < cnt:
			return false
	return true


func can_craft(recipe_id: String) -> Dictionary:
	var rec: Dictionary = GameData.crafting.get(recipe_id, {})
	if rec.is_empty():
		return {"ok": false, "reason": "Recipe does not exist."}
	var req_sk := str(rec.get("requiredSkill", "foraging"))
	var req_lv := int(rec.get("requiredLevel", 1))
	if PlayerState.get_skill_level(req_sk) < req_lv:
		return {"ok": false, "reason": "Requires %s Lv.%d." % [req_sk.capitalize(), req_lv]}
	if not has_ingredients(rec.get("ingredients", [])):
		return {"ok": false, "reason": "Missing required materials."}
	var out_id := str(rec.get("outputItemId", ""))
	var out_cnt := int(rec.get("outputCount", 1))
	if not InventorySystem.can_fit(out_id, out_cnt):
		return {"ok": false, "reason": "Inventory is full."}
	return {"ok": true, "reason": ""}


func craft(recipe_id: String) -> Dictionary:
	var chk := can_craft(recipe_id)
	if not bool(chk["ok"]):
		return chk
	var rec: Dictionary = GameData.crafting[recipe_id]
	var ings: Array = rec.get("ingredients", [])

	# Consume materials atomically (with rollback guard)
	var consumed: Array = []
	for ing in ings:
		var iid := str(ing["itemId"])
		var cnt := int(ing["count"])
		if not InventorySystem.remove_item(iid, cnt, -1, true):
			for c in consumed:
				InventorySystem.add_item(c["id"], c["count"], 0, true)
			InventorySystem.slots = InventorySystem.slots
			EventBus.inventory_changed.emit()
			return {"ok": false, "reason": "Failed to consume ingredients."}
		consumed.append({"id": iid, "count": cnt})

	var out_id := str(rec["outputItemId"])
	var out_cnt := int(rec.get("outputCount", 1))
	if not InventorySystem.add_item(out_id, out_cnt):
		for c in consumed:
			InventorySystem.add_item(c["id"], c["count"], 0, true)
		EventBus.inventory_changed.emit()
		return {"ok": false, "reason": "Failed to add crafted item."}

	PlayerState.add_xp(str(rec.get("requiredSkill", "foraging")), 10)
	AudioManager.play_sfx("harvest")
	EventBus.item_crafted.emit(recipe_id, out_id, out_cnt)
	return {"ok": true, "itemId": out_id, "count": out_cnt}


func can_cook(dish_id: String) -> Dictionary:
	var dish: Dictionary = GameData.cooking.get(dish_id, {})
	if dish.is_empty():
		return {"ok": false, "reason": "Dish not found."}
	if not has_ingredients(dish.get("ingredients", [])):
		return {"ok": false, "reason": "Missing ingredients."}
	var out_id := str(dish.get("outputItemId", dish_id))
	if not InventorySystem.can_fit(out_id, 1):
		return {"ok": false, "reason": "Inventory is full."}
	return {"ok": true, "reason": ""}


func cook(dish_id: String) -> Dictionary:
	var chk := can_cook(dish_id)
	if not bool(chk["ok"]):
		return chk
	var dish: Dictionary = GameData.cooking[dish_id]
	var consumed: Array = []
	for ing in dish.get("ingredients", []):
		var iid := str(ing["itemId"])
		var cnt := int(ing["count"])
		if not InventorySystem.remove_item(iid, cnt, -1, true):
			for c in consumed:
				InventorySystem.add_item(c["id"], c["count"], 0, true)
			EventBus.inventory_changed.emit()
			return {"ok": false, "reason": "Ingredient removal failed."}
		consumed.append({"id": iid, "count": cnt})

	var out_id := str(dish.get("outputItemId", dish_id))
	if not InventorySystem.add_item(out_id, 1):
		for c in consumed:
			InventorySystem.add_item(c["id"], c["count"], 0, true)
		EventBus.inventory_changed.emit()
		return {"ok": false, "reason": "Bag full."}

	PlayerState.add_xp("cooking", 14)
	AudioManager.play_sfx("harvest")
	EventBus.dish_cooked.emit(dish_id, out_id)
	return {"ok": true, "itemId": out_id}
