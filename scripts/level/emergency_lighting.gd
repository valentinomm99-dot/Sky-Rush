extends Node3D

@export var sun_path: NodePath
@export var light_energy := 2.2
@export var light_height := 2.6

var _sun: DirectionalLight3D
var _room_lights: Array[OmniLight3D] = []

func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D


func setup(room_positions: Array[Vector3]) -> void:
	for light in _room_lights:
		light.queue_free()
	_room_lights.clear()

	for index in room_positions.size():
		var light := OmniLight3D.new()
		light.name = "EmergencyLight_%02d" % (index + 1)
		light.position = room_positions[index] + Vector3(0.0, light_height, 0.0)
		light.light_color = Color(1.0, 0.16, 0.08, 1.0)
		light.light_energy = light_energy
		light.omni_range = 8.0
		light.visible = false
		add_child(light)
		_room_lights.append(light)


func activate_emergency() -> void:
	if _sun != null:
		_sun.light_color = Color(1.0, 0.28, 0.16, 1.0)
		_sun.light_energy = 0.65

	for light in _room_lights:
		light.visible = true


func reset_lighting() -> void:
	if _sun != null:
		_sun.light_color = Color.WHITE
		_sun.light_energy = 1.3

	for light in _room_lights:
		light.visible = false
