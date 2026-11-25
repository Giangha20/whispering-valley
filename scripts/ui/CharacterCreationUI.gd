extends Control
class_name CharacterCreationUI
## Live Pixel Art Character Customization Screen with Name, Farm Name, Slot, and 54 Customization Options.

const OUTFIT_PALETTE := ["#4f8d4e", "#4b75a3", "#b85545", "#c9943b", "#7a589c", "#3a7d7c", "#c96f8f", "#59554e"]

var name_edit: LineEdit
var farm_edit: LineEdit
var skin_idx: int = 1
var hair_style_idx: int = 0
var hair_col_idx: int = 0
var outfit_style_idx: int = 0
var outfit_col_idx: int = 0
var acc_idx: int = 0
var slot_idx: int = 1
var preview_dir: int = 0
var preview_frame: int = 0
var _anim_t: float = 0.0

var body_spr: Sprite2D
var outfit_spr: Sprite2D
var hair_spr: Sprite2D
var acc_spr: Sprite2D
var lbl_skin: Label
var lbl_hair: Label
var lbl_hcol: Label
var lbl_outfit: Label
var lbl_ocol: Label
var lbl_acc: Label
var lbl_slot: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = UIThemeHelper.get_theme()
	_build_ui()
	_refresh_preview()


func _process(delta: float) -> void:
	_anim_t += delta * 4.0
	preview_frame = int(_anim_t) % 4
	_update_sprite_frames()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#2f4a36")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 316)
	center.add_child(panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 6)
	panel.add_child(root_v)

	var hdr := Label.new()
	hdr.text = "Create Your Farmer"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 15)
	root_v.add_child(hdr)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	root_v.add_child(cols)

	# Left Preview Box
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(160, 200)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(left)

	var preview_bg := Panel.new()
	preview_bg.custom_minimum_size = Vector2(140, 140)
	preview_bg.add_theme_stylebox_override("panel", UIThemeHelper.make_wood_style("#69a85d", "#5c3a21"))
	left.add_child(preview_bg)

	var holder := Node2D.new()
	holder.position = Vector2(70, 74)
	holder.scale = Vector2(4, 4)
	preview_bg.add_child(holder)

	body_spr = Sprite2D.new(); body_spr.texture = load("res://assets/sprites/player/base.png"); body_spr.region_enabled = true; holder.add_child(body_spr)
	outfit_spr = Sprite2D.new(); outfit_spr.texture = load("res://assets/sprites/player/outfit.png"); outfit_spr.region_enabled = true; holder.add_child(outfit_spr)
	hair_spr = Sprite2D.new(); hair_spr.texture = load("res://assets/sprites/player/hair.png"); hair_spr.region_enabled = true; holder.add_child(hair_spr)
	acc_spr = Sprite2D.new(); acc_spr.texture = load("res://assets/sprites/player/accessory.png"); acc_spr.region_enabled = true; holder.add_child(acc_spr)

	var rot_row := HBoxContainer.new()
	rot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(rot_row)
	var rot_l := Button.new(); rot_l.text = "< Turn"; rot_l.pressed.connect(func(): preview_dir = (preview_dir + 1) % 4); rot_row.add_child(rot_l)
	var rand_b := Button.new(); rand_b.text = "Random"; rand_b.pressed.connect(_randomize_all); rot_row.add_child(rand_b)

	# Right Customization Form
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)

	var name_row := HBoxContainer.new(); right.add_child(name_row)
	var nl := Label.new(); nl.text = "Farmer Name:"; nl.custom_minimum_size = Vector2(96, 0); name_row.add_child(nl)
	name_edit = LineEdit.new(); name_edit.text = "Aria"; name_edit.size_flags_horizontal = SIZE_EXPAND_FILL; name_row.add_child(name_edit)

	var farm_row := HBoxContainer.new(); right.add_child(farm_row)
	var fl := Label.new(); fl.text = "Farm Name:"; fl.custom_minimum_size = Vector2(96, 0); farm_row.add_child(fl)
	farm_edit = LineEdit.new(); farm_edit.text = "Greenfield Farm"; farm_edit.size_flags_horizontal = SIZE_EXPAND_FILL; farm_row.add_child(farm_edit)

	lbl_skin = _make_selector(right, "Skin Tone:", func(d): skin_idx = (skin_idx + d + 6) % 6; _refresh_preview())
	lbl_hair = _make_selector(right, "Hair Style:", func(d): hair_style_idx = (hair_style_idx + d + 12) % 12; _refresh_preview())
	lbl_hcol = _make_selector(right, "Hair Color:", func(d): hair_col_idx = (hair_col_idx + d + 10) % 10; _refresh_preview())
	lbl_outfit = _make_selector(right, "Outfit Style:", func(d): outfit_style_idx = (outfit_style_idx + d + 14) % 14; _refresh_preview())
	lbl_ocol = _make_selector(right, "Outfit Color:", func(d): outfit_col_idx = (outfit_col_idx + d + OUTFIT_PALETTE.size()) % OUTFIT_PALETTE.size(); _refresh_preview())
	lbl_acc = _make_selector(right, "Accessory:", func(d): acc_idx = (acc_idx + d + 12) % 12; _refresh_preview())
	lbl_slot = _make_selector(right, "Save Slot:", func(d): slot_idx = ((slot_idx - 1 + d + 5) % 5) + 1; _refresh_preview())

	var bot := HBoxContainer.new()
	bot.alignment = BoxContainer.ALIGNMENT_END
	bot.add_theme_constant_override("separation", 8)
	root_v.add_child(bot)

	var back_b := Button.new(); back_b.text = "Back to Menu"
	back_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/MainMenuScene.tscn"))
	bot.add_child(back_b)

	var start_b := Button.new(); start_b.text = "Start Adventure!"
	start_b.pressed.connect(_on_start)
	bot.add_child(start_b)


