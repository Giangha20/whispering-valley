extends Control
class_name JournalSocialCollectionPanel
## Unified Tabbed Codex: Quests (156), Relationships (32), Skills/Character, Collections & Achievements (64), Calendar & Festivals (12).

signal closed()

var current_tab: String = "quests"
var root_win: Dictionary
var list_box: VBoxContainer
var summary_lbl: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("Valley Journal & Codex", Vector2(580, 324))
	add_child(root_win["root"])
	var cb: Button = root_win["closeBtn"]
	cb.pressed.connect(close_panel)

	var body: VBoxContainer = root_win["body"]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	body.add_child(tabs)

	for t in [
		["quests", "Quests"],
		["npcs", "Villagers (32)"],
		["skills", "Skills & Stats"],
		["collections", "Collections"],
		["calendar", "Calendar"]
	]:
		var b := Button.new()
		b.text = t[1]
		b.add_theme_font_size_override("font_size", 9)
		b.pressed.connect(func():
			current_tab = t[0]
			AudioManager.play_sfx("ui_click")
			refresh()
		)
		tabs.add_child(b)

	summary_lbl = Label.new()
	summary_lbl.add_theme_font_size_override("font_size", 10)
	body.add_child(summary_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(list_box)

	visible = false


func open_panel(tab: String = "quests") -> void:
	current_tab = tab
	InputAdapter.set_modal_locked("codex", true)
	visible = true
	refresh()


func close_panel() -> void:
	visible = false
	InputAdapter.set_modal_locked("codex", false)
	closed.emit()


func refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()

	match current_tab:
		"quests": _render_quests()
		"npcs": _render_npcs()
		"skills": _render_skills()
		"collections": _render_collections()
		"calendar": _render_calendar()


func _render_quests() -> void:
	var active := QuestSystem.get_active_quests()
	var completed_cnt := 0
	for qst in QuestSystem.quest_states.values():
		if str(qst.get("status", "")) in ["completed", "claimed"]:
			completed_cnt += 1
	summary_lbl.text = "Active Quests: %d | Completed: %d / %d" % [active.size(), completed_cnt, GameData.quests_list.size()]

	for entry in active:
		var q: Dictionary = entry["quest"]
		var st: Dictionary = entry["state"]
		var obj: Dictionary = q["objectives"][0]
		var row := PanelContainer.new()
		var vb := VBoxContainer.new()
		row.add_child(vb)

		var h := Label.new()
		h.text = "[%s] %s (%d/%d) - Reward: %dG" % [
			q["category"], q["title"], int(st["progress"]), int(obj["required"]), int(q["rewards"]["gold"])
		]
		h.add_theme_font_size_override("font_size", 10)
		vb.add_child(h)

		var d := Label.new()
		d.text = str(q["description"])
		d.add_theme_font_size_override("font_size", 9)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		vb.add_child(d)
		list_box.add_child(row)


func _render_npcs() -> void:
	summary_lbl.text = "Residents of Whispering Valley (32 NPCs)"
	for npc in GameData.npcs_list:
		var nid := str(npc["id"])
		var hearts := NPCSystem.get_hearts(nid)
		var loc := NPCSystem.get_npc_location(nid)
		var reg_name := str(GameData.regions.get(str(loc.get("region", "")), {}).get("name", ""))
		var fav_names := []
		for fid in npc.get("favoriteGifts", []):
			fav_names.append(GameData.get_item(str(fid)).get("name", fid))

		var row := HBoxContainer.new()
		var por := TextureRect.new()
		por.texture = GameData.get_npc_portrait(nid, 0)
		por.custom_minimum_size = Vector2(24, 24)
		por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(por)

		var lbl := Label.new()
		lbl.text = "%s (%s) | ♥ %d/10 | Now: %s | Loves: %s" % [
			npc["name"], npc["occupation"], hearts, reg_name, ", ".join(fav_names)
		]
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(lbl)
		list_box.add_child(row)


func _render_skills() -> void:
	summary_lbl.text = "%s - %s | Overall Lv.%d | ATK %d / DEF %d | Speed %.0f%%" % [
		PlayerState.player_name, PlayerState.farm_name, PlayerState.get_overall_level(),
		PlayerState.get_attack(), PlayerState.get_defense(), PlayerState.get_speed_multiplier() * 100.0
	]
	for sk in PlayerState.SKILL_NAMES:
		var sd: Dictionary = PlayerState.skills[sk]
		var lv := int(sd["level"])
		var xp := int(sd["xp"])
		var nxt := PlayerState.xp_needed_for_level(mini(10, lv + 1))
		var lbl := Label.new()
		lbl.text = "%s: Level %d (XP: %d / %d)" % [sk.capitalize(), lv, xp, nxt]
		list_box.add_child(lbl)

	if not AnimalSystem.owned_animals.is_empty():
		var al := Label.new()
		al.text = "--- Owned Livestock (%d) ---" % AnimalSystem.owned_animals.size()
		list_box.add_child(al)
		for a in AnimalSystem.owned_animals:
			var sp: Dictionary = GameData.animals.get(str(a["speciesId"]), {})
			var row := Label.new()
			row.text = "%s (%s) - Happiness %d%%, Fed: %s, Ready: %s" % [
				a["name"], sp.get("name", ""), int(a["happiness"]),
				"Yes" if bool(a["fedToday"]) else "No",
				"YES" if bool(a["productReady"]) else "No"
			]
			row.add_theme_font_size_override("font_size", 9)
			list_box.add_child(row)


func _render_collections() -> void:
	var cols := QuestSystem.collections
	summary_lbl.text = "Fish: %d/%d | Crops: %d/%d | Dishes: %d/%d | Crafted: %d/%d | Achievements: %d/%d" % [
		cols["fish"].size(), GameData.fish_list.size(),
		cols["crops"].size(), GameData.crops_list.size(),
		cols["cooking"].size(), GameData.cooking_list.size(),
		cols["crafting"].size(), GameData.crafting_list.size(),
		QuestSystem.unlocked_achievements.size(), GameData.achievements_list.size()
	]
	for ach in GameData.achievements_list:
		var aid := str(ach["id"])
		var unlocked := QuestSystem.unlocked_achievements.has(aid)
		var lbl := Label.new()
		lbl.text = "%s %s - %s (+%dG)" % ["[DONE]" if unlocked else "[    ]", ach["name"], ach["description"], int(ach["rewardGold"])]
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.modulate = Color("#2e692e") if unlocked else Color(0.45, 0.42, 0.38)
		list_box.add_child(lbl)


func _render_calendar() -> void:
	summary_lbl.text = "Season: %s | Day %d / 28 | Tomorrow's Forecast: %s" % [
		TimeSystem.get_season().capitalize(), TimeSystem.day, WeatherSystem.tomorrow_weather.capitalize()
	]
	for f in GameData.festivals_list:
		var is_today := (str(f["season"]) == TimeSystem.get_season() and int(f["day"]) == TimeSystem.day)
		var lbl := Label.new()
		lbl.text = "%s %d: %s @ %s%s\n   %s" % [
			str(f["season"]).capitalize(), int(f["day"]), f["name"],
			GameData.regions[f["region"]]["name"],
			"  [TODAY!]" if is_today else "",
			f["description"]
		]
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		if is_today:
			lbl.add_theme_color_override("font_color", Color("#9e3e1c"))
		list_box.add_child(lbl)
