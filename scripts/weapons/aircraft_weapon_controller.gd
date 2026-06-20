class_name AircraftWeaponController
extends Node

signal gun_temperature_changed(ratio: float, overheated: bool)
signal missiles_changed(available: int, maximum: int, reload_ratio: float)
signal lock_changed(target: Node, progress: float, locked: bool)

@export var projectile_scene: PackedScene
@export var missile_scene: PackedScene
@export var gun_damage: float = 8.0
@export var gun_fire_rate: float = 12.0
@export var gun_range: float = 430.0
@export var gun_spread_degrees: float = 1.4
@export var heat_per_shot: float = 6.2
@export var heat_cool_per_second: float = 28.0
@export var overheat_threshold: float = 100.0
@export var overheat_resume_threshold: float = 48.0
@export var max_missiles: int = 4
@export var missile_reload_seconds: float = 5.0
@export var lock_seconds: float = 2.0
@export var lock_angle_degrees: float = 13.0
@export var target_scan_distance: float = 620.0

var aircraft: Node3D
var enabled: bool = false

var _gun_heat: float = 0.0
var _gun_cooldown: float = 0.0
var _overheated: bool = false
var _available_missiles: int = 4
var _reload_timer: float = 0.0
var _selected_target: Node
var _locked_target: Node
var _lock_progress: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _muzzle_flash: OmniLight3D
var _gun_sound: AudioStreamPlayer3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	aircraft = get_parent() as Node3D
	if projectile_scene == null:
		projectile_scene = load("res://scenes/weapons/projectile.tscn") as PackedScene
	if missile_scene == null:
		missile_scene = load("res://scenes/weapons/missile.tscn") as PackedScene
	_available_missiles = max_missiles
	_build_feedback_nodes()
	_emit_weapon_data()


func _process(delta: float) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return

	enabled = aircraft.get("input_enabled") == true
	_update_heat(delta)
	_update_missile_reload(delta)
	_update_lock(delta)
	_update_muzzle_flash(delta)

	if not enabled:
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire_gun()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_try_fire_missile()


func reset_weapons() -> void:
	_gun_heat = 0.0
	_gun_cooldown = 0.0
	_overheated = false
	_available_missiles = max_missiles
	_reload_timer = 0.0
	_lock_progress = 0.0
	_locked_target = null
	_set_selected_target(null)
	_emit_weapon_data()


func _try_fire_gun() -> void:
	if _overheated or _gun_cooldown > 0.0:
		return

	_gun_cooldown = 1.0 / gun_fire_rate
	_gun_heat = minf(overheat_threshold, _gun_heat + heat_per_shot)
	if _gun_heat >= overheat_threshold:
		_overheated = true

	_spawn_projectile(_get_muzzle("LeftGunMuzzle"))
	_spawn_projectile(_get_muzzle("RightGunMuzzle"))
	_show_muzzle_feedback()
	_emit_weapon_data()


func _try_fire_missile() -> void:
	if _available_missiles <= 0:
		return

	_available_missiles -= 1
	if _available_missiles < max_missiles and _reload_timer <= 0.0:
		_reload_timer = missile_reload_seconds

	var missile := missile_scene.instantiate()
	var muzzle := _get_muzzle("MissileMuzzle")
	_get_spawn_parent().add_child(missile)
	missile.global_transform = muzzle.global_transform if muzzle != null else aircraft.global_transform
	var target := _locked_target as Node3D
	missile.setup(aircraft, target, target != null)
	_emit_weapon_data()


func _spawn_projectile(muzzle: Node3D) -> void:
	var projectile := projectile_scene.instantiate()
	_get_spawn_parent().add_child(projectile)
	projectile.global_transform = muzzle.global_transform if muzzle != null else aircraft.global_transform
	projectile.setup(aircraft, gun_damage, gun_range, deg_to_rad(gun_spread_degrees))


func _update_heat(delta: float) -> void:
	_gun_cooldown = maxf(0.0, _gun_cooldown - delta)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not enabled:
		_gun_heat = maxf(0.0, _gun_heat - heat_cool_per_second * delta)

	if _overheated and _gun_heat <= overheat_resume_threshold:
		_overheated = false
	_emit_weapon_data()


