extends Node

@export var body: CharacterBody3D
@export var walk_speed := 6.0
@export var sprint_speed := 9.0
@export var jump_velocity := 4.8
@export var acceleration := 18.0
@export var deceleration := 24.0
@export var gravity := 18.0

const ACTION_KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
}

func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody3D

	for action_name in ACTION_KEYS:
		_ensure_action(action_name, ACTION_KEYS[action_name])


func _physics_process(delta: float) -> void:
	if body == null:
		return

	var velocity := body.velocity
	if body.is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.1
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_direction := Vector3.ZERO
	if input_vector.length_squared() > 0.0:
		wish_direction = (body.global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()

	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_horizontal := wish_direction * target_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if wish_direction != Vector3.ZERO else deceleration
	horizontal = horizontal.move_toward(target_horizontal, rate * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	body.velocity = velocity
	body.move_and_slide()


func _ensure_action(action_name: StringName, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for keycode in keys:
		if not _action_has_key(action_name, keycode):
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)


func _action_has_key(action_name: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false
