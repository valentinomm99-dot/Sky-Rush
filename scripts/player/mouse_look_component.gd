extends Node

@export var body: CharacterBody3D
@export var camera_pivot: Node3D
@export var mouse_sensitivity := 0.0025
@export_range(1.0, 89.0, 1.0) var max_pitch_degrees := 85.0

var _pitch := 0.0

func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody3D
	if camera_pivot == null and body != null:
		camera_pivot = body.get_node_or_null("CameraPivot") as Node3D

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_view(event.relative)


func _rotate_view(relative_motion: Vector2) -> void:
	if body == null or camera_pivot == null:
		return

	body.rotate_y(-relative_motion.x * mouse_sensitivity)
	_pitch = clamp(
		_pitch - relative_motion.y * mouse_sensitivity,
		deg_to_rad(-max_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)
	camera_pivot.rotation.x = _pitch
