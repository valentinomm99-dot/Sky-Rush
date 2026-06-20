extends Node

signal focused_interactable_changed(interactable: Node)
signal interaction_text_changed(text: String)

@export var body: CharacterBody3D
@export var raycast_path: NodePath

var focused_interactable: Node

const INTERACT_ACTION := "interact"

func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody3D
	_ensure_interact_action()


func _physics_process(_delta: float) -> void:
	var next_focus := _find_interactable()
	if next_focus != focused_interactable:
		focused_interactable = next_focus
		focused_interactable_changed.emit(focused_interactable)
		interaction_text_changed.emit(_get_interaction_text(focused_interactable))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(INTERACT_ACTION) and focused_interactable != null:
		if focused_interactable.has_method("interact"):
			focused_interactable.interact(body)


func _find_interactable() -> Node:
	var raycast := get_node_or_null(raycast_path) as RayCast3D
	if raycast == null:
		return null

	raycast.force_raycast_update()
	if not raycast.is_colliding():
		return null

	var collider := raycast.get_collider() as Node
	if collider != null and collider.has_method("interact"):
		return collider
	return null


func _get_interaction_text(interactable: Node) -> String:
	if interactable != null and interactable.has_method("get_interaction_text"):
		return interactable.get_interaction_text()
	return ""


func _ensure_interact_action() -> void:
	if not InputMap.has_action(INTERACT_ACTION):
		InputMap.add_action(INTERACT_ACTION)

	for event in InputMap.action_get_events(INTERACT_ACTION):
		if event is InputEventKey and event.physical_keycode == KEY_E:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_E
	InputMap.action_add_event(INTERACT_ACTION, key_event)
