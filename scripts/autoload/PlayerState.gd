extends Node
## Holds player stats, customization, skills, equipment, and buffs.

const SKILL_NAMES := ["farming", "fishing", "mining", "foraging", "combat", "cooking"]

var player_name: String = "Aria"
var farm_name: String = "Greenfield Farm"
var customization: Dictionary = {
	"skinTone": "#ebb896",
	"hairStyle": 0,
	"hairColor": "#6a3e26",
	"outfitStyle": 0,
	"outfitColor": "#4f8d4e",
	"accessory": 0
}

var max_energy: int = 120
var energy: int = 120
var max_health: int = 100
var health: int = 100
var gold: int = 500
var total_gold_earned: int = 0

var skills: Dictionary = {}
var equipped: Dictionary = {
	"sword": "equip_rusty_sword",
	"shield": "",
	"boots": "",
	"ring": ""
}
var active_buffs: Dictionary = {} # buffType -> remaining real seconds


func _ready() -> void:
	reset_player()


func _process(delta: float) -> void:
	if not TimeSystem.is_playing or TimeSystem.is_time_paused():
		return
	if active_buffs.is_empty():
		return
	var expired := []
	for b in active_buffs.keys():
		active_buffs[b] = float(active_buffs[b]) - delta
		if float(active_buffs[b]) <= 0.0:
			expired.append(b)
	for b in expired:
		active_buffs.erase(b)
		EventBus.player_stats_changed.emit()


func reset_player() -> void:
	max_energy = 120
	energy = 120
	max_health = 100
	health = 100
	gold = 500
	total_gold_earned = 0
	skills.clear()
	for s in SKILL_NAMES:
		skills[s] = {"level": 1, "xp": 0}
	equipped = {"sword": "equip_rusty_sword", "shield": "", "boots": "", "ring": ""}
	active_buffs.clear()
	EventBus.player_stats_changed.emit()


func set_customization(cfg: Dictionary) -> void:
	for k in ["skinTone", "hairStyle", "hairColor", "outfitStyle", "outfitColor", "accessory"]:
		if cfg.has(k):
			customization[k] = cfg[k]
	EventBus.player_stats_changed.emit()


func consume_energy(amount: int) -> bool:
	if amount <= 0:
		return true
	if energy < amount:
		EventBus.ui_toast.emit("Low energy! Eat food or sleep in your farmhouse bed.", "warning")
		return false
	energy = maxi(0, energy - amount)
	EventBus.player_stats_changed.emit()
	return true


func restore_energy(amount: int) -> void:
	energy = mini(max_energy, energy + maxi(0, amount))
	EventBus.player_stats_changed.emit()


func restore_health(amount: int) -> void:
	health = mini(max_health, health + maxi(0, amount))
	EventBus.player_stats_changed.emit()


func take_damage(raw_damage: int) -> void:
	var dmg := maxi(1, raw_damage - get_defense())
	health = maxi(0, health - dmg)
	EventBus.player_stats_changed.emit()
	if health <= 0:
		EventBus.ui_toast.emit("You fainted in the mines and were rescued back to Greenfield!", "warning")
		health = max_health / 2
		energy = maxi(20, energy / 2)
		WorldSystem.travel_to("greenfield_farm", Vector2i(10, 12))


func recover_morning(ratio: float = 1.0) -> void:
	energy = clampi(int(round(max_energy * ratio)), 25, max_energy)
	health = max_health
	EventBus.player_stats_changed.emit()


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	total_gold_earned += amount
	EventBus.gold_earned.emit(total_gold_earned)
	EventBus.player_stats_changed.emit()


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	EventBus.player_stats_changed.emit()
	return true


func add_xp(skill_name: String, amount: int) -> void:
	if not skills.has(skill_name) or amount <= 0:
		return
	var sk: Dictionary = skills[skill_name]
	sk["xp"] = int(sk["xp"]) + amount
	var lv := int(sk["level"])
	while lv < 10 and int(sk["xp"]) >= xp_needed_for_level(lv + 1):
		lv += 1
		sk["level"] = lv
		max_energy += 5
		energy = max_energy
		AudioManager.play_sfx("level_up")
		EventBus.ui_toast.emit("%s leveled up to Lv.%d!" % [skill_name.capitalize(), lv], "success")
	EventBus.player_stats_changed.emit()


func xp_needed_for_level(lv: int) -> int:
	return (lv - 1) * (lv - 1) * 50


