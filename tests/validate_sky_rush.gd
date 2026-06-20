extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _validate_main_menu():
		quit(1)
		return
	if not await _validate_race_scene():
		quit(1)
		return
	if not await _validate_combat_scene():
		quit(1)
		return

	print("Sky Rush validation passed: menu, carrera, combate, avion, HUD, camaras y enemigos OK.")
	quit(0)


func _validate_main_menu() -> bool:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("No se pudo cargar el menu principal")
		return false
	var menu := scene.instantiate()
	root.add_child(menu)
	await process_frame
	var ok := menu.has_method("_start_race") and menu.has_method("_start_combat")
	menu.queue_free()
	if not ok:
		push_error("El menu principal no expone los botones de modos")
	return ok


func _validate_race_scene() -> bool:
	var scene := load("res://scenes/race/ring_race.tscn") as PackedScene
	if scene == null:
		push_error("No se pudo cargar scenes/race/ring_race.tscn")
		return false

	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var aircraft := main.get_node_or_null("Aircraft")
	var camera := main.get_node_or_null("AircraftCameraRig")
	var hud := main.get_node_or_null("HUD")
	var manager := main.get_node_or_null("GameManager")
	var rings := main.get_node_or_null("Rings")
	var world := main.get_node_or_null("World")

	if aircraft == null or camera == null or hud == null or manager == null or rings == null or world == null:
		push_error("Faltan nodos principales en la escena de carrera")
		main.queue_free()
		return false

	if rings.get_child_count() != 15:
		push_error("La ruta debe tener 15 anillos, pero tiene %d" % rings.get_child_count())
		main.queue_free()
		return false

	if world.get_child_count() < 10:
		push_error("El escenario de carrera no genero suficientes elementos")
		main.queue_free()
		return false

	main.queue_free()
	return true


func _validate_combat_scene() -> bool:
	var scene := load("res://scenes/combat/combat_mission.tscn") as PackedScene
	if scene == null:
		push_error("No se pudo cargar scenes/combat/combat_mission.tscn")
		return false

	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var aircraft := main.get_node_or_null("Aircraft")
	var hud := main.get_node_or_null("HUD")
	var enemies := main.get_node_or_null("Enemies")
	var manager := main.get_node_or_null("CombatMissionManager")
	if aircraft == null or hud == null or enemies == null or manager == null:
		push_error("Faltan nodos principales en la escena de combate")
		main.queue_free()
		return false

	if enemies.get_child_count() != 5:
		push_error("La mision debe crear 5 enemigos, pero tiene %d" % enemies.get_child_count())
		main.queue_free()
		return false

	if aircraft.get_node_or_null("WeaponController") == null:
		push_error("El avion no tiene WeaponController")
		main.queue_free()
		return false

	main.queue_free()
	return true
