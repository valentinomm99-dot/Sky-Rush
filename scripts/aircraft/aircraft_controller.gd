class_name AircraftController
extends CharacterBody3D

signal crashed(reason: String)
signal flight_data_changed(speed: float, altitude: float, turbo_energy: float, turbo_active: bool, too_slow: bool)
signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal destroyed(source: Node)

@export_group("Speed")
@export var min_speed: float = 24.0
@export var normal_speed: float = 46.0
@export var max_speed: float = 78.0
@export var acceleration: float = 24.0
@export var deceleration: float = 16.0
@export var velocity_alignment: float = 2.4
@export var climb_drag: float = 18.0

@export_group("Turning")
@export var pitch_rate: float = 1.15
@export var roll_rate: float = 1.75
@export var yaw_rate: float = 0.85
@export var bank_turn_rate: float = 0.58
@export var control_response: float = 4.8
@export var auto_level_strength: float = 0.85

@export_group("Turbo")
@export var turbo_capacity: float = 100.0
@export var turbo_drain_per_second: float = 30.0
@export var turbo_recovery_per_second: float = 17.0
@export var turbo_recovery_delay: float = 0.55

@export_group("Altitude")
@export var min_altitude: float = 6.0
@export var max_altitude: float = 160.0
@export var stall_warning_speed: float = 30.0
@export var stall_sink_rate: float = 18.0

@export_group("Combat")
@export var max_health: float = 100.0
@export var damage_invulnerability: float = 1.0

var current_speed: float = 46.0
var turbo_energy: float = 100.0
var input_enabled: bool = false

var _spawn_transform: Transform3D
var _turbo_active: bool = false
var _turbo_recovery_timer: float = 0.0
var _crashed: bool = false
var _pitch_input: float = 0.0
var _roll_input: float = 0.0
var _yaw_input: float = 0.0
var _body_material: Material
var _wing_material: Material
var _damage_flash_material: Material
var _health_component
var _damage_flash_timer: float = 0.0
var _flash_meshes: Array[MeshInstance3D] = []
var _mesh_materials: Dictionary = {}


func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform
	current_speed = normal_speed
	turbo_energy = turbo_capacity
	_body_material = load("res://materials/aircraft_body.tres") as Material
	_wing_material = load("res://materials/aircraft_wing.tres") as Material
	_damage_flash_material = load("res://materials/damage_flash.tres") as Material
	_build_collision()
	_build_visual()
	_setup_health()
	_emit_flight_data()


func _process(delta: float) -> void:
	if _damage_flash_timer <= 0.0:
		return

	_damage_flash_timer = maxf(0.0, _damage_flash_timer - delta)
	if _damage_flash_timer <= 0.0:
		for mesh in _flash_meshes:
			if is_instance_valid(mesh) and _mesh_materials.has(mesh):
				mesh.material_override = _mesh_materials[mesh]


func _physics_process(delta: float) -> void:
	if _crashed:
		_emit_flight_data()
		return

	if not input_enabled:
		velocity = Vector3.ZERO
		_turbo_active = false
		_emit_flight_data()
		return

	_read_controls(delta)
	_update_speed(delta)
	_apply_rotation(delta)
	_apply_velocity(delta)
	move_and_slide()
	_check_limits_and_collisions()
	_emit_flight_data()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		_turbo_active = false


func set_spawn_transform(new_spawn: Transform3D) -> void:
	_spawn_transform = new_spawn


func reset_to_spawn() -> void:
	reset_to_transform(_spawn_transform)


func reset_to_transform(target_transform: Transform3D) -> void:
	global_transform = target_transform
	velocity = Vector3.ZERO
	current_speed = normal_speed
	turbo_energy = turbo_capacity
	_turbo_recovery_timer = 0.0
	_turbo_active = false
	_crashed = false
	_pitch_input = 0.0
	_roll_input = 0.0
	_yaw_input = 0.0
	if _health_component != null:
		_health_component.reset_health()
	_emit_flight_data()


func is_turbo_active() -> bool:
	return _turbo_active


func has_low_speed_warning() -> bool:
	return current_speed <= stall_warning_speed


func force_crash(reason: String) -> void:
	if _crashed:
		return
	_crashed = true
	input_enabled = false
	_turbo_active = false
	velocity = Vector3.ZERO
	crashed.emit(reason)
	_emit_flight_data()


