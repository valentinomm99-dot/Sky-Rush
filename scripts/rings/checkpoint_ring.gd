class_name CheckpointRing
extends Area3D

signal ring_entered(ring_index: int)

@export var ring_index: int = 0
@export var ring_radius: float = 7.0
@export var ring_thickness: float = 0.42
@export var detection_radius: float = 5.2

var is_active: bool = false
var is_passed: bool = false

var _visual: MeshInstance3D
var _label: Label3D
var _light: OmniLight3D
var _active_material: Material
var _inactive_material: Material
var _passed_material: Material


func _ready() -> void:
	monitoring = true
	monitorable = false
	_active_material = load("res://materials/ring_active.tres") as Material
	_inactive_material = load("res://materials/ring_inactive.tres") as Material
	_passed_material = load("res://materials/ring_passed.tres") as Material
	_build_collision()
	_build_visual()
	body_entered.connect(_on_body_entered)
	_refresh_appearance()


func configure(index: int) -> void:
	ring_index = index
	if _label != null:
		_label.text = str(index + 1)


func set_active(active: bool) -> void:
	is_active = active
	_refresh_appearance()


func mark_passed() -> void:
	is_passed = true
	is_active = false
	_refresh_appearance()


func reset_ring() -> void:
	is_passed = false
	is_active = false
	_refresh_appearance()


func _on_body_entered(body: Node) -> void:
	if is_active and not is_passed and body.is_in_group("player"):
		ring_entered.emit(ring_index)


func _build_collision() -> void:
	if has_node("DetectionShape"):
		return

	var sphere := SphereShape3D.new()
	sphere.radius = detection_radius

	var collision := CollisionShape3D.new()
	collision.name = "DetectionShape"
	collision.shape = sphere
	add_child(collision)


func _build_visual() -> void:
	if _visual == null:
		var mesh := TorusMesh.new()
		mesh.inner_radius = ring_radius - ring_thickness
		mesh.outer_radius = ring_radius + ring_thickness
		mesh.rings = 18
		mesh.ring_segments = 72

		_visual = MeshInstance3D.new()
		_visual.name = "RingVisual"
		_visual.mesh = mesh
		_visual.rotation_degrees.x = 90.0
		add_child(_visual)

	if _label == null:
		_label = Label3D.new()
		_label.name = "RingNumber"
		_label.text = str(ring_index + 1)
		_label.font_size = 96
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.position = Vector3(0.0, ring_radius + 2.0, 0.0)
		add_child(_label)

	if _light == null:
		_light = OmniLight3D.new()
		_light.name = "ActiveLight"
		_light.light_energy = 2.2
		_light.omni_range = 18.0
		add_child(_light)


func _refresh_appearance() -> void:
	if _visual == null:
		return

	if is_passed:
		_visual.material_override = _passed_material
		_label.modulate = Color(0.35, 1.0, 0.45, 0.75)
		_light.visible = false
	elif is_active:
		_visual.material_override = _active_material
		_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
		_light.visible = true
	else:
		_visual.material_override = _inactive_material
		_label.modulate = Color(0.45, 0.65, 1.0, 0.38)
		_light.visible = false
