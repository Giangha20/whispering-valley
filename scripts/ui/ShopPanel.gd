extends Control
class_name ShopPanel
## Interactive Shop & Livestock Purchase + Player Selling UI with atomic transaction feedback.

signal closed()

var active_shop_id: String = ""
var root_win: Dictionary
var stock_list: VBoxContainer
var bag_list: VBoxContainer
var gold_lbl: Label
var status_lbl: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("Merchant Shop", Vector2(560, 310))
	add_child(root_win["root"])
	var cb: Button = root_win["closeBtn"]
	cb.pressed.connect(close_panel)

	var body: VBoxContainer = root_win["body"]
	var top := HBoxContainer.new()
	body.add_child(top)
	gold_lbl = Label.new()
	gold_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(gold_lbl)
	status_lbl = Label.new()
	status_lbl.add_theme_color_override("font_color", Color("#8a3420"))
	top.add_child(status_lbl)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 8)
	body.add_child(cols)

	# Buy column
	var buy_col := VBoxContainer.new()
	buy_col.size_flags_horizontal = SIZE_EXPAND_FILL
	cols.add_child(buy_col)
	var bl := Label.new(); bl.text = "Buy from Shop:"; buy_col.add_child(bl)
	var bscroll := ScrollContainer.new(); bscroll.size_flags_vertical = SIZE_EXPAND_FILL; buy_col.add_child(bscroll)
	stock_list = VBoxContainer.new(); stock_list.size_flags_horizontal = SIZE_EXPAND_FILL; bscroll.add_child(stock_list)

	# Sell column
	var sell_col := VBoxContainer.new()
	sell_col.size_flags_horizontal = SIZE_EXPAND_FILL
	cols.add_child(sell_col)
	var sl := Label.new(); sl.text = "Sell from Backpack:"; sell_col.add_child(sl)
	var sscroll := ScrollContainer.new(); sscroll.size_flags_vertical = SIZE_EXPAND_FILL; sell_col.add_child(sscroll)
	bag_list = VBoxContainer.new(); bag_list.size_flags_horizontal = SIZE_EXPAND_FILL; sscroll.add_child(bag_list)

	visible = false


func open_shop(shop_id: String) -> void:
	active_shop_id = shop_id
	status_lbl.text = ""
	InputAdapter.set_modal_locked("shop", true)
	visible = true
	refresh()


func close_panel() -> void:
	visible = false
	InputAdapter.set_modal_locked("shop", false)
	closed.emit()


func refresh() -> void:
	var shop: Dictionary = GameData.shops.get(active_shop_id, {})
	var tl: Label = root_win["title"]
	tl.text = "%s (%02d:00-%02d:00)" % [shop.get("name", "Shop"), int(shop.get("openHour", 6)), int(shop.get("closeHour", 22))]
	gold_lbl.text = "Your Gold: %dG | Season: %s" % [PlayerState.gold, TimeSystem.get_season().capitalize()]

	for ch in stock_list.get_children():
		ch.queue_free()
	for ch in bag_list.get_children():
		ch.queue_free()

	for iid in EconomySystem.get_shop_stock(active_shop_id):
		var def := GameData.get_item(str(iid))
		var price := EconomySystem.get_buy_price(active_shop_id, str(iid))
		var row := HBoxContainer.new()
		var ico := TextureRect.new()
		ico.texture = GameData.get_item_texture(str(iid))
		ico.custom_minimum_size = Vector2(20, 20)
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ico)

		var lbl := Label.new()
		lbl.text = "%s (%dG)" % [def["name"], price]
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(lbl)

		var b1 := Button.new()
		b1.text = "Buy 1"
		b1.disabled = PlayerState.gold < price
		b1.pressed.connect(func():
			var res := EconomySystem.buy_item(active_shop_id, str(iid), 1)
			status_lbl.text = "" if bool(res["ok"]) else str(res.get("error", ""))
			refresh()
		)
		row.add_child(b1)

		if int(def.get("maxStack", 1)) > 1:
			var b5 := Button.new()
			b5.text = "x5"
			b5.disabled = PlayerState.gold < price * 5
			b5.pressed.connect(func():
				var res := EconomySystem.buy_item(active_shop_id, str(iid), 5)
				status_lbl.text = "" if bool(res["ok"]) else str(res.get("error", ""))
				refresh()
			)
			row.add_child(b5)
		stock_list.add_child(row)

	# Animal adoption rows if Barnaby's ranch
	for aid in shop.get("animalStock", []):
		var sp: Dictionary = GameData.animals.get(str(aid), {})
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "[Animal] %s (%dG)" % [sp["name"], int(sp["buyPrice"])]
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(lbl)
		var ab := Button.new()
		ab.text = "Adopt"
		ab.disabled = PlayerState.gold < int(sp["buyPrice"])
		ab.pressed.connect(func():
			AnimalSystem.buy_animal(str(aid))
			refresh()
		)
		row.add_child(ab)
		stock_list.add_child(row)

	# Player inventory sell rows
	for idx in range(InventorySystem.slots.size()):
		var s: Dictionary = InventorySystem.slots[idx]
		if s.is_empty():
			continue
		var iid := str(s["id"])
		var q := int(s.get("quality", 0))
		var val := EconomySystem.get_sell_price(iid, q)
		if val <= 0:
			continue
		var def := GameData.get_item(iid)
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s x%d (%dG ea)" % [def["name"], int(s["count"]), val]
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(lbl)

		var s1 := Button.new()
		s1.text = "Sell 1"
		s1.pressed.connect(func():
			EconomySystem.sell_from_slot(idx, 1)
			refresh()
		)
		row.add_child(s1)

		if int(s["count"]) > 1:
			var sa := Button.new()
			sa.text = "All"
			sa.pressed.connect(func():
				EconomySystem.sell_from_slot(idx, int(s["count"]))
				refresh()
			)
			row.add_child(sa)
		bag_list.add_child(row)
