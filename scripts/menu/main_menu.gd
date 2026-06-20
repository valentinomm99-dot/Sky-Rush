class_name MainMenu
extends Control

var controls_panel: PanelContainer


func _ready() -> void:
	_build_menu()


func _build_menu() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.04, 0.12, 0.2, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var title := Label.new()
	title.text = "Sky Rush"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 72.0
	title.offset_bottom = 160.0
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Crear partida"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42, 1.0))
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 156.0
	subtitle.offset_bottom = 204.0
	add_child(subtitle)

	var buttons := VBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_CENTER)
	buttons.offset_left = -170.0
	buttons.offset_top = -50.0
	buttons.offset_right = 170.0
	buttons.offset_bottom = 190.0
	buttons.add_theme_constant_override("separation", 12)
	add_child(buttons)

	_add_button(buttons, "Carrera de anillos", _start_race)
	_add_button(buttons, "Mision de combate", _start_combat)
	_add_button(buttons, "Controles", _toggle_controls)
	_add_button(buttons, "Salir", _quit_game)
	_build_controls_panel()


func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340.0, 46.0)
	button.pressed.connect(callback)
	parent.add_child(button)


func _build_controls_panel() -> void:
	controls_panel = PanelContainer.new()
	controls_panel.visible = false
	controls_panel.set_anchors_preset(Control.PRESET_CENTER)
	controls_panel.offset_left = -360.0
	controls_panel.offset_top = 160.0
	controls_panel.offset_right = 360.0
	controls_panel.offset_bottom = 280.0
	add_child(controls_panel)

	var label := Label.new()
	label.text = "W/S cabeceo   A/D moverse y girar   Q/E guinada   Shift turbo\nClick izquierdo ametralladora   Click derecho misil   C camara   R reiniciar   Esc pausa"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	controls_panel.add_child(label)


func _start_race() -> void:
	get_tree().change_scene_to_file("res://scenes/race/ring_race.tscn")


func _start_combat() -> void:
	get_tree().change_scene_to_file("res://scenes/combat/combat_mission.tscn")


func _toggle_controls() -> void:
	controls_panel.visible = not controls_panel.visible


func _quit_game() -> void:
	get_tree().quit()
