extends Node2D
## Cozy Indoor Scene for Farmhouse (Bed/Kitchen/Chest/Workbench/TV), Greenhouse (All-season farming),
## and Village Shops (General Store, Blacksmith, Tavern, Clinic).

const TILE_SIZE := 16
const ROOM_W := 24
const ROOM_H := 18

var interior_id: String = "farmhouse"
var tile_layer: TileMapLayer
var crops_container: Node2D
var soil_layer: TileMapLayer
var player: PlayerController
var hud: HUDController
var interactables: Array[InteractableObject] = []
var sleep_dialog: ConfirmationDialog


func _ready() -> void:
	interior_id = WorldSystem.current_region
	tile_layer = TileMapLayer.new()
	tile_layer.tile_set = RegionMapBuilder.get_shared_tileset()
	add_child(tile_layer)

	soil_layer = TileMapLayer.new()
	soil_layer.tile_set = RegionMapBuilder.get_shared_tileset()
	soil_layer.z_index = 1
	add_child(soil_layer)

	crops_container = Node2D.new()
	crops_container.z_index = 2
	add_child(crops_container)

	_build_interior_map()

	player = PlayerController.new()
	player.add_to_group("player")
	player.global_position = Vector2(ROOM_W / 2 * TILE_SIZE + 8, (ROOM_H - 3) * TILE_SIZE + 8)
	player.set_camera_limits(Vector2i(ROOM_W * TILE_SIZE, ROOM_H * TILE_SIZE))
	player.interacted.connect(_on_interact)
	player.tool_used.connect(_on_use_tool)
	add_child(player)

	hud = HUDController.new()
	hud.set_player_tile_getter(func() -> Vector2i: return player.get_target_tile())
	hud.build_refreshed.connect(_refresh_greenhouse_crops)
	hud.return_to_menu_requested.connect(func():
		SaveManager.autosave()
		TimeSystem.is_playing = false
		get_tree().change_scene_to_file("res://scenes/menu/MainMenuScene.tscn")
	)
	add_child(hud)

	sleep_dialog = ConfirmationDialog.new()
	sleep_dialog.title = "Sleep Until Morning?"
	sleep_dialog.dialog_text = "Rest in your bed to restore Energy, advance crops, and save your game?"
	sleep_dialog.confirmed.connect(_on_confirm_sleep)
	hud.add_child(sleep_dialog)

	_refresh_greenhouse_crops()
	hud.refresh_all()


func _build_interior_map() -> void:
	for y in range(ROOM_H):
		for x in range(ROOM_W):
			var tp := Vector2i(x, y)
			if x == 0 or y == 0 or x == ROOM_W - 1 or y == ROOM_H - 1:
				tile_layer.set_cell(tp, 0, RegionMapBuilder.T_INT_WALL)
			elif interior_id == "greenhouse_interior" and Rect2i(6, 6, 12, 8).has_point(tp):
				tile_layer.set_cell(tp, 0, RegionMapBuilder.T_DIRT)
			elif x >= 8 and x <= 15 and y >= 7 and y <= 12:
				tile_layer.set_cell(tp, 0, RegionMapBuilder.T_INT_RUG)
			else:
				tile_layer.set_cell(tp, 0, RegionMapBuilder.T_INT_WOOD)

	# Exit door at bottom center
	_add_obj("exit_door", Vector2i(ROOM_W / 2, ROOM_H - 2), RegionMapBuilder.get_tile_from_atlas(Vector2i(13, 2)), "Exit Outside")

	if interior_id == "farmhouse":
		_add_obj("bed", Vector2i(5, 4), RegionMapBuilder.get_tile_from_atlas(Vector2i(0, 3)), "Bed (Sleep)")
		_add_obj("stove", Vector2i(10, 4), RegionMapBuilder.get_tile_from_atlas(Vector2i(1, 3)), "Kitchen (Cook)")
		_add_obj("chest", Vector2i(14, 4), RegionMapBuilder.get_tile_from_atlas(Vector2i(2, 3)), "Storage Chest")
		_add_obj("workbench", Vector2i(18, 4), RegionMapBuilder.get_tile_from_atlas(Vector2i(3, 3)), "Workbench")
		_add_obj("tv", Vector2i(7, 4), RegionMapBuilder.get_tile_from_atlas(Vector2i(13, 3)), "TV Forecast")
	elif interior_id in ["general_store", "blacksmith_shop", "tavern", "clinic"]:
		var shop_map := {
			"general_store": "clara_general_store",
			"blacksmith_shop": "rowan_smithy",
			"tavern": "maya_tavern",
			"clinic": "julian_clinic"
		}
		var sid: String = shop_map[interior_id]
		var sdef: Dictionary = GameData.shops.get(sid, {})
		_add_obj("shop_counter", Vector2i(ROOM_W / 2, 6), RegionMapBuilder.get_tile_from_atlas(Vector2i(13, 2)), "Shop Counter", {"shopId": sid})
		var owner_id := str(sdef.get("ownerNpcId", "clara"))
		if GameData.npcs.has(owner_id):
			var npc_ent := NPCEntity.new()
			npc_ent.setup(GameData.npcs[owner_id], Vector2i(ROOM_W / 2, 4))
			add_child(npc_ent)
			_add_obj("npc_talk", Vector2i(ROOM_W / 2, 4), null, "", {"npcId": owner_id})


