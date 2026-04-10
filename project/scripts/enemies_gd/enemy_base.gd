extends CharacterBody2D
class_name EnemyBase

enum State {
	IDLE,
	RUN,
	ATTACK,
	HIT,
	DEATH
}

# =========================
# Base Combat
# Shared defaults for all enemies.
# Enemy-specific tuning should live in the child scripts and then be applied to these base values in _ready().
# =========================
@export_group("Base Combat")
@export var max_health: int = 50
@export var hit_stop_duration: float = 0.015
@export var crit_hit_stop_duration: float = 0.03
@export var knockback_force: float = 24.0
@export var crit_knockback_force: float = 44.0
@export var knockback_decay: float = 4800.0
@export var enemy_crit_hit_shake_strength: float = 5.0
@export var enemy_crit_hit_shake_time: float = 0.12
@export var normal_hits_interrupt_attack: bool = false
@export var crit_hits_interrupt_attack: bool = true
@export var normal_hits_use_hit_state: bool = false
@export var crit_hits_use_hit_state: bool = true
# =========================
# Base Chase
# Generic tracking / leash defaults.
# =========================
@export_group("Base Chase")
@export var max_chase_distance: float = 500.0
@export var return_to_spawn_speed: float = 78.0
@export var search_duration: float = 2.2

# =========================
# Base Patrol
# Generic patrol defaults.
# =========================
@export_group("Base Patrol")
@export var use_patrol: bool = false
@export var patrol_distance: float = 40.0
@export var patrol_pause_time: float = 1.0
@export var patrol_speed: float = 35.0

# =========================
# Base Separation
# Generic crowd handling defaults.
# =========================
@export_group("Base Separation")
@export var use_soft_separation: bool = true
@export var separation_radius: float = 30.0
@export var separation_strength: float = 80.0

# =========================
# Base Movement
# Generic movement defaults.
# =========================
@export_group("Base Movement")
@export var use_gravity: bool = true
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 900.0
@export var use_ledge_check: bool = false

# =========================
# Base Step Up
# Generic terrain traversal defaults.
# =========================
@export_group("Base Step Up")
@export var use_step_up: bool = true
@export var max_step_height: float = 10.0
@export var step_height_increment: float = 2.0
@export var min_step_forward_check: float = 4.0
@export var step_forward_padding: float = 2.0

# =========================
# Base Audio
# =========================
@export_group("Base Audio")
@export var footstep_sound: AudioStream
@export var footstep_frames: Array[int] = [1, 5]
@export var footstep_min_interval: float = 0.18

@export var hit_sound: AudioStream
@export var death_sound: AudioStream

@export var attack_sounds: Array[AudioStream] = []
@export var idle_sounds: Array[AudioStream] = []

@export var idle_sound_interval_min: float = 2.5
@export var idle_sound_interval_max: float = 5.5
@export var idle_sound_volume_db: float = -5.0

# =========================
# Loot / FX
# =========================
@export_group("Loot / FX")
@export var damage_number_scene: PackedScene
@export var crit_damage_number_scene: PackedScene
@export var damage_number_offset: Vector2 = Vector2(0, -40)

@export var spell_pickup_scene: PackedScene
@export var loot_spells: Array[SpellData] = []

# =========================
# Node References
# =========================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ledge_check: RayCast2D = get_node_or_null("LedgeCheck")
@onready var footstep_player: AudioStreamPlayer2D = get_node_or_null("FootstepPlayer")
@onready var hit_player: AudioStreamPlayer2D = get_node_or_null("HitPlayer")
@onready var voice_player: AudioStreamPlayer2D = get_node_or_null("VoicePlayer")

# =========================
# Runtime State
# =========================
var health: int
var current_state: State = State.IDLE
var is_in_hit_stop: bool = false
var knockback_velocity_x: float = 0.0

# Tracking / Aggro
var spawn_position: Vector2
var last_seen_position: Vector2
var has_last_seen_position: bool = false
var is_returning_to_spawn: bool = false
var is_searching: bool = false
var search_timer: float = 0.0

# Patrol
var patrol_center_position: Vector2
var patrol_target_position: Vector2
var is_patrol_waiting: bool = false
var patrol_wait_timer: float = 0.0
var patrol_dir: float = 1.0

# Attack Base Flow
var can_attack: bool = true
var is_attacking: bool = false
var is_winding_up: bool = false

