extends EnemyBase
class_name EnemyHumanoid

@export_group("Humanoid Combat")
@export var move_speed: float = 92.0
@export var aggro_range: float = 340.0
@export var attack_range: float = 72.0
@export var min_attack_distance: float = 50.0
@export var preferred_distance: float = 66.0
@export var disengage_distance: float = 36.0
@export var attack_damage: int = 11
@export var attack_cooldown: float = 0.45
@export var crit_chance: float = 0.12
@export var crit_multiplier: float = 1.5

@export_group("Humanoid Movement Feel")
@export var sprite_offset: float = 35.0
@export var attack_hitbox_offset: float = 60.0
@export var backstep_speed_multiplier: float = 0.82
@export var approach_slowdown_distance: float = 96.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var player: Node2D = null
var can_attack: bool = true
var has_hit_this_attack: bool = false

func _ready() -> void:
	max_health = 62
	max_chase_distance = 620.0
	return_to_spawn_speed = 68.0
	search_duration = 2.6

	use_patrol = true
	patrol_distance = 42.0
	patrol_pause_time = 1.3
	patrol_speed = 26.0

	use_soft_separation = true
	separation_radius = 26.0
	separation_strength = 58.0

	use_gravity = true
	use_ledge_check = true
	use_step_up = true
	max_step_height = 12.0
	step_height_increment = 2.0
	min_step_forward_check = 5.0
	step_forward_padding = 2.0

	super._ready()
	reset_patrol()
	attack_hitbox_shape.set_deferred("disabled", true)

func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
		return

	apply_gravity(delta)

	if current_state == State.HIT:
		velocity.x = get_separation_velocity_x()
		velocity.x += get_knockback_velocity_x(delta)
		move_and_slide_with_step(delta)
		return

	if current_state == State.ATTACK:
		velocity.x = get_separation_velocity_x()
		velocity.x += get_knockback_velocity_x(delta)
		move_and_slide_with_step(delta)
		return

	if check_leash():
		if player != null and player.has_method("try_leave_combat"):
			player.try_leave_combat()
		player = null
		start_return_to_spawn()

	if player == null or not is_instance_valid(player):
		_handle_no_player_state(delta)
		return

	_handle_player_state(delta)

func _handle_no_player_state(delta: float) -> void:
	if has_last_seen_position:
		var dx_last: float = last_seen_position.x - global_position.x
		var dir_last: float = 1.0 if dx_last > 0.0 else -1.0

		update_facing_and_attack_hitbox(dir_last)

		if can_move_in_direction(dir_last):
			velocity.x = dir_last * move_speed
			change_state(State.RUN)
		else:
			velocity.x = 0.0
			change_state(State.IDLE)

		if absf(dx_last) < 6.0:
			has_last_seen_position = false
			start_search()

	elif is_searching:
		update_search(delta)
		velocity.x = 0.0
		change_state(State.IDLE)

	elif is_returning_to_spawn:
		var return_speed: float = update_return_to_spawn(delta)
		var return_dir: float = 1.0 if return_speed > 0.0 else -1.0

		if return_speed != 0.0:
			update_facing_and_attack_hitbox(return_dir)

		if return_speed != 0.0 and can_move_in_direction(return_dir):
			velocity.x = return_speed
			change_state(State.RUN)
		else:
			velocity.x = 0.0
			change_state(State.IDLE)

		if not is_returning_to_spawn:
			clear_tracking()
			reset_patrol()
			change_state(State.IDLE)

	elif use_patrol:
		var patrol_velocity: float = update_patrol(delta)
		if patrol_velocity != 0.0:
			var patrol_dir_sign: float = 1.0 if patrol_velocity > 0.0 else -1.0
			update_facing_and_attack_hitbox(patrol_dir_sign)

			if can_move_in_direction(patrol_dir_sign):
				velocity.x = patrol_velocity
				change_state(State.RUN)
			else:
				velocity.x = 0.0
				change_state(State.IDLE)
		else:
			velocity.x = 0.0
			change_state(State.IDLE)

	else:
		velocity.x = 0.0
		change_state(State.IDLE)

	velocity.x += get_separation_velocity_x()
	velocity.x += get_knockback_velocity_x(delta)
	move_and_slide_with_step(delta)

