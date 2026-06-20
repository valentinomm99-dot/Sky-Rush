extends Area3D

signal exit_requested(exit_door: Node)

@export var active_material: Material
@export var inactive_material: Material

var is_active := false

@onready var door_mesh := $DoorMesh as MeshInstance3D

func _ready() -> void:
	set_active(is_active)


func set_active(value: bool) -> void:
	is_active = value
	if door_mesh == null:
		return

	door_mesh.material_override = active_material if is_active else inactive_material


func get_interaction_text() -> String:
	if is_active:
		return "Pulsa E para escapar"
	return "Necesitas el Nucleo"


func interact(_actor: Node) -> void:
	if is_active:
		exit_requested.emit(self)
