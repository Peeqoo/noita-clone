extends Node
class_name PlayerAnimationController

@onready var player: CharacterBody2D = get_parent()
@onready var animated_sprite: AnimatedSprite2D = $"../AnimatedSprite2D"
@onready var health_component: PlayerHealthComponent = $"../HealthComponent"

func update_animation(input_dir: float, was_on_floor_last_frame: bool, was_running_last_frame: bool) -> void:
	if health_component == null:
		return

	if health_component.is_dead:
		if animated_sprite.animation != "death":
			animated_sprite.play("death")
		return

	if health_component.is_hurt:
		if animated_sprite.animation != "hit":
			animated_sprite.play("hit")
		return

	if not player.is_on_floor():
		if player.velocity.y < 0.0:
			if animated_sprite.animation != "jump":
				animated_sprite.play("jump")
		else:
			if animated_sprite.animation != "fall":
				animated_sprite.play("fall")
		return

	if not was_on_floor_last_frame and player.is_on_floor():
		player.is_stopping_run = false
		player.idle_flip_lock_time = 0.35

		if absf(input_dir) > 0.0:
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		return

	if player.is_stopping_run:
		return

	if absf(input_dir) > 0.0:
		if animated_sprite.animation != "run":
			animated_sprite.play("run")
		return

	if was_running_last_frame and absf(input_dir) == 0.0:
		player.is_stopping_run = true
		if animated_sprite.animation != "stop_run":
			animated_sprite.play("stop_run")
		return

	if animated_sprite.animation != "idle":
		animated_sprite.play("idle")

func on_animation_finished() -> void:
	if animated_sprite.animation == "stop_run":
		player.is_stopping_run = false
		animated_sprite.play("idle")
	elif animated_sprite.animation == "hit":
		if health_component != null:
			health_component.on_animation_finished("hit")
	elif animated_sprite.animation == "death":
		player.queue_free()
