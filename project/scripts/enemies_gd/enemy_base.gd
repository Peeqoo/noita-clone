extends CharacterBody2D
class_name EnemyBase

enum State {
	IDLE,
	RUN,
	ATTACK,
	HIT,
	DEATH
}

@export_group("Base Combat")
@export var max_health: int = 50
@export var hit_stop_duration: float = 0.03
@export var crit_hit_stop_duration: float = 0.05
@export var knockback_force: float = 65.0
@export var crit_knockback_force: float = 95.0
@export var knockback_decay: float = 1800.0

@export_group("Base Chase")
@export var max_chase_distance: float = 420.0
@export var return_to_spawn_speed: float = 70.0
@export var search_duration: float = 1.2

@export_group("Base Patrol")
@export var use_patrol: bool = false
@export var patrol_distance: float = 40.0
@export var patrol_pause_time: float = 1.0
@export var patrol_speed: float = 35.0

@export_group("Base Separation")
@export var use_soft_separation: bool = true
@export var separation_radius: float = 22.0
@export var separation_strength: float = 55.0

@export_group("Base Movement")
@export var use_gravity: bool = true
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 900.0
@export var use_ledge_check: bool = false

@export_group("Base Step Up")
@export var use_step_up: bool = true
@export var max_step_height: float = 10.0
@export var step_height_increment: float = 2.0
@export var min_step_forward_check: float = 4.0
@export var step_forward_padding: float = 2.0

@export_group("Loot / FX")
@export var damage_number_scene: PackedScene
@export var crit_damage_number_scene: PackedScene
@export var damage_number_offset: Vector2 = Vector2(0, -40)

@export var spell_pickup_scene: PackedScene
@export var magic_bolt_data: SpellData
@export var triple_shot_data: SpellData
@export var sniper_needle_data: SpellData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ledge_check: RayCast2D = get_node_or_null("LedgeCheck")

var health: int
var current_state: State = State.IDLE
var is_sleeping: bool = false
var is_in_hit_stop: bool = false
var knockback_velocity_x: float = 0.0

var spawn_position: Vector2
var last_seen_position: Vector2
var has_last_seen_position: bool = false
var is_returning_to_spawn: bool = false
var is_searching: bool = false
var search_timer: float = 0.0

var patrol_center_position: Vector2
var patrol_target_position: Vector2
var is_patrol_waiting: bool = false
var patrol_wait_timer: float = 0.0
var patrol_dir: float = 1.0

func _ready() -> void:
	health = max_health
	spawn_position = global_position
	patrol_center_position = spawn_position
	patrol_target_position = patrol_center_position + Vector2(patrol_distance, 0)

	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	_update_animation()

func change_state(new_state: State) -> void:
	if current_state == State.DEATH:
		return

	current_state = new_state
	_update_animation()

func _update_animation() -> void:
	match current_state:
		State.IDLE:
			if is_sleeping and sprite.sprite_frames.has_animation("sleep"):
				sprite.play("sleep")
			else:
				sprite.play("idle")
		State.RUN:
			if sprite.sprite_frames.has_animation("run"):
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

func start_attack() -> void:
	pass

func finish_attack() -> void:
	change_state(State.IDLE)

func cancel_attack() -> void:
	pass

func aggro_on_hit(_source_position: Vector2 = Vector2.ZERO) -> void:
	pass

func set_last_seen_position(pos: Vector2) -> void:
	last_seen_position = pos
	has_last_seen_position = true

func start_search() -> void:
	is_searching = true
	search_timer = search_duration

func update_search(delta: float) -> void:
	if not is_searching:
		return

	search_timer -= delta
	if search_timer <= 0.0:
		is_searching = false
		start_return_to_spawn()

func start_return_to_spawn() -> void:
	is_returning_to_spawn = true
	has_last_seen_position = false
	is_searching = false

func update_return_to_spawn(_delta: float) -> float:
	var dx: float = spawn_position.x - global_position.x
	var distance: float = absf(dx)

	if distance < 4.0:
		is_returning_to_spawn = false
		return 0.0

	var dir: float = 1.0 if dx > 0.0 else -1.0
	return dir * return_to_spawn_speed

func has_reached_spawn() -> bool:
	return absf(global_position.x - spawn_position.x) < 4.0

func check_leash() -> bool:
	return global_position.distance_to(spawn_position) > max_chase_distance

func clear_tracking() -> void:
	has_last_seen_position = false
	is_searching = false
	search_timer = 0.0

func reset_patrol() -> void:
	patrol_center_position = spawn_position
	patrol_dir = 1.0
	is_patrol_waiting = false
	patrol_wait_timer = 0.0
	patrol_target_position = patrol_center_position + Vector2(patrol_distance, 0)

func update_patrol(delta: float) -> float:
	if not use_patrol:
		return 0.0

	if is_patrol_waiting:
		patrol_wait_timer -= delta
		if patrol_wait_timer <= 0.0:
			is_patrol_waiting = false
			patrol_dir *= -1.0
			patrol_target_position = patrol_center_position + Vector2(patrol_distance * patrol_dir, 0)
		return 0.0

	var dx: float = patrol_target_position.x - global_position.x
	if absf(dx) < 4.0:
		is_patrol_waiting = true
		patrol_wait_timer = patrol_pause_time
		return 0.0

	var dir: float = 1.0 if dx > 0.0 else -1.0
	return dir * patrol_speed

