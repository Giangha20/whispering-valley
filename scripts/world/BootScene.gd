extends Control
## Entry Boot Scene: initializes settings, shows brief emblem, and moves to Main Menu.


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#1b2b20")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var lbl := Label.new()
	lbl.text = "WHISPERING VALLEY\nLoading World..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color("#f5e8cc"))
	center.add_child(lbl)

	call_deferred("_go_menu")


func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/MainMenuScene.tscn")
