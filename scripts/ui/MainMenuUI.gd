extends Control
class_name MainMenuUI
## Animated Cozy Pixel Main Menu with Continue, New Game, Load Game, Settings, Credits, and Exit.

var continue_btn: Button
var save_panel: SaveLoadPanel
var settings_panel: SettingsPanel
var credits_dialog: AcceptDialog
var sky_particles: Array[ColorRect] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	TimeSystem.is_playing = false
	InputAdapter.clear_modal_locks()
	set_anchors_preset(PRESET_FULL_RECT)
	theme = UIThemeHelper.get_theme()
	_build_backdrop()
	_build_menu()
	AudioManager.play_music("main_theme")


func _build_backdrop() -> void:
	var season := TimeSystem.get_season()
	var sky_col := Color("#4f8ec9") if season != "autumn" else Color("#c97e57")
	if season == "winter":
		sky_col = Color("#6588a8")

	var sky := ColorRect.new()
	sky.color = sky_col
	sky.set_anchors_preset(PRESET_FULL_RECT)
	add_child(sky)

	# Rolling valley hills
	var hill_far := ColorRect.new()
	hill_far.color = Color("#3e7045") if season != "winter" else Color("#aac4d6")
	hill_far.set_anchors_preset(PRESET_BOTTOM_WIDE)
	hill_far.offset_top = -140
	add_child(hill_far)

	var hill_near := ColorRect.new()
	hill_near.color = Color("#4d8a4b") if season != "autumn" else Color("#b87533")
	if season == "winter":
		hill_near.color = Color("#d9eaf5")
	hill_near.set_anchors_preset(PRESET_BOTTOM_WIDE)
	hill_near.offset_top = -84
	add_child(hill_near)

	# Ambient sky petals / snowflakes / clouds
	for _i in range(20):
		var p := ColorRect.new()
		p.size = Vector2(_rng.randf_range(4, 14), _rng.randf_range(3, 6))
		p.position = Vector2(_rng.randf_range(0, 640), _rng.randf_range(10, 240))
		p.color = Color(1, 1, 1, 0.55) if season != "spring" else Color("#ffd6e6bb")
		p.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(p)
		sky_particles.append(p)


func _process(delta: float) -> void:
	for p in sky_particles:
		p.position.x += 18.0 * delta
		p.position.y += 6.0 * delta
		if p.position.x > 660:
			p.position.x = -16
		if p.position.y > 360:
			p.position.y = -8


func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 260)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "WHISPERING VALLEY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#3b5e2a"))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Farming, Life & Adventure RPG"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 10)
	vbox.add_child(sub)

	continue_btn = Button.new()
	continue_btn.text = "Continue Adventure"
	continue_btn.disabled = not SaveManager.has_any_save()
	continue_btn.pressed.connect(_on_continue)
	vbox.add_child(continue_btn)

	var new_btn := Button.new()
	new_btn.text = "New Game"
	new_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		get_tree().change_scene_to_file("res://scenes/menu/CharacterCreationScene.tscn")
	)
	vbox.add_child(new_btn)

	var load_btn := Button.new()
	load_btn.text = "Load Game"
	load_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		save_panel.open_panel(false)
	)
	vbox.add_child(load_btn)

	var set_btn := Button.new()
	set_btn.text = "Settings"
	set_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		settings_panel.open_panel()
	)
	vbox.add_child(set_btn)

	var cred_btn := Button.new()
	cred_btn.text = "Credits"
	cred_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		credits_dialog.popup_centered()
	)
	vbox.add_child(cred_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit"
	exit_btn.pressed.connect(func():
		if OS.get_name() == "Web":
			credits_dialog.dialog_text = "Thanks for playing Whispering Valley! You may close this browser tab."
			credits_dialog.popup_centered()
		else:
			get_tree().quit()
	)
	vbox.add_child(exit_btn)

	save_panel = SaveLoadPanel.new()
	save_panel.save_loaded.connect(_enter_world)
	add_child(save_panel)

	settings_panel = SettingsPanel.new()
	add_child(settings_panel)

	credits_dialog = AcceptDialog.new()
	credits_dialog.title = "Whispering Valley - Credits"
	credits_dialog.dialog_text = "Whispering Valley v1.0\nBuilt with Godot Engine 4.7.2\n12 Regions | 32 NPCs | 64 Crops | 84 Fish | 100 Mine Floors | 156 Quests"
	add_child(credits_dialog)


func _on_continue() -> void:
	var slot := SaveManager.get_latest_slot_id()
	if slot > 0:
		var res := SaveManager.load_slot(slot)
		if bool(res["ok"]):
			_enter_world()


func _enter_world() -> void:
	TimeSystem.is_playing = true
	InputAdapter.clear_modal_locks()
	get_tree().change_scene_to_file("res://scenes/world/WorldScene.tscn")