func _add_obj(kind: String, tile: Vector2i, tex: Texture2D, tag: String, payload: Dictionary = {}) -> void:
	var obj := InteractableObject.new()
	obj.setup(kind, Vector2(tile.x * TILE_SIZE + 8, tile.y * TILE_SIZE + 8), tex, payload, tag)
	add_child(obj)
	interactables.append(obj)


func _refresh_greenhouse_crops() -> void:
	if interior_id != "greenhouse_interior":
		return
	soil_layer.clear()
	for c in crops_container.get_children():
		c.queue_free()
	var reg_tiles := FarmingSystem.get_region_tiles("greenhouse_interior")
	for pv in reg_tiles.keys():
		var pos: Vector2i = pv
		var t: Dictionary = reg_tiles[pos]
		if bool(t.get("tilled", false)):
			soil_layer.set_cell(pos, 0, RegionMapBuilder.T_TILLED_WET if bool(t.get("watered", false)) else RegionMapBuilder.T_TILLED_DRY)
		var cid := str(t.get("cropId", ""))
		if cid != "":
			var spr := Sprite2D.new()
			spr.position = Vector2(pos.x * TILE_SIZE + 8, pos.y * TILE_SIZE + 6)
			spr.texture = GameData.get_crop_texture(cid, int(t.get("stage", 0)))
			crops_container.add_child(spr)


func _on_interact() -> void:
	if interior_id == "greenhouse_interior":
		for tp in [player.get_target_tile(), player.get_tile_pos()]:
			if FarmingSystem.harvest_tile("greenhouse_interior", tp):
				_refresh_greenhouse_crops()
				return

	var best: InteractableObject = null
	var best_d := 28.0
	for obj in interactables:
		if is_instance_valid(obj):
			var d := obj.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = obj
	if best == null:
		return

	match best.kind:
		"exit_door":
			WorldSystem.current_region = WorldSystem.return_region
			WorldSystem.player_spawn_tile = WorldSystem.return_tile
			get_tree().change_scene_to_file("res://scenes/world/WorldScene.tscn")
		"bed":
			sleep_dialog.popup_centered()
		"stove":
			hud.craft_panel.open_panel("cooking")
		"workbench":
			hud.craft_panel.open_panel("crafting")
		"chest":
			hud.inv_panel.open_panel("farm_starter_chest")
		"tv":
			EventBus.ui_toast.emit("Tomorrow's Forecast: %s!" % WeatherSystem.tomorrow_weather.capitalize(), "info")
		"shop_counter":
			hud.shop_panel.open_shop(str(best.data_dict["shopId"]))
		"npc_talk":
			hud.dialogue_panel.open_npc(str(best.data_dict["npcId"]))


func _on_use_tool(target_tile: Vector2i, facing: Vector2i) -> void:
	if interior_id != "greenhouse_interior":
		InventorySystem.use_item_in_slot(InventorySystem.selected_slot)
		return
	if FarmingSystem.harvest_tile("greenhouse_interior", target_tile):
		_refresh_greenhouse_crops()
		return
	var sel_id := InventorySystem.get_selected_item_id()
	var def := GameData.get_item(sel_id)
	if str(def.get("category", "")) == "Seeds":
		if FarmingSystem.plant_seed("greenhouse_interior", target_tile, sel_id):
			_refresh_greenhouse_crops()
		return
	var tool_type := str(def.get("metadata", {}).get("toolType", ""))
	if tool_type == "hoe" and PlayerState.consume_energy(2):
		FarmingSystem.till_tile("greenhouse_interior", target_tile, int(def["metadata"].get("power", 1)), facing)
		_refresh_greenhouse_crops()
	elif tool_type == "watering_can" and PlayerState.consume_energy(2):
		FarmingSystem.water_tile("greenhouse_interior", target_tile, int(def["metadata"].get("power", 1)), facing)
		_refresh_greenhouse_crops()


func _on_confirm_sleep() -> void:
	AudioManager.play_sfx("sleep")
	TimeSystem.sleep_to_next_day(false)
	SaveManager.autosave()
	EventBus.ui_toast.emit("Slept well! Good morning, Day %d of %s!" % [TimeSystem.day, TimeSystem.get_season().capitalize()], "success")
	hud.refresh_all()