func take_damage(amount: float, source: Node = null) -> bool:
	if _health_component == null:
		return false
	return _health_component.take_damage(amount, source)


func get_health_ratio() -> float:
	if _health_component == null or _health_component.max_health <= 0.0:
		return 1.0
	return _health_component.current_health / _health_component.max_health


func _read_controls(delta: float) -> void:
	var raw_pitch := 0.0
	var raw_roll := 0.0
	var raw_yaw := 0.0

	if Input.is_physical_key_pressed(KEY_W):
		raw_pitch += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		raw_pitch -= 1.0
	if Input.is_physical_key_pressed(KEY_A):
		raw_roll -= 1.0
		raw_yaw += 0.45
	if Input.is_physical_key_pressed(KEY_D):
		raw_roll += 1.0
		raw_yaw -= 0.45
	if Input.is_physical_key_pressed(KEY_Q):
		raw_yaw += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		raw_yaw -= 1.0

	var response := minf(1.0, control_response * delta)
	_pitch_input = lerpf(_pitch_input, raw_pitch, response)
	_roll_input = lerpf(_roll_input, raw_roll, response)
	_yaw_input = lerpf(_yaw_input, raw_yaw, response)


func _update_speed(delta: float) -> void:
	var wants_turbo := Input.is_physical_key_pressed(KEY_SHIFT) and turbo_energy > 0.0
	_turbo_active = wants_turbo

	var target_speed := normal_speed
	if _turbo_active:
		target_speed = max_speed
		turbo_energy = maxf(0.0, turbo_energy - turbo_drain_per_second * delta)
		_turbo_recovery_timer = turbo_recovery_delay
	else:
		_turbo_recovery_timer = maxf(0.0, _turbo_recovery_timer - delta)
		if _turbo_recovery_timer <= 0.0:
			turbo_energy = minf(turbo_capacity, turbo_energy + turbo_recovery_per_second * delta)

	var forward := -global_transform.basis.z.normalized()
	if forward.y > 0.05:
		target_speed -= forward.y * climb_drag

	var change_rate := acceleration if target_speed > current_speed else deceleration
	current_speed = move_toward(current_speed, target_speed, change_rate * delta)
	current_speed = clampf(current_speed, min_speed * 0.72, max_speed)


func _apply_rotation(delta: float) -> void:
	rotate_object_local(Vector3.RIGHT, _pitch_input * pitch_rate * delta)
	rotate_object_local(Vector3.FORWARD, -_roll_input * roll_rate * delta)

	var arcade_yaw := _yaw_input + _roll_input * bank_turn_rate
	rotate_object_local(Vector3.UP, arcade_yaw * yaw_rate * delta)

	if absf(_roll_input) < 0.05:
		var basis := global_transform.basis.orthonormalized()
		var forward := -basis.z.normalized()
		var flattened_forward := Vector3(forward.x, 0.0, forward.z).normalized()
		if flattened_forward.length() > 0.01:
			var target_basis := Basis.looking_at(flattened_forward, Vector3.UP)
			basis = basis.slerp(target_basis, minf(1.0, auto_level_strength * delta))
			var leveled := global_transform
			leveled.basis = basis.orthonormalized()
			global_transform = leveled
	else:
		var fixed := global_transform
		fixed.basis = fixed.basis.orthonormalized()
		global_transform = fixed


func _apply_velocity(delta: float) -> void:
	var forward := -global_transform.basis.z.normalized()
	var target_velocity := forward * current_speed
	if current_speed < min_speed:
		target_velocity += Vector3.DOWN * stall_sink_rate

	var align := minf(1.0, velocity_alignment * delta)
	velocity = velocity.lerp(target_velocity, align)


func _check_limits_and_collisions() -> void:
	if global_position.y < min_altitude:
		force_crash("Altura minima")
		return

	if global_position.y > max_altitude:
		var clamped := global_position
		clamped.y = max_altitude
		global_position = clamped
		velocity.y = minf(velocity.y, 0.0)
		current_speed = minf(current_speed, normal_speed)

	if get_slide_collision_count() > 0:
		force_crash("Impacto")


func _emit_flight_data() -> void:
	flight_data_changed.emit(current_speed, global_position.y, turbo_energy / turbo_capacity, _turbo_active, has_low_speed_warning())


