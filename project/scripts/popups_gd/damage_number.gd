extends Node2D

@export var float_distance: float = 18.0
@export var crit_float_distance: float = 26.0

@export var duration: float = 0.68
@export var crit_duration: float = 0.84

@export var random_x_offset: float = 5.0
@export var start_offset: Vector2 = Vector2(0, -20)

@export var start_scale: Vector2 = Vector2(1.35, 1.35)
@export var pop_scale: Vector2 = Vector2(1.62, 1.62)
@export var end_scale: Vector2 = Vector2(1.08, 1.08)

@export var crit_start_scale: Vector2 = Vector2(1.8, 1.8)
@export var crit_pop_scale: Vector2 = Vector2(2.45, 2.45)
@export var crit_end_scale: Vector2 = Vector2(1.45, 1.45)

@export var drift_x_min: float = -7.0
@export var drift_x_max: float = 7.0
@export var crit_drift_x_min: float = -11.0
@export var crit_drift_x_max: float = 11.0

@export var pop_duration: float = 0.09
@export var shrink_duration: float = 0.20

@export var fade_delay: float = 0.24
@export var fade_duration: float = 0.24

@export var crit_fade_delay: float = 0.34
@export var crit_fade_duration: float = 0.28

@export var start_rotation_degrees: float = 0.0
@export var end_rotation_degrees: float = 0.0

@export var crit_start_rotation_degrees: float = 18.0
@export var crit_end_rotation_degrees: float = 4.0

@export var burst_window_ms: int = 90
@export var burst_x_step: float = 11.0
@export var burst_y_step: float = 6.0
@export var max_burst_stack: int = 6

@onready var label: Label = $Label

static var _last_spawn_time_ms: int = -999999
static var _burst_index: int = 0

func setup(value: int, is_crit: bool = false) -> void:
	label.text = str(value)
	label.visible = true
	label.modulate.a = 1.0

	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_spawn_time_ms <= burst_window_ms:
		_burst_index += 1
	else:
		_burst_index = 0
	_last_spawn_time_ms = now_ms

	var burst_slot: int = mini(_burst_index, max_burst_stack)
	var burst_offset: Vector2 = _get_burst_offset(burst_slot, is_crit)

	global_position += start_offset + burst_offset
	global_position.x += randf_range(-random_x_offset, random_x_offset)
	global_position = global_position.round()

	var start_pos: Vector2 = global_position
	var end_pos: Vector2

	if is_crit:
		label.scale = crit_start_scale
		rotation_degrees = crit_start_rotation_degrees
		end_pos = (
			start_pos
			+ Vector2(
				randf_range(crit_drift_x_min, crit_drift_x_max),
				-crit_float_distance
			)
		).round()
	else:
		label.scale = start_scale
		rotation_degrees = start_rotation_degrees
		end_pos = (
			start_pos
			+ Vector2(
				randf_range(drift_x_min, drift_x_max),
				-float_distance
			)
		).round()

	var move_duration: float = crit_duration if is_crit else duration
	var alpha_delay: float = crit_fade_delay if is_crit else fade_delay
	var alpha_duration: float = crit_fade_duration if is_crit else fade_duration

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_method(_set_position_snapped, start_pos, end_pos, move_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	if is_crit:
		tween.tween_property(label, "scale", crit_pop_scale, pop_duration)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		tween.tween_property(label, "scale", crit_end_scale, shrink_duration)\
			.set_delay(pop_duration)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)

		tween.tween_property(self, "rotation_degrees", crit_end_rotation_degrees, move_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(label, "scale", pop_scale, pop_duration)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		tween.tween_property(label, "scale", end_scale, shrink_duration)\
			.set_delay(pop_duration)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)

		tween.tween_property(self, "rotation_degrees", end_rotation_degrees, move_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

	tween.tween_property(label, "modulate:a", 0.0, alpha_duration)\
		.set_delay(alpha_delay)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	await tween.finished
	queue_free()

func _get_burst_offset(index: int, is_crit: bool) -> Vector2:
	if index <= 0:
		return Vector2.ZERO

	var side: float = -1.0 if index % 2 == 0 else 1.0
	var horizontal_step: int = int((index + 1.0) / 2.0)
	var x_offset: float = side * horizontal_step * burst_x_step
	var y_offset: float = -float(index) * burst_y_step

	if is_crit:
		x_offset *= 1.15
		y_offset *= 1.15

	return Vector2(x_offset, y_offset)

func _set_position_snapped(pos: Vector2) -> void:
	global_position = pos.round()
