class_name SkyRushGameManager
extends Node

enum RaceState { COUNTDOWN, RUNNING, WON, LOST, CRASHED }

@export var aircraft_path: NodePath
@export var camera_rig_path: NodePath
@export var hud_path: NodePath
@export var world_path: NodePath
@export var ring_parent_path: NodePath
@export var ring_scene: PackedScene
@export var race_duration: float = 120.0
@export var countdown_seconds: float = 3.0
@export var crash_reset_delay: float = 1.4

var aircraft
var camera_rig
var hud
var world: Node3D
var ring_parent: Node3D

var state: RaceState = RaceState.COUNTDOWN
var countdown_remaining: float = 3.0
var time_remaining: float = 120.0
var current_ring_index: int = 0
var rings: Array = []
var controls_timer: float = 0.0

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
	ring_parent = get_node(ring_parent_path) as Node3D

	aircraft.flight_data_changed.connect(hud.set_flight_data)
	aircraft.crashed.connect(_on_aircraft_crashed)
	hud.resume_requested.connect(_on_resume_requested)
	hud.restart_requested.connect(_start_new_race)
	hud.lobby_requested.connect(_return_to_lobby)

	if ring_scene == null:
		ring_scene = load("res://scenes/rings/checkpoint_ring.tscn") as PackedScene

	_build_test_world()
	_build_ring_route()
	_start_new_race()


func _process(delta: float) -> void:
	if _paused:
		return

	match state:
		RaceState.COUNTDOWN:
			_update_countdown(delta)
		RaceState.RUNNING:
			_update_running_race(delta)
		_:
			pass


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	match key_event.physical_keycode:
		KEY_ESCAPE:
			_toggle_pause()
		KEY_R:
			_start_new_race()
		KEY_C:
			camera_rig.switch_camera()


func _start_new_race() -> void:
	_set_paused(false)
	state = RaceState.COUNTDOWN
	countdown_remaining = countdown_seconds
	time_remaining = race_duration
	current_ring_index = 0
	controls_timer = countdown_seconds + 7.0

	for ring in rings:
		ring.reset_ring()
	if not rings.is_empty():
		rings[0].set_active(true)

	var spawn_transform := _get_start_transform()
	aircraft.set_spawn_transform(spawn_transform)
	aircraft.reset_to_spawn()
	aircraft.set_input_enabled(false)

	hud.show_controls(true)
	hud.show_pause_menu(false)
	hud.show_countdown(int(ceilf(countdown_remaining)))
	_update_hud_race_data()


func _update_countdown(delta: float) -> void:
	countdown_remaining -= delta
	if countdown_remaining > 0.0:
		hud.show_countdown(maxi(1, int(ceilf(countdown_remaining))))
		return

	state = RaceState.RUNNING
	aircraft.set_input_enabled(true)
	hud.show_race_message("GO")
	await get_tree().create_timer(0.55).timeout
	if state == RaceState.RUNNING:
		hud.show_race_message("")


func _update_running_race(delta: float) -> void:
	time_remaining = maxf(0.0, time_remaining - delta)
	controls_timer = maxf(0.0, controls_timer - delta)
	hud.show_controls(controls_timer > 0.0)
	_update_hud_race_data()

	if time_remaining <= 0.0:
		_lose_race()


func _on_ring_entered(ring_index: int) -> void:
	if state != RaceState.RUNNING or ring_index != current_ring_index:
		return

	rings[ring_index].mark_passed()
	current_ring_index += 1

	if current_ring_index >= rings.size():
		_win_race()
		return

	rings[current_ring_index].set_active(true)
	hud.show_race_message("Anillo %d" % current_ring_index)
	_update_hud_race_data()
	await get_tree().create_timer(0.35).timeout
	if state == RaceState.RUNNING:
		hud.show_race_message("")


func _win_race() -> void:
	state = RaceState.WON
	aircraft.set_input_enabled(false)
	hud.show_controls(false)
	hud.show_race_message("VICTORIA")
	_update_hud_race_data()


func _lose_race() -> void:
	state = RaceState.LOST
	aircraft.set_input_enabled(false)
	hud.show_controls(false)
	hud.show_race_message("DERROTA")
	_update_hud_race_data()


func _on_aircraft_crashed(reason: String) -> void:
	if state == RaceState.WON or state == RaceState.LOST:
		return

	state = RaceState.CRASHED
	aircraft.set_input_enabled(false)
	hud.show_race_message("CHOQUE: %s" % reason)
	await get_tree().create_timer(crash_reset_delay).timeout
	if state == RaceState.CRASHED:
		_recover_after_crash()


func _recover_after_crash() -> void:
	if time_remaining <= 0.0:
		_lose_race()
		return

	aircraft.reset_to_transform(_get_recovery_transform())
	aircraft.set_input_enabled(true)
	state = RaceState.RUNNING
	hud.show_race_message("")
	_update_hud_race_data()


func _toggle_pause() -> void:
	if state == RaceState.WON or state == RaceState.LOST:
		return
	_set_paused(not _paused)


func _set_paused(value: bool) -> void:
	_paused = value
	get_tree().paused = value
	hud.show_pause_menu(value)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED


func _on_resume_requested() -> void:
	_set_paused(false)


func _return_to_lobby() -> void:
	_set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_hud_race_data() -> void:
	var next_ring := current_ring_index
	if next_ring >= rings.size():
		next_ring = -1
	hud.set_race_data(current_ring_index, rings.size(), next_ring, time_remaining)


func _get_start_transform() -> Transform3D:
	return Transform3D(Basis(), Vector3(0.0, 18.0, 54.0)).looking_at(Vector3(0.0, 30.0, -80.0), Vector3.UP)


