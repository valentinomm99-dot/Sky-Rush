class_name EnemyAircraft
extends CharacterBody3D

signal destroyed(enemy: Node)
signal health_changed(enemy: Node, current: float, maximum: float)

enum AIState { PATROL, CHASE, ATTACK, EVADE, SEARCH }

@export var max_health: float = 70.0
@export var cruise_speed: float = 34.0
@export var attack_speed: float = 44.0
@export var turn_rate: float = 1.25
@export var min_altitude: float = 14.0
@export var max_altitude: float = 140.0
@export var detection_range: float = 360.0
@export var attack_range: float = 210.0
@export var attack_angle_degrees: float = 13.0
@export var gun_damage: float = 6.0
@export var gun_fire_rate: float = 5.0
@export var patrol_radius: float = 120.0
@export var projectile_scene: PackedScene

var player: Node3D
var patrol_points: Array = []
var state: AIState = AIState.PATROL
var last_known_player_position: Vector3

var _health_component
var _body_material: Material
var _wing_material: Material
var _damage_flash_material: Material
var _flash_timer: float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _mesh_materials: Dictionary = {}
var _patrol_index: int = 0
var _gun_cooldown: float = 0.0
var _evade_timer: float = 0.0
var _destroyed: bool = false
var _marker: Label3D
var _health_bar: MeshInstance3D
var _health_bar_back: MeshInstance3D


func _ready() -> void:
	add_to_group("enemies")
	_body_material = load("res://materials/enemy_body.tres") as Material
	_wing_material = load("res://materials/enemy_wing.tres") as Material
	_damage_flash_material = load("res://materials/damage_flash.tres") as Material
	if projectile_scene == null:
		projectile_scene = load("res://scenes/weapons/projectile.tscn") as PackedScene
	_build_collision()
	_build_visual()
	_setup_health()


func _process(delta: float) -> void:
	_update_damage_flash(delta)
	_update_marker_visibility()


func _physics_process(delta: float) -> void:
	if _destroyed:
		return

	_gun_cooldown = maxf(0.0, _gun_cooldown - delta)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D

	_update_state(delta)
	_fly(delta)


func configure(new_player: Node3D, points: Array) -> void:
	player = new_player
	patrol_points = points
	if not patrol_points.is_empty():
		global_position = patrol_points[0]
		if patrol_points.size() > 1:
			look_at(patrol_points[1], Vector3.UP)


func take_damage(amount: float, source: Node = null) -> bool:
	if _health_component == null:
		return false
	return _health_component.take_damage(amount, source)


func is_destroyed() -> bool:
	return _destroyed


func set_target_marker(active: bool, locked: bool, progress: float) -> void:
	if _marker == null:
		return
	if active:
		_marker.visible = true
		_marker.text = "FIJADO" if locked else "LOCK %.0f%%" % (progress * 100.0)
		_marker.modulate = Color(1.0, 0.2, 0.1, 1.0) if locked else Color(1.0, 0.85, 0.18, 1.0)
	else:
		_marker.text = "ENEMIGO"


func _update_state(delta: float) -> void:
	if player == null:
		state = AIState.PATROL
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var can_see_player := distance <= detection_range and _has_line_of_sight(player.global_position)
	if can_see_player:
		last_known_player_position = player.global_position

	match state:
		AIState.PATROL:
			if can_see_player:
				state = AIState.CHASE
		AIState.CHASE:
			if not can_see_player:
				state = AIState.SEARCH
			elif _can_attack_player(distance):
				state = AIState.ATTACK
		AIState.ATTACK:
			if not can_see_player:
				state = AIState.SEARCH
			elif not _can_attack_player(distance):
				state = AIState.CHASE
		AIState.EVADE:
			_evade_timer = maxf(0.0, _evade_timer - delta)
			if _evade_timer <= 0.0:
				state = AIState.CHASE if can_see_player else AIState.SEARCH
		AIState.SEARCH:
			if can_see_player:
				state = AIState.CHASE
			elif global_position.distance_to(last_known_player_position) < 18.0:
				state = AIState.PATROL