func _update_missile_reload(delta: float) -> void:
	if _available_missiles >= max_missiles:
		return

	_reload_timer = maxf(0.0, _reload_timer - delta)
	if _reload_timer <= 0.0:
		_available_missiles += 1
		_reload_timer = missile_reload_seconds if _available_missiles < max_missiles else 0.0
	_emit_weapon_data()


func _update_lock(delta: float) -> void:
	var candidate := _find_best_target()
	if candidate != _selected_target:
		_set_selected_target(candidate)
		_lock_progress = 0.0
		_locked_target = null

	if _selected_target == null:
		lock_changed.emit(null, 0.0, false)
		return

	var forward := -aircraft.global_transform.basis.z.normalized()
	var to_target: Vector3 = (_selected_target.global_position - aircraft.global_position).normalized()
	var centered := rad_to_deg(acos(clampf(forward.dot(to_target), -1.0, 1.0))) <= lock_angle_degrees
	if centered:
		_lock_progress = minf(1.0, _lock_progress + delta / lock_seconds)
	else:
		_lock_progress = maxf(0.0, _lock_progress - delta / lock_seconds)

	var locked := _lock_progress >= 1.0
	_locked_target = _selected_target if locked else null
	if _selected_target.has_method("set_target_marker"):
		_selected_target.set_target_marker(true, locked, _lock_progress)
	lock_changed.emit(_selected_target, _lock_progress, locked)


func _find_best_target() -> Node:
	var forward := -aircraft.global_transform.basis.z.normalized()
	var best: Node = null
	var best_score := INF
	var min_dot := cos(deg_to_rad(42.0))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.has_method("is_destroyed") and enemy.is_destroyed():
			continue
		var offset: Vector3 = enemy.global_position - aircraft.global_position
		var distance := offset.length()
		if distance > target_scan_distance or distance < 0.1:
			continue
		var direction := offset / distance
		var dot := forward.dot(direction)
		if dot < min_dot:
			continue
		var score := distance * (1.25 - dot)
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _set_selected_target(target: Node) -> void:
	if _selected_target != null and is_instance_valid(_selected_target) and _selected_target.has_method("set_target_marker"):
		_selected_target.set_target_marker(false, false, 0.0)
	_selected_target = target


func _get_muzzle(node_name: String) -> Node3D:
	if aircraft == null:
		return null
	return aircraft.get_node_or_null(node_name) as Node3D


func _get_spawn_parent() -> Node:
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_tree().root


func _build_feedback_nodes() -> void:
	_muzzle_flash = OmniLight3D.new()
	_muzzle_flash.name = "GunMuzzleFlash"
	_muzzle_flash.light_energy = 4.0
	_muzzle_flash.omni_range = 5.0
	_muzzle_flash.visible = false
	add_child(_muzzle_flash)

	_gun_sound = AudioStreamPlayer3D.new()
	_gun_sound.name = "ProceduralGunSound"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 11025.0
	stream.buffer_length = 0.08
	_gun_sound.stream = stream
	add_child(_gun_sound)


func _show_muzzle_feedback() -> void:
	var muzzle := _get_muzzle("LeftGunMuzzle")
	if muzzle != null:
		_muzzle_flash.global_position = muzzle.global_position
	_muzzle_flash.visible = true
	_muzzle_flash_timer = 0.055
	_play_gun_sound()


func _update_muzzle_flash(delta: float) -> void:
	_muzzle_flash_timer = maxf(0.0, _muzzle_flash_timer - delta)
	if _muzzle_flash_timer <= 0.0 and _muzzle_flash != null:
		_muzzle_flash.visible = false


func _play_gun_sound() -> void:
	if _gun_sound == null:
		return
	_gun_sound.play()
	var playback = _gun_sound.get_stream_playback()
	if playback == null:
		return
	for i in range(96):
		var sample := sin(float(i) * 0.72) * 0.12
		playback.push_frame(Vector2(sample, sample))


func _emit_weapon_data() -> void:
	gun_temperature_changed.emit(_gun_heat / overheat_threshold, _overheated)
	var reload_ratio := 1.0
	if _available_missiles < max_missiles and missile_reload_seconds > 0.0:
		reload_ratio = 1.0 - (_reload_timer / missile_reload_seconds)
	missiles_changed.emit(_available_missiles, max_missiles, reload_ratio)
