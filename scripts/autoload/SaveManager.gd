extends Node
## Versioned Save/Load Persistence Manager using user:// (IndexedDB on Web, AppData on Windows),
## with 5 save slots, atomic backups (.bak), schema migration, strict validation, and JSON export/import.

const SAVE_DIR := "user://saves/"
const SETTINGS_PATH := "user://settings.json"
const SCHEMA_VERSION := 1
const MAX_SLOTS := 5
const MAX_IMPORT_BYTES := 2 * 1024 * 1024
const FORBIDDEN_KEYS := ["__proto__", "constructor", "prototype"]

var current_slot: int = 1
var settings: Dictionary = {
	"graphicsQuality": "high", # low, medium, high
	"reducedParticles": false,
	"reducedShadows": false,
	"musicVolume": 0.7,
	"sfxVolume": 0.8,
	"ambientVolume": 0.5,
	"muted": false,
	"touchControls": "auto",
	"timeSpeed": 60.0
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	load_settings()


func _slot_path(slot_id: int) -> String:
	return "%sslot_%d.json" % [SAVE_DIR, clampi(slot_id, 1, MAX_SLOTS)]


func _bak_path(slot_id: int) -> String:
	return "%sslot_%d.bak" % [SAVE_DIR, clampi(slot_id, 1, MAX_SLOTS)]


func has_any_save() -> bool:
	for s in range(1, MAX_SLOTS + 1):
		if FileAccess.file_exists(_slot_path(s)) or FileAccess.file_exists(_bak_path(s)):
			return true
	return false


func get_latest_slot_id() -> int:
	var best_slot := -1
	var best_ts := -1
	for s in range(1, MAX_SLOTS + 1):
		var meta := get_slot_metadata(s)
		if bool(meta.get("exists", false)):
			var ts := int(meta.get("savedAtUnix", 0))
			if ts >= best_ts:
				best_ts = ts
				best_slot = s
	return best_slot


func start_new_game(p_name: String, f_name: String, custom: Dictionary, slot_id: int = 1) -> void:
	current_slot = clampi(slot_id, 1, MAX_SLOTS)
	TimeSystem.reset_calendar()
	WeatherSystem.reset_weather()
	PlayerState.reset_player()
	PlayerState.player_name = p_name.strip_edges().left(24) if p_name.strip_edges() != "" else "Aria"
	PlayerState.farm_name = f_name.strip_edges().left(28) if f_name.strip_edges() != "" else "Greenfield Farm"
	PlayerState.set_customization(custom)
	InventorySystem.reset_inventory()
	FarmingSystem.reset_farm()
	BuildingSystem.reset_buildings()
	AnimalSystem.reset_animals()
	EconomySystem.reset_economy()
	NPCSystem.reset_npcs()
	MiningSystem.reset_mining()
	QuestSystem.reset_progression()
	WorldSystem.reset_world()
	save_slot(current_slot)


func build_save_payload() -> Dictionary:
	return {
		"schemaVersion": SCHEMA_VERSION,
		"savedAtUnix": int(Time.get_unix_time_from_system()),
		"savedAtText": Time.get_datetime_string_from_system(false, true),
		"time": TimeSystem.serialize(),
		"weather": WeatherSystem.serialize(),
		"player": PlayerState.serialize(),
		"inventory": InventorySystem.serialize(),
		"farming": FarmingSystem.serialize(),
		"animals": AnimalSystem.serialize(),
		"economy": EconomySystem.serialize(),
		"npcs": NPCSystem.serialize(),
		"mining": MiningSystem.serialize(),
		"buildings": BuildingSystem.serialize(),
		"progression": QuestSystem.serialize(),
		"world": WorldSystem.serialize()
	}


func save_slot(slot_id: int = -1) -> bool:
	var sid := current_slot if slot_id == -1 else clampi(slot_id, 1, MAX_SLOTS)
	current_slot = sid
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := build_save_payload()
	if not validate_save_data(payload)["ok"]:
		push_error("Save aborted: payload failed validation.")
		return false

	var json_str := JSON.stringify(payload, "\t")
	var path := _slot_path(sid)
	var bak := _bak_path(sid)
	var tmp := path + ".tmp"

	var f_tmp := FileAccess.open(tmp, FileAccess.WRITE)
	if f_tmp == null:
		push_error("Cannot open save temp file: " + tmp)
		return false
	f_tmp.store_string(json_str)
	f_tmp.flush()
	f_tmp.close()

	# Snapshot existing valid save to .bak before replacing
	if FileAccess.file_exists(path):
		var old_txt := FileAccess.get_file_as_string(path)
		var jp := JSON.new()
		if jp.parse(old_txt) == OK and jp.data is Dictionary and bool(validate_save_data(jp.data)["ok"]):
			var fb := FileAccess.open(bak, FileAccess.WRITE)
			if fb != null:
				fb.store_string(old_txt)
				fb.close()

	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		var f_direct := FileAccess.open(path, FileAccess.WRITE)
		if f_direct == null:
			return false
		f_direct.store_string(json_str)
		f_direct.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	EventBus.game_saved.emit(sid)
	return true


func autosave() -> void:
	if TimeSystem.is_playing:
		save_slot(current_slot)


func load_slot(slot_id: int) -> Dictionary:
	var sid := clampi(slot_id, 1, MAX_SLOTS)
	var path := _slot_path(sid)
	var bak := _bak_path(sid)

	var res := _try_parse_file(path)
	if not bool(res["ok"]) and FileAccess.file_exists(bak):
		# Crash recovery fallback to .bak snapshot
		res = _try_parse_file(bak)
		if bool(res["ok"]):
			EventBus.ui_toast.emit("Recovered save slot %d from backup snapshot!" % sid, "warning")

	if not bool(res["ok"]):
		return res

	var payload: Dictionary = migrate_save(res["data"])
	var val := validate_save_data(payload)
	if not bool(val["ok"]):
		return val

	current_slot = sid
	apply_save_payload(payload)
	EventBus.game_loaded.emit(sid)
	return {"ok": true, "slot": sid}


func _try_parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Save file does not exist."}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "Unable to open save file."}
	var len_bytes := f.get_length()
	if len_bytes <= 0 or len_bytes > MAX_IMPORT_BYTES:
		f.close()
		return {"ok": false, "error": "Invalid save file size."}
	var txt := f.get_as_text()
	f.close()
	return parse_and_validate_json_string(txt)


func parse_and_validate_json_string(txt: String) -> Dictionary:
	if txt.length() > MAX_IMPORT_BYTES:
		return {"ok": false, "error": "Import exceeds maximum allowed size."}
	var jp := JSON.new()
	if jp.parse(txt) != OK:
		return {"ok": false, "error": "Corrupted JSON save format."}
	var parsed: Variant = jp.data
	if not (parsed is Dictionary):
		return {"ok": false, "error": "Corrupted JSON save format."}
	if _has_forbidden_keys(parsed):
		return {"ok": false, "error": "Security check rejected unsafe keys."}
	var migrated := migrate_save(parsed)
	var v := validate_save_data(migrated)
	if not bool(v["ok"]):
		return v
	return {"ok": true, "data": migrated}


func _has_forbidden_keys(node: Variant) -> bool:
	if node is Dictionary:
		for k in node.keys():
			if str(k) in FORBIDDEN_KEYS:
				return true
			if _has_forbidden_keys(node[k]):
				return true
	elif node is Array:
		for item in node:
			if _has_forbidden_keys(item):
				return true
	return false


func migrate_save(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var ver := int(data.get("schemaVersion", 0))
	if ver < 1:
		data["schemaVersion"] = 1
	return data


func validate_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("schemaVersion", 0)) < 1:
		return {"ok": false, "error": "Invalid or missing schemaVersion."}
	for req in ["time", "weather", "player", "inventory", "farming", "world"]:
		if not data.has(req) or not (data[req] is Dictionary):
			return {"ok": false, "error": "Missing required section: " + req}
	var pl: Dictionary = data["player"]
	if int(pl.get("gold", -1)) < 0:
		return {"ok": false, "error": "Invalid negative gold value."}
	var inv_slots: Variant = data["inventory"].get("slots", [])
	if not (inv_slots is Array):
		return {"ok": false, "error": "Invalid inventory slots."}
	for s in inv_slots:
		if s is Dictionary and not s.is_empty():
			if int(s.get("count", 0)) < 0:
				return {"ok": false, "error": "Negative item count rejected."}
	return {"ok": true}


func apply_save_payload(data: Dictionary) -> void:
	TimeSystem.deserialize(data.get("time", {}))
	WeatherSystem.deserialize(data.get("weather", {}))
	PlayerState.deserialize(data.get("player", {}))
	InventorySystem.deserialize(data.get("inventory", {}))
	FarmingSystem.deserialize(data.get("farming", {}))
	BuildingSystem.deserialize(data.get("buildings", {}))
	AnimalSystem.deserialize(data.get("animals", {}))
	EconomySystem.deserialize(data.get("economy", {}))
	NPCSystem.deserialize(data.get("npcs", {}))
	MiningSystem.deserialize(data.get("mining", {}))
	QuestSystem.deserialize(data.get("progression", {}))
	WorldSystem.deserialize(data.get("world", {}))


func get_slot_metadata(slot_id: int) -> Dictionary:
	var sid := clampi(slot_id, 1, MAX_SLOTS)
	var res := _try_parse_file(_slot_path(sid))
	if not bool(res["ok"]) and FileAccess.file_exists(_bak_path(sid)):
		res = _try_parse_file(_bak_path(sid))
	if not bool(res["ok"]):
		return {"slot": sid, "exists": false}
	var d: Dictionary = res["data"]
	var pl: Dictionary = d.get("player", {})
	var tm: Dictionary = d.get("time", {})
	var s_idx := clampi(int(tm.get("seasonIndex", 0)), 0, 3)
	return {
		"slot": sid,
		"exists": true,
		"playerName": str(pl.get("playerName", "Farmer")),
		"farmName": str(pl.get("farmName", "Greenfield Farm")),
		"year": int(tm.get("year", 1)),
		"season": TimeSystem.SEASONS[s_idx],
		"day": int(tm.get("day", 1)),
		"gold": int(pl.get("gold", 0)),
		"playSeconds": float(tm.get("totalPlaySeconds", 0.0)),
		"savedAtUnix": int(d.get("savedAtUnix", 0)),
		"savedAtText": str(d.get("savedAtText", ""))
	}


func export_save_string(slot_id: int) -> String:
	var sid := clampi(slot_id, 1, MAX_SLOTS)
	var res := _try_parse_file(_slot_path(sid))
	if not bool(res["ok"]) and FileAccess.file_exists(_bak_path(sid)):
		res = _try_parse_file(_bak_path(sid))
	if not bool(res["ok"]):
		return ""
	return JSON.stringify(res["data"], "\t")


func import_save_string(slot_id: int, json_text: String) -> Dictionary:
	var res := parse_and_validate_json_string(json_text)
	if not bool(res["ok"]):
		return res
	var sid := clampi(slot_id, 1, MAX_SLOTS)
	var f := FileAccess.open(_slot_path(sid), FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Cannot write imported save file."}
	f.store_string(JSON.stringify(res["data"], "\t"))
	f.close()
	return {"ok": true, "slot": sid}


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(settings, "\t"))
		f.close()
	apply_settings()


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary and not _has_forbidden_keys(parsed):
			for k in settings.keys():
				if parsed.has(k):
					settings[k] = parsed[k]
	apply_settings()


func apply_settings() -> void:
	AudioManager.set_volumes(
		float(settings.get("musicVolume", 0.7)),
		float(settings.get("sfxVolume", 0.8)),
		float(settings.get("ambientVolume", 0.5)),
		bool(settings.get("muted", false))
	)
	InputAdapter.touch_controls_mode = str(settings.get("touchControls", "auto"))
	TimeSystem.seconds_per_game_hour = clampf(float(settings.get("timeSpeed", 60.0)), 10.0, 300.0)
