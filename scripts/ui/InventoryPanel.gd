extends Control
class_name InventoryPanel
## Full Inventory + Storage Chest + Equipment + Splitting + Sorting + Category Filtering + Shipping UI.

signal closed()

var chest_uid: String = ""
var selected_slot_idx: int = -1
var current_filter: String = "All"

var slot_buttons: Array[Button] = []
var chest_buttons: Array[Button] = []
var tooltip_lbl: Label
var chest_box: VBoxContainer
var eq_label: Label
var root_win: Dictionary


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("Backpack & Equipment", Vector2(560, 316))
	add_child(root_win["root"])
	var close_b: Button = root_win["closeBtn"]
	close_b.pressed.connect(close_panel)

	var body: VBoxContainer = root_win["body"]

	# Top Filter & Action Toolbar
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	body.add_child(bar)

	for cat in ["All", "Seeds", "Crops", "Fish", "Tools", "Food", "Minerals", "Materials"]:
		var fb := Button.new()
		fb.text = cat
		fb.add_theme_font_size_override("font_size", 9)
		fb.pressed.connect(func():
			current_filter = cat
			AudioManager.play_sfx("ui_click")
			refresh()
		)
		bar.add_child(fb)

	var sort_b := Button.new()
	sort_b.text = "Sort"
	sort_b.pressed.connect(func():
		InventorySystem.sort_inventory(true)
		AudioManager.play_sfx("ui_click")
		refresh()
	)
	bar.add_child(sort_b)

	# Split middle area: Left=36 slots grid, Right=Tooltip/Actions/Equipment or Chest
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	body.add_child(mid)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310, 185)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	mid.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)

	for i in range(InventorySystem.BACKPACK_SIZE):
		var sb := Button.new()
		sb.custom_minimum_size = Vector2(30, 30)
		sb.add_theme_font_size_override("font_size", 8)
		sb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sb.pressed.connect(_on_slot_clicked.bind(i))
		grid.add_child(sb)
		slot_buttons.append(sb)

	# Right details + chest panel
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	mid.add_child(right)

	eq_label = Label.new()
	eq_label.add_theme_font_size_override("font_size", 9)
	eq_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(eq_label)

	tooltip_lbl = Label.new()
	tooltip_lbl.text = "Select a slot to inspect, swap, split, use, or equip."
	tooltip_lbl.add_theme_font_size_override("font_size", 9)
	tooltip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip_lbl.custom_minimum_size = Vector2(200, 62)
	right.add_child(tooltip_lbl)

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 4)
	right.add_child(act_row)

	var use_b := Button.new()
	use_b.text = "Use/Equip"
	use_b.pressed.connect(func():
		if selected_slot_idx >= 0:
			InventorySystem.use_item_in_slot(selected_slot_idx)
			refresh()
	)
	act_row.add_child(use_b)

	var split_b := Button.new()
	split_b.text = "Split"
	split_b.pressed.connect(func():
		if selected_slot_idx >= 0:
			InventorySystem.split_stack(selected_slot_idx)
			refresh()
	)
	act_row.add_child(split_b)

	var ship_b := Button.new()
	ship_b.text = "Sell Now"
	ship_b.pressed.connect(func():
		if selected_slot_idx >= 0:
			var res := EconomySystem.sell_from_slot(selected_slot_idx, 1)
			if bool(res["ok"]):
				EventBus.ui_toast.emit("Sold for +%dG" % int(res["earned"]), "success")
			refresh()
	)
	act_row.add_child(ship_b)

	chest_box = VBoxContainer.new()
	chest_box.visible = false
	right.add_child(chest_box)

	var ch_lbl := Label.new()
	ch_lbl.text = "Storage Chest (Click to Withdraw):"
	ch_lbl.add_theme_font_size_override("font_size", 9)
	chest_box.add_child(ch_lbl)

	var ch_grid := GridContainer.new()
	ch_grid.columns = 6
	chest_box.add_child(ch_grid)
	for ci in range(18):
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(28, 28)
		cb.add_theme_font_size_override("font_size", 8)
		cb.pressed.connect(_on_chest_slot_clicked.bind(ci))
		ch_grid.add_child(cb)
		chest_buttons.append(cb)

	EventBus.inventory_changed.connect(func():
		if visible:
			refresh()
	)
	visible = false


