extends Node2D
## Primary Outdoor World Scene rendering any of the 12 interconnected regions,
## dynamic farm soil/crops, placed buildings/machines, NPCs, Animals, Weather, and HUD.

const TILE_SIZE := 16

var map_container: Node2D
var entities_container: Node2D
var crops_container: Node2D
var weather_overlay: CanvasLayer
var weather_particles: CPUParticles2D
var day_tint: CanvasModulate
var hud: HUDController
var player: PlayerController

var current_map_data: Dictionary = {}
var soil_layer: TileMapLayer
var water_tiles: Dictionary = {}
var crop_sprites: Dictionary = {} # Vector2i -> Sprite2D
var interactables: Array[InteractableObject] = []
var npcs_spawned: Array[NPCEntity] = []
var animals_spawned: Array[AnimalEntity] = []
var _last_refresh_hour: int = -1


func _ready() -> void:
	map_container = Node2D.new(); map_container.name = "MapContainer"; add_child(map_container)
	crops_container = Node2D.new(); crops_container.name = "CropsContainer"; crops_container.z_index = 3; add_child(crops_container)
	entities_container = Node2D.new(); entities_container.name = "EntitiesContainer"; entities_container.z_index = 4; y_sort_enabled = true; add_child(entities_container)

	day_tint = CanvasModulate.new()
	add_child(day_tint)

	player = PlayerController.new()
	player.add_to_group("player")
	player.interacted.connect(_on_player_interact)
	player.tool_used.connect(_on_player_use_tool)
	entities_container.add_child(player)

	_build_weather_overlay()
	_build_hud()
	_connect_events()

	load_region(WorldSystem.current_region, WorldSystem.player_spawn_tile)
	TimeSystem.is_playing = true


func _build_weather_overlay() -> void:
	weather_overlay = CanvasLayer.new()
	weather_overlay.layer = 5
	add_child(weather_overlay)

	weather_particles = CPUParticles2D.new()
	weather_particles.position = Vector2(320, -10)
	weather_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	weather_particles.emission_rect_extents = Vector2(340, 10)
	weather_particles.direction = Vector2(-0.15, 1.0)
	weather_particles.spread = 8.0
	weather_particles.gravity = Vector2(0, 120)
	weather_particles.initial_velocity_min = 90.0
	weather_particles.initial_velocity_max = 150.0
	weather_particles.scale_amount_min = 1.5
	weather_particles.scale_amount_max = 2.5
	weather_particles.amount = 65
	weather_particles.lifetime = 3.2
	weather_particles.emitting = false
	weather_overlay.add_child(weather_particles)


func _build_hud() -> void:
	hud = HUDController.new()
	hud.set_player_tile_getter(func() -> Vector2i: return player.get_target_tile())
	hud.build_refreshed.connect(func(): load_region(WorldSystem.current_region, player.get_tile_pos()))
	hud.return_to_menu_requested.connect(func():
		SaveManager.autosave()
		TimeSystem.is_playing = false
		get_tree().change_scene_to_file("res://scenes/menu/MainMenuScene.tscn")
	)
	add_child(hud)


func _connect_events() -> void:
	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.weather_changed.connect(func(_w): _refresh_weather_and_tint())
	EventBus.day_started.connect(func(_y, _s, _d):
		SaveManager.autosave()
		load_region(WorldSystem.current_region, player.get_tile_pos())
	)


func _on_time_ticked(h: int, _m: int) -> void:
	_refresh_weather_and_tint()
	if h != _last_refresh_hour:
		_last_refresh_hour = h
		_rebuild_npcs()


