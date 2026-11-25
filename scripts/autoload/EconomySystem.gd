extends Node
## Handles Shop Transactions (atomic with rollback), Shipping Bin overnight sales, and Economy rules.

var shipping_bin: Array = [] # [{"id": String, "count": int, "quality": int}]


func _ready() -> void:
	EventBus.day_ended.connect(_on_day_ended)


func reset_economy() -> void:
	shipping_bin.clear()


func is_shop_open(shop_id: String) -> bool:
	var shop: Dictionary = GameData.shops.get(shop_id, {})
	if shop.is_empty():
		return false
	var cond := str(shop.get("unlockCondition", ""))
	if cond != "" and not QuestSystem.check_condition(cond):
		return false
	var oh := int(shop.get("openHour", 6))
	var ch := int(shop.get("closeHour", 22))
	return TimeSystem.hour >= oh and TimeSystem.hour <= ch


func get_shop_stock(shop_id: String) -> Array:
	var shop: Dictionary = GameData.shops.get(shop_id, {})
	if shop.is_empty():
		return []
	var stock: Array = []
	for iid in shop.get("baseStock", []):
		if GameData.items.has(iid):
			stock.append(iid)
	var seasonal: Dictionary = shop.get("seasonalStock", {})
	var cur_s := TimeSystem.get_season()
	if seasonal.has(cur_s):
		for iid in seasonal[cur_s]:
			if GameData.items.has(iid) and iid not in stock:
				stock.append(iid)
	return stock


func get_buy_price(shop_id: String, item_id: String) -> int:
	var shop: Dictionary = GameData.shops.get(shop_id, {})
	var item := GameData.get_item(item_id)
	if item.is_empty():
		return 0
	var mult := float(shop.get("priceMultiplier", 1.0))
	var base := maxi(1, int(item.get("basePrice", 10)))
	# Seeds & shop goods sell at slight retail price above raw crop base where appropriate
	return maxi(1, int(round(base * mult)))


func get_sell_price(item_id: String, quality: int = 0) -> int:
	var item := GameData.get_item(item_id)
	if item.is_empty() or not bool(item.get("sellable", true)):
		return 0
	var base := int(item.get("basePrice", 0))
	return int(round(base * InventorySystem.quality_multiplier(quality)))


func buy_item(shop_id: String, item_id: String, qty: int = 1, ignore_hours: bool = false) -> Dictionary:
	# Atomic transaction with full validation and rollback
	if qty <= 0:
		return {"ok": false, "error": "Invalid quantity."}
	var shop: Dictionary = GameData.shops.get(shop_id, {})
	if shop.is_empty():
		return {"ok": false, "error": "Shop not found."}
	if not ignore_hours and not is_shop_open(shop_id):
		return {"ok": false, "error": "%s is closed right now (%02d:00-%02d:00)." % [shop["name"], int(shop["openHour"]), int(shop["closeHour"])]}

	var stock := get_shop_stock(shop_id)
	if item_id not in stock:
		return {"ok": false, "error": "Item is not in stock this season."}

	var unit_price := get_buy_price(shop_id, item_id)
	var total_cost := unit_price * qty
	if PlayerState.gold < total_cost:
		return {"ok": false, "error": "Not enough Gold (%dG required)." % total_cost}

	if not InventorySystem.can_fit(item_id, qty, 0):
		return {"ok": false, "error": "Not enough space in your bag!"}

	# Step 4: Deduct gold
	if not PlayerState.spend_gold(total_cost):
		return {"ok": false, "error": "Payment failed."}

	# Step 5: Add item (rollback gold if anything fails)
	if not InventorySystem.add_item(item_id, qty, 0):
		PlayerState.add_gold(total_cost)
		return {"ok": false, "error": "Failed to add item to inventory; transaction rolled back."}

	AudioManager.play_sfx("coin")
	EventBus.item_bought.emit(shop_id, item_id, qty, total_cost)
	return {"ok": true, "cost": total_cost}


func sell_from_slot(slot_idx: int, qty: int = 1) -> Dictionary:
	if qty <= 0 or slot_idx < 0 or slot_idx >= InventorySystem.slots.size():
		return {"ok": false, "error": "Invalid slot or quantity."}
	var s: Dictionary = InventorySystem.slots[slot_idx]
	if s.is_empty():
		return {"ok": false, "error": "Slot is empty."}
	var item_id := str(s["id"])
	var quality := int(s.get("quality", 0))
	var available := int(s.get("count", 0))
	if qty > available:
		return {"ok": false, "error": "Not enough items to sell."}
	var unit_val := get_sell_price(item_id, quality)
	if unit_val <= 0:
		return {"ok": false, "error": "This item cannot be sold."}

	if not InventorySystem.remove_from_slot(slot_idx, qty):
		return {"ok": false, "error": "Could not remove item."}

	var earned := unit_val * qty
	PlayerState.add_gold(earned)
	AudioManager.play_sfx("coin")
	EventBus.item_sold.emit(item_id, qty, earned)
	return {"ok": true, "earned": earned}


func ship_from_slot(slot_idx: int, qty: int = 1) -> bool:
	if qty <= 0 or slot_idx < 0 or slot_idx >= InventorySystem.slots.size():
		return false
	var s: Dictionary = InventorySystem.slots[slot_idx]
	if s.is_empty():
		return false
	var item_id := str(s["id"])
	var q := int(s.get("quality", 0))
	if get_sell_price(item_id, q) <= 0:
		EventBus.ui_toast.emit("That item cannot be shipped.", "warning")
		return false
	if not InventorySystem.remove_from_slot(slot_idx, qty):
		return false
	shipping_bin.append({"id": item_id, "count": qty, "quality": q})
	AudioManager.play_sfx("ui_click")
	EventBus.ui_toast.emit("Placed %dx %s in Shipping Bin." % [qty, GameData.get_item(item_id)["name"]], "info")
	return true


func _on_day_ended(_year: int, _season: String, _day: int) -> void:
	if shipping_bin.is_empty():
		return
	var total := 0
	for entry in shipping_bin:
		var item_id := str(entry["id"])
		var cnt := int(entry["count"])
		var q := int(entry.get("quality", 0))
		var val := get_sell_price(item_id, q) * cnt
		total += val
		EventBus.item_sold.emit(item_id, cnt, val)
	shipping_bin.clear()
	if total > 0:
		PlayerState.add_gold(total)
		EventBus.ui_toast.emit("Shipping Bin overnight payout: +%dG!" % total, "success")


func serialize() -> Dictionary:
	return {"shippingBin": shipping_bin.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	shipping_bin.clear()
	var arr: Variant = data.get("shippingBin", [])
	if arr is Array:
		for e in arr:
			if e is Dictionary and GameData.items.has(str(e.get("id", ""))) and int(e.get("count", 0)) > 0:
				shipping_bin.append({"id": str(e["id"]), "count": int(e["count"]), "quality": int(e.get("quality", 0))})
