class_name SkyRushHUD
extends CanvasLayer

var speed_label: Label
var altitude_label: Label
var turbo_bar: ProgressBar
var health_bar: ProgressBar
var gun_heat_bar: ProgressBar
var missile_label: Label
var lock_bar: ProgressBar
var enemies_label: Label
var objective_label: Label
var health_title_label: Label
var heat_title_label: Label
var rings_label: Label
var time_label: Label
var next_ring_label: Label
var warning_label: Label
var center_label: Label
var controls_label: Label
var pause_overlay: ColorRect
var pause_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()


func set_flight_data(speed: float, altitude: float, turbo_ratio: float, turbo_active: bool, too_slow: bool) -> void:
	speed_label.text = "Velocidad: %03d" % int(roundf(speed))
	altitude_label.text = "Altura: %03d m" % int(roundf(altitude))
	turbo_bar.value = clampf(turbo_ratio * 100.0, 0.0, 100.0)
	warning_label.visible = too_slow
	warning_label.text = "VELOCIDAD BAJA" if too_slow else ""
	if turbo_active:
		turbo_bar.modulate = Color(1.0, 0.82, 0.28, 1.0)
	else:
		turbo_bar.modulate = Color(0.35, 0.75, 1.0, 1.0)


func set_health(current: float, maximum: float) -> void:
	health_bar.value = 100.0 if maximum <= 0.0 else clampf(current / maximum * 100.0, 0.0, 100.0)


func set_gun_temperature(ratio: float, overheated: bool) -> void:
	gun_heat_bar.value = clampf(ratio * 100.0, 0.0, 100.0)
	gun_heat_bar.modulate = Color(1.0, 0.18, 0.08, 1.0) if overheated else Color(1.0, 0.58, 0.18, 1.0)


func set_missiles(available: int, maximum: int, reload_ratio: float) -> void:
	missile_label.text = "Misiles: %d / %d  Recarga %.0f%%" % [available, maximum, reload_ratio * 100.0]


func set_lock_progress(progress: float, locked: bool) -> void:
	lock_bar.value = clampf(progress * 100.0, 0.0, 100.0)
	lock_bar.modulate = Color(1.0, 0.16, 0.08, 1.0) if locked else Color(1.0, 0.86, 0.18, 1.0)


func set_combat_data(enemies_remaining: int, objective: String) -> void:
	enemies_label.text = "Enemigos: %d" % enemies_remaining
	objective_label.text = objective


func set_combat_visible(visible: bool) -> void:
	health_bar.visible = visible
	gun_heat_bar.visible = visible
	missile_label.visible = visible
	lock_bar.visible = visible
	enemies_label.visible = visible
	objective_label.visible = visible
	health_title_label.visible = visible
	heat_title_label.visible = visible


func set_race_data(passed_rings: int, total_rings: int, next_ring: int, seconds_left: float) -> void:
	rings_label.text = "Anillos: %d / %d" % [passed_rings, total_rings]
	if next_ring >= 0:
		next_ring_label.text = "Proximo anillo: %d" % (next_ring + 1)
	else:
		next_ring_label.text = "Proximo anillo: --"
	var total_seconds := maxi(0, int(ceilf(seconds_left)))
	var minutes := floori(float(total_seconds) / 60.0)
	var seconds := total_seconds % 60
	time_label.text = "Tiempo: %02d:%02d" % [minutes, seconds]


func show_countdown(value: int) -> void:
	center_label.visible = true
	center_label.text = str(value)
	center_label.add_theme_font_size_override("font_size", 96)


func show_race_message(message: String) -> void:
	center_label.visible = message != ""
	center_label.text = message
	center_label.add_theme_font_size_override("font_size", 48)


func show_controls(visible: bool) -> void:
	controls_label.visible = visible


func show_pause_menu(visible: bool) -> void:
	pause_overlay.visible = visible


func _build_hud() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := VBoxContainer.new()
	panel.name = "StatsPanel"
	panel.offset_left = 18.0
	panel.offset_top = 16.0
	panel.offset_right = 330.0
	panel.offset_bottom = 190.0
	panel.add_theme_constant_override("separation", 7)
	root.add_child(panel)

	speed_label = _make_label(panel, "Velocidad: 000", 20)
	altitude_label = _make_label(panel, "Altura: 000 m", 20)
	objective_label = _make_label(panel, "", 19)
	rings_label = _make_label(panel, "Anillos: 0 / 15", 20)
	time_label = _make_label(panel, "Tiempo: 02:00", 20)
	next_ring_label = _make_label(panel, "Proximo anillo: 1", 20)
	enemies_label = _make_label(panel, "Enemigos: 0", 20)

	var turbo_label := _make_label(panel, "Turbo", 18)
	turbo_label.modulate = Color(0.8, 0.92, 1.0, 1.0)

	turbo_bar = ProgressBar.new()
	turbo_bar.name = "TurboBar"
	turbo_bar.min_value = 0.0
	turbo_bar.max_value = 100.0
	turbo_bar.value = 100.0
	turbo_bar.custom_minimum_size = Vector2(260.0, 18.0)
	panel.add_child(turbo_bar)

	health_title_label = _make_label(panel, "Vida", 18)
	health_title_label.modulate = Color(1.0, 0.82, 0.82, 1.0)
	health_bar = _make_progress_bar(panel, "HealthBar", Color(0.95, 0.16, 0.12, 1.0))

	heat_title_label = _make_label(panel, "Ametralladora", 18)
	heat_title_label.modulate = Color(1.0, 0.86, 0.64, 1.0)
	gun_heat_bar = _make_progress_bar(panel, "GunHeatBar", Color(1.0, 0.58, 0.18, 1.0))

	missile_label = _make_label(panel, "Misiles: 4 / 4", 18)
	lock_bar = _make_progress_bar(panel, "LockBar", Color(1.0, 0.86, 0.18, 1.0))
	set_combat_visible(false)

	warning_label = Label.new()
	warning_label.name = "WarningLabel"
	warning_label.text = ""
	warning_label.visible = false
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	warning_label.offset_top = 92.0
	warning_label.offset_bottom = 132.0
	warning_label.add_theme_font_size_override("font_size", 30)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.18, 1.0))
	root.add_child(warning_label)

	center_label = Label.new()
	center_label.name = "CenterMessage"
	center_label.visible = false
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72, 1.0))
	root.add_child(center_label)

	controls_label = Label.new()
	controls_label.name = "ControlsLabel"
	controls_label.text = "W/S cabeceo  A/D moverse y girar  Q/E guinada  Shift turbo  Click dispara  Click derecho misil  C camara  R reiniciar  Esc pausa"
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls_label.offset_top = -52.0
	controls_label.offset_bottom = -20.0
	controls_label.add_theme_font_size_override("font_size", 18)
	controls_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	root.add_child(controls_label)

	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.visible = false
	pause_overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_overlay)

	pause_label = Label.new()
	pause_label.name = "PauseLabel"
	pause_label.text = "PAUSA\nEsc para continuar\nR para reiniciar"
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_label.add_theme_font_size_override("font_size", 44)
	pause_overlay.add_child(pause_label)


func _make_label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	parent.add_child(label)
	return label


func _make_progress_bar(parent: Node, node_name: String, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.custom_minimum_size = Vector2(260.0, 16.0)
	bar.modulate = color
	parent.add_child(bar)
	return bar