func load_region(region_id: String, spawn_tile: Vector2i) -> void:
	for c in map_container.get_children():
		c.queue_free()
	for c in crops_container.get_children():
		c.queue_free()
	for obj in interactables:
		if is_instance_valid(obj):
			obj.queue_free()
	interactables.clear()
	for a in animals_spawned:
		if is_instance_valid(a):
			a.queue_free()
	animals_spawned.clear()
	crop_sprites.clear()

	if not GameData.regions.has(region_id):
		region_id = "greenfield_farm"
	WorldSystem.current_region = region_id

	var reg: Dictionary = GameData.regions[region_id]
	current_map_data = RegionMapBuilder.build_region(map_container, region_id, TimeSystem.get_season())
	soil_layer = current_map_data["soil"]
	water_tiles = current_map_data["waterTiles"]

	var w := int(current_map_data["width"])
	var h := int(current_map_data["height"])
	player.set_camera_limits(Vector2i(w * TILE_SIZE, h * TILE_SIZE))
	player.global_position = Vector2(
		clampi(spawn_tile.x, 2, w - 3) * TILE_SIZE + 8,
		clampi(spawn_tile.y, 2, h - 3) * TILE_SIZE + 8
	)

	_spawn_region_connections(reg)
	_spawn_region_landmarks(region_id, reg)
	_spawn_placed_buildings(region_id)
	_spawn_natural_resources(region_id, w, h)
	_spawn_forage(region_id)
	_rebuild_farm_visuals(region_id)
	_rebuild_npcs()
	_rebuild_animals(region_id)
	_refresh_weather_and_tint()
	hud.refresh_all()


func _spawn_region_connections(reg: Dictionary) -> void:
	for conn in reg.get("connections", []):
		var to_id := str(conn["to"])
		var ft: Array = conn["fromTile"]
		var tt: Array = conn["toTile"]
		var target_reg: Dictionary = GameData.regions.get(to_id, {})
		var label_txt := "-> " + str(target_reg.get("name", to_id))
		var obj := InteractableObject.new()
		obj.setup(
			"portal",
			Vector2(int(ft[0]) * TILE_SIZE + 8, int(ft[1]) * TILE_SIZE + 8),
			RegionMapBuilder.get_tile_from_atlas(Vector2i(13, 2)),
			{"toRegion": to_id, "toTile": Vector2i(int(tt[0]), int(tt[1]))},
			label_txt
		)
		obj.body_entered.connect(func(body: Node):
			if body == player:
				var ok := WorldSystem.travel_to(to_id, Vector2i(int(tt[0]), int(tt[1])))
				if ok:
					call_deferred("load_region", to_id, Vector2i(int(tt[0]), int(tt[1])))
		)
		map_container.add_child(obj)
		interactables.append(obj)

	for intr in reg.get("interiors", []):
		var iid := str(intr["id"])
		var dt: Array = intr["doorTile"]
		var st: Array = intr["spawnTile"]
		var tex := GameData.get_building_texture("shed" if iid != "greenhouse_interior" else "greenhouse")
		if iid == "mine_shaft":
			tex = RegionMapBuilder.get_tile_from_atlas(Vector2i(11, 2))
		var door := InteractableObject.new()
		door.setup(
			"interior_door",
			Vector2(int(dt[0]) * TILE_SIZE + 8, int(dt[1]) * TILE_SIZE + 8),
			tex,
			{"interiorId": iid, "returnTile": Vector2i(int(st[0]), int(st[1]))},
			str(intr["name"])
		)
		map_container.add_child(door)
		interactables.append(door)


