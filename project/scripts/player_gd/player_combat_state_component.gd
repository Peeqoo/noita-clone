extends Node
class_name PlayerCombatStateComponent

@export_group("Combat State")
@export var combat_exit_delay: float = 3.0

@export_group("Regen")
@export var health_regen_amount: int = 1
@export var health_regen_interval: float = 0.5

@onready var player: CharacterBody2D = get_parent().get_parent()
@onready var health_component: PlayerHealthComponent = $"../HealthComponent"

var in_combat: bool = false
var combat_token: int = 0
var regen_running: bool = false

func set_in_combat() -> void:
	in_combat = true
	combat_token += 1

func try_leave_combat() -> void:
	combat_token += 1
	var my_token: int = combat_token
	_leave_combat_after_delay.call_deferred(my_token)

func _leave_combat_after_delay(token: int) -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	await tree.create_timer(combat_exit_delay).timeout

	if not is_inside_tree():
		return

	if token != combat_token:
		return

	in_combat = false
	_start_health_regen()

func _start_health_regen() -> void:
	if regen_running:
		return

	if not is_inside_tree():
		return

	regen_running = true
	_health_regen_loop.call_deferred()

func _health_regen_loop() -> void:
	while true:
		if not is_inside_tree():
			break

		if in_combat:
			break

		if health_component == null:
			break

		if health_component.is_dead:
			break

		if health_component.health >= health_component.max_health:
			break

		var tree := get_tree()
		if tree == null:
			break

		await tree.create_timer(health_regen_interval).timeout

		if not is_inside_tree():
			break

		if in_combat:
			break

		if health_component == null:
			break

		if health_component.is_dead:
			break

		if health_component.health < health_component.max_health:
			health_component.heal(health_regen_amount)

	regen_running = false
