extends Node
class_name PlayerAimComponent

@export_group("Wand Aim")
@export var wand_angle_offset_degrees: float = 0.0
@export var wand_pivot_right_position: Vector2 = Vector2(4, -4)
@export var wand_pivot_left_position: Vector2 = Vector2(-4, -4)

@onready var player: CharacterBody2D = get_parent().get_parent()
@onready var wand_pivot: Node2D = $"../../Visuals/WandPivot"
@onready var wand: Node2D = $"../../Visuals/WandPivot/Wand"

var aim_direction: Vector2 = Vector2.RIGHT

func setup_initial_state() -> void:
	_update_wand_pivot_position()
	_update_aim()

	if wand != null and wand.has_method("set_actor_owner"):
		wand.set_actor_owner(player)

func update_after_movement() -> void:
	_update_wand_pivot_position()
	_update_aim()

func update_wand_input(can_use: bool) -> void:
	if wand == null:
		return

	if wand.has_method("set_input_enabled"):
		wand.set_input_enabled(can_use)

func get_aim_direction() -> Vector2:
	return aim_direction

func _update_wand_pivot_position() -> void:
	if wand_pivot == null:
		return

	if player.facing_left:
		wand_pivot.position = wand_pivot_left_position
	else:
		wand_pivot.position = wand_pivot_right_position

func _update_aim() -> void:
	if wand_pivot == null:
		return

	var mouse_pos: Vector2 = player.get_global_mouse_position()
	aim_direction = mouse_pos - wand_pivot.global_position

	if aim_direction == Vector2.ZERO:
		return

	aim_direction = aim_direction.normalized()
	wand_pivot.rotation = aim_direction.angle() + deg_to_rad(wand_angle_offset_degrees)