func _spawn_region_landmarks(region_id: String, _reg: Dictionary) -> void:
	if region_id == "greenfield_farm":
		# Shipping bin, Well, Crafting Bench, Storage Chest, Mailbox, Barnaby Stall
		_add_obj("shipping_bin", Vector2i(14, 10), RegionMapBuilder.get_tile_from_atlas(Vector2i(15, 1)), {}, "Ship Bin")
		_add_obj("well", Vector2i(33, 10), RegionMapBuilder.get_tile_from_atlas(Vector2i(15, 2)), {}, "Water Well")
		_add_obj("workbench", Vector2i(12, 10), RegionMapBuilder.get_tile_from_atlas(Vector2i(3, 3)), {}, "Workbench")
		_add_obj("chest", Vector2i(13, 10), RegionMapBuilder.get_tile_from_atlas(Vector2i(2, 3)), {"chestUid": "farm_starter_chest"}, "Chest")
		_add_obj("mailbox", Vector2i(11, 11), RegionMapBuilder.get_tile_from_atlas(Vector2i(14, 2)), {}, "Mailbox")
		_add_obj("shop_stall", Vector2i(42, 14), RegionMapBuilder.get_tile_from_atlas(Vector2i(13, 2)), {"shopId": "barnaby_ranch"}, "Ranch Shop")

	# Outdoor Merchant Stalls for regional shops
	for sh in GameData.shops_list:
		var sid := str(sh["id"])
		if str(sh["region"]) == region_id and sid not in ["clara_general_store", "rowan_smithy", "maya_tavern", "julian_clinic", "barnaby_ranch"]:
			var pos_t := Vector2i(14, 18) if sid == "toby_carpenter" else Vector2i(26, 15)
			if region_id == "sunflower_beach":
				pos_t = Vector2i(22, 16)
			elif region_id == "ancient_mine":
				pos_t = Vector2i(26, 16)
			_add_obj("shop_stall", pos_t, RegionMapBuilder.get_tile_from_atlas(Vector2i(13, 2)), {"shopId": sid}, str(sh["name"]))

	# Festival Booth if festival is today in this region
	var fest := QuestSystem.get_today_festival()
	if not fest.is_empty() and str(fest["region"]) == region_id:
		_add_obj("festival_booth", Vector2i(24, 18), RegionMapBuilder.get_tile_from_atlas(Vector2i(12, 2)), {"festival": fest}, str(fest["name"]))


func _add_obj(obj_kind: String, tile: Vector2i, tex: Texture2D, payload: Dictionary, tag: String) -> void:
	var obj := InteractableObject.new()
	obj.setup(obj_kind, Vector2(tile.x * TILE_SIZE + 8, tile.y * TILE_SIZE + 8), tex, payload, tag)
	map_container.add_child(obj)
	interactables.append(obj)


func _spawn_placed_buildings(region_id: String) -> void:
	for b in BuildingSystem.placed_buildings:
		if str(b.get("region", "")) != region_id:
			continue
		var bid := str(b["buildingId"])
		var t_arr: Array = b["tile"]
		var tp := Vector2i(int(t_arr[0]), int(t_arr[1]))
		var tex := GameData.get_building_texture(bid)
		var def: Dictionary = GameData.buildings.get(bid, {})
		var kind := "machine"
		if bid in ["storage_chest", "stone_chest"]:
			kind = "chest"
		elif bid == "shipping_bin_extra":
			kind = "shipping_bin"
		elif bid == "well":
			kind = "well"
		var tag := str(def.get("name", bid))
		if str(b.get("readyItem", "")) != "":
			tag = "READY!"
		_add_obj(kind, tp, tex, {"uid": b["uid"], "chestUid": b["uid"], "buildingId": bid}, tag)


