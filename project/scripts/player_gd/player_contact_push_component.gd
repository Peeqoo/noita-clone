extends Node
class_name PlayerContactPushComponent

@export_group("Contact Push")
@export var contact_push_enabled: bool = true
@export var contact_push_radius: float = 18.0
@export var contact_push_strength: float = 85.0
@export var contact_push_vertical_tolerance: float = 20.0
@export var contact_push_max_per_frame: float = 3.0
@export var disable_push_while_dash: bool = true
@export var disable_push_while_block_dash: bool = true

@onready var player: CharacterBody2D = get_parent().get_parent()
@onready var dash_component: PlayerDashComponent = $"../DashComponent"

func _physics_process(delta: float) -> void:
	_apply_contact_push(delta)

func _apply_contact_push(delta: float) -> void:
	if not contact_push_enabled:
		return

	if player == null:
		return

	if dash_component != null:
		if disable_push_while_dash and dash_component.is_dashing:
			return

		if disable_push_while_block_dash and dash_component.is_block_dashing:
			return

	var total_push_x: float = 0.0
	var enemies := get_tree().get_nodes_in_group("enemy")

	for enemy in enemies:
		if enemy == null:
			continue

		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		var dx: float = player.global_position.x - enemy.global_position.x
		var dy: float = absf(player.global_position.y - enemy.global_position.y)

		if dy > contact_push_vertical_tolerance:
			continue

		var dist_x: float = absf(dx)

		if dist_x <= 0.001:
			if player.facing_left:
				dx = -1.0
			else:
				dx = 1.0
			dist_x = 0.001

		if dist_x > contact_push_radius:
			continue

		var push_dir: float = 1.0 if dx > 0.0 else -1.0
		var ratio: float = 1.0 - (dist_x / contact_push_radius)
		total_push_x += push_dir * ratio * contact_push_strength * delta

	total_push_x = clampf(total_push_x, -contact_push_max_per_frame, contact_push_max_per_frame)

	if absf(total_push_x) > 0.001:
		player.global_position.x += total_push_x
