extends Node
class_name PlayerDashComponent

@export_group("Dash")
@export var dash_speed: float = 420.0
@export var dash_end_speed_multiplier: float = 0.2
@export var dash_duration: float = 0.12
@export var allow_air_dash: bool = true
@export var use_dash_animation_duration: bool = true
@export var dash_animation_name: StringName = &"ausweich_dash"
@export var dash_iframe_start_frame: int = 0
@export var dash_iframe_end_frame: int = 2
@export var dash_guard_start_frame: int = 3
@export var dash_guard_end_frame: int = 5

@export_group("Dash Charges")
@export var max_dash_charges: int = 2
@export var dash_charge_recovery_time: float = 1.8

@export_group("Block Dash")
@export var block_dash_duration: float = 0.16
@export var block_dash_cooldown: float = 0.7
@export var allow_air_block_dash: bool = false
@export var use_block_dash_animation_duration: bool = true
@export var block_dash_animation_name: StringName = &"block_dash"
@export var block_dash_iframe_start_frame: int = 0
@export var block_dash_iframe_end_frame: int = 3
@export var block_dash_guard_start_frame: int = 4
@export var block_dash_guard_end_frame: int = 7

@onready var player: CharacterBody2D = get_parent().get_parent()
@onready var animated_sprite: AnimatedSprite2D = $"../../Visuals/AnimatedSprite2D"

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: float = 0.0
var dash_total_duration: float = 0.12

var current_dash_charges: int = 2
var dash_charge_recovery_timer: float = 0.0

var is_block_dashing: bool = false
var block_dash_timer: float = 0.0
var block_dash_cooldown_timer: float = 0.0
var can_air_block_dash: bool = true
var block_dash_total_duration: float = 0.16

func _ready() -> void:
	_setup_dash_duration_from_animation()
	_setup_block_dash_duration_from_animation()
	current_dash_charges = max_dash_charges
	dash_charge_recovery_timer = 0.0

func tick_cooldowns(delta: float) -> void:
	_update_dash_charge_recovery(delta)

	if block_dash_cooldown_timer > 0.0:
		block_dash_cooldown_timer -= delta

func reset_air_actions() -> void:
	can_air_block_dash = true

func force_stop_all() -> void:
	is_dashing = false
	is_block_dashing = false

func try_start_dash(raw_input_dir: float) -> bool:
	if is_dashing or is_block_dashing:
		return false

	if current_dash_charges <= 0:
		return false

	if not player.is_on_floor() and not allow_air_dash:
		return false

	var dir: float = raw_input_dir
	if dir == 0.0:
		dir = -1.0 if player.facing_left else 1.0

	is_dashing = true
	dash_timer = dash_total_duration
	dash_direction = dir
	player.is_stopping_run = false
	player.velocity = Vector2.ZERO

	current_dash_charges -= 1

	if current_dash_charges < max_dash_charges and dash_charge_recovery_timer <= 0.0:
		dash_charge_recovery_timer = dash_charge_recovery_time

	return true

func try_start_block_dash(raw_input_dir: float) -> bool:
	if is_dashing or is_block_dashing:
		return false

	if block_dash_cooldown_timer > 0.0:
		return false

	if not player.is_on_floor() and (not allow_air_block_dash or not can_air_block_dash):
		return false

	var dir: float = raw_input_dir
	if dir == 0.0:
		dir = -1.0 if player.facing_left else 1.0

	is_block_dashing = true
	block_dash_timer = block_dash_total_duration
	player.is_stopping_run = false
	player.velocity = Vector2.ZERO
	block_dash_cooldown_timer = block_dash_cooldown

	if not player.is_on_floor():
		can_air_block_dash = false

	return true