func _fly(delta: float) -> void:
	var target_position := _get_state_target()
	var desired_direction := (target_position - global_position).normalized()
	desired_direction = _apply_avoidance(desired_direction)

	if desired_direction.length() < 0.01:
		desired_direction = -global_transform.basis.z.normalized()

	var desired_basis := Basis.looking_at(desired_direction, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(desired_basis, minf(1.0, turn_rate * delta)).orthonormalized()

	var speed := attack_speed if state == AIState.ATTACK or state == AIState.CHASE else cruise_speed
	velocity = -global_transform.basis.z.normalized() * speed
	move_and_slide()

	if global_position.y < min_altitude:
		global_position.y = min_altitude
	if global_position.y > max_altitude:
		global_position.y = max_altitude

	if state == AIState.ATTACK:
		_try_fire()


func _get_state_target() -> Vector3:
	match state:
		AIState.PATROL:
			if patrol_points.is_empty():
				return global_position + -global_transform.basis.z * 40.0
			var target: Vector3 = patrol_points[_patrol_index]
			if global_position.distance_to(target) < 22.0:
				_patrol_index = (_patrol_index + 1) % patrol_points.size()
				target = patrol_points[_patrol_index]
			return target
		AIState.CHASE:
			var behind_player: Vector3 = player.global_position + player.global_transform.basis.z.normalized() * 45.0 + Vector3.UP * 4.0
			return behind_player
		AIState.ATTACK:
			return player.global_position
		AIState.EVADE:
			return global_position + global_transform.basis.x.normalized() * 85.0 + Vector3.UP * 34.0
		AIState.SEARCH:
			return last_known_player_position
	return global_position


func _apply_avoidance(desired_direction: Vector3) -> Vector3:
	var forward := -global_transform.basis.z.normalized()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + forward * 45.0)
	query.exclude = [self]
	query.collision_mask = 3
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		desired_direction += Vector3.UP * 0.9 + global_transform.basis.x.normalized() * randf_range(-0.6, 0.6)

	if global_position.y < min_altitude + 16.0:
		desired_direction += Vector3.UP * 0.75
	if global_position.y > max_altitude - 12.0:
		desired_direction += Vector3.DOWN * 0.75
	if absf(global_position.x) > 340.0:
		desired_direction.x += -signf(global_position.x) * 0.9
	if absf(global_position.z) > 1180.0:
		desired_direction.z += -signf(global_position.z) * 0.9
	return desired_direction.normalized()


func _can_attack_player(distance: float) -> bool:
	if player == null or distance > attack_range:
		return false
	var forward := -global_transform.basis.z.normalized()
	var direction := (player.global_position - global_position).normalized()
	var angle := rad_to_deg(acos(clampf(forward.dot(direction), -1.0, 1.0)))
	return angle <= attack_angle_degrees and _has_line_of_sight(player.global_position)


func _has_line_of_sight(point: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, point)
	query.exclude = [self]
	query.collision_mask = 3
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	return collider == player


func _try_fire() -> void:
	if _gun_cooldown > 0.0 or projectile_scene == null:
		return
	_gun_cooldown = 1.0 / gun_fire_rate
	var projectile := projectile_scene.instantiate()
	_get_spawn_parent().add_child(projectile)
	projectile.global_transform = global_transform
	projectile.global_position += -global_transform.basis.z.normalized() * 3.0
	projectile.setup(self, gun_damage, attack_range + 80.0, deg_to_rad(1.8))


func _setup_health() -> void:
	_health_component = get_node_or_null("HealthComponent")
	if _health_component == null:
		_health_component = Node.new()
		_health_component.name = "HealthComponent"
		_health_component.set_script(load("res://scripts/components/health_component.gd"))
		add_child(_health_component)
	_health_component.max_health = max_health
	_health_component.invulnerability_seconds = 0.15
	_health_component.health_changed.connect(_on_health_changed)
	_health_component.damaged.connect(_on_damaged)
	_health_component.died.connect(_on_died)
	_health_component.reset_health()


func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(self, current, maximum)
	if _health_bar != null:
		_health_bar.scale.x = maxf(0.02, current / maximum)


