extends Node

enum GameState {
	FIND_CORE,
	ESCAPE,
	VICTORY,
	DEFEAT,
}

@export var generator_path: NodePath
@export var generated_parent_path: NodePath
@export var player_path: NodePath
@export var hud_path: NodePath
@export var lighting_path: NodePath
@export var core_scene: PackedScene
@export var exit_scene: PackedScene
@export var countdown_seconds := 90.0

var state := GameState.FIND_CORE
var time_remaining := 0.0
var core_pickup: Node
var exit_door: Node

var _hud: Node
var _lighting: Node
var _player: CharacterBody3D
var _generated_parent: Node3D

func _ready() -> void:
	start_game()


func _process(delta: float) -> void:
	if state != GameState.ESCAPE:
		return

	time_remaining -= delta
	if _hud != null and _hud.has_method("set_time_remaining"):
		_hud.set_time_remaining(time_remaining, true)

	if time_remaining <= 0.0:
		_trigger_defeat()


func start_game() -> void:
	_hud = get_node_or_null(hud_path)
	_lighting = get_node_or_null(lighting_path)
	_player = get_node_or_null(player_path) as CharacterBody3D
	_generated_parent = get_node_or_null(generated_parent_path) as Node3D

	_connect_player_interactor()
	_set_state_find_core()

	var generator := get_node_or_null(generator_path)
	if generator == null:
		push_error("GameManager necesita un ProceduralLevelGenerator.")
		return

	if generator.has_signal("level_generated") and not generator.level_generated.is_connected(_on_level_generated):
		generator.level_generated.connect(_on_level_generated)

	if generator.has_method("generate"):
		generator.generate()


func _on_level_generated(room_positions: Array[Vector3], generated_seed: int) -> void:
	if _hud != null and _hud.has_method("set_seed"):
		_hud.set_seed(generated_seed)
	if _lighting != null and _lighting.has_method("setup"):
		_lighting.setup(room_positions)
	if _lighting != null and _lighting.has_method("reset_lighting"):
		_lighting.reset_lighting()

	_spawn_objectives(room_positions, generated_seed)


func _spawn_objectives(room_positions: Array[Vector3], generated_seed: int) -> void:
	if core_scene == null or exit_scene == null or _generated_parent == null:
		push_error("GameManager necesita core_scene, exit_scene y generated_parent.")
		return
	if room_positions.size() < 2:
		push_error("Se necesitan al menos 2 salas para colocar Nucleo y salida.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = generated_seed ^ 0x5A17

	var core_index := rng.randi_range(0, room_positions.size() - 1)
	var exit_index := rng.randi_range(0, room_positions.size() - 1)
	while exit_index == core_index:
		exit_index = rng.randi_range(0, room_positions.size() - 1)

	core_pickup = core_scene.instantiate()
	core_pickup.name = "Nucleo"
	_generated_parent.add_child(core_pickup)
	(core_pickup as Node3D).position = room_positions[core_index] + Vector3(0.0, 1.0, 0.0)
	if core_pickup.has_signal("core_collected"):
		core_pickup.core_collected.connect(_on_core_collected)

	exit_door = exit_scene.instantiate()
	exit_door.name = "PuertaSalida"
	_generated_parent.add_child(exit_door)
	(exit_door as Node3D).position = room_positions[exit_index] + Vector3(0.0, 1.25, 0.0)
	if exit_door.has_method("set_active"):
		exit_door.set_active(false)
	if exit_door.has_signal("exit_requested"):
		exit_door.exit_requested.connect(_on_exit_requested)


func _connect_player_interactor() -> void:
	if _player == null:
		return

	var interactor := _player.get_node_or_null("InteractorComponent")
	if interactor == null:
		return

	if interactor.has_signal("interaction_text_changed") and not interactor.interaction_text_changed.is_connected(_on_interaction_text_changed):
		interactor.interaction_text_changed.connect(_on_interaction_text_changed)


func _on_core_collected(_core: Node) -> void:
	state = GameState.ESCAPE
	time_remaining = countdown_seconds

	if exit_door != null and exit_door.has_method("set_active"):
		exit_door.set_active(true)
	if _lighting != null and _lighting.has_method("activate_emergency"):
		_lighting.activate_emergency()
	if _hud != null:
		if _hud.has_method("set_objective"):
			_hud.set_objective("Llega a la salida")
		if _hud.has_method("set_time_remaining"):
			_hud.set_time_remaining(time_remaining, true)
		if _hud.has_method("set_interaction_text"):
			_hud.set_interaction_text("")


func _on_exit_requested(_exit_door: Node) -> void:
	if state == GameState.ESCAPE:
		_trigger_victory()


func _on_interaction_text_changed(text: String) -> void:
	if state == GameState.VICTORY or state == GameState.DEFEAT:
		return
	if _hud != null and _hud.has_method("set_interaction_text"):
		_hud.set_interaction_text(text)


func _set_state_find_core() -> void:
	state = GameState.FIND_CORE
	time_remaining = 0.0
	if _hud != null:
		if _hud.has_method("set_objective"):
			_hud.set_objective("Encuentra el Nucleo")
		if _hud.has_method("set_time_remaining"):
			_hud.set_time_remaining(0.0, false)
		if _hud.has_method("set_interaction_text"):
			_hud.set_interaction_text("")
		if _hud.has_method("show_end_screen"):
			_hud.show_end_screen("", false)


func _trigger_victory() -> void:
	state = GameState.VICTORY
	_show_result("VICTORIA\nEscapaste con el Nucleo")


func _trigger_defeat() -> void:
	state = GameState.DEFEAT
	_show_result("DERROTA\nSe acabo el tiempo")


func _show_result(text: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _hud != null:
		if _hud.has_method("set_interaction_text"):
			_hud.set_interaction_text("")
		if _hud.has_method("set_time_remaining"):
			_hud.set_time_remaining(time_remaining, state == GameState.DEFEAT)
		if _hud.has_method("show_end_screen"):
			_hud.show_end_screen(text, true)
