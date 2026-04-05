extends Node
class_name PlayerMovementComponent

@export_group("Movement")
@export var move_speed: float = 100.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var air_control_multiplier: float = 0.6

@export_group("Jump")
@export var jump_velocity: float = -280.0
@export var gravity: float = 1000.0
@export var max_fall_speed: float = 900.0
@export var fall_gravity_multiplier: float = 1.3
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

@export_group("Knockback")
@export var knockback_decay: float = 900.0

@export_group("Audio")
@export var footstep_sound: AudioStream
@export var jump_sound: AudioStream
@export var footstep_frames: Array[int] = [1, 5]

@onready var player: CharacterBody2D = get_parent().get_parent()
@onready var animated_sprite: AnimatedSprite2D = $"../../Visuals/AnimatedSprite2D"
@onready var footstep_player: AudioStreamPlayer2D = $"../../Audio/FootstepPlayer"
@onready var jump_player: AudioStreamPlayer2D = $"../../Audio/JumpPlayer"
@onready var health_component: PlayerHealthComponent = $"../HealthComponent"

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var last_footstep_frame: int = -1

func physics_step(delta: float, input_dir: float) -> void:
	_update_jump_timers(delta)
	_apply_horizontal(delta, input_dir)
	_apply_gravity(delta)
	_try_jump()

	if health_component != null:
		player.velocity += health_component.knockback_velocity
		health_component.knockback_velocity = health_component.knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_decay * delta
		)

func apply_dead_gravity(delta: float) -> void:
	player.velocity.x = 0.0
	player.velocity.y = minf(player.velocity.y + gravity * delta, max_fall_speed)

func reset_footstep_state() -> void:
	last_footstep_frame = -1

func update_footsteps_from_animation() -> void:
	if animated_sprite == null:
		return

	if footstep_player == null:
		return

	if footstep_sound == null:
		return

	if animated_sprite.animation != "run":
		last_footstep_frame = -1
		return

	var current_frame: int = animated_sprite.frame
	if current_frame == last_footstep_frame:
		return

	if current_frame in footstep_frames:
		footstep_player.stream = footstep_sound
		footstep_player.pitch_scale = randf_range(0.96, 1.04)
		footstep_player.volume_db = randf_range(-3.0, 0.0)
		footstep_player.play()
		last_footstep_frame = current_frame

func _update_jump_timers(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	if player.is_on_floor():
		coyote_timer = coyote_time
	elif coyote_timer > 0.0:
		coyote_timer -= delta

func _apply_horizontal(delta: float, input_dir: float) -> void:
	var target_speed: float = input_dir * move_speed
	var control_multiplier: float = 1.0

	if not player.is_on_floor():
		control_multiplier = air_control_multiplier

	if input_dir != 0.0:
		var accel: float = acceleration * control_multiplier

		if signf(target_speed) != signf(player.velocity.x) and absf(player.velocity.x) > 0.0:
			accel = acceleration * 1.35 * control_multiplier
		elif absf(target_speed) > absf(player.velocity.x):
			accel = acceleration * 1.15 * control_multiplier
		else:
			accel = acceleration * 0.9 * control_multiplier

		player.velocity.x = move_toward(player.velocity.x, target_speed, accel * delta)
	else:
		var stop_friction: float = friction * 1.15

		if absf(player.velocity.x) < 40.0:
			stop_friction *= 1.6

		player.velocity.x = move_toward(player.velocity.x, 0.0, stop_friction * delta)

func _apply_gravity(delta: float) -> void:
	if player.is_on_floor():
		return

	var applied_gravity: float = gravity
	if player.velocity.y > 0.0:
		applied_gravity *= fall_gravity_multiplier

	player.velocity.y = minf(player.velocity.y + applied_gravity * delta, max_fall_speed)

func _try_jump() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if coyote_timer <= 0.0:
		return

	if health_component != null and health_component.is_hurt:
		return

	if player.is_stopping_run:
		return

	player.velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_play_jump_sound()

func _play_jump_sound() -> void:
	if jump_sound == null:
		return

	if jump_player == null:
		return

	jump_player.stream = jump_sound
	jump_player.pitch_scale = randf_range(0.98, 1.02)
	jump_player.volume_db = randf_range(-2.0, 0.0)
	jump_player.play()