func _get_recovery_transform() -> Transform3D:
	if current_ring_index < 0 or current_ring_index >= rings.size():
		return _get_start_transform()

	var target_position: Vector3 = rings[current_ring_index].global_position
	var approach_direction := Vector3(0.0, 0.0, -1.0)
	if current_ring_index > 0:
		var previous_position: Vector3 = rings[current_ring_index - 1].global_position
		approach_direction = (target_position - previous_position).normalized()
	elif rings.size() > 1:
		approach_direction = (rings[1].global_position - target_position).normalized()

	var recovery_position: Vector3 = target_position - approach_direction * 38.0 + Vector3.UP * 1.5
	return Transform3D(Basis(), recovery_position).looking_at(target_position, Vector3.UP)


func _build_ring_route() -> void:
	_clear_children(ring_parent)
	rings.clear()

	var route := [
		Vector3(0, 34, -70),
		Vector3(38, 42, -135),
		Vector3(86, 58, -205),
		Vector3(62, 76, -285),
		Vector3(-5, 68, -355),
		Vector3(-70, 52, -420),
		Vector3(-118, 45, -505),
		Vector3(-78, 66, -585),
		Vector3(0, 88, -650),
		Vector3(78, 73, -720),
		Vector3(128, 56, -805),
		Vector3(92, 38, -890),
		Vector3(18, 48, -960),
		Vector3(-58, 72, -1030),
		Vector3(0, 86, -1120)
	]

	for index in range(route.size()):
		var ring = ring_scene.instantiate()
		ring.name = "Ring%02d" % (index + 1)
		ring_parent.add_child(ring)
		ring.global_position = route[index]
		ring.configure(index)
		var look_target: Vector3
		if index < route.size() - 1:
			look_target = route[index + 1]
		elif index > 0:
			look_target = route[index] + (route[index] - route[index - 1])
		else:
			look_target = route[index] + Vector3.FORWARD
		ring.look_at(look_target, Vector3.UP)
		ring.ring_entered.connect(_on_ring_entered)
		rings.append(ring)


func _build_test_world() -> void:
	_clear_children(world)
	_create_static_box("Terrain", Vector3(0.0, -1.0, -520.0), Vector3(760.0, 2.0, 1240.0), _terrain_material)
	_create_carrier(Vector3(0.0, 5.0, 42.0))
	_create_visual_box("StartZone", Vector3(0.0, 11.3, 52.0), Vector3(34.0, 0.16, 24.0), _make_material(Color(0.1, 0.75, 1.0, 0.55)))

	var mountain_data := [
		[Vector3(-170, 0, -150), 48.0, 82.0],
		[Vector3(190, 0, -260), 68.0, 125.0],
		[Vector3(-225, 0, -410), 72.0, 118.0],
		[Vector3(205, 0, -570), 58.0, 92.0],
		[Vector3(-175, 0, -760), 64.0, 108.0],
		[Vector3(215, 0, -930), 78.0, 132.0],
		[Vector3(-135, 0, -1070), 54.0, 96.0]
	]

	for data in mountain_data:
		_create_mountain(data[0], data[1], data[2])

	var obstacles := [
		[Vector3(28, 18, -245), Vector3(13, 36, 13)],
		[Vector3(-38, 24, -330), Vector3(16, 48, 16)],
		[Vector3(-108, 28, -535), Vector3(14, 56, 14)],
		[Vector3(112, 23, -760), Vector3(15, 46, 15)],
		[Vector3(52, 30, -905), Vector3(18, 60, 18)]
	]

	for obstacle in obstacles:
		_create_static_box("Obstacle", obstacle[0], obstacle[1], _obstacle_material)


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
	body.name = "Mountain"
	body.position = base_position + Vector3.UP * (height * 0.5)
	world.add_child(body)

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.12
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 11

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _obstacle_material
	body.add_child(mesh_instance)

	var shape := BoxShape3D.new()
	shape.size = Vector3(radius * 1.2, height, radius * 1.2)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)

	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = radius * 0.05
	cap_mesh.bottom_radius = radius * 0.34
	cap_mesh.height = height * 0.18
	cap_mesh.radial_segments = 9
	var cap := MeshInstance3D.new()
	cap.name = "SnowCap"
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, height * 0.42, 0.0)
	cap.material_override = _make_material(Color(0.82, 0.86, 0.82, 1.0))
	body.add_child(cap)


func _create_carrier(origin: Vector3) -> void:
	_create_static_box("AircraftCarrierHull", origin, Vector3(42.0, 9.0, 118.0), _carrier_material)
	_create_static_box("AircraftCarrierDeck", origin + Vector3(0.0, 5.0, -4.0), Vector3(58.0, 2.0, 132.0), _carrier_material)
	_create_static_box("CarrierIsland", origin + Vector3(18.0, 12.0, -18.0), Vector3(12.0, 14.0, 18.0), _carrier_material)
	_create_visual_box("RunwayStripe", origin + Vector3(0.0, 6.2, -5.0), Vector3(2.2, 0.15, 112.0), _make_material(Color(0.9, 0.92, 0.86, 1.0)))
	_create_visual_box("RunwayLeftMark", origin + Vector3(-18.0, 6.25, 24.0), Vector3(8.0, 0.12, 2.2), _make_material(Color(1.0, 0.82, 0.22, 1.0)))
	_create_visual_box("RunwayRightMark", origin + Vector3(18.0, 6.25, 24.0), Vector3(8.0, 0.12, 2.2), _make_material(Color(1.0, 0.82, 0.22, 1.0)))


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.free()


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.5
	return material
