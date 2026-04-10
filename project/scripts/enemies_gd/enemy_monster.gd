extends EnemyBase
class_name EnemyMonster

@export_group("Monster Combat")
@export var move_speed: float = 108.0
@export var chase_speed_multiplier: float = 1.28
@export var close_chase_speed_multiplier: float = 1.15
@export var attack_range: float = 72.0
@export var attack_stop_distance: float = 40.0
@export var attack_damage: int = 7
@export var attack_cooldown: float = 0.30
@export var attack_windup: float = 0.10
@export var crit_chance: float = 0.08
@export var crit_multiplier: float = 1.25

@export_group("Catch Up Chase")
@export var use_catch_up_speed: bool = true
@export var catch_up_distance: float = 120.0
@export var catch_up_speed_multiplier: float = 1.26

@export_group("Aggro Chase")
@export var use_aggro_chase: bool = true
@export var aggro_bonus_per_hit: float = 0.06
@export var max_aggro_bonus: float = 0.22
@export var aggro_decay_per_second: float = 0.08

@export_group("Monster Feel")
@export var attack_hitbox_offset: float = 18.0

@export_group("Attack Jump")
@export var use_attack_jump: bool = true
@export var attack_jump_requires_run_state: bool = true
@export var attack_jump_min_distance: float = 34.0
@export var attack_jump_trigger_distance: float = 68.0
@export var attack_jump_max_distance: float = 40.0
@export var attack_jump_duration: float = 0.18
@export var attack_jump_up_velocity: float = -145.0
@export var attack_jump_movement_enabled: bool = true
@export var attack_jump_move_speed: float = 260.0
@export var attack_jump_use_chase_speed: bool = false
@export var attack_jump_chase_speed_multiplier: float = 1.85
@export var attack_jump_min_run_speed: float = 20.0

@export_group("Monster Base Tuning")
@export var monster_max_health: int = 46
@export var monster_max_chase_distance: float = 720.0
@export var monster_return_to_spawn_speed: float = 88.0
@export var monster_search_duration: float = 3.2
@export var monster_use_patrol: bool = false
@export var monster_use_soft_separation: bool = true
@export var monster_separation_radius: float = 30.0
@export var monster_separation_strength: float = 80.0
@export var monster_use_gravity: bool = true
@export var monster_use_ledge_check: bool = false
@export var monster_use_step_up: bool = true
@export var monster_max_step_height: float = 14.0
@export var monster_step_height_increment: float = 1.0
@export var monster_min_step_forward_check: float = 6.0
@export var monster_step_forward_padding: float = 3.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var player: Node2D = null
var has_hit_this_attack: bool = false
var facing_dir: float = -1.0
var is_sleeping: bool = false
var aggro_chase_bonus: float = 0.0

var is_attack_jumping: bool = false
var attack_jump_timer: float = 0.0
var attack_jump_dir: float = 0.0
var attack_jump_target_distance: float = 0.0
var attack_jump_distance_travelled: float = 0.0
var attack_jump_should_attack_after_landing: bool = false

func _ready() -> void:
	_apply_monster_base_settings()
	is_sleeping = true

	super._ready()
	attack_hitbox_shape.set_deferred("disabled", true)
	facing_dir = -1.0
	_update_facing_visuals()
	change_state(State.IDLE)

func _apply_monster_base_settings() -> void:
	max_health = monster_max_health
	max_chase_distance = monster_max_chase_distance
	return_to_spawn_speed = monster_return_to_spawn_speed
	search_duration = monster_search_duration

	use_patrol = monster_use_patrol

	use_soft_separation = monster_use_soft_separation
	separation_radius = monster_separation_radius
	separation_strength = monster_separation_strength

	use_gravity = monster_use_gravity
	use_ledge_check = monster_use_ledge_check
	use_step_up = monster_use_step_up
	max_step_height = monster_max_step_height
	step_height_increment = monster_step_height_increment
	min_step_forward_check = monster_min_step_forward_check
	step_forward_padding = monster_step_forward_padding

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
		_cancel_attack_jump()
		start_return_to_spawn()
		is_sleeping = false

	if is_sleeping:
		velocity.x = 0.0
		velocity.x += get_separation_velocity_x()
		velocity.x += get_knockback_velocity_x(delta)
		change_state(State.IDLE)
		move_and_slide_with_step(delta)
		return

	if is_attack_jumping:
		_update_attack_jump(delta)
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

	if _should_start_attack_jump(distance):
		start_attack_jump(dir)
		return

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

func _should_start_attack_jump(distance: float) -> bool:
	if not use_attack_jump:
		return false
	if not can_attack or is_winding_up or is_attack_jumping:
		return false

	# zu nah = normale attack
	if distance <= attack_jump_min_distance:
		return false

	# zu weit = weiter chasen
	if distance > attack_jump_trigger_distance:
		return false

	# nur in sinnvoller mittlerer distanz = jump attack
	if attack_jump_requires_run_state:
		var is_actively_running: bool = current_state == State.RUN or absf(velocity.x) >= attack_jump_min_run_speed
		if not is_actively_running:
			return false

	return true

