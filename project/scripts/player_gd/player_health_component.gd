extends Node
class_name PlayerHealthComponent

signal health_changed(current: int, max_value: int)
signal died

@export_group("Health")
@export var max_health: int = 100
@export var health: int = 100
@export var invincibility_time: float = 0.2

@export_group("Knockback")
@export var knockback_force_x: float = 60.0
@export var knockback_force_y: float = -18.0
@export var crit_knockback_multiplier: float = 1.4

@export_group("Damage Numbers")
@export var damage_number_scene: PackedScene
@export var crit_damage_number_scene: PackedScene
@export var damage_number_offset: Vector2 = Vector2(0, -18)

@export_group("Hit Audio")
@export var hit_sound: AudioStream

@export_group("Hit Camera Shake")
@export var player_hit_shake_strength: float = 2.0
@export var player_hit_shake_time: float = 0.08
@export var player_crit_hit_shake_strength: float = 4.0
@export var player_crit_hit_shake_time: float = 0.12

@export_group("Dash Guard Camera Shake")
@export var dash_guard_shake_strength: float = 2.5
@export var dash_guard_shake_time: float = 0.08

@export_group("Block Guard Camera Shake")
@export var block_dash_guard_shake_strength: float = 3.5
@export var block_dash_guard_shake_time: float = 0.10

@onready var player: CharacterBody2D = get_parent().get_parent()
@onready var animated_sprite: AnimatedSprite2D = $"../../Visuals/AnimatedSprite2D"
@onready var hit_player: AudioStreamPlayer2D = $"../../Audio/HitPlayer"

var is_dead: bool = false
var is_hurt: bool = false
var is_invincible: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	health = clamp(health, 0, max_health)
	health_changed.emit(health, max_health)

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	if is_invincible:
		return

	show_damage_number(amount, is_crit)

	if player.has_method("is_in_block_dash_iframe") and player.is_in_block_dash_iframe():
		return

	if player.has_method("is_in_dash_iframe") and player.is_in_dash_iframe():
		return

	if player.has_method("is_in_block_dash_guard_window") and player.is_in_block_dash_guard_window():
		_play_hit_sound()
		_shake_block_guard_camera()
		return

	if player.has_method("is_in_dash_guard_window") and player.is_in_dash_guard_window():
		_play_hit_sound()
		_shake_dash_guard_camera()
		return

	health -= amount
	health = max(health, 0)
	health_changed.emit(health, max_health)

	if player.has_method("set_in_combat"):
		player.set_in_combat()

	if health <= 0:
		die()
		return

	apply_knockback(source_position, is_crit)
	_play_hit_sound()
	_shake_player_camera(is_crit)
	play_hit()
	start_invincibility()

func heal(amount: int) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	if health >= max_health:
		return

	health = clamp(health + amount, 0, max_health)
	health_changed.emit(health, max_health)

func show_damage_number(amount: int, is_crit: bool = false) -> void:
	var scene_to_use: PackedScene = damage_number_scene

	if is_crit and crit_damage_number_scene != null:
		scene_to_use = crit_damage_number_scene

	if scene_to_use == null:
		return

	var number = scene_to_use.instantiate()
	player.get_tree().current_scene.add_child(number)

	var random_offset := Vector2(
		randf_range(-8.0, 8.0),
		randf_range(-4.0, 4.0)
	)

	if is_crit:
		random_offset.y -= 8.0

	number.global_position = player.global_position + damage_number_offset + random_offset

	if number.has_method("setup"):
		number.setup(amount, is_crit)

func start_invincibility() -> void:
	is_invincible = true

	var blink_time: float = invincibility_time
	var t: float = 0.0

	while t < blink_time:
		animated_sprite.visible = not animated_sprite.visible
		await get_tree().create_timer(0.05).timeout
		t += 0.05

	animated_sprite.visible = true
	is_invincible = false

func apply_knockback(source_position: Vector2, is_crit: bool = false) -> void:
	if source_position == Vector2.ZERO:
		return

	var dir_x: float = signf(player.global_position.x - source_position.x)

	if dir_x == 0.0:
		dir_x = -1.0 if player.facing_left else 1.0

	var multiplier: float = 1.0
	if is_crit:
		multiplier = crit_knockback_multiplier

	knockback_velocity.x = dir_x * knockback_force_x * multiplier
	knockback_velocity.y = knockback_force_y * multiplier

func play_hit() -> void:
	if is_dead:
		return

	is_hurt = true
	player.is_stopping_run = false
	animated_sprite.play("hit")

func die() -> void:
	play_death()

func play_death() -> void:
	if is_dead:
		return

	is_dead = true
	is_hurt = false
	player.is_stopping_run = false
	player.velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO

	var aim_component := player.get_node_or_null("Components/AimComponent")
	if aim_component != null and aim_component.has_method("update_wand_input"):
		aim_component.update_wand_input(false)

	animated_sprite.play("death")
	died.emit()

func on_animation_finished(animation_name: String) -> void:
	if animation_name == "hit":
		is_hurt = false

func _play_hit_sound() -> void:
	if hit_sound == null:
		return

	if hit_player == null:
		return

	hit_player.stream = hit_sound
	hit_player.pitch_scale = randf_range(0.97, 1.03)
	hit_player.volume_db = randf_range(-2.0, 0.0)
	hit_player.play()

func _shake_player_camera(is_crit: bool) -> void:
	if player == null:
		return

	var camera := player.get_node_or_null("PlayerCamera")
	if camera == null:
		return

	if not camera.has_method("shake"):
		return

	if is_crit:
		camera.shake(player_crit_hit_shake_strength, player_crit_hit_shake_time)
	else:
		camera.shake(player_hit_shake_strength, player_hit_shake_time)

func _shake_dash_guard_camera() -> void:
	if player == null:
		return

	var camera := player.get_node_or_null("PlayerCamera")
	if camera == null:
		return

	if not camera.has_method("shake"):
		return

	camera.shake(dash_guard_shake_strength, dash_guard_shake_time)

func _shake_block_guard_camera() -> void:
	if player == null:
		return

	var camera := player.get_node_or_null("PlayerCamera")
	if camera == null:
		return

	if not camera.has_method("shake"):
		return

	camera.shake(block_dash_guard_shake_strength, block_dash_guard_shake_time)
