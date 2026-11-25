extends Control
class_name WorldMapPanel
## Interactive 12-Region World Map with Discovery Fog-of-War, Locked Badges, Player & Quest Markers.

signal closed()

var root_win: Dictionary
var canvas_box: Control
var info_lbl: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("World Map of Whispering Valley", Vector2(580, 320))
	add_child(root_win["root"])
	var cb: Button = root_win["closeBtn"]
	cb.pressed.connect(close_panel)

	var body: VBoxContainer = root_win["body"]
	canvas_box = Panel.new()
	canvas_box.size_flags_vertical = SIZE_EXPAND_FILL
	canvas_box.add_theme_stylebox_override("panel", UIThemeHelper.make_wood_style("#3e6945", "#4a2e19"))
	body.add_child(canvas_box)

	info_lbl = Label.new()
	info_lbl.text = "Select a region marker to view details."
	body.add_child(info_lbl)
	visible = false


func open_panel() -> void:
	InputAdapter.set_modal_locked("map", true)
	visible = true
	refresh()


func close_panel() -> void:
	visible = false
	InputAdapter.set_modal_locked("map", false)
	closed.emit()


func refresh() -> void:
	for c in canvas_box.get_children():
		c.queue_free()

	for r in GameData.regions_list:
		var rid := str(r["id"])
		var pos_arr: Array = r.get("worldMapPos", [100, 100])
		var discovered := WorldSystem.discovered_regions.has(rid)
		var unlocked := WorldSystem.is_region_unlocked(rid)
		var is_here := (WorldSystem.current_region == rid)

		var btn := Button.new()
		btn.position = Vector2(float(pos_arr[0]) * 0.92 - 42.0, float(pos_arr[1]) * 0.78 - 14.0)
		btn.custom_minimum_size = Vector2(96, 26)
		btn.add_theme_font_size_override("font_size", 8)

		if is_here:
			btn.text = "[YOU] " + str(r["name"])
			btn.modulate = Color(1.0, 0.95, 0.45)
		elif not unlocked:
			btn.text = "[LOCKED] ???"
			btn.modulate = Color(0.45, 0.45, 0.50)
		elif not discovered:
			btn.text = "[Fog] " + str(r["name"])
			btn.modulate = Color(0.65, 0.68, 0.72)
		else:
			btn.text = str(r["name"])
			btn.modulate = Color.WHITE

		btn.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			if not unlocked:
				info_lbl.text = "%s (Locked: %s)" % [r["name"], str(r.get("unlockCondition", "")).replace("_", " ")]
			elif not discovered:
				info_lbl.text = "%s - Undiscovered! Explore along connecting valley trails." % r["name"]
			else:
				var npc_cnt := NPCSystem.get_npcs_in_region(rid).size()
				info_lbl.text = "%s | Biome: %s | NPCs nearby: %d" % [r["name"], str(r["biome"]).capitalize(), npc_cnt]
		)
		canvas_box.add_child(btn)
