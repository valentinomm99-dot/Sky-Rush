extends Area3D

signal core_collected(core: Node)

var _collected := false

func get_interaction_text() -> String:
	return "Pulsa E para recoger el Nucleo"


func interact(_actor: Node) -> void:
	if _collected:
		return

	_collected = true
	core_collected.emit(self)
	queue_free()
