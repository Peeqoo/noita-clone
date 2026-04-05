extends EnemyBase
class_name EnemyMonster

@export_group("Monster Combat")
@export var move_speed: float = 102.0
@export var chase_speed_multiplier: float = 1.2
@export var close_chase_speed_multiplier: float = 0.68
@export var attack_range: float = 56.0
@export var attack_stop_distance: float = 24.0
@export var attack_damage: int = 9
@export var attack_cooldown: float = 0.22
@export var attack_windup: float = 0.22
@export var crit_chance: float = 0.14
@export var crit_multiplier: float = 1.4

@export_group("Catch Up Chase")
@export var use_catch_up_speed: bool = true
@export var catch_up_distance: float = 140.0
@export var catch_up_speed_multiplier: float = 0.8

@export_group("Aggro Chase")
@export var use_aggro_chase: bool = true
@export var aggro_bonus_per_hit: float = 0.04
@export var max_aggro_bonus: float = 0.18
@export var aggro_decay_per_second: float = 0.10

@export_group("Monster Feel")
@export var attack_hitbox_offset: float = 10.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var player: Node2D = null
var has_hit_this_attack: bool = false
var facing_dir: float = -1.0
var is_sleeping: bool = false
var aggro_chase_bonus: float = 0.0

func _ready() -> void:
	max_health = 46
	max_chase_distance = 720.0
	return_to_spawn_speed = 88.0
	search_duration = 3.2

	use_patrol = false

	use_soft_separation = true
	separation_radius = 30.0
	separation_strength = 80.0

	use_gravity = true
	use_ledge_check = false
	use_step_up = true
	max_step_height = 14.0
	step_height_increment = 1.0
	min_step_forward_check = 6.0
	step_forward_padding = 3.0

	is_sleeping = true

	super._ready()
	attack_hitbox_shape.set_deferred("disabled", true)
	facing_dir = -1.0
	_update_facing_visuals()
	change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
		return

	_update_aggro_decay(delta)
	apply_gravity(delta)

	if current_state == State.HIT:
		velocity.x = get_separation_velocity_x()
		velocity.x += get_knockback_velocity_x(delta)
		move_and_slide_with_step(delta)
		return

	if check_leash():
		if player != null and player.has_method("try_leave_combat"):
			player.try_leave_combat()
		player = null
		start_return_to_spawn()
		is_sleeping = false

	if is_sleeping:
		velocity.x = 0.0
		velocity.x += get_separation_velocity_x()
		velocity.x += get_knockback_velocity_x(delta)
		change_state(State.IDLE)
		move_and_slide_with_step(delta)
		return

	if is_winding_up:
		velocity.x = 0.0
		velocity.x += get_separation_velocity_x()
		velocity.x += get_knockback_velocity_x(delta)
		move_and_slide_with_step(delta)
		return

	if current_state == State.ATTACK:
		velocity.x = get_separation_velocity_x()
		velocity.x += get_knockback_velocity_x(delta)
		move_and_slide_with_step(delta)
		return

	if player == null or not is_instance_valid(player):
		_handle_no_player_state(delta)
		return

	_handle_player_state(delta)

func _handle_no_player_state(delta: float) -> void:
	if has_last_seen_position:
		var dx_last: float = last_seen_position.x - global_position.x
		var dir_last: float = 1.0 if dx_last > 0.0 else -1.0

		facing_dir = dir_last
		_update_facing_visuals()

		velocity.x = dir_last * move_speed
		change_state(State.RUN)

		if absf(dx_last) < 6.0:
			has_last_seen_position = false
			start_search()

	elif is_searching:
		update_search(delta)
		velocity.x = 0.0
		change_state(State.IDLE)

	elif is_returning_to_spawn:
		var return_speed: float = update_return_to_spawn(delta)
		if return_speed != 0.0:
			facing_dir = 1.0 if return_speed > 0.0 else -1.0
			_update_facing_visuals()

		velocity.x = return_speed

		if is_returning_to_spawn and velocity.x != 0.0:
			change_state(State.RUN)
		elif is_returning_to_spawn:
			change_state(State.IDLE)
		else:
			clear_tracking()
			is_sleeping = true
			current_state = State.IDLE
			_update_animation()

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

	facing_dir = dir
	_update_facing_visuals()

	if distance > attack_range * 2.8:
		set_last_seen_position(player.global_position)

	if distance <= attack_stop_distance:
		velocity.x = 0.0
		if can_attack and not is_winding_up:
			start_attack()
		else:
			change_state(State.IDLE)

	elif distance <= attack_range:
		var close_speed_mult: float = close_chase_speed_multiplier + aggro_chase_bonus * 0.35
		velocity.x = dir * move_speed * close_speed_mult
		change_state(State.RUN)

	else:
		var final_chase_multiplier: float = _get_current_chase_multiplier(distance)
		velocity.x = dir * move_speed * final_chase_multiplier
		change_state(State.RUN)

	velocity.x += get_separation_velocity_x()
	velocity.x += get_knockback_velocity_x(delta)
	move_and_slide_with_step(delta)

