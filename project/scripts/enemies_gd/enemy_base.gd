extends CharacterBody2D
class_name EnemyBase

enum State {
	IDLE,
	RUN,
	ATTACK,
	HIT,
	DEATH
}

@export var max_health: int = 1000

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var damage_number_scene: PackedScene
@export var crit_damage_number_scene: PackedScene
@export var damage_number_offset: Vector2 = Vector2(0, -40)

var health: int
var current_state: State = State.IDLE

func _ready() -> void:
	health = max_health

	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	sprite.play("idle")

func change_state(new_state: State) -> void:
	if current_state == State.DEATH:
		return

	if current_state == new_state:
		return

	current_state = new_state

	match current_state:
		State.IDLE:
			sprite.play("idle")

		State.RUN:
			sprite.play("run")

		State.ATTACK:
			if sprite.sprite_frames.has_animation("attack"):
				sprite.play("attack")
			else:
				change_state(State.IDLE)

		State.HIT:
			if sprite.sprite_frames.has_animation("hit"):
				sprite.play("hit")
			else:
				change_state(State.IDLE)

		State.DEATH:
			if sprite.sprite_frames.has_animation("death"):
				sprite.play("death")
			else:
				queue_free()

func take_hit(hit_data: Dictionary) -> void:
	if current_state == State.DEATH:
		return

	var amount: int = int(hit_data.get("damage", 0))
	var is_crit: bool = bool(hit_data.get("is_crit", false))

	take_damage(amount, is_crit)

func take_damage(amount: int, is_crit: bool = false) -> void:
	if current_state == State.DEATH:
		return

	if current_state == State.ATTACK and has_method("cancel_attack"):
		call("cancel_attack")

	health -= amount
	show_damage_number(amount, is_crit)
	print(name, " HP:", health, " | Crit:", is_crit)

	if health <= 0:
		die()
	else:
		change_state(State.HIT)

func show_damage_number(amount: int, is_crit: bool = false) -> void:
	var scene_to_use: PackedScene = damage_number_scene

	if is_crit and crit_damage_number_scene != null:
		scene_to_use = crit_damage_number_scene

	if scene_to_use == null:
		return

	var number = scene_to_use.instantiate()
	get_tree().current_scene.add_child(number)
	
	var random_offset := Vector2(
		randf_range(-8.0, 8.0),
		randf_range(-6.0, 6.0)
	)

	if is_crit:
		random_offset.y -= 8.0

	number.global_position = global_position + damage_number_offset + random_offset

	if number.has_method("setup"):
		number.setup(amount, is_crit)

func die() -> void:
	change_state(State.DEATH)

func _on_animation_finished() -> void:
	match current_state:
		State.HIT:
			change_state(State.IDLE)

		State.ATTACK:
			if has_method("finish_attack"):
				call("finish_attack")
			change_state(State.IDLE)

		State.DEATH:
			queue_free()
