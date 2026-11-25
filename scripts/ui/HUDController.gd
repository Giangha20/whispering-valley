extends CanvasLayer
class_name HUDController
## Main Gameplay HUD: Time/Season/Weather/Gold badge, Energy/Health bars, Hotbar (1-0),
## Quick Action Menu, Toast Alerts, Pause Menu, and all Sub-Panels.

signal return_to_menu_requested()
signal build_refreshed()

var region_lbl: Label
var date_lbl: Label
var time_lbl: Label
var weather_lbl: Label
var gold_lbl: Label
var energy_bar: ProgressBar
var health_bar: ProgressBar
var energy_txt: Label
var health_txt: Label
var toast_lbl: Label
var hotbar_btns: Array[Button] = []
var selected_name_lbl: Label

var touch_ui: TouchControlsUI
var inv_panel: InventoryPanel
var shop_panel: ShopPanel
var dialogue_panel: DialoguePanel
var craft_panel: CraftingCookingPanel
var fish_panel: FishingMinigamePanel
var build_panel: BuildingPanel
var map_panel: WorldMapPanel
var codex_panel: JournalSocialCollectionPanel
var save_panel: SaveLoadPanel
var settings_panel: SettingsPanel
var pause_overlay: Control

var _player_tile_cb: Callable


func _ready() -> void:
	_build_hud()
	_build_modals()
	_connect_signals()
	refresh_all()


func set_player_tile_getter(cb: Callable) -> void:
	_player_tile_cb = cb


func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIThemeHelper.get_theme()
	add_child(root)

	# Top-Left Status Panel (Player, Region, Energy, Health, Quick Icons)
	var tl_panel := PanelContainer.new()
	tl_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tl_panel.position = Vector2(8, 8)
	tl_panel.custom_minimum_size = Vector2(215, 62)
	root.add_child(tl_panel)

	var tl_v := VBoxContainer.new()
	tl_v.add_theme_constant_override("separation", 2)
	tl_panel.add_child(tl_v)

	region_lbl = Label.new()
	region_lbl.add_theme_font_size_override("font_size", 10)
	tl_v.add_child(region_lbl)

	var e_row := HBoxContainer.new()
	tl_v.add_child(e_row)
	energy_txt = Label.new(); energy_txt.text = "EN"; energy_txt.add_theme_font_size_override("font_size", 8); e_row.add_child(energy_txt)
	energy_bar = ProgressBar.new(); energy_bar.custom_minimum_size = Vector2(120, 10); energy_bar.show_percentage = false
	energy_bar.modulate = Color("#8ee64c"); e_row.add_child(energy_bar)

	var h_row := HBoxContainer.new()
	tl_v.add_child(h_row)
	health_txt = Label.new(); health_txt.text = "HP"; health_txt.add_theme_font_size_override("font_size", 8); h_row.add_child(health_txt)
	health_bar = ProgressBar.new(); health_bar.custom_minimum_size = Vector2(120, 10); health_bar.show_percentage = false
	health_bar.modulate = Color("#eb5e5e"); h_row.add_child(health_bar)

	# Quick Menu Row right below top-left card
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 3)
	tl_v.add_child(qrow)
	for pair in [["Bag(I)", "inventory"], ["Map(M)", "map"], ["Quest(J)", "quests"], ["Craft(C)", "craft"], ["Build(B)", "build"], ["Menu", "pause"]]:
		var qb := Button.new()
		qb.text = pair[0]
		qb.add_theme_font_size_override("font_size", 8)
		qb.custom_minimum_size = Vector2(36, 18)
		qb.pressed.connect(func(): open_named_panel(pair[1]))
		qrow.add_child(qb)

	# Top-Right Calendar / Clock / Weather / Gold Panel
	var tr_panel := PanelContainer.new()
	tr_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_panel.position = Vector2(-178, 8)
	tr_panel.size = Vector2(170, 74)
	root.add_child(tr_panel)

	var tr_v := VBoxContainer.new()
	tr_v.add_theme_constant_override("separation", 1)
	tr_panel.add_child(tr_v)

	date_lbl = Label.new(); date_lbl.add_theme_font_size_override("font_size", 9); tr_v.add_child(date_lbl)
	time_lbl = Label.new(); time_lbl.add_theme_font_size_override("font_size", 11); tr_v.add_child(time_lbl)
	weather_lbl = Label.new(); weather_lbl.add_theme_font_size_override("font_size", 9); tr_v.add_child(weather_lbl)
	gold_lbl = Label.new(); gold_lbl.add_theme_font_size_override("font_size", 11); gold_lbl.add_theme_color_override("font_color", Color("#945e0e")); tr_v.add_child(gold_lbl)

	# Toast Notification banner top-center
	toast_lbl = Label.new()
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_lbl.position = Vector2(-130, 88)
	toast_lbl.size = Vector2(260, 22)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_color_override("font_color", Color("#fffbe0"))
	toast_lbl.add_theme_color_override("font_outline_color", Color("#2a1a0e"))
	toast_lbl.add_theme_constant_override("outline_size", 3)
	toast_lbl.visible = false
	root.add_child(toast_lbl)

	# Bottom-Center Hotbar
	var hb_wrap := VBoxContainer.new()
	hb_wrap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hb_wrap.position = Vector2(-168, -50)
	hb_wrap.size = Vector2(336, 46)
	root.add_child(hb_wrap)

	selected_name_lbl = Label.new()
	selected_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_name_lbl.add_theme_font_size_override("font_size", 9)
	selected_name_lbl.add_theme_color_override("font_color", Color("#fff9e2"))
	selected_name_lbl.add_theme_color_override("font_outline_color", Color("#241509"))
	selected_name_lbl.add_theme_constant_override("outline_size", 2)
	hb_wrap.add_child(selected_name_lbl)

	var hb_panel := PanelContainer.new()
	hb_wrap.add_child(hb_panel)
	var hb_row := HBoxContainer.new()
	hb_row.add_theme_constant_override("separation", 3)
	hb_panel.add_child(hb_row)

	for i in range(InventorySystem.HOTBAR_SIZE):
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(func():
			InventorySystem.select_hotbar(i)
			AudioManager.play_sfx("ui_click")
		)
		hb_row.add_child(b)
		hotbar_btns.append(b)

	touch_ui = TouchControlsUI.new()
	touch_ui.panel_requested.connect(open_named_panel)
	root.add_child(touch_ui)