func _spawn_natural_resources(region_id: String, w: int, h: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = region_id.hash() + TimeSystem.year * 17
	var biome := str(GameData.regions[region_id].get("biome", "farm"))
	var tree_tile := Vector2i(1, 2)
	if biome == "snow": tree_tile = Vector2i(0, 2)
	elif biome == "desert" or biome == "beach": tree_tile = Vector2i(3, 2)
	elif biome == "mushroom": tree_tile = Vector2i(4, 2)
	elif biome == "sanctuary": tree_tile = Vector2i(5, 2)

	for i in range(14):
		var tx := rng.randi_range(4, w - 5)
		var ty := rng.randi_range(5, h - 5)
		var tp := Vector2i(tx, ty)
		if region_id == "greenfield_farm" and Rect2i(9, 7, 30, 23).has_point(tp):
			continue
		if water_tiles.has(tp):
			continue
		var nkey := "%s:%d,%d" % [region_id, tx, ty]
		if WorldSystem.harvested_nodes.has(nkey):
			continue
		if i % 3 == 0:
			_add_obj("rock", tp, RegionMapBuilder.get_tile_from_atlas(Vector2i(6, 2)), {"nodeKey": nkey, "hp": 3}, "")
		else:
			_add_obj("tree", tp, RegionMapBuilder.get_tile_from_atlas(tree_tile), {"nodeKey": nkey, "hp": 3}, "")


func _spawn_forage(region_id: String) -> void:
	var arr: Array = WorldSystem.daily_forage.get(region_id, [])
	for idx in range(arr.size()):
		var f: Dictionary = arr[idx]
		var iid := str(f["itemId"])
		var t: Array = f["tile"]
		_add_obj("forage", Vector2i(int(t[0]), int(t[1])), GameData.get_item_texture(iid), {"forageIndex": idx, "itemId": iid}, "")


func _rebuild_farm_visuals(region_id: String) -> void:
	if soil_layer == null:
		return
	soil_layer.clear()
	for s in crop_sprites.values():
		if is_instance_valid(s):
			s.queue_free()
	crop_sprites.clear()

	var reg_tiles := FarmingSystem.get_region_tiles(region_id)
	for pos_v in reg_tiles.keys():
		var pos: Vector2i = pos_v
		var t: Dictionary = reg_tiles[pos]
		if bool(t.get("tilled", false)):
			var soil_tile := RegionMapBuilder.T_TILLED_WET if bool(t.get("watered", false)) else RegionMapBuilder.T_TILLED_DRY
			soil_layer.set_cell(pos, 0, soil_tile)

		var cid := str(t.get("cropId", ""))
		if cid != "":
			var spr := Sprite2D.new()
			spr.position = Vector2(pos.x * TILE_SIZE + 8, pos.y * TILE_SIZE + 6)
			if bool(t.get("withered", false)):
				spr.texture = GameData.get_crop_texture(cid, 1)
				spr.modulate = Color(0.45, 0.35, 0.25)
			else:
				spr.texture = GameData.get_crop_texture(cid, int(t.get("stage", 0)))
			crops_container.add_child(spr)
			crop_sprites[pos] = spr


func _rebuild_npcs() -> void:
	for n in npcs_spawned:
		if is_instance_valid(n):
			n.queue_free()
	npcs_spawned.clear()

	var list := NPCSystem.get_npcs_in_region(WorldSystem.current_region)
	for entry in list:
		var ent := NPCEntity.new()
		var loc: Dictionary = entry["loc"]
		ent.setup(entry["npc"], loc["tile"])
		entities_container.add_child(ent)
		npcs_spawned.append(ent)


func _rebuild_animals(region_id: String) -> void:
	if region_id != "greenfield_farm":
		return
	for i in range(AnimalSystem.owned_animals.size()):
		var a: Dictionary = AnimalSystem.owned_animals[i]
		var ae := AnimalEntity.new()
		var spawn_p := Vector2((38 + (i % 6)) * TILE_SIZE, (16 + (i / 6) * 2) * TILE_SIZE)
		ae.setup(a, spawn_p)
		entities_container.add_child(ae)
		animals_spawned.append(ae)


func _refresh_weather_and_tint() -> void:
	var base := TimeSystem.get_ambient_tint()
	var w := WeatherSystem.current_weather
	var part_disabled := bool(SaveManager.settings.get("reducedParticles", false))
	weather_particles.emitting = false

	if w == "rainy" or w == "stormy":
		day_tint.color = base * Color(0.78, 0.84, 0.96)
		if not part_disabled:
			weather_particles.color = Color("#87cef5cc")
			weather_particles.gravity = Vector2(0, 260)
			weather_particles.amount = 95 if w == "stormy" else 60
			weather_particles.emitting = true
	elif w == "snowy":
		day_tint.color = base * Color(0.92, 0.96, 1.0)
		if not part_disabled:
			weather_particles.color = Color("#ffffffdd")
			weather_particles.gravity = Vector2(0, 45)
			weather_particles.amount = 55
			weather_particles.emitting = true
	elif w == "foggy":
		day_tint.color = base * Color(0.86, 0.88, 0.90)
	else:
		day_tint.color = base


func _on_player_interact() -> void:
	# 1. Nearest NPC
	var best_npc: NPCEntity = null
	var best_d := 28.0
	for n in npcs_spawned:
		if is_instance_valid(n):
			var d := n.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best_npc = n
	if best_npc != null:
		hud.dialogue_panel.open_npc(best_npc.npc_id)
		return

	# 2. Nearest Farm Animal (Collect -> Feed -> Pet)
	for ae in animals_spawned:
		if is_instance_valid(ae) and ae.global_position.distance_to(player.global_position) < 24.0:
			var uid := ae.animal_uid
			if not AnimalSystem.collect_product(uid):
				if not AnimalSystem.feed_animal(uid):
					AnimalSystem.pet_animal(uid)
			for a_data in AnimalSystem.owned_animals:
				if a_data["uid"] == uid:
					ae.refresh_badge(bool(a_data["productReady"]))
					break
			return

	# 3. Mature crop under or in front of player
	for tp in [player.get_target_tile(), player.get_tile_pos()]:
		if FarmingSystem.harvest_tile(WorldSystem.current_region, tp):
			_rebuild_farm_visuals(WorldSystem.current_region)
			return

	# 4. Nearest InteractableObject
	var best_obj: InteractableObject = null
	var best_od := 28.0
	for obj in interactables:
		if is_instance_valid(obj):
			var d := obj.global_position.distance_to(player.global_position)
			if d < best_od:
				best_od = d
				best_obj = obj
	if best_obj != null:
		_handle_object_interact(best_obj)


func _handle_object_interact(obj: InteractableObject) -> void:
	match obj.kind:
		"forage":
			if WorldSystem.collect_forage(WorldSystem.current_region, int(obj.data_dict["forageIndex"])):
				load_region(WorldSystem.current_region, player.get_tile_pos())
		"shipping_bin":
			if not EconomySystem.ship_from_slot(InventorySystem.selected_slot, 1):
				EventBus.ui_toast.emit("Hold a crop, fish, or mineral to ship it!", "info")
		"well":
			PlayerState.restore_energy(25)
			AudioManager.play_sfx("water")
			EventBus.ui_toast.emit("Drank cool well water (+25 Energy).", "success")
		"workbench":
			hud.craft_panel.open_panel("crafting")
		"chest":
			hud.inv_panel.open_panel(str(obj.data_dict.get("chestUid", "farm_starter_chest")))
		"mailbox":
			EventBus.ui_toast.emit("Welcome to %s! Check Quests (J) & Shops in Willow Village." % PlayerState.farm_name, "info")
		"shop_stall":
			hud.shop_panel.open_shop(str(obj.data_dict["shopId"]))
		"machine":
			if BuildingSystem.interact_machine(str(obj.data_dict.get("uid", ""))):
				load_region(WorldSystem.current_region, player.get_tile_pos())
		"festival_booth":
			var fest: Dictionary = obj.data_dict["festival"]
			var fres := QuestSystem.participate_in_festival(str(fest["id"]))
			EventBus.ui_toast.emit(str(fres["message"]), "success" if bool(fres["ok"]) else "info")
		"interior_door":
			WorldSystem.return_region = WorldSystem.current_region
			WorldSystem.return_tile = obj.data_dict["returnTile"]
			var iid := str(obj.data_dict["interiorId"])
			WorldSystem.current_region = iid
			if iid == "mine_shaft":
				get_tree().change_scene_to_file("res://scenes/world/MineScene.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/world/InteriorScene.tscn")
		"portal":
			var to_id := str(obj.data_dict["toRegion"])
			var tt: Vector2i = obj.data_dict["toTile"]
			if WorldSystem.travel_to(to_id, tt):
				load_region(to_id, tt)


func _on_player_use_tool(target_tile: Vector2i, facing: Vector2i) -> void:
	# Priority harvest if mature crop in front
	if FarmingSystem.harvest_tile(WorldSystem.current_region, target_tile):
		_rebuild_farm_visuals(WorldSystem.current_region)
		return

	var sel_id := InventorySystem.get_selected_item_id()
	if sel_id == "":
		return
	var def := GameData.get_item(sel_id)
	var cat := str(def.get("category", ""))
	var meta: Dictionary = def.get("metadata", {})
	var tool_type := str(meta.get("toolType", ""))
	var power := int(meta.get("power", 1))
	var e_cost := int(meta.get("energyCost", 2))

	if cat == "Seeds":
		if FarmingSystem.plant_seed(WorldSystem.current_region, target_tile, sel_id):
			_rebuild_farm_visuals(WorldSystem.current_region)
		return

	if meta.has("fertilizer"):
		FarmingSystem.apply_fertilizer(WorldSystem.current_region, target_tile, sel_id)
		return

	if meta.has("buildingId"):
		var res := BuildingSystem.place_from_inventory(str(meta["buildingId"]), WorldSystem.current_region, target_tile)
		if bool(res["ok"]):
			load_region(WorldSystem.current_region, player.get_tile_pos())
		else:
			EventBus.ui_toast.emit(str(res["reason"]), "warning")
		return

	match tool_type:
		"hoe":
			if PlayerState.consume_energy(e_cost):
				FarmingSystem.till_tile(WorldSystem.current_region, target_tile, power, facing)
				_rebuild_farm_visuals(WorldSystem.current_region)
		"watering_can":
			if PlayerState.consume_energy(e_cost):
				FarmingSystem.water_tile(WorldSystem.current_region, target_tile, power, facing)
				_rebuild_farm_visuals(WorldSystem.current_region)
		"scythe":
			FarmingSystem.clear_tile(WorldSystem.current_region, target_tile)
			_rebuild_farm_visuals(WorldSystem.current_region)
		"fishing_rod":
			if _is_near_water(target_tile) or _is_near_water(player.get_tile_pos()):
				if PlayerState.consume_energy(e_cost):
					AudioManager.play_sfx("fish_cast")
					var biome := str(GameData.regions[WorldSystem.current_region].get("fishBiome", "crystal_lake"))
					hud.fish_panel.start_minigame(biome)
			else:
				EventBus.ui_toast.emit("Stand near water (lake, river, pond, or ocean) to fish!", "info")
		"axe":
			_hit_natural_node("tree", "wood", target_tile, e_cost)
		"pickaxe":
			_hit_natural_node("rock", "stone", target_tile, e_cost)
		_:
			InventorySystem.use_item_in_slot(InventorySystem.selected_slot)


func _is_near_water(tile: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if water_tiles.has(tile + Vector2i(dx, dy)):
				return true
	return false


func _hit_natural_node(node_kind: String, drop_id: String, target_tile: Vector2i, e_cost: int) -> void:
	var world_pt := Vector2(target_tile.x * TILE_SIZE + 8, target_tile.y * TILE_SIZE + 8)
	for obj in interactables:
		if is_instance_valid(obj) and obj.kind == node_kind and obj.global_position.distance_to(world_pt) < 22.0:
			if not PlayerState.consume_energy(e_cost):
				return
			obj.hp -= 1
			AudioManager.play_sfx("axe" if node_kind == "tree" else "pickaxe")
			if obj.hp <= 0:
				WorldSystem.harvested_nodes[str(obj.data_dict["nodeKey"])] = 4
				InventorySystem.add_item(drop_id, 4)
				if node_kind == "tree":
					InventorySystem.add_item("sap", 2)
					PlayerState.add_xp("foraging", 10)
				else:
					InventorySystem.add_item("coal", 1)
					PlayerState.add_xp("mining", 8)
				obj.queue_free()
			return


func _unhandled_input(event: InputEvent) -> void:
	if InputAdapter.is_gameplay_locked():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_click := get_global_mouse_position()
		if player.global_position.distance_to(world_click) < 34.0:
			var click_tile := Vector2i(int(floor(world_click.x / TILE_SIZE)), int(floor(world_click.y / TILE_SIZE)))
			_on_player_use_tool(click_tile, player.facing_dir)
		else:
			player.set_touch_move_target(world_click)
