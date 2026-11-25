extends Control
class_name BuildingPanel
## Farm Building Construction, Inventory Placement, Move & Demolish Panel.

signal placement_requested(building_id: String, via_carpenter: bool)
signal closed()

var root_win: Dictionary
var build_list: VBoxContainer
var placed_list: VBoxContainer
var player_tile_getter: Callable


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("Farm Builder & Architect", Vector2(560, 312))
	add_child(root_win["root"])
	var cb: Button = root_win["closeBtn"]
	cb.pressed.connect(close_panel)

	var body: VBoxContainer = root_win["body"]
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 8)
	body.add_child(cols)

	var left := VBoxContainer.new(); left.size_flags_horizontal = SIZE_EXPAND_FILL; cols.add_child(left)
	var ll := Label.new(); ll.text = "Construct / Place Structure:"; left.add_child(ll)
	var ls := ScrollContainer.new(); ls.size_flags_vertical = SIZE_EXPAND_FILL; left.add_child(ls)
	build_list = VBoxContainer.new(); build_list.size_flags_horizontal = SIZE_EXPAND_FILL; ls.add_child(build_list)

	var right := VBoxContainer.new(); right.size_flags_horizontal = SIZE_EXPAND_FILL; cols.add_child(right)
	var rl := Label.new(); rl.text = "Placed Buildings on Farm:"; right.add_child(rl)
	var rs := ScrollContainer.new(); rs.size_flags_vertical = SIZE_EXPAND_FILL; right.add_child(rs)
	placed_list = VBoxContainer.new(); placed_list.size_flags_horizontal = SIZE_EXPAND_FILL; rs.add_child(placed_list)

	visible = false


func open_panel(tile_cb: Callable) -> void:
	player_tile_getter = tile_cb
	InputAdapter.set_modal_locked("building", true)
	visible = true
	refresh()


func close_panel() -> void:
	visible = false
	InputAdapter.set_modal_locked("building", false)
	closed.emit()


func refresh() -> void:
	for c in build_list.get_children():
		c.queue_free()
	for c in placed_list.get_children():
		c.queue_free()

	var target_tile := Vector2i(18, 12)
	if player_tile_getter.is_valid():
		target_tile = player_tile_getter.call()

	for b in GameData.buildings_list:
		var bid := str(b["id"])
		var row := HBoxContainer.new()
		var ico := TextureRect.new()
		ico.texture = GameData.get_building_texture(bid)
		ico.custom_minimum_size = Vector2(22, 22)
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ico)

		var mats := []
		for m in b.get("materials", []):
			mats.append("%dx %s" % [int(m["count"]), GameData.get_item(str(m["itemId"]))["name"]])

		var lbl := Label.new()
		lbl.text = "%s (%dG, %s)" % [b["name"], int(b["buildCostGold"]), ", ".join(mats)]
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 9)
		row.add_child(lbl)

		var has_item := InventorySystem.has_item(str(b["itemId"]), 1)
		var btn := Button.new()
		btn.text = "Place Item" if has_item else "Build"
		btn.pressed.connect(func():
			var res := BuildingSystem.place_from_inventory(bid, WorldSystem.current_region, target_tile) if has_item else BuildingSystem.construct_via_carpenter(bid, WorldSystem.current_region, target_tile)
			if bool(res["ok"]):
				EventBus.ui_toast.emit("Built %s!" % b["name"], "success")
				close_panel()
				placement_requested.emit(bid, not has_item)
			else:
				EventBus.ui_toast.emit(str(res.get("reason", "Cannot build here.")), "warning")
		)
		row.add_child(btn)
		build_list.add_child(row)

	for pb in BuildingSystem.placed_buildings:
		var def: Dictionary = GameData.buildings.get(str(pb["buildingId"]), {})
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s @ (%d,%d)" % [def.get("name", pb["buildingId"]), int(pb["tile"][0]), int(pb["tile"][1])]
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 9)
		row.add_child(lbl)

		var mv := Button.new()
		mv.text = "Move Here"
		mv.pressed.connect(func():
			var res := BuildingSystem.move_building(str(pb["uid"]), target_tile)
			if bool(res["ok"]):
				EventBus.ui_toast.emit("Moved building!", "info")
				close_panel()
			else:
				EventBus.ui_toast.emit(str(res.get("reason", "Blocked")), "warning")
		)
		row.add_child(mv)

		var rm := Button.new()
		rm.text = "Pack"
		rm.pressed.connect(func():
			BuildingSystem.demolish_building(str(pb["uid"]))
			refresh()
			placement_requested.emit("", false)
		)
		row.add_child(rm)
		placed_list.add_child(row)
