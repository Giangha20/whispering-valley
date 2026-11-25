extends Control
class_name SettingsPanel
## Audio, Graphics Quality, Time Speed, and Mobile Touch Controls Settings Panel.

signal closed()

var root_win: Dictionary
var music_sl: HSlider
var sfx_sl: HSlider
var amb_sl: HSlider
var speed_sl: HSlider
var mute_chk: CheckBox
var part_chk: CheckBox
var shad_chk: CheckBox
var gfx_opt: OptionButton
var touch_opt: OptionButton


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("Game Settings", Vector2(460, 290))
	add_child(root_win["root"])
	var cb: Button = root_win["closeBtn"]
	cb.pressed.connect(close_panel)

	var body: VBoxContainer = root_win["body"]

	music_sl = _make_slider(body, "Music Volume", 0.0, 1.0, 0.05)
	sfx_sl = _make_slider(body, "SFX Volume", 0.0, 1.0, 0.05)
	amb_sl = _make_slider(body, "Ambient Volume", 0.0, 1.0, 0.05)
	speed_sl = _make_slider(body, "Sec / Game Hour", 15.0, 120.0, 5.0)

	var chk_row := HBoxContainer.new()
	body.add_child(chk_row)
	mute_chk = CheckBox.new(); mute_chk.text = "Mute All"; chk_row.add_child(mute_chk)
	part_chk = CheckBox.new(); part_chk.text = "Reduced Particles"; chk_row.add_child(part_chk)
	shad_chk = CheckBox.new(); shad_chk.text = "Reduced Shadows"; chk_row.add_child(shad_chk)

	var opt_row := HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 10)
	body.add_child(opt_row)

	var gl := Label.new(); gl.text = "Graphics:"; opt_row.add_child(gl)
	gfx_opt = OptionButton.new()
	gfx_opt.add_item("Low", 0); gfx_opt.add_item("Medium", 1); gfx_opt.add_item("High", 2)
	opt_row.add_child(gfx_opt)

	var tl := Label.new(); tl.text = "Touch Controls:"; opt_row.add_child(tl)
	touch_opt = OptionButton.new()
	touch_opt.add_item("Auto", 0); touch_opt.add_item("Always Show", 1); touch_opt.add_item("Off", 2)
	opt_row.add_child(touch_opt)

	var save_btn := Button.new()
	save_btn.text = "Save & Apply Settings"
	save_btn.pressed.connect(func():
		SaveManager.settings["musicVolume"] = music_sl.value
		SaveManager.settings["sfxVolume"] = sfx_sl.value
		SaveManager.settings["ambientVolume"] = amb_sl.value
		SaveManager.settings["timeSpeed"] = speed_sl.value
		SaveManager.settings["muted"] = mute_chk.button_pressed
		SaveManager.settings["reducedParticles"] = part_chk.button_pressed
		SaveManager.settings["reducedShadows"] = shad_chk.button_pressed
		SaveManager.settings["graphicsQuality"] = ["low", "medium", "high"][gfx_opt.selected]
		SaveManager.settings["touchControls"] = ["auto", "always", "off"][touch_opt.selected]
		SaveManager.save_settings()
		AudioManager.play_sfx("ui_click")
		EventBus.ui_toast.emit("Settings saved!", "success")
		close_panel()
	)
	body.add_child(save_btn)
	visible = false


func _make_slider(parent: Control, label_text: String, min_v: float, max_v: float, step_v: float) -> HSlider:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label_text; l.custom_minimum_size = Vector2(130, 0); row.add_child(l)
	var sl := HSlider.new(); sl.min_value = min_v; sl.max_value = max_v; sl.step = step_v; sl.size_flags_horizontal = SIZE_EXPAND_FILL; row.add_child(sl)
	parent.add_child(row)
	return sl


func open_panel() -> void:
	var s := SaveManager.settings
	music_sl.value = float(s.get("musicVolume", 0.7))
	sfx_sl.value = float(s.get("sfxVolume", 0.8))
	amb_sl.value = float(s.get("ambientVolume", 0.5))
	speed_sl.value = float(s.get("timeSpeed", 60.0))
	mute_chk.button_pressed = bool(s.get("muted", false))
	part_chk.button_pressed = bool(s.get("reducedParticles", false))
	shad_chk.button_pressed = bool(s.get("reducedShadows", false))
	var g_idx := ["low", "medium", "high"].find(str(s.get("graphicsQuality", "high")))
	gfx_opt.selected = maxi(0, g_idx)
	var t_idx := ["auto", "always", "off"].find(str(s.get("touchControls", "auto")))
	touch_opt.selected = maxi(0, t_idx)

	InputAdapter.set_modal_locked("settings", true)
	visible = true


func close_panel() -> void:
	visible = false
	InputAdapter.set_modal_locked("settings", false)
	closed.emit()
