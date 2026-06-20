extends Node3D

signal level_generated(room_positions: Array[Vector3], generated_seed: int)

@export var room_prefab: PackedScene
@export_range(1, 64, 1) var room_count := 10
@export var seed := 20260620
@export var use_random_seed := false
@export var auto_generate := true
@export var room_spacing := 12.0
@export var room_size := Vector2(8.0, 8.0)
@export var corridor_width := 3.0
@export var wall_height := 3.0
@export var wall_thickness := 0.3
@export var generated_parent_path: NodePath
@export var player_path: NodePath
@export var seed_label_path: NodePath

var generated_seed := 0
var room_cells: Array[Vector2i] = []
var room_world_positions: Array[Vector3] = []
var connections: Dictionary = {}

var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D

const DIRECTIONS := [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.DOWN,
]

func _ready() -> void:
	if auto_generate:
		generate()


func generate() -> void:
	var generated_parent := _get_generated_parent()
	_clear_children(generated_parent)
	_setup_materials()
	_generate_layout()
	_spawn_rooms(generated_parent)
	_spawn_connections(generated_parent)
	_place_player()
	_update_seed_label()
	level_generated.emit(room_world_positions, generated_seed)


func _get_generated_parent() -> Node3D:
	var parent := get_node_or_null(generated_parent_path) as Node3D
	return parent if parent != null else self


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


func _setup_materials() -> void:
	_floor_material = StandardMaterial3D.new()
	_floor_material.albedo_color = Color(0.34, 0.34, 0.32, 1.0)
	_floor_material.roughness = 0.9

	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = Color(0.58, 0.61, 0.64, 1.0)
	_wall_material.roughness = 0.8


func _generate_layout() -> void:
	generated_seed = seed
	if use_random_seed or generated_seed == 0:
		generated_seed = int(Time.get_unix_time_from_system()) & 0x7fffffff

	var rng := RandomNumberGenerator.new()
	rng.seed = generated_seed
	var occupied := {}
	room_cells.clear()
	room_world_positions.clear()
	connections.clear()

	var start := Vector2i.ZERO
	room_cells.append(start)
	occupied[start] = true
	connections[start] = []

	var attempts := 0
	var max_attempts := room_count * 80
	while room_cells.size() < room_count and attempts < max_attempts:
		attempts += 1
		var from_cell: Vector2i = room_cells[rng.randi_range(0, room_cells.size() - 1)]
		var directions := _get_shuffled_directions(rng)

		for direction in directions:
			var candidate: Vector2i = from_cell + direction
			if occupied.has(candidate):
				continue

			occupied[candidate] = true
			room_cells.append(candidate)
			connections[candidate] = []
			_add_connection(from_cell, candidate)
			break

	if room_cells.size() != room_count:
		push_error("No se pudieron colocar todas las salas sin superposicion.")