func _build_collision() -> void:
	if has_node("CollisionShape3D"):
		return

	var shape := BoxShape3D.new()
	shape.size = Vector3(3.6, 1.1, 5.2)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	if has_node("AircraftVisual"):
		return

	var visual := Node3D.new()
	visual.name = "AircraftVisual"
	add_child(visual)

	_add_cylinder_mesh(visual, "Fuselage", Vector3(0.0, 0.0, 0.0), 0.45, 4.8, _body_material, false)
	_add_cylinder_mesh(visual, "NoseCone", Vector3(0.0, 0.0, -2.75), 0.48, 1.05, _body_material, true)
	_add_box_mesh(visual, "MainWings", Vector3(0.0, -0.03, -0.2), Vector3(7.4, 0.14, 1.05), _wing_material)
	_add_box_mesh(visual, "WingTips", Vector3(0.0, -0.01, -0.05), Vector3(8.2, 0.08, 0.26), _make_material(Color(0.82, 0.08, 0.06, 1.0)))
	_add_box_mesh(visual, "TailWing", Vector3(0.0, 0.05, 2.05), Vector3(3.0, 0.12, 0.55), _wing_material)
	_add_box_mesh(visual, "VerticalFin", Vector3(0.0, 0.62, 2.0), Vector3(0.24, 1.1, 0.7), _wing_material)
	_add_cylinder_mesh(visual, "EngineLeft", Vector3(-0.72, -0.16, 0.55), 0.18, 0.62, _make_material(Color(0.08, 0.09, 0.1, 1.0)), false)
	_add_cylinder_mesh(visual, "EngineRight", Vector3(0.72, -0.16, 0.55), 0.18, 0.62, _make_material(Color(0.08, 0.09, 0.1, 1.0)), false)
	_add_cylinder_mesh(visual, "Cockpit", Vector3(0.0, 0.46, -0.95), 0.32, 0.86, _make_material(Color(0.08, 0.22, 0.34, 0.92)), false)

	var left_muzzle := Marker3D.new()
	left_muzzle.name = "LeftGunMuzzle"
	left_muzzle.position = Vector3(-0.48, -0.08, -2.85)
	add_child(left_muzzle)

	var right_muzzle := Marker3D.new()
	right_muzzle.name = "RightGunMuzzle"
	right_muzzle.position = Vector3(0.48, -0.08, -2.85)
	add_child(right_muzzle)

	var missile_muzzle := Marker3D.new()
	missile_muzzle.name = "MissileMuzzle"
	missile_muzzle.position = Vector3(0.0, -0.28, -1.8)
	add_child(missile_muzzle)


func _add_box_mesh(parent: Node, node_name: String, local_position: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	if material != null:
		instance.material_override = material
	parent.add_child(instance)
	_flash_meshes.append(instance)
	_mesh_materials[instance] = material


func _add_cylinder_mesh(parent: Node, node_name: String, local_position: Vector3, radius: float, height: float, material: Material, cone: bool) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0 if cone else radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.rotation_degrees.x = 90.0
	if material != null:
		instance.material_override = material
	parent.add_child(instance)
	_flash_meshes.append(instance)
	_mesh_materials[instance] = material


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.35
	return material


func _setup_health() -> void:
	_health_component = get_node_or_null("HealthComponent")
	if _health_component == null:
		_health_component = Node.new()
		_health_component.name = "HealthComponent"
		_health_component.set_script(load("res://scripts/components/health_component.gd"))
		add_child(_health_component)

	_health_component.max_health = max_health
	_health_component.invulnerability_seconds = damage_invulnerability
	_health_component.reset_health()
	_health_component.health_changed.connect(_on_health_changed)
	_health_component.damaged.connect(_on_damaged)
	_health_component.died.connect(_on_destroyed)
	_on_health_changed(_health_component.current_health, _health_component.max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)


func _on_damaged(amount: float, source: Node) -> void:
	_damage_flash_timer = 0.16
	for mesh in _flash_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = _damage_flash_material
	damaged.emit(amount, source)


func _on_destroyed(source: Node) -> void:
	_crashed = true
	input_enabled = false
	velocity = Vector3.ZERO
	destroyed.emit(source)
