extends CanvasLayer

@onready var seed_label := $SeedLabel as Label
@onready var objective_label := $ObjectiveLabel as Label
@onready var timer_label := $TimerLabel as Label
@onready var interaction_label := $InteractionLabel as Label
@onready var end_overlay := $EndOverlay as ColorRect
@onready var result_label := $EndOverlay/ResultLabel as Label

func _ready() -> void:
	_ensure_refs()
	set_interaction_text("")
	show_end_screen("", false)


func set_seed(value: int) -> void:
	_ensure_refs()
	seed_label.text = "Semilla: %d" % value


func set_objective(text: String) -> void:
	_ensure_refs()
	objective_label.text = "Objetivo: %s" % text


func set_time_remaining(seconds: float, visible: bool) -> void:
	_ensure_refs()
	timer_label.visible = visible
	if not visible:
		timer_label.text = "Tiempo: --"
		return

	var total_seconds := maxi(0, ceili(seconds))
	var minutes := total_seconds / 60
	var remaining_seconds := total_seconds % 60
	timer_label.text = "Tiempo: %02d:%02d" % [minutes, remaining_seconds]


func set_interaction_text(text: String) -> void:
	_ensure_refs()
	interaction_label.visible = not text.is_empty()
	interaction_label.text = text


func show_end_screen(text: String, visible: bool) -> void:
	_ensure_refs()
	end_overlay.visible = visible
	result_label.text = text


func _ensure_refs() -> void:
	if seed_label == null:
		seed_label = get_node_or_null("SeedLabel") as Label
	if objective_label == null:
		objective_label = get_node_or_null("ObjectiveLabel") as Label
	if timer_label == null:
		timer_label = get_node_or_null("TimerLabel") as Label
	if interaction_label == null:
		interaction_label = get_node_or_null("InteractionLabel") as Label
	if end_overlay == null:
		end_overlay = get_node_or_null("EndOverlay") as ColorRect
	if result_label == null:
		result_label = get_node_or_null("EndOverlay/ResultLabel") as Label