func physics_process_dash(delta: float) -> void:
	dash_timer -= delta

	var dash_progress: float = 0.0
	if dash_total_duration > 0.0:
		dash_progress = 1.0 - (dash_timer / dash_total_duration)
	dash_progress = clampf(dash_progress, 0.0, 1.0)

	var dash_eased_progress: float = dash_progress * dash_progress
	var current_dash_speed: float = lerpf(
		dash_speed,
		dash_speed * dash_end_speed_multiplier,
		dash_eased_progress
	)

	player.velocity.x = dash_direction * current_dash_speed
	player.velocity.y = 0.0
	player.is_stopping_run = false

	if dash_timer <= 0.0:
		is_dashing = false

func physics_process_block_dash(delta: float) -> void:
	block_dash_timer -= delta
	player.velocity = Vector2.ZERO
	player.is_stopping_run = false

	if block_dash_timer <= 0.0:
		is_block_dashing = false

func is_in_dash_iframe() -> bool:
	if not is_dashing:
		return false
	return _is_current_frame_between(dash_animation_name, dash_iframe_start_frame, dash_iframe_end_frame)

func is_in_dash_guard_window() -> bool:
	if not is_dashing:
		return false
	return _is_current_frame_between(dash_animation_name, dash_guard_start_frame, dash_guard_end_frame)

func is_in_block_dash_iframe() -> bool:
	if not is_block_dashing:
		return false
	return _is_current_frame_between(block_dash_animation_name, block_dash_iframe_start_frame, block_dash_iframe_end_frame)

func is_in_block_dash_guard_window() -> bool:
	if not is_block_dashing:
		return false
	return _is_current_frame_between(block_dash_animation_name, block_dash_guard_start_frame, block_dash_guard_end_frame)

func get_dash_charges() -> int:
	return current_dash_charges

func get_max_dash_charges() -> int:
	return max_dash_charges

func get_dash_charge_recovery_ratio() -> float:
	if max_dash_charges <= 0:
		return 0.0

	if current_dash_charges >= max_dash_charges:
		return 1.0

	if dash_charge_recovery_time <= 0.0:
		return 1.0

	return clampf(1.0 - (dash_charge_recovery_timer / dash_charge_recovery_time), 0.0, 1.0)

func _update_dash_charge_recovery(delta: float) -> void:
	if current_dash_charges >= max_dash_charges:
		dash_charge_recovery_timer = 0.0
		return

	if dash_charge_recovery_timer > 0.0:
		dash_charge_recovery_timer -= delta

	if dash_charge_recovery_timer <= 0.0:
		current_dash_charges += 1
		current_dash_charges = min(current_dash_charges, max_dash_charges)

		if current_dash_charges < max_dash_charges:
			dash_charge_recovery_timer = dash_charge_recovery_time
		else:
			dash_charge_recovery_timer = 0.0

func _is_current_frame_between(animation_name: StringName, start_frame: int, end_frame: int) -> bool:
	if animated_sprite == null:
		return false

	if animated_sprite.animation != animation_name:
		return false

	var current_frame: int = animated_sprite.frame
	return current_frame >= start_frame and current_frame <= end_frame

func _setup_dash_duration_from_animation() -> void:
	dash_total_duration = dash_duration

	if not use_dash_animation_duration:
		return

	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames == null:
		return

	if not animated_sprite.sprite_frames.has_animation(dash_animation_name):
		return

	var frame_count: int = animated_sprite.sprite_frames.get_frame_count(dash_animation_name)
	var fps: float = animated_sprite.sprite_frames.get_animation_speed(dash_animation_name)

	if frame_count <= 0 or fps <= 0.0:
		return

	dash_total_duration = frame_count / fps

func _setup_block_dash_duration_from_animation() -> void:
	block_dash_total_duration = block_dash_duration

	if not use_block_dash_animation_duration:
		return

	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames == null:
		return

	if not animated_sprite.sprite_frames.has_animation(block_dash_animation_name):
		return

	var frame_count: int = animated_sprite.sprite_frames.get_frame_count(block_dash_animation_name)
	var fps: float = animated_sprite.sprite_frames.get_animation_speed(block_dash_animation_name)

	if frame_count <= 0 or fps <= 0.0:
		return

	block_dash_total_duration = frame_count / fps
