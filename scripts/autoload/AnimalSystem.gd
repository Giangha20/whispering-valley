extends Node
## Manages owned livestock, daily feeding/petting, happiness, and artisan animal products.

var owned_animals: Array = [] # Array of Dictionaries
var _next_uid: int = 1


func _ready() -> void:
	EventBus.day_ended.connect(_on_day_ended)


func reset_animals() -> void:
	owned_animals.clear()
	_next_uid = 1


func get_housing_capacity(building_group: String) -> int:
	var cap := 0
	for b in BuildingSystem.placed_buildings:
		var def: Dictionary = GameData.buildings.get(str(b.get("buildingId", "")), {})
		var bid := str(def.get("id", ""))
		if building_group == "coop" and bid in ["coop", "big_coop"]:
			cap += int(def.get("capacity", 4))
		elif building_group == "barn" and bid in ["barn", "big_barn"]:
			cap += int(def.get("capacity", 4))
	return cap


func count_animals_in_group(building_group: String) -> int:
	var cnt := 0
	for a in owned_animals:
		var sp: Dictionary = GameData.animals.get(str(a["speciesId"]), {})
		if str(sp.get("building", "coop")) == building_group:
			cnt += 1
	return cnt


func buy_animal(species_id: String, custom_name: String = "") -> bool:
	var sp: Dictionary = GameData.animals.get(species_id, {})
	if sp.is_empty():
		return false
	var group := str(sp.get("building", "coop"))
	var cap := get_housing_capacity(group)
	if cap <= 0:
		EventBus.ui_toast.emit("Build a %s on Greenfield Farm first!" % group.capitalize(), "warning")
		return false
	if count_animals_in_group(group) >= cap:
		EventBus.ui_toast.emit("Your %s is full! Build or upgrade another." % group.capitalize(), "warning")
		return false
	var price := int(sp.get("buyPrice", 500))
	if not PlayerState.spend_gold(price):
		EventBus.ui_toast.emit("Need %dG to adopt %s!" % [price, sp["name"]], "warning")
		return false

	var uid := "animal_%d" % _next_uid
	_next_uid += 1
	var aname := custom_name if custom_name != "" else "%s #%d" % [sp["name"].split(" ")[-1], _next_uid - 1]
	owned_animals.append({
		"uid": uid,
		"name": aname,
		"speciesId": species_id,
		"age": 1,
		"friendship": 20,
		"happiness": 75,
		"health": 100,
		"fedToday": false,
		"pettedToday": false,
		"productReady": false,
		"productQuality": 0,
		"daysCounter": 0
	})
	AudioManager.play_sfx("coin")
	EventBus.ui_toast.emit("Adopted %s (%s)!" % [aname, sp["name"]], "success")
	return true


func feed_animal(uid: String) -> bool:
	var a := _find_animal(uid)
	if a.is_empty():
		return false
	if bool(a.get("fedToday", false)):
		EventBus.ui_toast.emit("%s already ate today!" % a["name"], "info")
		return false
	if not InventorySystem.remove_item("hay", 1):
		EventBus.ui_toast.emit("You need Golden Hay to feed %s!" % a["name"], "warning")
		return false
	a["fedToday"] = true
	a["happiness"] = mini(100, int(a["happiness"]) + 10)
	a["health"] = mini(100, int(a["health"]) + 5)
	AudioManager.play_sfx("harvest")
	return true


func pet_animal(uid: String) -> bool:
	var a := _find_animal(uid)
	if a.is_empty():
		return false
	if bool(a.get("pettedToday", false)):
		return false
	a["pettedToday"] = true
	a["friendship"] = mini(1000, int(a["friendship"]) + 15)
	a["happiness"] = mini(100, int(a["happiness"]) + 12)
	AudioManager.play_sfx("ui_click")
	EventBus.ui_toast.emit("%s loves the attention! (+Happiness)" % a["name"], "success")
	return true


func collect_product(uid: String) -> bool:
	var a := _find_animal(uid)
	if a.is_empty() or not bool(a.get("productReady", false)):
		return false
	var sp: Dictionary = GameData.animals.get(str(a["speciesId"]), {})
	var prod_id := str(sp.get("productItemId", "egg"))
	var q := int(a.get("productQuality", 0))
	if not InventorySystem.add_item(prod_id, 1, q):
		return false
	a["productReady"] = false
	a["daysCounter"] = 0
	PlayerState.add_xp("farming", 10)
	AudioManager.play_sfx("harvest")
	EventBus.animal_product_collected.emit(str(a["speciesId"]), prod_id, q)
	return true


func sell_animal(uid: String) -> bool:
	for i in range(owned_animals.size()):
		if owned_animals[i]["uid"] == uid:
			var sp: Dictionary = GameData.animals.get(str(owned_animals[i]["speciesId"]), {})
			var sell_val := maxi(100, int(int(sp.get("buyPrice", 400)) * 0.65) + int(owned_animals[i]["friendship"]) / 5)
			owned_animals.remove_at(i)
			PlayerState.add_gold(sell_val)
			AudioManager.play_sfx("coin")
			EventBus.ui_toast.emit("Sold animal for %dG." % sell_val, "info")
			return true
	return false


func _find_animal(uid: String) -> Dictionary:
	for a in owned_animals:
		if a["uid"] == uid:
			return a
	return {}


func _on_day_ended(_year: int, _season: String, _day: int) -> void:
	for a in owned_animals:
		a["age"] = int(a["age"]) + 1
		var fed := bool(a.get("fedToday", false))
		if fed:
			a["happiness"] = mini(100, int(a["happiness"]) + 5)
			a["daysCounter"] = int(a.get("daysCounter", 0)) + 1
			var sp: Dictionary = GameData.animals.get(str(a["speciesId"]), {})
			var interval := maxi(1, int(sp.get("intervalDays", 1)))
			if int(a["daysCounter"]) >= interval and int(a["happiness"]) >= 30:
				a["productReady"] = true
				var fr := int(a["friendship"])
				a["productQuality"] = 3 if fr >= 800 else (2 if fr >= 450 else (1 if fr >= 200 else 0))
		else:
			a["happiness"] = maxi(0, int(a["happiness"]) - 15)
		a["fedToday"] = false
		a["pettedToday"] = false


func serialize() -> Dictionary:
	return {"nextUid": _next_uid, "animals": owned_animals.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	_next_uid = maxi(1, int(data.get("nextUid", 1)))
	owned_animals.clear()
	var arr: Variant = data.get("animals", [])
	if arr is Array:
		for a in arr:
			if a is Dictionary and GameData.animals.has(str(a.get("speciesId", ""))):
				owned_animals.append(a.duplicate(true))