func open_panel(with_chest_uid: String = "") -> void:
	chest_uid = with_chest_uid
	selected_slot_idx = -1
	InputAdapter.set_modal_locked("inventory", true)
	visible = true
	refresh()


func close_panel() -> void:
	visible = false
	chest_uid = ""
	InputAdapter.set_modal_locked("inventory", false)
	closed.emit()


func _on_slot_clicked(idx: int) -> void:
	AudioManager.play_sfx("ui_click")
	if chest_uid != "" and Input.is_key_pressed(KEY_SHIFT):
		InventorySystem.deposit_to_chest(chest_uid, idx)
		refresh()
		return
	if selected_slot_idx == -1:
		selected_slot_idx = idx
	elif selected_slot_idx == idx:
		selected_slot_idx = -1
	else:
		InventorySystem.swap_slots(selected_slot_idx, idx)
		selected_slot_idx = -1
	refresh()


func _on_chest_slot_clicked(ci: int) -> void:
	if chest_uid == "":
		return
	InventorySystem.withdraw_from_chest(chest_uid, ci)
	refresh()


func refresh() -> void:
	var title_l: Label = root_win["title"]
	title_l.text = "Storage Chest & Backpack" if chest_uid != "" else "Backpack & Equipment"
	chest_box.visible = chest_uid != ""

	var sw := str(GameData.get_item(str(PlayerState.equipped.get("sword", ""))).get("name", "None"))
	var sh := str(GameData.get_item(str(PlayerState.equipped.get("shield", ""))).get("name", "None"))
	var bt := str(GameData.get_item(str(PlayerState.equipped.get("boots", ""))).get("name", "None"))
	var rg := str(GameData.get_item(str(PlayerState.equipped.get("ring", ""))).get("name", "None"))
	eq_label.text = "Gear: %s | %s | %s | %s  (ATK %d / DEF %d)" % [sw, sh, bt, rg, PlayerState.get_attack(), PlayerState.get_defense()]

	for i in range(InventorySystem.BACKPACK_SIZE):
		var sb := slot_buttons[i]
		var s: Dictionary = InventorySystem.slots[i]
		if s.is_empty():
			sb.icon = null
			sb.text = ""
			sb.modulate = Color(0.85, 0.85, 0.85) if selected_slot_idx != i else Color(1.0, 0.95, 0.5)
		else:
			var iid := str(s["id"])
			var def := GameData.get_item(iid)
			sb.icon = GameData.get_item_texture(iid)
			var cnt := int(s["count"])
			sb.text = str(cnt) if cnt > 1 else ""
			var matches_filter := (current_filter == "All" or str(def.get("category", "")) == current_filter)
			sb.modulate = (Color(1.0, 0.95, 0.55) if selected_slot_idx == i else Color.WHITE) if matches_filter else Color(0.5, 0.5, 0.5, 0.5)

	if selected_slot_idx >= 0 and not InventorySystem.slots[selected_slot_idx].is_empty():
		var ss: Dictionary = InventorySystem.slots[selected_slot_idx]
		var d := GameData.get_item(str(ss["id"]))
		var q := int(ss.get("quality", 0))
		tooltip_lbl.text = "%s [%s] x%d\n%s\nValue: %dG each" % [
			d.get("name", ""), InventorySystem.quality_name(q), int(ss["count"]),
			d.get("description", ""), EconomySystem.get_sell_price(str(ss["id"]), q)
		]
		if chest_uid != "":
			tooltip_lbl.text += "\n(Hold Shift+Click to store in chest)"
	else:
		tooltip_lbl.text = "Gold: %dG | Slots: %d/%d\nClick two slots to swap or stack." % [
			PlayerState.gold,
			InventorySystem.BACKPACK_SIZE - InventorySystem.slots.count({}),
			InventorySystem.BACKPACK_SIZE
		]

	if chest_uid != "":
		var ch := InventorySystem.get_or_create_chest(chest_uid)
		for ci in range(chest_buttons.size()):
			var cb := chest_buttons[ci]
			var cs: Dictionary = ch[ci]
			if cs.is_empty():
				cb.icon = null
				cb.text = ""
			else:
				cb.icon = GameData.get_item_texture(str(cs["id"]))
				cb.text = str(cs["count"]) if int(cs["count"]) > 1 else ""
