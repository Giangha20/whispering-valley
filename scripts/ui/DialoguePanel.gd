extends Control
class_name DialoguePanel
## NPC Conversation Panel with Expressive Portrait, Friendship Hearts, Dialogue Choices, and Gift Giving.

signal closed()

var active_npc_id: String = ""
var root_win: Dictionary
var portrait_rect: TextureRect
var speech_lbl: Label
var meta_lbl: Label
var choices_box: HBoxContainer


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("Conversation", Vector2(490, 210))
	add_child(root_win["root"])
	var cb: Button = root_win["closeBtn"]
	cb.pressed.connect(close_panel)

	var body: VBoxContainer = root_win["body"]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)

	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(64, 64)
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(portrait_rect)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(text_col)

	meta_lbl = Label.new()
	meta_lbl.add_theme_font_size_override("font_size", 10)
	meta_lbl.add_theme_color_override("font_color", Color("#7a4424"))
	text_col.add_child(meta_lbl)

	speech_lbl = Label.new()
	speech_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	speech_lbl.size_flags_vertical = SIZE_EXPAND_FILL
	text_col.add_child(speech_lbl)

	choices_box = HBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 6)
	body.add_child(choices_box)

	visible = false


func open_npc(npc_id: String) -> void:
	active_npc_id = npc_id
	var res := NPCSystem.talk_to_npc(npc_id)
	if res.is_empty():
		return
	var npc: Dictionary = res["npc"]
	var tl: Label = root_win["title"]
	tl.text = "%s - %s" % [npc["name"], npc["occupation"]]
	portrait_rect.texture = GameData.get_npc_portrait(npc_id, int(res["expression"]))
	speech_lbl.text = str(res["text"])
	_update_meta(int(res["hearts"]))
	_rebuild_choices(res.get("choices", []), bool(res.get("canChoice", false)))

	InputAdapter.set_modal_locked("dialogue", true)
	visible = true


func _update_meta(hearts: int) -> void:
	var h_str := "♥".repeat(hearts) + "♡".repeat(10 - hearts)
	meta_lbl.text = "Friendship: %s (%d/10)" % [h_str, hearts]


func _rebuild_choices(choices: Array, can_choice: bool) -> void:
	for c in choices_box.get_children():
		c.queue_free()

	if can_choice:
		for i in range(choices.size()):
			var ch: Dictionary = choices[i]
			var btn := Button.new()
			btn.text = str(ch["prompt"])
			btn.pressed.connect(func():
				AudioManager.play_sfx("ui_click")
				var ans := NPCSystem.answer_dialogue_choice(active_npc_id, i)
				speech_lbl.text = str(ans.get("reply", ""))
				portrait_rect.texture = GameData.get_npc_portrait(active_npc_id, int(ans.get("expression", 1)))
				_update_meta(int(ans.get("hearts", 0)))
				_rebuild_choices([], false)
			)
			choices_box.add_child(btn)

	# Give currently held Hotbar item as Gift button
	var held_id := InventorySystem.get_selected_item_id()
	if held_id != "":
		var gdef := GameData.get_item(held_id)
		if str(gdef.get("category", "")) != "Tools":
			var gb := Button.new()
			gb.text = "Gift: %s" % gdef["name"]
			gb.pressed.connect(func():
				var gres := NPCSystem.give_gift(active_npc_id, held_id)
				speech_lbl.text = str(gres.get("message", ""))
				if bool(gres.get("ok", false)):
					portrait_rect.texture = GameData.get_npc_portrait(active_npc_id, int(gres.get("expression", 1)))
					_update_meta(int(gres.get("hearts", 0)))
				_rebuild_choices([], false)
			)
			choices_box.add_child(gb)

	var bye := Button.new()
	bye.text = "Goodbye"
	bye.pressed.connect(close_panel)
	choices_box.add_child(bye)


func close_panel() -> void:
	visible = false
	InputAdapter.set_modal_locked("dialogue", false)
	closed.emit()
