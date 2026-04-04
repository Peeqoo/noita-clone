extends Camera2D

@export var look_ahead_distance: float = 60.0
@export var look_ahead_speed: float = 1.0
@export var min_velocity_for_look_ahead: float = 20.0
@export var direction_commit_distance: float = 60.0

@export var fall_look_down_distance: float = 32.0
@export var fall_look_down_speed: float = 3.0
@export var fall_return_speed: float = 2.0
@export var min_fall_velocity: float = 80.0
@export var fall_trigger_time: float = 0.12

@export var pixel_step: float = 1.0

var room_offset: Vector2 = Vector2.ZERO

var shake_strength: float = 0.0
var shake_time: float = 0.0
var shake_cooldown: float = 0.0
var shake_duration: float = 0.0

var _dynamic_offset: Vector2 = Vector2.ZERO

var _target_offset_x: float = 0.0
var _committed_direction: int = 0
var _candidate_direction: int = 0
var _candidate_distance: float = 0.0
var _last_player_x: float = 0.0

var _target_offset_y: float = 0.0
var _fall_time: float = 0.0


func _ready() -> void:
	position = Vector2.ZERO
	offset = Vector2.ZERO

	var player := get_parent() as CharacterBody2D
	if player == null:
		return

	_last_player_x = player.global_position.x


func _physics_process(delta: float) -> void:
	var player := get_parent() as CharacterBody2D
	if player == null:
		return
	if shake_cooldown > 0.0:
		shake_cooldown -= delta
		
	_update_horizontal(player, delta)
	_update_vertical(player, delta)
	_update_final_offset(delta)


func shake(strength: float, time: float) -> void:
	if shake_cooldown > 0.0:
		return

	shake_strength = max(shake_strength, strength)
	shake_time = max(shake_time, time)
	shake_duration = shake_time
	shake_cooldown = 0.05

func set_room_offset(v: Vector2) -> void:
	room_offset = v


func _update_horizontal(player: CharacterBody2D, delta: float) -> void:
	var current_x: float = player.global_position.x
	var moved_x: float = current_x - _last_player_x
	_last_player_x = current_x

	var velocity_x: float = player.velocity.x
	var move_dir: int = 0

	if velocity_x > min_velocity_for_look_ahead:
		move_dir = 1
	elif velocity_x < -min_velocity_for_look_ahead:
		move_dir = -1

	if move_dir != 0:
		if move_dir != _committed_direction:
			if move_dir != _candidate_direction:
				_candidate_direction = move_dir
				_candidate_distance = 0.0

			_candidate_distance += abs(moved_x)

			if _candidate_distance >= direction_commit_distance:
				_committed_direction = move_dir
				_candidate_direction = 0
				_candidate_distance = 0.0
		else:
			_candidate_direction = 0
			_candidate_distance = 0.0

	_target_offset_x = _committed_direction * look_ahead_distance

	var next_x := move_toward(
		_dynamic_offset.x,
		_target_offset_x,
		look_ahead_speed * look_ahead_distance * delta
	)

	if abs(next_x) < 1.0:
		next_x = 0.0

	_dynamic_offset.x = next_x


func _update_vertical(player: CharacterBody2D, delta: float) -> void:
	var is_falling: bool = not player.is_on_floor() and player.velocity.y > min_fall_velocity

	if is_falling:
		_fall_time += delta
	else:
		_fall_time = 0.0

	if _fall_time >= fall_trigger_time:
		_target_offset_y = fall_look_down_distance
	else:
		_target_offset_y = 0.0

	var speed := fall_return_speed
	if _target_offset_y > _dynamic_offset.y:
		speed = fall_look_down_speed

	_dynamic_offset.y = move_toward(
		_dynamic_offset.y,
		_target_offset_y,
		speed * fall_look_down_distance * delta
	)


func _update_final_offset(delta: float) -> void:
	var final_offset := Vector2(
		_snap(room_offset.x + _dynamic_offset.x),
		_snap(room_offset.y + _dynamic_offset.y)
	)

	if shake_time > 0.0:
		shake_time -= delta

		var t := 0.0
		if shake_duration > 0.0:
			t = shake_time / shake_duration

		var current_strength := shake_strength * t

		final_offset += Vector2(
			randf_range(-current_strength, current_strength),
			randf_range(-current_strength, current_strength)
		)

	offset = final_offset


func _snap(v: float) -> float:
	return round(v / pixel_step) * pixel_step