func _get_current_chase_multiplier(distance: float) -> float:
	var final_multiplier: float = chase_speed_multiplier

	if use_aggro_chase:
		final_multiplier += aggro_chase_bonus

	if use_catch_up_speed and distance > catch_up_distance:
		final_multiplier *= catch_up_speed_multiplier

	return final_multiplier

func _get_attack_jump_move_speed(distance: float) -> float:
	if attack_jump_use_chase_speed:
		return move_speed * _get_current_chase_multiplier(distance) * attack_jump_chase_speed_multiplier
	return attack_jump_move_speed

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

	_cancel_attack_jump()

	super.start_attack()
	begin_attack_windup()

	has_hit_this_attack = false
	velocity.x = 0.0
	change_state(State.IDLE)
	_start_attack_after_windup()

func start_attack_jump(dir: float) -> void:
	if not can_attack:
		return
	if player == null or not is_instance_valid(player):
		return

	var player_distance: float = absf(player.global_position.x - global_position.x)
	var desired_jump_distance: float = minf(player_distance, attack_jump_max_distance)
	if desired_jump_distance <= 0.0:
		return

	is_attack_jumping = true
	attack_jump_timer = attack_jump_duration
	attack_jump_dir = dir
	attack_jump_target_distance = desired_jump_distance
	attack_jump_distance_travelled = 0.0
	attack_jump_should_attack_after_landing = true
	has_hit_this_attack = false

	facing_dir = dir
	_update_facing_visuals()

	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("jump"):
		animated_sprite.play("jump")

	velocity.x = 0.0
	velocity.y = attack_jump_up_velocity

func _update_attack_jump(delta: float) -> void:
	attack_jump_timer -= delta

	if player == null or not is_instance_valid(player):
		_cancel_attack_jump()
		change_state(State.IDLE)
		return

	var previous_x: float = global_position.x
	var dx: float = player.global_position.x - global_position.x
	var distance: float = absf(dx)
	attack_jump_dir = 1.0 if dx > 0.0 else -1.0
	facing_dir = attack_jump_dir
	_update_facing_visuals()

	var remaining_jump_distance: float = maxf(0.0, attack_jump_target_distance - attack_jump_distance_travelled)

	if attack_jump_movement_enabled and remaining_jump_distance > 0.0 and delta > 0.0:
		var wanted_speed: float = _get_attack_jump_move_speed(distance)
		var max_speed_this_frame: float = remaining_jump_distance / delta
		velocity.x = attack_jump_dir * minf(wanted_speed, max_speed_this_frame)
	else:
		velocity.x = 0.0

	velocity.x += get_separation_velocity_x()
	velocity.x += get_knockback_velocity_x(delta)
	move_and_slide_with_step(delta)

	attack_jump_distance_travelled += absf(global_position.x - previous_x)

	if attack_jump_timer <= 0.0 or attack_jump_distance_travelled >= attack_jump_target_distance - 0.5:
		var should_attack: bool = attack_jump_should_attack_after_landing
		_cancel_attack_jump()
		if should_attack and can_attack:
			start_attack()
		else:
			change_state(State.IDLE)
		return

func _cancel_attack_jump() -> void:
	is_attack_jumping = false
	attack_jump_timer = 0.0
	attack_jump_dir = 0.0
	attack_jump_target_distance = 0.0
	attack_jump_distance_travelled = 0.0
	attack_jump_should_attack_after_landing = false

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

	var dx: float = player.global_position.x - global_position.x
	facing_dir = 1.0 if dx > 0.0 else -1.0
	_update_facing_visuals()

	commit_attack()

func finish_attack() -> void:
	disable_attack_hitbox()
	velocity.x = 0.0
	has_hit_this_attack = false
	_cancel_attack_jump()

	end_attack()

	if current_state == State.DEATH:
		return

	change_state(State.IDLE)

	await get_tree().create_timer(attack_cooldown).timeout

	if current_state == State.DEATH:
		return

	can_attack = true

func cancel_attack() -> void:
	disable_attack_hitbox()
	has_hit_this_attack = false
	velocity.x = 0.0
	_cancel_attack_jump()

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

	if is_attack_jumping:
		disable_attack_hitbox()
		return

	if animated_sprite.animation != "attack":
		disable_attack_hitbox()
		return

	if animated_sprite.frame >= 2 and animated_sprite.frame <= 4:
		enable_attack_hitbox()
	else:
		disable_attack_hitbox()

func _on_animation_finished() -> void:
	if is_attack_jumping and animated_sprite != null and animated_sprite.animation == "jump":
		return

	super._on_animation_finished()
