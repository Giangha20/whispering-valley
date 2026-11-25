extends Node
## Manages 36-slot Player Inventory (10-slot Hotbar + 26-slot Backpack), Storage Chests,
## stacking, splitting, sorting, filtering, and quality pricing.

const HOTBAR_SIZE := 10
const BACKPACK_SIZE := 36
const CHEST_SIZE := 36

# Each slot is either {} (empty) or {"id": String, "count": int, "quality": int}
var slots: Array = []
var chests: Dictionary = {} # chest_uid -> Array of 36 slots
var selected_slot: int = 0


func _ready() -> void:
	reset_inventory()


func reset_inventory() -> void:
	slots.clear()
	for i in range(BACKPACK_SIZE):
		slots.append({})
	chests.clear()
	selected_slot = 0

	# Starter farm tools & seeds so player can immediately farm, chop, mine, fish, and defend
	add_item("tool_hoe", 1, 0, true)
	add_item("tool_watering_can", 1, 0, true)
	add_item("tool_axe", 1, 0, true)
	add_item("tool_pickaxe", 1, 0, true)
	add_item("tool_scythe", 1, 0, true)
	add_item("tool_fishing_bamboo", 1, 0, true)
	add_item("equip_rusty_sword", 1, 0, true)
	add_item("turnip_seed", 12, 0, true)
	add_item("parsnip_seed", 6, 0, true)
	add_item("strawberry_seed", 4, 0, true)
	EventBus.inventory_changed.emit()
	EventBus.hotbar_selection_changed.emit(selected_slot)


func select_hotbar(index: int) -> void:
	selected_slot = clampi(index, 0, HOTBAR_SIZE - 1)
	EventBus.hotbar_selection_changed.emit(selected_slot)


func get_selected_slot() -> Dictionary:
	if selected_slot >= 0 and selected_slot < slots.size():
		return slots[selected_slot]
	return {}


func get_selected_item_id() -> String:
	var s := get_selected_slot()
	return str(s.get("id", ""))


func can_fit(item_id: String, count: int, quality: int = 0) -> bool:
	if count <= 0:
		return false
	var def := GameData.get_item(item_id)
	if def.is_empty():
		return false
	var max_stack := maxi(1, int(def.get("maxStack", 99)))
	var remaining := count

	for s in slots:
		if s.is_empty():
			remaining -= max_stack
		elif str(s.get("id", "")) == item_id and int(s.get("quality", 0)) == quality:
			var space := max_stack - int(s.get("count", 0))
			if space > 0:
				remaining -= space
		if remaining <= 0:
			return true
	return false


func add_item(item_id: String, count: int, quality: int = 0, silent: bool = false) -> bool:
	if count <= 0:
		return false
	var def := GameData.get_item(item_id)
	if def.is_empty():
		return false
	if not can_fit(item_id, count, quality):
		if not silent:
			EventBus.ui_toast.emit("Inventory is full!", "warning")
		return false

	var max_stack := maxi(1, int(def.get("maxStack", 99)))
	var remaining := count

	# Fill existing matching stacks first
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var s: Dictionary = slots[i]
		if not s.is_empty() and str(s.get("id", "")) == item_id and int(s.get("quality", 0)) == quality:
			var cur := int(s.get("count", 0))
			if cur < max_stack:
				var take := mini(remaining, max_stack - cur)
				s["count"] = cur + take
				remaining -= take

	# Fill empty slots
	for i in range(slots.size()):
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var take := mini(remaining, max_stack)
			slots[i] = {"id": item_id, "count": take, "quality": quality}
			remaining -= take

	if not silent:
		EventBus.inventory_changed.emit()
	return true


func remove_item(item_id: String, count: int, quality: int = -1, silent: bool = false) -> bool:
	if count <= 0:
		return false
	if count_item(item_id, quality) < count:
		return false

	var remaining := count
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var s: Dictionary = slots[i]
		if s.is_empty() or str(s.get("id", "")) != item_id:
			continue
		if quality != -1 and int(s.get("quality", 0)) != quality:
			continue
		var cur := int(s.get("count", 0))
		var take := mini(remaining, cur)
		cur -= take
		remaining -= take
		if cur <= 0:
			slots[i] = {}
		else:
			s["count"] = cur

	if not silent:
		EventBus.inventory_changed.emit()
	return true


