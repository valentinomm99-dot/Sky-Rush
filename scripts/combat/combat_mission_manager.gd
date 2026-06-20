class_name CombatMissionManager
extends Node

enum MissionState { RUNNING, WON, LOST }

@export var aircraft_path: NodePath
@export var camera_rig_path: NodePath
@export var hud_path: NodePath
@export var world_path: NodePath
@export var enemy_parent_path: NodePath
@export var enemy_scene: PackedScene
@export var combat_boundary: Vector3 = Vector3(360, 150, 560)

var aircraft
var camera_rig
var hud
var world: Node3D
var enemy_parent: Node3D
var enemies_remaining: int = 0
var state: MissionState = MissionState.RUNNING

var _terrain_material: Material
var _obstacle_material: Material
var _carrier_material: Material
var _paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_terrain_material = load("res://materials/terrain.tres") as Material
	_obstacle_material = load("res://materials/obstacle.tres") as Material
	_carrier_material = load("res://materials/carrier.tres") as Material
	aircraft = get_node(aircraft_path)
	camera_rig = get_node(camera_rig_path)
	hud = get_node(hud_path)
	world = get_node(world_path) as Node3D
	enemy_parent = get_node(enemy_parent_path) as Node3D
	if enemy_scene == null:
		enemy_scene = load("res://scenes/enemies/enemy_aircraft.tscn") as PackedScene
	_connect_player_systems()
	_build_combat_world()
	_start_mission()


func _process(_delta: float) -> void:
	if _paused or state != MissionState.RUNNING:
		return
	_apply_combat_bounds()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	match key_event.physical_keycode:
		KEY_ESCAPE:
			_toggle_pause()
		KEY_R:
			_start_mission()
		KEY_C:
			camera_rig.switch_camera()


func _connect_player_systems() -> void:
	aircraft.flight_data_changed.connect(hud.set_flight_data)
	aircraft.health_changed.connect(hud.set_health)
	aircraft.destroyed.connect(_on_player_destroyed)
	aircraft.crashed.connect(_on_player_crashed)

	var weapons: Node = aircraft.get_node_or_null("WeaponController")
	if weapons != null:
		weapons.gun_temperature_changed.connect(hud.set_gun_temperature)
		weapons.missiles_changed.connect(hud.set_missiles)
		weapons.lock_changed.connect(_on_lock_changed)


func _start_mission() -> void:
	_set_paused(false)
	state = MissionState.RUNNING
	_clear_projectiles()
	_clear_children(enemy_parent)
	aircraft.set_spawn_transform(_get_spawn_transform())
	aircraft.reset_to_spawn()
	aircraft.set_input_enabled(true)
	var weapons: Node = aircraft.get_node_or_null("WeaponController")
	if weapons != null and weapons.has_method("reset_weapons"):
		weapons.reset_weapons()

	hud.set_combat_visible(true)
	hud.show_controls(true)
	hud.show_pause_menu(false)
	hud.show_race_message("")
	hud.set_race_data(0, 0, -1, 0.0)
	_spawn_enemies()
	_update_hud()


func _spawn_enemies() -> void:
	var starts := [
		Vector3(-95, 64, -210),
		Vector3(110, 76, -260),
		Vector3(-150, 88, -390),
		Vector3(155, 54, -430),
		Vector3(10, 96, -535)
	]
	enemies_remaining = starts.size()
	for index in range(starts.size()):
		var enemy = enemy_scene.instantiate()
		enemy.name = "EnemyAircraft%02d" % (index + 1)
		enemy_parent.add_child(enemy)
		var center: Vector3 = starts[index]
		var patrol := [
			center,
			center + Vector3(55, 12, -45),
			center + Vector3(-35, -8, -88),
			center + Vector3(-70, 10, 25)
		]
		enemy.configure(aircraft, patrol)
		enemy.destroyed.connect(_on_enemy_destroyed)


func _on_enemy_destroyed(_enemy: Node) -> void:
	enemies_remaining = max(0, enemies_remaining - 1)
	_update_hud()
	if enemies_remaining <= 0 and state == MissionState.RUNNING:
		state = MissionState.WON
		aircraft.set_input_enabled(false)
		hud.show_controls(false)
		hud.show_race_message("VICTORIA\nAviones enemigos destruidos")