func get_skill_level(skill_name: String) -> int:
	return int(skills.get(skill_name, {}).get("level", 1))


func get_overall_level() -> int:
	var sum_lv := 0
	for s in SKILL_NAMES:
		sum_lv += get_skill_level(s)
	return maxi(1, sum_lv / SKILL_NAMES.size())


func apply_buff(buff_type: String, duration: float) -> void:
	if buff_type == "" or buff_type == "none" or duration <= 0.0:
		return
	active_buffs[buff_type] = maxf(float(active_buffs.get(buff_type, 0.0)), duration)
	EventBus.player_stats_changed.emit()


func get_attack() -> int:
	var base := 8 + (get_skill_level("combat") - 1) * 3
	var sw_id := str(equipped.get("sword", ""))
	if sw_id != "" and GameData.items.has(sw_id):
		base += int(GameData.items[sw_id].get("metadata", {}).get("attack", 0))
	var ring_id := str(equipped.get("ring", ""))
	if ring_id != "" and GameData.items.has(ring_id):
		var bonus := float(GameData.items[ring_id].get("metadata", {}).get("attackBonus", 0.0))
		base = int(round(base * (1.0 + bonus)))
	if active_buffs.has("attack") or active_buffs.has("all"):
		base += 8
	return base


func get_defense() -> int:
	var def := (get_skill_level("combat") - 1)
	for slot in ["shield", "boots"]:
		var iid := str(equipped.get(slot, ""))
		if iid != "" and GameData.items.has(iid):
			def += int(GameData.items[iid].get("metadata", {}).get("defense", 0))
	if active_buffs.has("defense") or active_buffs.has("all"):
		def += 5
	return def


func get_speed_multiplier() -> float:
	var mul := 1.0
	var boots_id := str(equipped.get("boots", ""))
	if boots_id != "" and GameData.items.has(boots_id):
		mul += float(GameData.items[boots_id].get("metadata", {}).get("speedBonus", 0.0))
	if active_buffs.has("speed") or active_buffs.has("all"):
		mul += 0.2
	return mul


func equip_item(item_id: String) -> bool:
	var item := GameData.get_item(item_id)
	if item.is_empty():
		return false
	var meta: Dictionary = item.get("metadata", {})
	var slot := str(meta.get("slot", ""))
	if slot == "" and str(meta.get("toolType", "")) == "sword":
		slot = "sword"
	if slot not in equipped:
		return false
	equipped[slot] = item_id
	EventBus.player_stats_changed.emit()
	return true


func serialize() -> Dictionary:
	return {
		"playerName": player_name,
		"farmName": farm_name,
		"customization": customization.duplicate(true),
		"maxEnergy": max_energy,
		"energy": energy,
		"maxHealth": max_health,
		"health": health,
		"gold": gold,
		"totalGoldEarned": total_gold_earned,
		"skills": skills.duplicate(true),
		"equipped": equipped.duplicate(true),
		"activeBuffs": active_buffs.duplicate(true)
	}


func deserialize(data: Dictionary) -> void:
	player_name = str(data.get("playerName", "Aria")).left(24)
	farm_name = str(data.get("farmName", "Greenfield Farm")).left(28)
	var cust: Variant = data.get("customization", {})
	if cust is Dictionary:
		set_customization(cust)
	max_energy = clampi(int(data.get("maxEnergy", 120)), 80, 500)
	energy = clampi(int(data.get("energy", max_energy)), 0, max_energy)
	max_health = clampi(int(data.get("maxHealth", 100)), 80, 500)
	health = clampi(int(data.get("health", max_health)), 1, max_health)
	gold = maxi(0, int(data.get("gold", 500)))
	total_gold_earned = maxi(0, int(data.get("totalGoldEarned", 0)))
	var sk_data: Variant = data.get("skills", {})
	if sk_data is Dictionary:
		for s in SKILL_NAMES:
			if sk_data.has(s) and sk_data[s] is Dictionary:
				skills[s] = {
					"level": clampi(int(sk_data[s].get("level", 1)), 1, 10),
					"xp": maxi(0, int(sk_data[s].get("xp", 0)))
				}
	var eq_data: Variant = data.get("equipped", {})
	if eq_data is Dictionary:
		for k in equipped.keys():
			if eq_data.has(k):
				equipped[k] = str(eq_data[k])
	active_buffs.clear()
	EventBus.player_stats_changed.emit()