func _handle_player_state(delta: float) -> void:
	set_last_seen_position(player.global_position)

	var dx: float = player.global_position.x - global_position.x
	var distance: float = absf(dx)
	var dir: float = 1.0 if dx > 0.0 else -1.0

	if distance > aggro_range:
		set_last_seen_position(player.global_position)

		if player.has_method("try_leave_combat"):
			player.try_leave_combat()

		player = null
		start_search()

		velocity.x += get_separation_velocity_x()
		velocity.x += get_knockback_velocity_x(delta)
		move_and_slide_with_step(delta)
		return

	update_facing_and_attack_hitbox(dir)

	if distance <= disengage_distance:
		var retreat_dir: float = -dir

		if can_move_in_direction(retreat_dir):
			velocity.x = retreat_dir * move_speed * backstep_speed_multiplier
			change_state(State.RUN)
		else:
			velocity.x = 0.0
			change_state(State.IDLE)

	elif is_player_in_attack_position(dx, distance):
		velocity.x = 0.0
		if can_attack:
			start_attack()
		else:
			change_state(State.IDLE)

	elif distance < preferred_distance:
		var reposition_dir: float = -dir

		if can_move_in_direction(reposition_dir):
			velocity.x = reposition_dir * move_speed * 0.55
			change_state(State.RUN)
		else:
			velocity.x = 0.0
			change_state(State.IDLE)

	else:
		var move_mult: float = 1.0
		if distance < approach_slowdown_distance:
			move_mult = 0.7

		if can_move_in_direction(dir):
			velocity.x = dir * move_speed * move_mult
			change_state(State.RUN)
		else:
			velocity.x = 0.0
			change_state(State.IDLE)

	velocity.x += get_separation_velocity_x()
	velocity.x += get_knockback_velocity_x(delta)
	move_and_slide_with_step(delta)

func update_facing_and_attack_hitbox(dir: float) -> void:
	animated_sprite.flip_h = dir > 0.0

	if animated_sprite.flip_h:
		animated_sprite.offset.x = sprite_offset
		attack_hitbox.position.x = attack_hitbox_offset
	else:
		animated_sprite.offset.x = -sprite_offset
		attack_hitbox.position.x = -attack_hitbox_offset

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
	velocity.x = 0.0
	change_state(State.ATTACK)

func finish_attack() -> void:
	disable_attack_hitbox()
	velocity.x = 0.0
	has_hit_this_attack = false

	if current_state == State.DEATH:
		return

	if player != null and is_instance_valid(player):
		change_state(State.RUN)
	else:
		change_state(State.IDLE)

	await get_tree().create_timer(attack_cooldown).timeout

	if current_state == State.DEATH:
		return

	can_attack = true

func cancel_attack() -> void:
	disable_attack_hitbox()
	has_hit_this_attack = false
	velocity.x = 0.0
	can_attack = true

	if current_state != State.DEATH:
		change_state(State.IDLE)

func aggro_on_hit(source_position: Vector2 = Vector2.ZERO) -> void:
	is_returning_to_spawn = false
	is_searching = false
	is_patrol_waiting = false

	var found_player := get_tree().get_first_node_in_group("player")
	if found_player != null and found_player is Node2D:
		player = found_player
		set_last_seen_position(player.global_position)

		if player.has_method("set_in_combat"):
			player.set_in_combat()

	if source_position != Vector2.ZERO:
		var dir: float = 1.0 if source_position.x > global_position.x else -1.0
		update_facing_and_attack_hitbox(dir)

	if current_state != State.DEATH and current_state != State.ATTACK:
		change_state(State.IDLE)

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
		is_returning_to_spawn = false
		is_searching = false
		is_patrol_waiting = false
		set_last_seen_position(player.global_position)

		if player.has_method("set_in_combat"):
			player.set_in_combat()

func _on_detection_area_body_exited(body: Node) -> void:
	if body == player:
		set_last_seen_position(player.global_position)

		if player.has_method("try_leave_combat"):
			player.try_leave_combat()

		player = null
		start_search()

func _on_attack_hitbox_body_entered(body: Node) -> void:
	if current_state != State.ATTACK:
		return

	if has_hit_this_attack:
		return

	if body.is_in_group("player") and body.has_method("take_damage"):
		if body.has_method("set_in_combat"):
			body.set_in_combat()

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
