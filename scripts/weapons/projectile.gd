class_name Projectile
extends Area3D

@export var speed: float = 165.0
@export var damage: float = 8.0
@export var max_distance: float = 420.0
@export var radius: float = 0.16

var owner_node: Node
var _start_position: Vector3
var _direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
	add_to_group("projectiles")
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_start_position = global_position
	_direction = -global_transform.basis.z.normalized()
	_build_shape()
	_build_visual()


func setup(new_owner: Node, new_damage: float, new_range: float, spread_radians: float = 0.0) -> void:
	owner_node = new_owner
	damage = new_damage
	max_distance = new_range
	if spread_radians > 0.0:
		var random_yaw := randf_range(-spread_radians, spread_radians)
		var random_pitch := randf_range(-spread_radians, spread_radians)
		rotate_object_local(Vector3.UP, random_yaw)
		rotate_object_local(Vector3.RIGHT, random_pitch)
	_start_position = global_position
	_direction = -global_transform.basis.z.normalized()


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	if global_position.distance_to(_start_position) >= max_distance:
		queue_free()


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area3D) -> void:
	_try_hit(area)


func _try_hit(target: Node) -> void:
	if target == owner_node or target.is_ancestor_of(owner_node) or owner_node != null and owner_node.is_ancestor_of(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(damage, owner_node)
	queue_free()


func _build_shape() -> void:
	if has_node("CollisionShape3D"):
		return
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = sphere
	add_child(shape)


func _build_visual() -> void:
	if has_node("Visual"):
		return
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = 0.9
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	visual.rotation_degrees.x = 90.0
	visual.material_override = load("res://materials/projectile.tres") as Material
	add_child(visual)
