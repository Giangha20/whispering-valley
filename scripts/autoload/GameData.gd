extends Node
## Loads and caches all JSON game databases and Pixel Art sprite atlases.

var items: Dictionary = {}
var items_list: Array = []
var crops: Dictionary = {}
var crops_list: Array = []
var fish: Dictionary = {}
var fish_list: Array = []
var animals: Dictionary = {}
var animals_list: Array = []
var regions: Dictionary = {}
var regions_list: Array = []
var npcs: Dictionary = {}
var npcs_list: Array = []
var shops: Dictionary = {}
var shops_list: Array = []
var crafting: Dictionary = {}
var crafting_list: Array = []
var cooking: Dictionary = {}
var cooking_list: Array = []
var quests: Dictionary = {}
var quests_list: Array = []
var festivals: Dictionary = {}
var festivals_list: Array = []
var achievements: Dictionary = {}
var achievements_list: Array = []
var buildings: Dictionary = {}
var buildings_list: Array = []
var outfits: Dictionary = {}
var monsters: Dictionary = {}
var monsters_list: Array = []

var _items_atlas: Texture2D
var _crops_atlas: Texture2D
var _animals_atlas: Texture2D
var _monsters_atlas: Texture2D
var _buildings_atlas: Texture2D
var _ui_icons: Texture2D
var _tex_cache: Dictionary = {}


func _ready() -> void:
	load_all_data()


func load_all_data() -> void:
	items_list = _load_json_array("res://data/items.json")
	items = _index_by_id(items_list)

	crops_list = _load_json_array("res://data/crops.json")
	crops = _index_by_id(crops_list)

	fish_list = _load_json_array("res://data/fish.json")
	fish = _index_by_id(fish_list)

	animals_list = _load_json_array("res://data/animals.json")
	animals = _index_by_id(animals_list)

	regions_list = _load_json_array("res://data/regions.json")
	regions = _index_by_id(regions_list)

	npcs_list = _load_json_array("res://data/npcs.json")
	npcs = _index_by_id(npcs_list)

	shops_list = _load_json_array("res://data/shops.json")
	shops = _index_by_id(shops_list)

	crafting_list = _load_json_array("res://data/crafting.json")
	crafting = _index_by_id(crafting_list)

	cooking_list = _load_json_array("res://data/cooking.json")
	cooking = _index_by_id(cooking_list)

	quests_list = _load_json_array("res://data/quests.json")
	quests = _index_by_id(quests_list)

	festivals_list = _load_json_array("res://data/festivals.json")
	festivals = _index_by_id(festivals_list)

	achievements_list = _load_json_array("res://data/achievements.json")
	achievements = _index_by_id(achievements_list)

	buildings_list = _load_json_array("res://data/buildings.json")
	buildings = _index_by_id(buildings_list)

	monsters_list = _load_json_array("res://data/monsters.json")
	monsters = _index_by_id(monsters_list)

	var outfits_raw: Variant = _load_json_variant("res://data/outfits.json")
	if outfits_raw is Dictionary:
		outfits = outfits_raw

	_load_atlases()


func _load_atlases() -> void:
	_items_atlas = _safe_load_tex("res://assets/sprites/items/items_atlas.png")
	_crops_atlas = _safe_load_tex("res://assets/sprites/crops/crops_atlas.png")
	_animals_atlas = _safe_load_tex("res://assets/sprites/animals/animals_atlas.png")
	_monsters_atlas = _safe_load_tex("res://assets/sprites/monsters/monsters_atlas.png")
	_buildings_atlas = _safe_load_tex("res://assets/sprites/buildings/buildings_atlas.png")
	_ui_icons = _safe_load_tex("res://assets/ui/ui_icons.png")


func _safe_load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _load_json_variant(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: " + path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		push_error("Invalid JSON in: " + path)
	return parsed


func _load_json_array(path: String) -> Array:
	var v: Variant = _load_json_variant(path)
	if v is Array:
		return v
	return []


func _index_by_id(arr: Array) -> Dictionary:
	var dict := {}
	for entry in arr:
		if entry is Dictionary and entry.has("id"):
			dict[str(entry["id"])] = entry
	return dict


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func get_crop(crop_id: String) -> Dictionary:
	return crops.get(crop_id, {})


func get_item_texture(item_id: String) -> Texture2D:
	var cache_key := "item:" + item_id
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	if _items_atlas == null or not items.has(item_id):
		return null
	var idx := int(items[item_id].get("atlasIndex", 0))
	var col := idx % 22
	var row := idx / 22
	var at := AtlasTexture.new()
	at.atlas = _items_atlas
	at.region = Rect2(col * 16, row * 16, 16, 16)
	_tex_cache[cache_key] = at
	return at


func get_crop_texture(crop_id: String, stage: int) -> Texture2D:
	var clamped_stage := clampi(stage, 0, 4)
	var cache_key := "crop:%s:%d" % [crop_id, clamped_stage]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	if _crops_atlas == null or not crops.has(crop_id):
		return null
	var row := int(crops[crop_id].get("atlasRow", 0))
	var at := AtlasTexture.new()
	at.atlas = _crops_atlas
	at.region = Rect2(clamped_stage * 16, row * 16, 16, 16)
	_tex_cache[cache_key] = at
	return at


func get_animal_texture(species_id: String, frame: int = 0) -> Texture2D:
	var row := 0
	for i in range(animals_list.size()):
		if animals_list[i]["id"] == species_id:
			row = i
			break
	var cache_key := "animal:%s:%d" % [species_id, frame % 4]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	if _animals_atlas == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = _animals_atlas
	at.region = Rect2((frame % 4) * 16, row * 16, 16, 16)
	_tex_cache[cache_key] = at
	return at


func get_monster_texture(monster_id: String, frame: int = 0) -> Texture2D:
	var row := 0
	for i in range(monsters_list.size()):
		if monsters_list[i]["id"] == monster_id:
			row = i
			break
	var cache_key := "monster:%s:%d" % [monster_id, frame % 4]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	if _monsters_atlas == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = _monsters_atlas
	at.region = Rect2((frame % 4) * 24, row * 24, 24, 24)
	_tex_cache[cache_key] = at
	return at


func get_building_texture(building_id: String) -> Texture2D:
	var idx := 0
	for i in range(buildings_list.size()):
		if buildings_list[i]["id"] == building_id:
			idx = i
			break
	var cache_key := "bldg:%s" % building_id
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	if _buildings_atlas == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = _buildings_atlas
	at.region = Rect2((idx % 8) * 48, (idx / 8) * 48, 48, 48)
	_tex_cache[cache_key] = at
	return at


func get_npc_portrait(npc_id: String, expression: int = 0) -> Texture2D:
	var cache_key := "portrait:%s:%d" % [npc_id, clampi(expression, 0, 2)]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	var path := "res://assets/portraits/%s.png" % npc_id
	var tex := _safe_load_tex(path)
	if tex == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(clampi(expression, 0, 2) * 32, 0, 32, 32)
	_tex_cache[cache_key] = at
	return at
