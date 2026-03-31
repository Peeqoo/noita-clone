extends Node
class_name PlayerHealthComponent

signal health_changed(current: int, max_value: int)
signal died

@export var max_health: int = 100
@export var invincibility_time: float = 0.4
@export var knockback_force_x: float = 80.0
@export var knockback_force_y: float = -30.0

@export var damage_number_scene: PackedScene
@export var crit_damage_number_scene: PackedScene
@export var damage_number_offset: Vector2 = Vector2(0, -40)

@onready var player: CharacterBody2D = get_parent()
@onready var animated_sprite: AnimatedSprite2D = $"../AnimatedSprite2D"

var health: int
var is_hurt: bool = false
var is_dead: bool = false
var is_invincible: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	if is_dead:
		return

	if is_invincible:
		return

	health -= amount
	health = clamp(health, 0, max_health)
	show_damage_number(amount, is_crit)
	print("Player HP:", health)
	health_changed.emit(health, max_health)

	apply_knockback(source_position)

	if health <= 0:
		play_death()
	else:
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

func apply_knockback(source_position: Vector2) -> void:
	if source_position == Vector2.ZERO:
		return

	var dir_x: float = signf(player.global_position.x - source_position.x)

	if dir_x == 0.0:
		dir_x = -1.0 if player.facing_left else 1.0

	knockback_velocity.x = dir_x * knockback_force_x
	knockback_velocity.y = knockback_force_y

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

	if player.has_method("_update_wand_input"):
		player._update_wand_input(false)

	animated_sprite.play("death")
	died.emit()

func on_animation_finished(animation_name: String) -> void:
	if animation_name == "hit":
		is_hurt = false