func _get_current_chase_multiplier(distance: float) -> float:
	var final_multiplier: float = chase_speed_multiplier

	if use_aggro_chase:
		final_multiplier += aggro_chase_bonus

	if use_catch_up_speed and distance > catch_up_distance:
		final_multiplier *= catch_up_speed_multiplier

	return final_multiplier

func _update_aggro_decay(delta: float) -> void:
	if not use_aggro_chase:
		return

	if aggro_chase_bonus <= 0.0:
		return

	aggro_chase_bonus = maxf(0.0, aggro_chase_bonus - aggro_decay_per_second * delta)

func _add_aggro_from_hit() -> void:
	if not use_aggro_chase:
		return

	aggro_chase_bonus = minf(max_aggro_bonus, aggro_chase_bonus + aggro_bonus_per_hit)

func _update_facing_visuals() -> void:
	if facing_dir < 0.0:
		animated_sprite.flip_h = false
		attack_hitbox.position.x = -absf(attack_hitbox_offset)
	else:
		animated_sprite.flip_h = true
		attack_hitbox.position.x = absf(attack_hitbox_offset)

func _play_idle_animation() -> void:
	if sprite == null:
		return

	if is_sleeping and sprite.sprite_frames.has_animation("sleep"):
		sprite.play("sleep")
		return

	super._play_idle_animation()

func start_attack() -> void:
	if not can_attack:
		return

	super.start_attack()
	begin_attack_windup()

	has_hit_this_attack = false
	velocity.x = 0.0
	change_state(State.IDLE)
	_start_attack_after_windup()

func _start_attack_after_windup() -> void:
	await get_tree().create_timer(attack_windup).timeout

	if current_state == State.DEATH:
		return

	if current_state == State.HIT:
		reset_attack_state()
		return

	if is_sleeping:
		reset_attack_state()
		return

	if player == null or not is_instance_valid(player):
		reset_attack_state()
		return

	commit_attack()

func finish_attack() -> void:
	disable_attack_hitbox()
	velocity.x = 0.0
	has_hit_this_attack = false

	end_attack()

	if current_state == State.DEATH:
		return

	if not is_sleeping and player != null and is_instance_valid(player):
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

	super.cancel_attack()

	if current_state != State.DEATH:
		change_state(State.IDLE)

func aggro_on_hit(source_position: Vector2 = Vector2.ZERO) -> void:
	is_sleeping = false
	is_returning_to_spawn = false
	is_searching = false
	_add_aggro_from_hit()

	var found_player := get_tree().get_first_node_in_group("player")
	if found_player != null and found_player is Node2D:
		player = found_player
		set_last_seen_position(player.global_position)

		if player.has_method("set_in_combat"):
			player.set_in_combat()

	if source_position != Vector2.ZERO:
		facing_dir = 1.0 if source_position.x > global_position.x else -1.0
		_update_facing_visuals()

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
		is_sleeping = false
		is_returning_to_spawn = false
		is_searching = false
		set_last_seen_position(player.global_position)
		change_state(State.IDLE)

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

	if animated_sprite.frame >= 2 and animated_sprite.frame <= 4:
		enable_attack_hitbox()
	else:
		disable_attack_hitbox()

func _on_animation_finished() -> void:
	super._on_animation_finished()