func _on_player_destroyed(_source: Node) -> void:
	if state != MissionState.RUNNING:
		return
	state = MissionState.LOST
	aircraft.set_input_enabled(false)
	hud.show_controls(false)
	hud.show_race_message("DERROTA\nAvion destruido\nR para reiniciar")


func _on_player_crashed(_reason: String) -> void:
	if state == MissionState.RUNNING and aircraft.has_method("take_damage"):
		aircraft.take_damage(1000.0, self)


func _on_lock_changed(_target: Node, progress: float, locked: bool) -> void:
	hud.set_lock_progress(progress, locked)


func _update_hud() -> void:
	hud.set_combat_data(enemies_remaining, "Objetivo: Destruye los aviones enemigos")


func _toggle_pause() -> void:
	if state == MissionState.WON or state == MissionState.LOST:
		return
	_set_paused(not _paused)


func _set_paused(value: bool) -> void:
	_paused = value
	get_tree().paused = value
	hud.show_pause_menu(value)


func _apply_combat_bounds() -> void:
	var position: Vector3 = aircraft.global_position
	var clamped := Vector3(
		clampf(position.x, -combat_boundary.x, combat_boundary.x),
		clampf(position.y, 10.0, combat_boundary.y),
		clampf(position.z, -combat_boundary.z, 90.0)
	)
	if clamped != position:
		aircraft.global_position = clamped
		if aircraft.has_method("take_damage"):
			aircraft.take_damage(6.0, self)
		hud.show_race_message("Limite de combate")
		await get_tree().create_timer(0.45).timeout
		if state == MissionState.RUNNING:
			hud.show_race_message("")


func _get_spawn_transform() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 46, 40)).looking_at(Vector3(0, 60, -180), Vector3.UP)


func _build_combat_world() -> void:
	_clear_children(world)
	_create_static_box("Ocean", Vector3(0, -2, -250), Vector3(820, 2, 900), _make_material(Color(0.04, 0.24, 0.42, 1.0)))
	_create_carrier(Vector3(0, 5, 42))
	var mountains := [
		[Vector3(-260, 0, -190), 68.0, 92.0],
		[Vector3(260, 0, -310), 84.0, 120.0],
		[Vector3(-220, 0, -480), 72.0, 116.0],
		[Vector3(230, 0, -610), 86.0, 128.0]
	]
	for data in mountains:
		_create_mountain(data[0], data[1], data[2])

	var towers := [
		[Vector3(-65, 22, -220), Vector3(14, 44, 14)],
		[Vector3(82, 28, -350), Vector3(18, 56, 18)],
		[Vector3(-110, 34, -520), Vector3(16, 68, 16)]
	]
	for tower in towers:
		_create_static_box("CombatObstacle", tower[0], tower[1], _obstacle_material)


func _create_carrier(origin: Vector3) -> void:
	_create_static_box("AircraftCarrierHull", origin + Vector3(0, 0, 0), Vector3(42, 9, 118), _carrier_material)
	_create_static_box("AircraftCarrierDeck", origin + Vector3(0, 5, -4), Vector3(58, 2, 132), _carrier_material)
	_create_static_box("CarrierIsland", origin + Vector3(18, 12, -18), Vector3(12, 14, 18), _carrier_material)
	_create_visual_box("RunwayStripe", origin + Vector3(0, 6.2, -5), Vector3(2.2, 0.15, 112), _make_material(Color(0.9, 0.92, 0.86, 1.0)))


func _create_static_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	world.add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	return body


func _create_visual_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	world.add_child(mesh_instance)


func _create_mountain(base_position: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "CombatMountain"
	body.position = base_position + Vector3.UP * (height * 0.5)
	world.add_child(body)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.08
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _obstacle_material
	body.add_child(mesh_instance)
	var shape := BoxShape3D.new()
	shape.size = Vector3(radius * 1.25, height, radius * 1.25)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


func _clear_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	return material
