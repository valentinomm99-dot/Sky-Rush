class_name GuidedMissile
extends Area3D

@export var speed: float = 92.0
@export var damage: float = 48.0
@export var area_damage_radius: float = 12.0
@export var max_distance: float = 760.0
@export var max_turn_rate: float = 1.45
@export var explosion_lifetime: float = 0.25

var owner_node: Node
var target: Node3D
var guided: bool = false

var _start_position: Vector3
var _direction: Vector3


func _ready() -> void:
	add_to_group("projectiles")
	monitoring = true
	body_entered.connect(_on_hit_node)
	area_entered.connect(_on_hit_node)
	_start_position = global_position
	_direction = -global_transform.basis.z.normalized()
	_build_shape()
	_build_visual()


func setup(new_owner: Node, new_target: Node3D, is_guided: bool) -> void:
	owner_node = new_owner
	target = new_target
	guided = is_guided
	_start_position = global_position
	_direction = -global_transform.basis.z.normalized()


func _physics_process(delta: float) -> void:
	if guided and target != null and is_instance_valid(target):
		var desired_direction := (target.global_position - global_position).normalized()
		var turn_weight := minf(1.0, max_turn_rate * delta)
		_direction = _direction.slerp(desired_direction, turn_weight).normalized()
		look_at(global_position + _direction, Vector3.UP)

	global_position += _direction * speed * delta
	if global_position.distance_to(_start_position) >= max_distance:
		_explode()


func _on_hit_node(node: Node) -> void:
	if node == owner_node or owner_node != null and owner_node.is_ancestor_of(node):
		return
	_explode()


func _explode() -> void:
	_apply_area_damage()
	_show_explosion()
	queue_free()


func _apply_area_damage() -> void:
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = area_damage_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var hits := space.intersect_shape(query, 24)
	for hit in hits:
		var collider := hit.get("collider") as Node
		if collider == null or collider == owner_node:
			continue
		if collider.has_method("take_damage"):
			collider.take_damage(damage, owner_node)


func _show_explosion() -> void:
	var sphere := MeshInstance3D.new()
	sphere.name = "MissileExplosion"
	var mesh := SphereMesh.new()
	mesh.radius = area_damage_radius * 0.35
	mesh.height = area_damage_radius * 0.7
	sphere.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.45, 0.08, 0.68)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.25, 0.05, 1.0)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material_override = material
	_get_spawn_parent().add_child(sphere)
	sphere.global_position = global_position
	sphere.create_tween().tween_property(sphere, "scale", Vector3.ONE * 2.6, explosion_lifetime)
	sphere.create_tween().tween_callback(sphere.queue_free).set_delay(explosion_lifetime)


func _get_spawn_parent() -> Node:
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_tree().root


func _build_shape() -> void:
	if has_node("CollisionShape3D"):
		return
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = sphere
	add_child(shape)


func _build_visual() -> void:
	if has_node("Visual"):
		return
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.12
	body_mesh.bottom_radius = 0.18
	body_mesh.height = 1.9
	body_mesh.radial_segments = 10
	var body := MeshInstance3D.new()
	body.name = "Visual"
	body.mesh = body_mesh
	body.rotation_degrees.x = 90.0
	body.material_override = load("res://materials/missile.tres") as Material
	add_child(body)