func remove_from_slot(slot_idx: int, count: int) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size() or count <= 0:
		return false
	var s: Dictionary = slots[slot_idx]
	if s.is_empty():
		return false
	var cur := int(s.get("count", 0))
	if cur < count:
		return false
	cur -= count
	if cur <= 0:
		slots[slot_idx] = {}
	else:
		s["count"] = cur
	EventBus.inventory_changed.emit()
	return true


func count_item(item_id: String, quality: int = -1) -> int:
	var total := 0
	for s in slots:
		if not s.is_empty() and str(s.get("id", "")) == item_id:
			if quality == -1 or int(s.get("quality", 0)) == quality:
				total += int(s.get("count", 0))
	return total


func has_item(item_id: String, count: int = 1) -> bool:
	return count_item(item_id) >= count


func swap_slots(idx_a: int, idx_b: int) -> bool:
	if idx_a < 0 or idx_a >= slots.size() or idx_b < 0 or idx_b >= slots.size():
		return false
	if idx_a == idx_b:
		return true
	var a: Dictionary = slots[idx_a]
	var b: Dictionary = slots[idx_b]

	# Merge if identical stackable item & quality
	if not a.is_empty() and not b.is_empty() and a["id"] == b["id"] and int(a["quality"]) == int(b["quality"]):
		var def := GameData.get_item(a["id"])
		var max_stack := maxi(1, int(def.get("maxStack", 99)))
		var space := max_stack - int(b["count"])
		if space > 0:
			var move := mini(space, int(a["count"]))
			b["count"] = int(b["count"]) + move
			a["count"] = int(a["count"]) - move
			if int(a["count"]) <= 0:
				slots[idx_a] = {}
			EventBus.inventory_changed.emit()
			return true

	var tmp: Dictionary = slots[idx_a]
	slots[idx_a] = slots[idx_b]
	slots[idx_b] = tmp
	EventBus.inventory_changed.emit()
	return true


