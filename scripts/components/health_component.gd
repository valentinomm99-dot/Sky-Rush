class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var max_health: float = 100.0
@export var invulnerability_seconds: float = 0.0

var current_health: float = 100.0
var _invulnerable_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _process(delta: float) -> void:
	_invulnerable_timer = maxf(0.0, _invulnerable_timer - delta)


func reset_health() -> void:
	_dead = false
	_invulnerable_timer = 0.0
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: float, source: Node = null) -> bool:
	if _dead or amount <= 0.0 or _invulnerable_timer > 0.0:
		return false

	current_health = maxf(0.0, current_health - amount)
	_invulnerable_timer = invulnerability_seconds
	damaged.emit(amount, source)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		_dead = true
		died.emit(source)
	return true


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return _dead
