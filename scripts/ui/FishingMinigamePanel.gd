extends Control
class_name FishingMinigamePanel
## Active Fishing Catch-Bar Physics Mini-game: hold Space / Mouse / Touch to reel in!

signal closed(caught: bool)

var active_fish: Dictionary = {}
var is_running: bool = false
var progress: float = 0.35
var fish_y: float = 0.5
var fish_target_y: float = 0.5
var fish_timer: float = 0.0
var bar_y: float = 0.5
var bar_vel: float = 0.0
var bar_height: float = 0.28
var perfect_catch: bool = true

var root_win: Dictionary
var track_panel: Panel
var bar_rect: ColorRect
var fish_marker: TextureRect
var prog_bar: ProgressBar
var status_lbl: Label
var reel_btn: Button
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("Fishing Reel!", Vector2(260, 290))
	add_child(root_win["root"])
	var cb: Button = root_win["closeBtn"]
	cb.pressed.connect(func(): _finish(false))

	var body: VBoxContainer = root_win["body"]
	status_lbl = Label.new()
	status_lbl.text = "Hold [SPACE] or [REEL] to keep the bar behind the fish!"
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.add_theme_font_size_override("font_size", 9)
	body.add_child(status_lbl)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	body.add_child(hbox)

	track_panel = Panel.new()
	track_panel.custom_minimum_size = Vector2(44, 170)
	track_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_wood_style("#265d85", "#4a2e19"))
	hbox.add_child(track_panel)

	bar_rect = ColorRect.new()
	bar_rect.color = Color("#74d658aa")
	bar_rect.size = Vector2(36, 48)
	bar_rect.position = Vector2(4, 60)
	track_panel.add_child(bar_rect)

	fish_marker = TextureRect.new()
	fish_marker.custom_minimum_size = Vector2(22, 22)
	fish_marker.size = Vector2(22, 22)
	fish_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	track_panel.add_child(fish_marker)

	prog_bar = ProgressBar.new()
	prog_bar.custom_minimum_size = Vector2(22, 170)
	prog_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	prog_bar.max_value = 100.0
	prog_bar.value = 35.0
	hbox.add_child(prog_bar)

	reel_btn = Button.new()
	reel_btn.text = "HOLD TO REEL"
	reel_btn.custom_minimum_size = Vector2(140, 32)
	body.add_child(reel_btn)

	visible = false


func start_minigame(biome: String) -> void:
	var bait_bonus := FishingSystem.consume_bait_if_available()
	active_fish = FishingSystem.roll_fish_for_biome(biome)
	is_running = true
	progress = 0.36
	fish_y = 0.5
	fish_target_y = 0.4
	bar_y = 0.5
	bar_vel = 0.0
	perfect_catch = true

	var flv := PlayerState.get_skill_level("fishing")
	var has_irid := InventorySystem.has_item("tool_fishing_iridium", 1)
	bar_height = clampf(0.26 + flv * 0.015 + bait_bonus * 0.03 + (0.06 if has_irid else 0.0), 0.24, 0.48)

	var tl: Label = root_win["title"]
	tl.text = "Hooked a Fish!"
	fish_marker.texture = GameData.get_item_texture(str(active_fish["id"]))
	AudioManager.play_sfx("fish_bite")

	InputAdapter.set_modal_locked("fishing", true)
	visible = true


func _process(delta: float) -> void:
	if not visible or not is_running:
		return

	var holding := Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or reel_btn.button_pressed
	if holding:
		bar_vel -= 1.65 * delta
	else:
		bar_vel += 1.45 * delta
	bar_vel = clampf(bar_vel, -1.2, 1.2)
	bar_y += bar_vel * delta
	if bar_y < 0.0:
		bar_y = 0.0
		bar_vel = 0.0
	elif bar_y > 1.0 - bar_height:
		bar_y = 1.0 - bar_height
		bar_vel = 0.0

	var diff := float(active_fish.get("difficulty", 35)) / 100.0
	fish_timer -= delta
	if fish_timer <= 0.0:
		fish_timer = _rng.randf_range(0.45, maxf(0.5, 1.4 - diff * 0.7))
		fish_target_y = _rng.randf_range(0.05, 0.88)
	fish_y = move_toward(fish_y, fish_target_y, (0.25 + diff * 0.55) * delta)

	var track_h := track_panel.size.y
	bar_rect.size.y = track_h * bar_height
	bar_rect.position.y = bar_y * track_h
	fish_marker.position = Vector2(11, clampf(fish_y * (track_h - 22.0), 2.0, track_h - 24.0))

	var in_bar := fish_y >= (bar_y - 0.05) and fish_y <= (bar_y + bar_height + 0.05)
	if in_bar:
		progress = minf(1.0, progress + 0.34 * delta)
		bar_rect.color = Color("#8af266cc")
	else:
		perfect_catch = false
		progress = maxf(0.0, progress - 0.22 * delta)
		bar_rect.color = Color("#e8b84bcc")

	prog_bar.value = progress * 100.0
	if progress >= 1.0:
		FishingSystem.complete_catch(str(active_fish["id"]), perfect_catch)
		_finish(true)
	elif progress <= 0.0:
		EventBus.ui_toast.emit("The fish slipped off the hook!", "info")
		_finish(false)


func _finish(caught: bool) -> void:
	is_running = false
	visible = false
	InputAdapter.set_modal_locked("fishing", false)
	closed.emit(caught)