func _make_selector(parent: Control, label_txt: String, on_step: Callable) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new(); l.text = label_txt; l.custom_minimum_size = Vector2(96, 0); row.add_child(l)
	var prev := Button.new(); prev.text = "<"; prev.pressed.connect(func(): AudioManager.play_sfx("ui_click"); on_step.call(-1)); row.add_child(prev)
	var val := Label.new(); val.size_flags_horizontal = SIZE_EXPAND_FILL; val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; row.add_child(val)
	var nxt := Button.new(); nxt.text = ">"; nxt.pressed.connect(func(): AudioManager.play_sfx("ui_click"); on_step.call(1)); row.add_child(nxt)
	return val


func _randomize_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	skin_idx = rng.randi() % 6
	hair_style_idx = rng.randi() % 12
	hair_col_idx = rng.randi() % 10
	outfit_style_idx = rng.randi() % 14
	outfit_col_idx = rng.randi() % OUTFIT_PALETTE.size()
	acc_idx = rng.randi() % 12
	AudioManager.play_sfx("ui_click")
	_refresh_preview()


func _refresh_preview() -> void:
	var skins: Array = GameData.outfits.get("skinTones", [])
	var hairs: Array = GameData.outfits.get("hairstyles", [])
	var hcols: Array = GameData.outfits.get("hairColors", [])
	var outs: Array = GameData.outfits.get("outfits", [])
	var accs: Array = GameData.outfits.get("accessories", [])

	var s_hex := str(skins[skin_idx]["hex"]) if skin_idx < skins.size() else "#ebb896"
	var h_hex := str(hcols[hair_col_idx]["hex"]) if hair_col_idx < hcols.size() else "#6a3e26"
	var o_hex := str(OUTFIT_PALETTE[outfit_col_idx])

	lbl_skin.text = str(skins[skin_idx]["name"]) if skin_idx < skins.size() else "Warm"
	lbl_hair.text = str(hairs[hair_style_idx]["name"]) if hair_style_idx < hairs.size() else "Style"
	lbl_hcol.text = str(hcols[hair_col_idx]["name"]) if hair_col_idx < hcols.size() else "Color"
	lbl_outfit.text = str(outs[outfit_style_idx]["name"]) if outfit_style_idx < outs.size() else "Outfit"
	lbl_ocol.text = "Color #%d" % (outfit_col_idx + 1)
	lbl_acc.text = str(accs[acc_idx]["name"]) if acc_idx < accs.size() else "None"
	lbl_slot.text = "Slot %d" % slot_idx

	body_spr.modulate = Color.html(s_hex)
	hair_spr.modulate = Color.html(h_hex)
	outfit_spr.modulate = Color.html(o_hex)
	_update_sprite_frames()


func _update_sprite_frames() -> void:
	var col_idx := preview_dir * 4 + preview_frame
	body_spr.region_rect = Rect2(preview_frame * 16, preview_dir * 24, 16, 24)
	hair_spr.region_rect = Rect2(col_idx * 16, hair_style_idx * 24, 16, 24)
	outfit_spr.region_rect = Rect2(col_idx * 16, outfit_style_idx * 24, 16, 24)
	acc_spr.visible = acc_idx > 0
	if acc_idx > 0:
		acc_spr.region_rect = Rect2(col_idx * 16, acc_idx * 24, 16, 24)


func _on_start() -> void:
	var skins: Array = GameData.outfits.get("skinTones", [])
	var hcols: Array = GameData.outfits.get("hairColors", [])
	var custom := {
		"skinTone": str(skins[skin_idx]["hex"]) if skin_idx < skins.size() else "#ebb896",
		"hairStyle": hair_style_idx,
		"hairColor": str(hcols[hair_col_idx]["hex"]) if hair_col_idx < hcols.size() else "#6a3e26",
		"outfitStyle": outfit_style_idx,
		"outfitColor": OUTFIT_PALETTE[outfit_col_idx],
		"accessory": acc_idx
	}
	SaveManager.start_new_game(name_edit.text, farm_edit.text, custom, slot_idx)
	TimeSystem.is_playing = true
	InputAdapter.clear_modal_locks()
	AudioManager.play_sfx("level_up")
	get_tree().change_scene_to_file("res://scenes/world/WorldScene.tscn")
