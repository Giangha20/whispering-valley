extends Control
class_name CraftingCookingPanel
## Tabbed Crafting (104 recipes) and Cooking (84 dishes) Panel with availability filtering.

signal closed()

var mode: String = "crafting" # "crafting" or "cooking"
var only_craftable: bool = false
var root_win: Dictionary
var list_box: VBoxContainer
var info_lbl: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("Workshop & Kitchen", Vector2(560, 314))
	add_child(root_win["root"])
	var cb: Button = root_win["closeBtn"]
	cb.pressed.connect(close_panel)

	var body: VBoxContainer = root_win["body"]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	body.add_child(top)

	var craft_tab := Button.new(); craft_tab.text = "Crafting (104)"
	craft_tab.pressed.connect(func(): mode = "crafting"; AudioManager.play_sfx("ui_click"); refresh())
	top.add_child(craft_tab)

	var cook_tab := Button.new(); cook_tab.text = "Cooking (84)"
	cook_tab.pressed.connect(func(): mode = "cooking"; AudioManager.play_sfx("ui_click"); refresh())
	top.add_child(cook_tab)

	var avail_chk := CheckBox.new(); avail_chk.text = "Craftable Only"
	avail_chk.toggled.connect(func(on: bool): only_craftable = on; refresh())
	top.add_child(avail_chk)

	info_lbl = Label.new()
	info_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(info_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(list_box)
	visible = false


func open_panel(initial_mode: String = "crafting") -> void:
	mode = initial_mode
	InputAdapter.set_modal_locked("crafting", true)
	visible = true
	refresh()


func close_panel() -> void:
	visible = false
	InputAdapter.set_modal_locked("crafting", false)
	closed.emit()


func refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()

	var tl: Label = root_win["title"]
	tl.text = "Crafting Bench" if mode == "crafting" else "Farmhouse Kitchen"
	var src: Array = GameData.crafting_list if mode == "crafting" else GameData.cooking_list
	var shown := 0

	for entry in src:
		var eid := str(entry["id"])
		var check := CraftingSystem.can_craft(eid) if mode == "crafting" else CraftingSystem.can_cook(eid)
		var ok := bool(check["ok"])
		if only_craftable and not ok:
			continue
		shown += 1
		if shown > 80 and not only_craftable:
			# Keep UI snappy while showing first 80 or all craftable; let's render all actually, 104 rows in VBox is very light
			pass

		var row := HBoxContainer.new()
		var out_id := str(entry.get("outputItemId", eid))
		var ico := TextureRect.new()
		ico.texture = GameData.get_item_texture(out_id)
		ico.custom_minimum_size = Vector2(20, 20)
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ico)

		var ing_parts: Array = []
		for ing in entry.get("ingredients", []):
			var iid := str(ing["itemId"])
			var req := int(ing["count"])
			var have := InventorySystem.count_item(iid)
			ing_parts.append("%s %d/%d" % [GameData.get_item(iid).get("name", iid), have, req])

		var lbl := Label.new()
		var cnt_tag := (" x%d" % int(entry.get("outputCount", 1))) if mode == "crafting" else ""
		lbl.text = "%s%s  [%s]" % [entry["name"], cnt_tag, ", ".join(ing_parts)]
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 9)
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "Craft" if mode == "crafting" else "Cook"
		btn.disabled = not ok
		btn.tooltip_text = str(check.get("reason", ""))
		btn.pressed.connect(func():
			var res := CraftingSystem.craft(eid) if mode == "crafting" else CraftingSystem.cook(eid)
			if bool(res["ok"]):
				EventBus.ui_toast.emit("Made %s!" % entry["name"], "success")
			else:
				EventBus.ui_toast.emit(str(res.get("reason", "Failed")), "warning")
			refresh()
		)
		row.add_child(btn)
		list_box.add_child(row)

	info_lbl.text = "Showing %d recipes" % shown
