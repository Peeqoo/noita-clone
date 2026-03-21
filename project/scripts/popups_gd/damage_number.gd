extends Node2D

@export var float_distance: float = 16.0
@export var duration: float = 0.8
@export var random_x_offset: float = 6.0
@export var start_offset: Vector2 = Vector2(0, -18)

@export var start_scale: Vector2 = Vector2(1.6, 1.6)
@export var end_scale: Vector2 = Vector2(1.0, 1.0)

@export var crit_start_scale: Vector2 = Vector2(2.0, 2.0)
@export var crit_end_scale: Vector2 = Vector2(1.2, 1.2)

@export var drift_x_min: float = -4.0
@export var drift_x_max: float = 4.0

@export var scale_hold_delay: float = 0.12
@export var scale_shrink_duration: float = 0.28

@export var fade_delay: float = 0.42
@export var fade_duration: float = 0.26

@export var start_rotation_degrees: float = 0.0
@export var end_rotation_degrees: float = 0.0

@export var crit_start_rotation_degrees: float = 25.0
@export var crit_end_rotation_degrees: float = 5.0

@onready var label: Label = $Label

func setup(value: int, is_crit: bool = false) -> void:
	label.text = str(value)
	label.visible = true
	label.modulate.a = 1.0

	if is_crit:
		label.scale = crit_start_scale
		rotation_degrees = crit_start_rotation_degrees
	else:
		label.scale = start_scale
		rotation_degrees = start_rotation_degrees

	global_position += start_offset
	global_position.x += randi_range(-int(random_x_offset), int(random_x_offset))
	global_position = global_position.round()

	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = (start_pos + Vector2(randf_range(drift_x_min, drift_x_max), -float_distance)).round()

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_method(_set_position_snapped, start_pos, end_pos, duration)

	if is_crit:
		tween.tween_property(label, "scale", crit_end_scale, scale_shrink_duration)\
			.set_delay(scale_hold_delay)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		tween.tween_property(self, "rotation_degrees", crit_end_rotation_degrees, duration)
	else:
		tween.tween_property(label, "scale", end_scale, scale_shrink_duration)\
			.set_delay(scale_hold_delay)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		tween.tween_property(self, "rotation_degrees", end_rotation_degrees, duration)

	tween.tween_property(label, "modulate:a", 0.0, fade_duration)\
		.set_delay(fade_delay)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	await tween.finished
	queue_free()

func _set_position_snapped(pos: Vector2) -> void:
	global_position = pos.round()
