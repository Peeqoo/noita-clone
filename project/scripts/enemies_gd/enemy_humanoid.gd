extends EnemyBase
class_name EnemyHumanoid

@export var move_speed: float = 50.0
@export var aggro_range: float = 280.0
@export var attack_range: float = 65.0
@export var min_attack_distance: float = 60.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var sprite_offset: float = 35.0
@export var attack_hitbox_offset: float = 60.0

@export var crit_chance: float = 0.1
@export var crit_multiplier: float = 1.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var player: Node2D = null
var can_attack: bool = true
var has_hit_this_attack: bool = false

func _ready() -> void:
	super._ready()
	attack_hitbox_shape.set_deferred("disabled", true)

func _physics_process(_delta: float) -> void:
	if current_state == State.DEATH:
		return

	if current_state == State.HIT:
		velocity.x = 0.0
		move_and_slide()
		return

	if current_state == State.ATTACK:
		velocity.x = 0.0
		move_and_slide()
		return

	if player == null or not is_instance_valid(player):
		velocity.x = 0.0
		change_state(State.IDLE)
		move_and_slide()
		return

	var dx: float = player.global_position.x - global_position.x
	var distance: float = absf(dx)
	var dir: float = signf(dx)

	if distance > aggro_range:
		player = null
		velocity.x = 0.0
		change_state(State.IDLE)
		move_and_slide()
		return

	update_facing_and_attack_hitbox(dir)

	if is_player_too_close(distance):
		velocity.x = -dir * move_speed
		change_state(State.RUN)
	elif is_player_in_attack_position(dx, distance):
		velocity.x = 0.0
		if can_attack:
			start_attack()
		else:
			change_state(State.IDLE)
	else:
		velocity.x = dir * move_speed
		change_state(State.RUN)

	move_and_slide()

func update_facing_and_attack_hitbox(dir: float) -> void:
	if dir == 0.0:
		return

	animated_sprite.flip_h = dir > 0.0

	if animated_sprite.flip_h:
		animated_sprite.offset.x = sprite_offset
		attack_hitbox.position.x = attack_hitbox_offset
	else:
		animated_sprite.offset.x = -sprite_offset
		attack_hitbox.position.x = -attack_hitbox_offset

func is_player_too_close(distance: float) -> bool:
	return distance < min_attack_distance

func is_player_in_attack_position(dx: float, distance: float) -> bool:
	if distance > attack_range:
		return false

	if distance < min_attack_distance:
		return false

	if animated_sprite.flip_h:
		if dx < 0.0:
			return false
	else:
		if dx > 0.0:
			return false

	return true

func start_attack() -> void:
	if not can_attack:
		return

	can_attack = false
	has_hit_this_attack = false
	change_state(State.ATTACK)

func finish_attack() -> void:
	disable_attack_hitbox()
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func cancel_attack() -> void:
	disable_attack_hitbox()
	has_hit_this_attack = false
	can_attack = true

func enable_attack_hitbox() -> void:
	attack_hitbox_shape.set_deferred("disabled", false)

func disable_attack_hitbox() -> void:
	attack_hitbox_shape.set_deferred("disabled", true)

func roll_damage(base_damage: int) -> Dictionary:
	var is_crit: bool = randf() < crit_chance
	var final_damage: int = base_damage

	if is_crit:
		final_damage = int(round(base_damage * crit_multiplier))

	return {
		"damage": final_damage,
		"is_crit": is_crit
	}

func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body: Node) -> void:
	if body == player:
		player = null

func _on_attack_hitbox_body_entered(body: Node) -> void:
	if current_state != State.ATTACK:
		return

	if has_hit_this_attack:
		return

	if body.is_in_group("player") and body.has_method("take_damage"):
		var result: Dictionary = roll_damage(attack_damage)
		body.take_damage(result["damage"], global_position, result["is_crit"])
		has_hit_this_attack = true

func _on_animated_sprite_2d_frame_changed() -> void:
	if animated_sprite == null:
		return

	if animated_sprite.animation != "attack":
		disable_attack_hitbox()
		return

	if animated_sprite.frame >= 4 and animated_sprite.frame <= 5:
		enable_attack_hitbox()
	else:
		disable_attack_hitbox()

func _on_animation_finished() -> void:
	super._on_animation_finished()
