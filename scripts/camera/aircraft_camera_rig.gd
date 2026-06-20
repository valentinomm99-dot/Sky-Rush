class_name AircraftCameraRig
extends Node3D

signal camera_changed(mode_name: String)

@export var target_path: NodePath
@export var follow_distance: float = 15.0
@export var follow_height: float = 5.0
@export var turbo_extra_distance: float = 7.0
@export var look_ahead: float = 12.0
@export var follow_smoothing: float = 5.2
@export var rotation_smoothing: float = 8.0
@export var turn_tilt_strength: float = 0.28
@export var cockpit_forward_offset: float = 1.65
@export var cockpit_height_offset: float = 0.85

var target
var third_person_camera: Camera3D
var cockpit_camera: Camera3D
var cockpit_mode: bool = false
var _last_basis: Basis


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	target = get_node_or_null(target_path)
	_build_cameras()
	third_person_camera.current = true
	cockpit_camera.current = false
	_last_basis = global_transform.basis


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	if cockpit_mode:
		_update_cockpit_camera()
	else:
		_update_third_person_camera(delta)


func switch_camera() -> void:
	cockpit_mode = not cockpit_mode
	third_person_camera.current = not cockpit_mode
	cockpit_camera.current = cockpit_mode
	camera_changed.emit("Cabina" if cockpit_mode else "Tercera persona")


func _update_third_person_camera(delta: float) -> void:
	var target_transform: Transform3D = target.global_transform
	var forward: Vector3 = -target_transform.basis.z.normalized()
	var right: Vector3 = target_transform.basis.x.normalized()
	var turbo_distance: float = turbo_extra_distance if target.is_turbo_active() else 0.0
	var desired_position: Vector3 = target.global_position - forward * (follow_distance + turbo_distance) + Vector3.UP * follow_height

	var position_weight := minf(1.0, follow_smoothing * delta)
	global_position = global_position.lerp(desired_position, position_weight)

	var look_position: Vector3 = target.global_position + forward * look_ahead + Vector3.UP * 1.8
	var desired_basis: Basis = Transform3D(Basis(), global_position).looking_at(look_position, Vector3.UP).basis
	var turn_tilt := clampf(-right.y * turn_tilt_strength, -0.32, 0.32)
	desired_basis = desired_basis.rotated(desired_basis.z.normalized(), turn_tilt)

	var rotation_weight := minf(1.0, rotation_smoothing * delta)
	_last_basis = _last_basis.slerp(desired_basis, rotation_weight).orthonormalized()
	global_transform = Transform3D(_last_basis, global_position)
	third_person_camera.global_transform = global_transform


func _update_cockpit_camera() -> void:
	var target_transform: Transform3D = target.global_transform
	var forward: Vector3 = -target_transform.basis.z.normalized()
	var cockpit_position: Vector3 = target.global_position + forward * cockpit_forward_offset + Vector3.UP * cockpit_height_offset
	var look_position: Vector3 = cockpit_position + forward * 24.0

	cockpit_camera.global_position = cockpit_position
	cockpit_camera.look_at(look_position, Vector3.UP)


func _build_cameras() -> void:
	third_person_camera = get_node_or_null("ThirdPersonCamera") as Camera3D
	if third_person_camera == null:
		third_person_camera = Camera3D.new()
		third_person_camera.name = "ThirdPersonCamera"
		add_child(third_person_camera)
	third_person_camera.fov = 68.0
	third_person_camera.near = 0.08
	third_person_camera.far = 1400.0

	cockpit_camera = get_node_or_null("CockpitCamera") as Camera3D
	if cockpit_camera == null:
		cockpit_camera = Camera3D.new()
		cockpit_camera.name = "CockpitCamera"
		add_child(cockpit_camera)
	cockpit_camera.fov = 78.0
	cockpit_camera.near = 0.05
	cockpit_camera.far = 1400.0