func _get_shuffled_directions(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	directions.assign(DIRECTIONS)

	for i in range(directions.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, i)
		var current := directions[i]
		directions[i] = directions[swap_index]
		directions[swap_index] = current

	return directions


func _add_connection(a: Vector2i, b: Vector2i) -> void:
	if not connections.has(a):
		connections[a] = []
	if not connections.has(b):
		connections[b] = []

	if not connections[a].has(b):
		connections[a].append(b)
	if not connections[b].has(a):
		connections[b].append(a)


func _spawn_rooms(parent: Node3D) -> void:
	if room_prefab == null:
		push_error("ProceduralLevelGenerator necesita un room_prefab asignado.")
		return

	for index in room_cells.size():
		var cell := room_cells[index]
		var room := room_prefab.instantiate() as Node3D
		room.name = "Room_%02d" % (index + 1)
		room.position = _cell_to_world(cell)
		room_world_positions.append(room.position)
		parent.add_child(room)
		_spawn_room_walls(parent, cell)


func _spawn_room_walls(parent: Node3D, cell: Vector2i) -> void:
	var origin := _cell_to_world(cell)
	var half_x := room_size.x * 0.5
	var half_z := room_size.y * 0.5

	_add_wall_side(parent, origin, Vector2i.UP, connections[cell].has(cell + Vector2i.UP), half_x, half_z)
	_add_wall_side(parent, origin, Vector2i.DOWN, connections[cell].has(cell + Vector2i.DOWN), half_x, half_z)
	_add_wall_side(parent, origin, Vector2i.LEFT, connections[cell].has(cell + Vector2i.LEFT), half_x, half_z)
	_add_wall_side(parent, origin, Vector2i.RIGHT, connections[cell].has(cell + Vector2i.RIGHT), half_x, half_z)


func _add_wall_side(parent: Node3D, origin: Vector3, direction: Vector2i, has_door: bool, half_x: float, half_z: float) -> void:
	var door_width := corridor_width
	var segment_x := maxf((room_size.x - door_width) * 0.5, 0.0)
	var segment_z := maxf((room_size.y - door_width) * 0.5, 0.0)

	if direction == Vector2i.UP:
		var z := origin.z - half_z - wall_thickness * 0.5
		if has_door:
			_add_box(parent, origin + Vector3(-(door_width * 0.5 + segment_x * 0.5), wall_height * 0.5, z - origin.z), Vector3(segment_x, wall_height, wall_thickness), _wall_material, "Wall")
			_add_box(parent, origin + Vector3(door_width * 0.5 + segment_x * 0.5, wall_height * 0.5, z - origin.z), Vector3(segment_x, wall_height, wall_thickness), _wall_material, "Wall")
		else:
			_add_box(parent, Vector3(origin.x, wall_height * 0.5, z), Vector3(room_size.x, wall_height, wall_thickness), _wall_material, "Wall")
	elif direction == Vector2i.DOWN:
		var z := origin.z + half_z + wall_thickness * 0.5
		if has_door:
			_add_box(parent, origin + Vector3(-(door_width * 0.5 + segment_x * 0.5), wall_height * 0.5, z - origin.z), Vector3(segment_x, wall_height, wall_thickness), _wall_material, "Wall")
			_add_box(parent, origin + Vector3(door_width * 0.5 + segment_x * 0.5, wall_height * 0.5, z - origin.z), Vector3(segment_x, wall_height, wall_thickness), _wall_material, "Wall")
		else:
			_add_box(parent, Vector3(origin.x, wall_height * 0.5, z), Vector3(room_size.x, wall_height, wall_thickness), _wall_material, "Wall")
	elif direction == Vector2i.LEFT:
		var x := origin.x - half_x - wall_thickness * 0.5
		if has_door:
			_add_box(parent, origin + Vector3(x - origin.x, wall_height * 0.5, -(door_width * 0.5 + segment_z * 0.5)), Vector3(wall_thickness, wall_height, segment_z), _wall_material, "Wall")
			_add_box(parent, origin + Vector3(x - origin.x, wall_height * 0.5, door_width * 0.5 + segment_z * 0.5), Vector3(wall_thickness, wall_height, segment_z), _wall_material, "Wall")
		else:
			_add_box(parent, Vector3(x, wall_height * 0.5, origin.z), Vector3(wall_thickness, wall_height, room_size.y), _wall_material, "Wall")
	elif direction == Vector2i.RIGHT:
		var x := origin.x + half_x + wall_thickness * 0.5
		if has_door:
			_add_box(parent, origin + Vector3(x - origin.x, wall_height * 0.5, -(door_width * 0.5 + segment_z * 0.5)), Vector3(wall_thickness, wall_height, segment_z), _wall_material, "Wall")
			_add_box(parent, origin + Vector3(x - origin.x, wall_height * 0.5, door_width * 0.5 + segment_z * 0.5), Vector3(wall_thickness, wall_height, segment_z), _wall_material, "Wall")
		else:
			_add_box(parent, Vector3(x, wall_height * 0.5, origin.z), Vector3(wall_thickness, wall_height, room_size.y), _wall_material, "Wall")


func _spawn_connections(parent: Node3D) -> void:
	var created := {}
	for cell in room_cells:
		for next_cell in connections[cell]:
			var key := [cell, next_cell]
			var reverse_key := [next_cell, cell]
			if created.has(key) or created.has(reverse_key):
				continue

			created[key] = true
			_spawn_corridor(parent, cell, next_cell)


func _spawn_corridor(parent: Node3D, a: Vector2i, b: Vector2i) -> void:
	var origin_a := _cell_to_world(a)
	var origin_b := _cell_to_world(b)
	var midpoint := (origin_a + origin_b) * 0.5
	var gap_x := absf(origin_a.x - origin_b.x) - room_size.x
	var gap_z := absf(origin_a.z - origin_b.z) - room_size.y

	if a.y == b.y:
		var length := maxf(gap_x + wall_thickness * 2.0, wall_thickness)
		_add_box(parent, Vector3(midpoint.x, -0.01, midpoint.z), Vector3(length, 0.18, corridor_width), _floor_material, "CorridorFloor")
		_add_box(parent, Vector3(midpoint.x, wall_height * 0.5, midpoint.z - corridor_width * 0.5), Vector3(length, wall_height, wall_thickness), _wall_material, "CorridorWall")
		_add_box(parent, Vector3(midpoint.x, wall_height * 0.5, midpoint.z + corridor_width * 0.5), Vector3(length, wall_height, wall_thickness), _wall_material, "CorridorWall")
	else:
		var length := maxf(gap_z + wall_thickness * 2.0, wall_thickness)
		_add_box(parent, Vector3(midpoint.x, -0.01, midpoint.z), Vector3(corridor_width, 0.18, length), _floor_material, "CorridorFloor")
		_add_box(parent, Vector3(midpoint.x - corridor_width * 0.5, wall_height * 0.5, midpoint.z), Vector3(wall_thickness, wall_height, length), _wall_material, "CorridorWall")
		_add_box(parent, Vector3(midpoint.x + corridor_width * 0.5, wall_height * 0.5, midpoint.z), Vector3(wall_thickness, wall_height, length), _wall_material, "CorridorWall")


func _add_box(parent: Node3D, position: Vector3, size: Vector3, material: Material, node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	parent.add_child(body)
	return body


func _place_player() -> void:
	var player := get_node_or_null(player_path) as CharacterBody3D
	if player == null or room_cells.is_empty():
		return

	var spawn_position := _cell_to_world(room_cells[0]) + Vector3(0.0, 0.05, 0.0)
	if player.is_inside_tree():
		player.global_position = spawn_position
	else:
		player.position = spawn_position
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO


func _update_seed_label() -> void:
	var label := get_node_or_null(seed_label_path) as Label
	if label != null:
		label.text = "Semilla: %d" % generated_seed


func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * room_spacing, 0.0, cell.y * room_spacing)
