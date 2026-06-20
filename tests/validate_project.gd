extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var required_paths := [
		"res://scenes/main.tscn",
		"res://scenes/race/ring_race.tscn",
		"res://scenes/combat/combat_mission.tscn",
		"res://scenes/aircraft/aircraft.tscn",
		"res://scenes/enemies/enemy_aircraft.tscn",
		"res://scripts/game/sky_rush_game_manager.gd",
		"res://scripts/combat/combat_mission_manager.gd"
	]

	for path in required_paths:
		if not ResourceLoader.exists(path):
			push_error("Falta recurso requerido: %s" % path)
			quit(1)
			return

	print("Project validation passed: recursos principales de Sky Rush encontrados.")
	quit(0)