func split_stack(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	var s: Dictionary = slots[slot_idx]
	if s.is_empty() or int(s.get("count", 0)) < 2:
		return false
	var empty_idx := -1
	for i in range(slots.size()):
		if slots[i].is_empty():
			empty_idx = i
			break
	if empty_idx == -1:
		return false
	var half := int(s["count"]) / 2
	s["count"] = int(s["count"]) - half
	slots[empty_idx] = {"id": s["id"], "count": half, "quality": int(s["quality"])}
	EventBus.inventory_changed.emit()
	return true


func sort_inventory(keep_hotbar: bool = true) -> void:
	var start_idx := HOTBAR_SIZE if keep_hotbar else 0
	var collected: Array = []
	for i in range(start_idx, slots.size()):
		if not slots[i].is_empty():
			collected.append(slots[i])
			slots[i] = {}

	# Compact matching stacks first
	var merged: Array = []
	for entry in collected:
		var def := GameData.get_item(str(entry["id"]))
		var max_stack := maxi(1, int(def.get("maxStack", 99)))
		var left := int(entry["count"])
		for m in merged:
			if m["id"] == entry["id"] and int(m["quality"]) == int(entry["quality"]) and int(m["count"]) < max_stack:
				var take := mini(left, max_stack - int(m["count"]))
				m["count"] = int(m["count"]) + take
				left -= take
				if left <= 0:
					break
		if left > 0:
			merged.append({"id": entry["id"], "count": left, "quality": int(entry["quality"])})

	merged.sort_custom(func(a, b):
		var da := GameData.get_item(str(a["id"]))
		var db := GameData.get_item(str(b["id"]))
		var ca := str(da.get("category", ""))
		var cb := str(db.get("category", ""))
		if ca != cb:
			return ca < cb
		return str(da.get("name", "")) < str(db.get("name", ""))
	)

	for i in range(mini(merged.size(), slots.size() - start_idx)):
		slots[start_idx + i] = merged[i]
	EventBus.inventory_changed.emit()


func get_filtered_indices(category: String) -> Array:
	var res := []
	for i in range(slots.size()):
		if slots[i].is_empty():
			continue
		if category == "All":
			res.append(i)
		else:
			var def := GameData.get_item(str(slots[i]["id"]))
			if str(def.get("category", "")) == category:
				res.append(i)
	return res


func use_item_in_slot(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	var s: Dictionary = slots[slot_idx]
	if s.is_empty():
		return false
	var item_id := str(s["id"])
	var def := GameData.get_item(item_id)
	if def.is_empty() or not bool(def.get("usable", false)):
		return false
	var meta: Dictionary = def.get("metadata", {})
	var cat := str(def.get("category", ""))

	if cat in ["Food", "Crops", "Forage", "Fish", "Materials", "Special Items"]:
		if meta.has("slot"):
			return PlayerState.equip_item(item_id)
		if meta.has("warpRegion"):
			if remove_from_slot(slot_idx, 1):
				WorldSystem.travel_to(str(meta["warpRegion"]), Vector2i(14, 14))
				EventBus.ui_toast.emit("Warped back to Greenfield Farm!", "success")
				return true
		var en := int(meta.get("energy", 0))
		var hp := int(meta.get("health", 0))
		if en > 0 or hp > 0:
			if remove_from_slot(slot_idx, 1):
				PlayerState.restore_energy(en)
				PlayerState.restore_health(hp)
				if meta.has("buffType"):
					PlayerState.apply_buff(str(meta["buffType"]), float(meta.get("buffDuration", 180)))
				AudioManager.play_sfx("harvest")
				EventBus.ui_toast.emit("Consumed %s (+%d EN, +%d HP)" % [def["name"], en, hp], "success")
				return true
	return false


func get_or_create_chest(chest_uid: String) -> Array:
	if not chests.has(chest_uid):
		var arr := []
		for i in range(CHEST_SIZE):
			arr.append({})
		chests[chest_uid] = arr
	return chests[chest_uid]


func deposit_to_chest(chest_uid: String, player_slot: int) -> bool:
	if player_slot < 0 or player_slot >= slots.size():
		return false
	var s: Dictionary = slots[player_slot]
	if s.is_empty():
		return false
	var chest := get_or_create_chest(chest_uid)
	for i in range(chest.size()):
		if chest[i].is_empty():
			chest[i] = s.duplicate()
			slots[player_slot] = {}
			EventBus.inventory_changed.emit()
			return true
	return false


func withdraw_from_chest(chest_uid: String, chest_slot: int) -> bool:
	var chest := get_or_create_chest(chest_uid)
	if chest_slot < 0 or chest_slot >= chest.size():
		return false
	var s: Dictionary = chest[chest_slot]
	if s.is_empty():
		return false
	if add_item(str(s["id"]), int(s["count"]), int(s.get("quality", 0))):
		chest[chest_slot] = {}
		return true
	return false


static func quality_name(q: int) -> String:
	match q:
		1: return "Silver"
		2: return "Gold"
		3: return "Iridium"
		_: return "Normal"


static func quality_multiplier(q: int) -> float:
	match q:
		1: return 1.25
		2: return 1.5
		3: return 2.0
		_: return 1.0


func serialize() -> Dictionary:
	return {
		"selectedSlot": selected_slot,
		"slots": slots.duplicate(true),
		"chests": chests.duplicate(true)
	}


func deserialize(data: Dictionary) -> void:
	selected_slot = clampi(int(data.get("selectedSlot", 0)), 0, HOTBAR_SIZE - 1)
	var loaded_slots: Variant = data.get("slots", [])
	slots.clear()
	for i in range(BACKPACK_SIZE):
		if loaded_slots is Array and i < loaded_slots.size() and loaded_slots[i] is Dictionary and not loaded_slots[i].is_empty():
			var e: Dictionary = loaded_slots[i]
			var iid := str(e.get("id", ""))
			var cnt := int(e.get("count", 0))
			if GameData.items.has(iid) and cnt > 0:
				slots.append({"id": iid, "count": cnt, "quality": clampi(int(e.get("quality", 0)), 0, 3)})
			else:
				slots.append({})
		else:
			slots.append({})
	chests.clear()
	var loaded_chests: Variant = data.get("chests", {})
	if loaded_chests is Dictionary:
		for cid in loaded_chests.keys():
			if loaded_chests[cid] is Array:
				var carr := []
				for j in range(CHEST_SIZE):
					if j < loaded_chests[cid].size() and loaded_chests[cid][j] is Dictionary and not loaded_chests[cid][j].is_empty():
						var ce: Dictionary = loaded_chests[cid][j]
						if GameData.items.has(str(ce.get("id", ""))) and int(ce.get("count", 0)) > 0:
							carr.append({"id": str(ce["id"]), "count": int(ce["count"]), "quality": clampi(int(ce.get("quality", 0)), 0, 3)})
						else:
							carr.append({})
					else:
						carr.append({})
				chests[str(cid)] = carr
	EventBus.inventory_changed.emit()
	EventBus.hotbar_selection_changed.emit(selected_slot)