func _on_damaged(_amount: float, _source: Node) -> void:
	_flash_timer = 0.18
	_evade_timer = 1.25
	state = AIState.EVADE
	_marker.visible = true
	_health_bar.visible = true
	_health_bar_back.visible = true
	for mesh in _meshes:
		mesh.material_override = _damage_flash_material


func _on_died(_source: Node) -> void:
	_destroyed = true
	set_physics_process(false)
	_create_destroy_effect()
	destroyed.emit(self)
	queue_free()


func _update_damage_flash(delta: float) -> void:
	if _flash_timer <= 0.0:
		return
	_flash_timer = maxf(0.0, _flash_timer - delta)
	if _flash_timer <= 0.0:
		for mesh in _meshes:
			if _mesh_materials.has(mesh):
				mesh.material_override = _mesh_materials[mesh]


func _update_marker_visibility() -> void:
	if player == null or _marker == null:
		return
	var distance := global_position.distance_to(player.global_position)
	var visible := distance < detection_range
	_marker.visible = visible
	var show_health := distance < 190.0 or _flash_timer > 0.0
	_health_bar.visible = show_health
	_health_bar_back.visible = show_health


func _build_collision() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.2, 1.2, 5.4)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	var visual := Node3D.new()
	visual.name = "EnemyVisual"
	add_child(visual)
	_add_cylinder_mesh(visual, "Fuselage", Vector3.ZERO, 0.42, 4.6, _body_material, false)
	_add_cylinder_mesh(visual, "Nose", Vector3(0, 0, -2.55), 0.42, 0.9, _body_material, true)
	_add_box_mesh(visual, "Wings", Vector3(0, -0.02, -0.15), Vector3(6.2, 0.14, 0.92), _wing_material)
	_add_box_mesh(visual, "Tail", Vector3(0, 0.08, 2.0), Vector3(2.4, 0.12, 0.48), _wing_material)
	_add_box_mesh(visual, "Fin", Vector3(0, 0.55, 1.9), Vector3(0.22, 0.95, 0.62), _wing_material)

	_marker = Label3D.new()
	_marker.name = "Marker"
	_marker.text = "ENEMIGO"
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.font_size = 54
	_marker.position = Vector3(0, 4.0, 0)
	_marker.modulate = Color(1.0, 0.34, 0.18, 1.0)
	add_child(_marker)

	_health_bar_back = _make_bar("HealthBack", Color(0.08, 0.08, 0.08, 0.9), Vector3(0, 3.35, 0), Vector3(2.4, 0.12, 0.08))
	_health_bar = _make_bar("HealthBar", Color(0.95, 0.12, 0.08, 1.0), Vector3(0, 3.35, -0.01), Vector3(2.3, 0.14, 0.1))


func _add_box_mesh(parent: Node, node_name: String, local_position: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	parent.add_child(instance)
	_meshes.append(instance)
	_mesh_materials[instance] = material


func _add_cylinder_mesh(parent: Node, node_name: String, local_position: Vector3, radius: float, height: float, material: Material, cone: bool) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0 if cone else radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.rotation_degrees.x = 90.0
	instance.material_override = material
	parent.add_child(instance)
	_meshes.append(instance)
	_mesh_materials[instance] = material


func _make_bar(node_name: String, color: Color, local_position: Vector3, size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var bar := MeshInstance3D.new()
	bar.name = node_name
	bar.mesh = mesh
	bar.material_override = material
	bar.position = local_position
	add_child(bar)
	return bar


func _create_destroy_effect() -> void:
	var effect := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 4.5
	mesh.height = 9.0
	effect.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.35, 0.05, 0.7)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.22, 0.05, 1.0)
	material.emission_energy_multiplier = 2.4
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	effect.material_override = material
	_get_spawn_parent().add_child(effect)
	effect.global_position = global_position
	effect.create_tween().tween_property(effect, "scale", Vector3.ONE * 2.8, 0.35)
	effect.create_tween().tween_callback(effect.queue_free).set_delay(0.38)


func _get_spawn_parent() -> Node:
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_tree().root