func _build_modals() -> void:
	inv_panel = InventoryPanel.new(); add_child(inv_panel)
	shop_panel = ShopPanel.new(); add_child(shop_panel)
	dialogue_panel = DialoguePanel.new(); add_child(dialogue_panel)
	craft_panel = CraftingCookingPanel.new(); add_child(craft_panel)
	fish_panel = FishingMinigamePanel.new(); add_child(fish_panel)
	build_panel = BuildingPanel.new()
	build_panel.placement_requested.connect(func(_b, _c): build_refreshed.emit())
	add_child(build_panel)
	map_panel = WorldMapPanel.new(); add_child(map_panel)
	codex_panel = JournalSocialCollectionPanel.new(); add_child(codex_panel)
	save_panel = SaveLoadPanel.new()
	save_panel.save_loaded.connect(func(): build_refreshed.emit(); refresh_all())
	add_child(save_panel)
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(func(): touch_ui.refresh_visibility())
	add_child(settings_panel)

	var pw := UIThemeHelper.make_window_frame("Game Paused", Vector2(240, 230))
	pause_overlay = pw["root"]
	var pb_close: Button = pw["closeBtn"]
	pb_close.pressed.connect(_close_pause)
	var pbody: VBoxContainer = pw["body"]
	for btn_spec in [
		["Resume", _close_pause],
		["Save / Load Game", func(): _close_pause(); save_panel.open_panel(true)],
		["Settings", func(): _close_pause(); settings_panel.open_panel()],
		["Return to Main Menu", func(): _close_pause(); return_to_menu_requested.emit()]
	]:
		var btn := Button.new()
		btn.text = btn_spec[0]
		btn.pressed.connect(btn_spec[1])
		pbody.add_child(btn)
	pause_overlay.visible = false
	add_child(pause_overlay)


func _connect_signals() -> void:
	EventBus.time_ticked.connect(func(_h, _m): _refresh_clock())
	EventBus.day_started.connect(func(_y, _s, _d): _refresh_clock())
	EventBus.weather_changed.connect(func(_w): _refresh_clock())
	EventBus.player_stats_changed.connect(_refresh_stats)
	EventBus.inventory_changed.connect(_refresh_hotbar)
	EventBus.hotbar_selection_changed.connect(func(_s): _refresh_hotbar())
	EventBus.region_changed.connect(func(_r): _refresh_region())
	EventBus.ui_toast.connect(_show_toast)


func refresh_all() -> void:
	_refresh_region()
	_refresh_clock()
	_refresh_stats()
	_refresh_hotbar()
	touch_ui.refresh_visibility()


func _refresh_region() -> void:
	var reg: Dictionary = GameData.regions.get(WorldSystem.current_region, {})
	var rname := str(reg.get("name", WorldSystem.current_region.capitalize()))
	if WorldSystem.current_region == "mine_shaft":
		rname = "Ancient Mine - Floor %d" % MiningSystem.current_floor
	region_lbl.text = "%s (%s)" % [PlayerState.player_name, rname]