# Audio Runtime
var _last_footstep_frame: int = -1
var _footstep_cooldown: float = 0.0
var _idle_sound_timer: float = 0.0

# =========================
# Lifecycle
# =========================
func _ready() -> void:
	_initialize_base_state()
	_connect_base_signals()
	_reset_idle_sound_timer()
	_update_animation()

func _process(delta: float) -> void:
	_update_run_footsteps(delta)
	_update_idle_sounds(delta)

func _initialize_base_state() -> void:
	health = max_health
	spawn_position = global_position
	patrol_center_position = spawn_position
	patrol_target_position = patrol_center_position + Vector2(patrol_distance, 0)

func _connect_base_signals() -> void:
	if sprite != null and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

# =========================
# State / Animation
# =========================
func change_state(new_state: State) -> void:
	if current_state == State.DEATH:
		return

	current_state = new_state
	_update_animation()

func _update_animation() -> void:
	match current_state:
		State.IDLE:
			_play_idle_animation()
		State.RUN:
			_play_run_animation()
		State.ATTACK:
			_play_attack_animation()
		State.HIT:
			_play_hit_animation()
		State.DEATH:
			_play_death_animation()

func _play_idle_animation() -> void:
	if sprite == null:
		return

	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func _play_run_animation() -> void:
	if sprite == null:
		return

	if sprite.sprite_frames.has_animation("run"):
		sprite.play("run")

func _play_attack_animation() -> void:
	if sprite == null:
		return

	if sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	else:
		change_state(State.IDLE)

func _play_hit_animation() -> void:
	if sprite == null:
		return

	if sprite.sprite_frames.has_animation("hit"):
		sprite.play("hit")
	else:
		change_state(State.IDLE)

func _play_death_animation() -> void:
	if sprite == null:
		queue_free()
		return

	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		queue_free()

# =========================
# Child Hooks
# =========================
func start_attack() -> void:
	_play_attack_sound()

func finish_attack() -> void:
	end_attack()
	change_state(State.IDLE)

func cancel_attack() -> void:
	reset_attack_state()

func aggro_on_hit(_source_position: Vector2 = Vector2.ZERO) -> void:
	pass

# =========================
# Attack Base Flow
# =========================
func begin_attack_windup() -> void:
	if not can_attack:
		return

	can_attack = false
	is_winding_up = true
	is_attacking = false

func commit_attack() -> void:
	is_winding_up = false
	is_attacking = true
	change_state(State.ATTACK)

func end_attack() -> void:
	is_attacking = false
	is_winding_up = false

func reset_attack_state() -> void:
	is_attacking = false
	is_winding_up = false
	can_attack = true

# =========================
# Tracking / Search / Return
# =========================
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

# =========================
# Patrol
# =========================
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

# =========================
# Separation
# =========================
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

# =========================
# Movement Helpers
# =========================
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

# =========================
# Damage / Knockback / Death
# =========================
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

	if source_position != Vector2.ZERO:
		aggro_on_hit(source_position)

	if current_state == State.ATTACK or is_winding_up or is_attacking:
		_handle_attack_interrupt_on_hit(is_crit)

	health -= amount

	apply_damage_knockback(source_position, is_crit)
	show_damage_number(amount, is_crit)
	_play_hit_sound()

	if is_crit:
		_shake_player_camera_on_enemy_crit()

	do_hit_stop(is_crit)

	if health <= 0:
		die()
		return

	_apply_hit_state_if_needed(is_crit)

func _handle_attack_interrupt_on_hit(is_crit: bool) -> void:
	if is_crit and crit_hits_interrupt_attack:
		cancel_attack()
	elif not is_crit and normal_hits_interrupt_attack:
		cancel_attack()

func _apply_hit_state_if_needed(is_crit: bool) -> void:
	if is_crit and crit_hits_use_hit_state:
		change_state(State.HIT)
	elif not is_crit and normal_hits_use_hit_state:
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

func die() -> void:
	_play_death_sound()
	change_state(State.DEATH)
	drop_loot()

func _shake_player_camera_on_enemy_crit() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		player = get_tree().current_scene.find_child("Player", true, false)

	if player == null:
		return

	var camera := player.get_node_or_null("PlayerCamera")
	if camera == null:
		return

	if camera.has_method("shake"):
		camera.shake(enemy_crit_hit_shake_strength, enemy_crit_hit_shake_time)