func get_separation_velocity_x() -> float:
	if not use_soft_separation:
		return 0.0

	var separation_x: float = 0.0
	var enemies := get_tree().get_nodes_in_group("enemy")

	for other in enemies:
		if other == self:
			continue
		if not is_instance_valid(other):
			continue
		if not (other is EnemyBase):
			continue
		if other.current_state == State.DEATH:
			continue

		var dx: float = global_position.x - other.global_position.x
		var dy: float = absf(global_position.y - other.global_position.y)

		if dy > 20.0:
			continue

		var dist_x: float = absf(dx)
		if dist_x <= 0.001 or dist_x > separation_radius:
			continue

		var push_dir: float = 1.0 if dx > 0.0 else -1.0
		var strength_ratio: float = 1.0 - (dist_x / separation_radius)
		separation_x += push_dir * strength_ratio * separation_strength

	return separation_x

func apply_gravity(delta: float) -> void:
	if not use_gravity:
		velocity.y = 0.0
		return

	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0
		return

	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	velocity.y += gravity * gravity_scale * delta
	velocity.y = minf(velocity.y, max_fall_speed)

func can_move_in_direction(dir: float) -> bool:
	if dir == 0.0:
		return true

	if not use_ledge_check:
		return true

	if ledge_check == null:
		return true

	if not is_on_floor():
		return true

	var target := ledge_check.target_position
	target.x = absf(target.x) * dir
	ledge_check.target_position = target

	ledge_check.force_raycast_update()
	return ledge_check.is_colliding()

func try_step_up(delta: float) -> void:
	if not use_step_up:
		return

	if not is_on_floor():
		return

	if velocity.y < 0.0:
		return

	if absf(velocity.x) < 0.01:
		return

	var dir: float = signf(velocity.x)
	if dir == 0.0:
		return

	var forward_check: float = maxf(absf(velocity.x * delta) + step_forward_padding, min_step_forward_check)

	if not test_move(global_transform, Vector2(dir * forward_check, 0.0)):
		return

	var step_height: float = step_height_increment
	while step_height <= max_step_height:
		var raised_transform: Transform2D = global_transform.translated(Vector2(0.0, -step_height))

		if test_move(raised_transform, Vector2.ZERO):
			step_height += step_height_increment
			continue

		if not test_move(raised_transform, Vector2(dir * forward_check, 0.0)):
			global_position.y -= step_height
			return

		step_height += step_height_increment

func move_and_slide_with_step(delta: float) -> void:
	try_step_up(delta)
	move_and_slide()

func take_hit(hit_data: Dictionary) -> void:
	if current_state == State.DEATH:
		return

	var amount: int = int(hit_data.get("damage", 0))
	var is_crit: bool = bool(hit_data.get("is_crit", false))
	var source_position: Vector2 = hit_data.get("source_position", global_position)

	take_damage(amount, is_crit, source_position)

func take_damage(amount: int, is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEATH:
		return

	if current_state == State.ATTACK:
		cancel_attack()

	if source_position != Vector2.ZERO:
		aggro_on_hit(source_position)

	health -= amount
	apply_damage_knockback(source_position, is_crit)
	show_damage_number(amount, is_crit)
	do_hit_stop(is_crit)

	if health <= 0:
		die()
	else:
		change_state(State.HIT)

func apply_damage_knockback(source_position: Vector2, is_crit: bool = false) -> void:
	var dir: float = global_position.x - source_position.x

	if absf(dir) < 0.001:
		dir = 1.0 if sprite.flip_h else -1.0
	else:
		dir = 1.0 if dir > 0.0 else -1.0

	var force: float = crit_knockback_force if is_crit else knockback_force
	knockback_velocity_x = dir * force

func get_knockback_velocity_x(delta: float) -> float:
	var current_knockback: float = knockback_velocity_x
	knockback_velocity_x = move_toward(knockback_velocity_x, 0.0, knockback_decay * delta)
	return current_knockback

func do_hit_stop(is_crit: bool = false) -> void:
	if is_in_hit_stop:
		return

	is_in_hit_stop = true

	var duration: float = crit_hit_stop_duration if is_crit else hit_stop_duration

	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

	is_in_hit_stop = false

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
	drop_loot()

func _on_animation_finished() -> void:
	match current_state:
		State.HIT:
			change_state(State.IDLE)
		State.ATTACK:
			finish_attack()
		State.DEATH:
			queue_free()

func drop_loot() -> void:
	if spell_pickup_scene == null:
		return

	var spells = [
		magic_bolt_data,
		triple_shot_data,
		sniper_needle_data
	]

	var spell_to_drop: SpellData = spells.pick_random()
	if spell_to_drop == null:
		return

	call_deferred("_spawn_loot_pickup", spell_to_drop, global_position)

func _spawn_loot_pickup(spell_to_drop: SpellData, new_spawn_position: Vector2) -> void:
	var pickup = spell_pickup_scene.instantiate()
	pickup.global_position = new_spawn_position
	pickup.spell_data = spell_to_drop
	get_tree().current_scene.add_child(pickup)