func _refresh_clock() -> void:
	date_lbl.text = TimeSystem.get_formatted_date()
	time_lbl.text = TimeSystem.get_formatted_time()
	weather_lbl.text = "Weather: %s" % WeatherSystem.get_weather_label()
	gold_lbl.text = "Gold: %dG" % PlayerState.gold


func _refresh_stats() -> void:
	energy_bar.max_value = PlayerState.max_energy
	energy_bar.value = PlayerState.energy
	energy_txt.text = "EN %d/%d" % [PlayerState.energy, PlayerState.max_energy]
	health_bar.max_value = PlayerState.max_health
	health_bar.value = PlayerState.health
	health_txt.text = "HP %d/%d" % [PlayerState.health, PlayerState.max_health]
	gold_lbl.text = "Gold: %dG" % PlayerState.gold


func _refresh_hotbar() -> void:
	for i in range(InventorySystem.HOTBAR_SIZE):
		var b := hotbar_btns[i]
		var s: Dictionary = InventorySystem.slots[i]
		if s.is_empty():
			b.icon = null
			b.text = ""
		else:
			b.icon = GameData.get_item_texture(str(s["id"]))
			b.text = str(s["count"]) if int(s["count"]) > 1 else ""
		b.modulate = Color(1.0, 0.94, 0.45) if i == InventorySystem.selected_slot else Color.WHITE

	var cur := InventorySystem.get_selected_slot()
	if cur.is_empty():
		selected_name_lbl.text = ""
	else:
		var def := GameData.get_item(str(cur["id"]))
		selected_name_lbl.text = "%s (%s)" % [def.get("name", ""), InventorySystem.quality_name(int(cur.get("quality", 0)))]


func _show_toast(msg: String, kind: String) -> void:
	toast_lbl.text = msg
	toast_lbl.modulate = Color("#a8ff9e") if kind == "success" else (Color("#ff9e8a") if kind == "warning" else Color.WHITE)
	toast_lbl.visible = true
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_callback(func(): toast_lbl.visible = false)


func _open_pause() -> void:
	InputAdapter.set_modal_locked("pause", true)
	pause_overlay.visible = true


func _close_pause() -> void:
	pause_overlay.visible = false
	InputAdapter.set_modal_locked("pause", false)


func open_named_panel(pname: String) -> void:
	if _close_any_open_modal():
		return
	AudioManager.play_sfx("ui_click")
	match pname:
		"inventory": inv_panel.open_panel()
		"map": map_panel.open_panel()
		"quests": codex_panel.open_panel("quests")
		"skills": codex_panel.open_panel("skills")
		"craft": craft_panel.open_panel("crafting")
		"cook": craft_panel.open_panel("cooking")
		"build": build_panel.open_panel(_player_tile_cb)
		"pause": _open_pause()


func _close_any_open_modal() -> bool:
	var closed_any := false
	for p in [inv_panel, shop_panel, dialogue_panel, craft_panel, map_panel, codex_panel, save_panel, settings_panel]:
		if p != null and p.visible:
			p.call("close_panel")
			closed_any = true
	if pause_overlay != null and pause_overlay.visible:
		_close_pause()
		closed_any = true
	return closed_any


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_ESCAPE:
			if not _close_any_open_modal():
				_open_pause()
			return
		if InputAdapter.is_gameplay_locked():
			return
		match ke.keycode:
			KEY_I: open_named_panel("inventory")
			KEY_M: open_named_panel("map")
			KEY_J: open_named_panel("quests")
			KEY_C: open_named_panel("craft")
			KEY_K: open_named_panel("skills")
			KEY_B: open_named_panel("build")
			KEY_1: InventorySystem.select_hotbar(0)
			KEY_2: InventorySystem.select_hotbar(1)
			KEY_3: InventorySystem.select_hotbar(2)
			KEY_4: InventorySystem.select_hotbar(3)
			KEY_5: InventorySystem.select_hotbar(4)
			KEY_6: InventorySystem.select_hotbar(5)
			KEY_7: InventorySystem.select_hotbar(6)
			KEY_8: InventorySystem.select_hotbar(7)
			KEY_9: InventorySystem.select_hotbar(8)
			KEY_0: InventorySystem.select_hotbar(9)
	elif event is InputEventMouseButton and event.pressed and not InputAdapter.is_gameplay_locked():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			InventorySystem.select_hotbar((InventorySystem.selected_slot - 1 + InventorySystem.HOTBAR_SIZE) % InventorySystem.HOTBAR_SIZE)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			InventorySystem.select_hotbar((InventorySystem.selected_slot + 1) % InventorySystem.HOTBAR_SIZE)