# =========================
# Damage Number FX
# =========================
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

# =========================
# Animation Events
# =========================
func _on_animation_finished() -> void:
	match current_state:
		State.HIT:
			change_state(State.IDLE)
		State.ATTACK:
			finish_attack()
		State.DEATH:
			queue_free()

# =========================
# Audio
# =========================
func _update_run_footsteps(delta: float) -> void:
	if _footstep_cooldown > 0.0:
		_footstep_cooldown -= delta

	if footstep_sound == null:
		_last_footstep_frame = -1
		return

	if footstep_player == null:
		_last_footstep_frame = -1
		return

	if current_state != State.RUN:
		_last_footstep_frame = -1
		return

	if not is_on_floor():
		_last_footstep_frame = -1
		return

	if sprite.animation != "run":
		_last_footstep_frame = -1
		return

	if absf(velocity.x) <= 5.0:
		_last_footstep_frame = -1
		return

	var current_frame: int = sprite.frame
	if current_frame == _last_footstep_frame:
		return

	if current_frame in footstep_frames and _footstep_cooldown <= 0.0:
		_play_footstep_sound()
		_footstep_cooldown = footstep_min_interval

	_last_footstep_frame = current_frame

func _update_idle_sounds(delta: float) -> void:
	if idle_sounds.is_empty():
		return

	if voice_player == null:
		return

	if current_state == State.ATTACK or current_state == State.HIT or current_state == State.DEATH:
		return

	_idle_sound_timer -= delta
	if _idle_sound_timer > 0.0:
		return

	if voice_player.playing:
		_reset_idle_sound_timer()
		return

	_play_idle_sound()
	_reset_idle_sound_timer()

func _reset_idle_sound_timer() -> void:
	_idle_sound_timer = randf_range(idle_sound_interval_min, idle_sound_interval_max)

func _play_footstep_sound() -> void:
	if footstep_sound == null:
		return

	if footstep_player == null:
		return

	footstep_player.stream = footstep_sound
	footstep_player.pitch_scale = randf_range(0.95, 1.05)
	footstep_player.volume_db = randf_range(-3.0, 0.0)
	footstep_player.play()

func _play_hit_sound() -> void:
	if hit_sound == null:
		return

	if hit_player == null:
		return

	hit_player.stream = hit_sound
	hit_player.pitch_scale = randf_range(0.97, 1.03)
	hit_player.volume_db = randf_range(-2.0, 0.0)
	hit_player.play()

func _play_attack_sound() -> void:
	if attack_sounds.is_empty():
		return

	if voice_player == null:
		return

	voice_player.stream = attack_sounds.pick_random()
	voice_player.pitch_scale = randf_range(0.95, 1.05)
	voice_player.volume_db = randf_range(-2.0, 0.0)
	voice_player.play()

func _play_idle_sound() -> void:
	if idle_sounds.is_empty():
		return

	if voice_player == null:
		return

	voice_player.stream = idle_sounds.pick_random()
	voice_player.pitch_scale = randf_range(0.95, 1.05)
	voice_player.volume_db = idle_sound_volume_db
	voice_player.play()

func _play_death_sound() -> void:
	if death_sound == null:
		return

	if voice_player == null:
		return

	voice_player.stream = death_sound
	voice_player.pitch_scale = randf_range(0.95, 1.05)
	voice_player.volume_db = randf_range(-2.0, 0.0)
	voice_player.play()

# =========================
# Loot
# =========================
func drop_loot() -> void:
	if spell_pickup_scene == null:
		return

	var chosen_spell: SpellData = get_loot_spell()
	if chosen_spell == null:
		return

	call_deferred("_spawn_loot_pickup", chosen_spell, global_position)

func get_loot_spell() -> SpellData:
	var valid_spells: Array[SpellData] = []

	for spell in loot_spells:
		if spell != null:
			valid_spells.append(spell)

	if valid_spells.is_empty():
		return null

	return valid_spells.pick_random()

func _spawn_loot_pickup(chosen_spell: SpellData, drop_position: Vector2) -> void:
	if spell_pickup_scene == null:
		return

	var pickup = spell_pickup_scene.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = drop_position

	if pickup.has_method("set_spell_data"):
		pickup.set_spell_data(chosen_spell)
