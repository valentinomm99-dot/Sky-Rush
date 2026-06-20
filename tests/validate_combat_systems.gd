extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/combat/combat_mission.tscn") as PackedScene
	if scene == null:
		push_error("No se pudo cargar la mision de combate")
		quit(1)
		return

	var mission := scene.instantiate()
	root.add_child(mission)
	await process_frame
	await process_frame

	var aircraft := mission.get_node("Aircraft")
	var weapons := aircraft.get_node_or_null("WeaponController")
	var enemies := mission.get_node("Enemies")
	if weapons == null or enemies.get_child_count() != 5:
		push_error("La mision no tiene armas o enemigos listos")
		quit(1)
		return

	aircraft.set_input_enabled(true)
	weapons._try_fire_gun()
	await process_frame
	if get_nodes_in_group("projectiles").is_empty():
		push_error("La ametralladora no genero proyectiles")
		quit(1)
		return

	weapons._try_fire_missile()
	await process_frame
	if get_nodes_in_group("projectiles").size() < 2:
		push_error("El misil no se genero")
		quit(1)
		return

	var enemy := enemies.get_child(0)
	if not enemy.has_method("take_damage"):
		push_error("El enemigo no puede recibir dano")
		quit(1)
		return
	enemy.take_damage(12.0, aircraft)
	await process_frame
	if enemy.state != enemy.AIState.EVADE:
		push_error("El enemigo no entro en evasion al recibir dano")
		quit(1)
		return

	print("Combat systems validation passed: ametralladora, misil, dano y evasion OK.")
	for projectile in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	mission.queue_free()
	await process_frame
	quit(0)
