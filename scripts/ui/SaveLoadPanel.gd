extends Control
class_name SaveLoadPanel
## 5-Slot Save/Load Management + Crash-Safe JSON Export/Import Panel.

signal save_loaded()
signal closed()

var allow_saving: bool = true
var root_win: Dictionary
var slot_box: VBoxContainer
var io_edit: TextEdit
var io_status: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	root_win = UIThemeHelper.make_window_frame("Save & Load Farm", Vector2(560, 322))
	add_child(root_win["root"])
	var cb: Button = root_win["closeBtn"]
	cb.pressed.connect(close_panel)

	var body: VBoxContainer = root_win["body"]
	var note := Label.new()
	note.text = "Saved locally in browser IndexedDB / Desktop AppData. Export JSON backups anytime!"
	note.add_theme_font_size_override("font_size", 9)
	body.add_child(note)

	slot_box = VBoxContainer.new()
	slot_box.add_theme_constant_override("separation", 4)
	body.add_child(slot_box)

	var io_lbl := Label.new()
	io_lbl.text = "JSON Backup Export / Import (paste exported JSON below to import into Slot 1):"
	io_lbl.add_theme_font_size_override("font_size", 9)
	body.add_child(io_lbl)

	io_edit = TextEdit.new()
	io_edit.custom_minimum_size = Vector2(520, 56)
	body.add_child(io_edit)

	var io_row := HBoxContainer.new()
	io_row.add_theme_constant_override("separation", 6)
	body.add_child(io_row)

	var exp_btn := Button.new(); exp_btn.text = "Export Current Slot JSON"
	exp_btn.pressed.connect(func():
		io_edit.text = SaveManager.export_save_string(SaveManager.current_slot)
		io_status.text = "Exported Slot %d JSON!" % SaveManager.current_slot if io_edit.text != "" else "No save in current slot."
	)
	io_row.add_child(exp_btn)

	var imp_btn := Button.new(); imp_btn.text = "Import JSON -> Slot 1"
	imp_btn.pressed.connect(func():
		var res := SaveManager.import_save_string(1, io_edit.text)
		io_status.text = "Imported into Slot 1!" if bool(res["ok"]) else str(res.get("error", "Import failed."))
		refresh()
	)
	io_row.add_child(imp_btn)

	io_status = Label.new()
	io_status.size_flags_horizontal = SIZE_EXPAND_FILL
	io_status.add_theme_font_size_override("font_size", 9)
	io_row.add_child(io_status)

	visible = false


func open_panel(can_save: bool = true) -> void:
	allow_saving = can_save
	io_status.text = ""
	InputAdapter.set_modal_locked("saveload", true)
	visible = true
	refresh()


func close_panel() -> void:
	visible = false
	InputAdapter.set_modal_locked("saveload", false)
	closed.emit()


func refresh() -> void:
	for c in slot_box.get_children():
		c.queue_free()

	for s in range(1, SaveManager.MAX_SLOTS + 1):
		var meta := SaveManager.get_slot_metadata(s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var lbl := Label.new()
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 10)
		if bool(meta.get("exists", false)):
			var mins := int(float(meta["playSeconds"]) / 60.0)
			lbl.text = "Slot %d: %s (%s) | Yr %d %s %d | %dG | %dm | %s" % [
				s, meta["playerName"], meta["farmName"],
				int(meta["year"]), str(meta["season"]).capitalize(), int(meta["day"]),
				int(meta["gold"]), mins, str(meta["savedAtText"])
			]
		else:
			lbl.text = "Slot %d: [Empty]" % s
		row.add_child(lbl)

		if allow_saving:
			var sb := Button.new()
			sb.text = "Save"
			sb.pressed.connect(func():
				if SaveManager.save_slot(s):
					io_status.text = "Saved to Slot %d!" % s
					AudioManager.play_sfx("ui_click")
				refresh()
			)
			row.add_child(sb)

		var lb := Button.new()
		lb.text = "Load"
		lb.disabled = not bool(meta.get("exists", false))
		lb.pressed.connect(func():
			var res := SaveManager.load_slot(s)
			if bool(res["ok"]):
				AudioManager.play_sfx("ui_click")
				close_panel()
				save_loaded.emit()
			else:
				io_status.text = str(res.get("error", "Failed to load"))
		)
		row.add_child(lb)
		slot_box.add_child(row)
