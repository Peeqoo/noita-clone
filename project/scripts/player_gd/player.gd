extends CharacterBody2D

@export var move_speed: float = 100.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -280.0
@export var gravity: float = 1000.0
@export var max_fall_speed: float = 900.0
@export var wand_angle_offset_degrees: float = 0.0
@export var wand_pivot_right_position: Vector2 = Vector2(4, -4)
@export var wand_pivot_left_position: Vector2 = Vector2(-4, -4)

@export var combat_exit_delay: float = 3.0
@export var health_regen_amount: int = 1
@export var health_regen_interval: float = 0.5

@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

@export var fall_gravity_multiplier: float = 1.3
@export var air_control_multiplier: float = 0.6

@export var footstep_sound: AudioStream
@export var jump_sound: AudioStream
@export var footstep_frames: Array[int] = [1, 5]

@onready var wand_pivot: Node2D = $WandPivot
@onready var wand: Node2D = $WandPivot/Wand
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hud = get_tree().get_first_node_in_group("hud")
@onready var inventory: InventoryComponent = $Inventory
@onready var health_component: PlayerHealthComponent = $HealthComponent
@onready var animation_controller: PlayerAnimationController = $AnimationController
@onready var player_inventory: PlayerInventoryComponent = $PlayerInventoryComponent
@onready var footstep_player: AudioStreamPlayer2D = $FootstepPlayer
@onready var jump_player: AudioStreamPlayer2D = $JumpPlayer

var is_stopping_run: bool = false
var facing_left: bool = false

var was_on_floor_last_frame: bool = false
var was_running_last_frame: bool = false
var idle_flip_lock_time: float = 0.0

var in_combat: bool = false
var _combat_token: int = 0
var _regen_running: bool = false

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var _last_footstep_frame: int = -1

func _ready() -> void:
	animated_sprite.play("idle")
	was_on_floor_last_frame = is_on_floor()
	_update_wand_pivot_position()
	_update_hud()

	if wand.has_method("set_actor_owner"):
		wand.set_actor_owner(self)

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	if health_component == null:
		return

	set_in_combat()
	health_component.take_damage(amount, source_position, is_crit)

func set_in_combat() -> void:
	in_combat = true
	_combat_token += 1

func try_leave_combat() -> void:
	_combat_token += 1
	var my_token: int = _combat_token
	_leave_combat_after_delay(my_token)

func _leave_combat_after_delay(token: int) -> void:
	await get_tree().create_timer(combat_exit_delay).timeout

	if token != _combat_token:
		return

	in_combat = false
	_start_health_regen()

func _start_health_regen() -> void:
	if _regen_running:
		return

	_regen_running = true
	_health_regen_loop()

func _health_regen_loop() -> void:
	while not in_combat:
		if health_component == null:
			break

		if health_component.health >= health_component.max_health:
			break

		await get_tree().create_timer(health_regen_interval).timeout

		if in_combat:
			break

		if health_component == null:
			break

		if health_component.health < health_component.max_health:
			health_component.heal(health_regen_amount)

	_regen_running = false

func _physics_process(delta: float) -> void:
	var raw_input_dir: float = Input.get_axis("move_left", "move_right")
	var input_dir: float = raw_input_dir
	var jumped_this_frame: bool = false

	if health_component != null and health_component.is_dead:
		velocity.x = 0.0
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		move_and_slide()

		_update_facing(raw_input_dir)
		_update_wand_pivot_position()
		_update_aim()
		_update_wand_input(false)

		was_on_floor_last_frame = is_on_floor()
		was_running_last_frame = false
		_last_footstep_frame = -1
		return

	if idle_flip_lock_time > 0.0:
		idle_flip_lock_time -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	if is_on_floor():
		coyote_timer = coyote_time
	elif coyote_timer > 0.0:
		coyote_timer -= delta

	if is_stopping_run:
		input_dir = 0.0

	var target_speed: float = input_dir * move_speed
	var control_multiplier: float = 1.0

	if not is_on_floor():
		control_multiplier = air_control_multiplier

	if input_dir != 0.0:
		var accel: float = acceleration * control_multiplier

		if signf(target_speed) != signf(velocity.x) and absf(velocity.x) > 0.0:
			accel = acceleration * 1.35 * control_multiplier
		elif absf(target_speed) > absf(velocity.x):
			accel = acceleration * 1.15 * control_multiplier
		else:
			accel = acceleration * 0.9 * control_multiplier

		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		var stop_friction: float = friction * 1.15

		if absf(velocity.x) < 40.0:
			stop_friction *= 1.6

		velocity.x = move_toward(velocity.x, 0.0, stop_friction * delta)

	if not is_on_floor():
		var applied_gravity: float = gravity

		if velocity.y > 0.0:
			applied_gravity *= fall_gravity_multiplier

		velocity.y = minf(velocity.y + applied_gravity * delta, max_fall_speed)

	if health_component != null:
		if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and not health_component.is_hurt and not is_stopping_run:
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			jumped_this_frame = true

		velocity += health_component.knockback_velocity
		health_component.knockback_velocity = health_component.knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	else:
		if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and not is_stopping_run:
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			jumped_this_frame = true

	if jumped_this_frame:
		_play_jump_sound()

	move_and_slide()

	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0

	if animation_controller != null:
		animation_controller.update_animation(input_dir, was_on_floor_last_frame, was_running_last_frame)

	_update_footsteps_from_animation()

	_update_facing(raw_input_dir)
	_update_wand_pivot_position()
	_update_aim()

	if health_component != null:
		_update_wand_input(not health_component.is_hurt and not is_stopping_run and not health_component.is_dead)
	else:
		_update_wand_input(not is_stopping_run)

	was_on_floor_last_frame = is_on_floor()
	was_running_last_frame = absf(input_dir) > 0.0 and is_on_floor()

func add_spell_to_inventory(new_spell: SpellData) -> bool:
	if inventory == null:
		return false
	return inventory.add_spell(new_spell)

func equip_inventory_spell_to_wand(inventory_index: int, slot_index: int) -> bool:
	if player_inventory == null:
		return false
	return player_inventory.equip_inventory_spell_to_wand(inventory_index, slot_index)

func unequip_wand_spell_to_inventory(slot_index: int) -> bool:
	if player_inventory == null:
		return false
	return player_inventory.unequip_wand_spell_to_inventory(slot_index)

func _update_aim() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var dir: Vector2 = mouse_pos - wand_pivot.global_position
	wand_pivot.rotation = dir.angle() + deg_to_rad(wand_angle_offset_degrees)

func _update_wand_input(can_shoot: bool) -> void:
	var inventory_open := false

	if hud != null and hud.has_method("is_inventory_open"):
		inventory_open = hud.is_inventory_open()

	if wand.has_method("set_trigger_held"):
		wand.set_trigger_held(can_shoot and not inventory_open and Input.is_action_pressed("shoot"))

func _update_wand_pivot_position() -> void:
	if facing_left:
		wand_pivot.position = wand_pivot_left_position
	else:
		wand_pivot.position = wand_pivot_right_position

func _update_facing(raw_input_dir: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()

	if is_stopping_run:
		animated_sprite.flip_h = facing_left
		return

	if not is_on_floor():
		animated_sprite.flip_h = facing_left
		return

	if absf(raw_input_dir) > 0.0:
		if raw_input_dir < 0.0:
			facing_left = true
		elif raw_input_dir > 0.0:
			facing_left = false

		animated_sprite.flip_h = facing_left
		return

	if idle_flip_lock_time > 0.0:
		animated_sprite.flip_h = facing_left
		return

	facing_left = mouse_pos.x < global_position.x
	animated_sprite.flip_h = facing_left

func _update_footsteps_from_animation() -> void:
	if footstep_sound == null:
		_last_footstep_frame = -1
		return

	if not is_on_floor():
		_last_footstep_frame = -1
		return

	if animated_sprite.animation != "run":
		_last_footstep_frame = -1
		return

	if absf(velocity.x) <= 5.0:
		_last_footstep_frame = -1
		return

	var current_frame: int = animated_sprite.frame

	if current_frame == _last_footstep_frame:
		return

	if current_frame in footstep_frames:
		play_footstep_sound()

	_last_footstep_frame = current_frame

func play_footstep_sound() -> void:
	if footstep_sound == null:
		return

	if footstep_player == null:
		return

	footstep_player.stream = footstep_sound
	footstep_player.pitch_scale = randf_range(0.95, 1.05)
	footstep_player.volume_db = randf_range(-3.0, 0.0)
	footstep_player.play()

func _play_jump_sound() -> void:
	if jump_sound == null:
		return

	if jump_player == null:
		return

	jump_player.stream = jump_sound
	jump_player.pitch_scale = randf_range(0.97, 1.03)
	jump_player.volume_db = 0.0
	jump_player.play()

func _on_animation_finished() -> void:
	if animation_controller != null:
		animation_controller.on_animation_finished()

func play_hit() -> void:
	if health_component == null:
		return

	health_component.play_hit()

func die() -> void:
	if health_component == null:
		return

	health_component.die()

func play_death() -> void:
	if health_component == null:
		return

	health_component.play_death()

func _update_hud() -> void:
	if hud == null:
		return

	if health_component != null:
		if hud.has_method("set_health"):
			hud.set_health(health_component.health, health_component.max_health)

func _on_player_health_component_health_changed(current: int, max_value: int) -> void:
	if hud != null and hud.has_method("set_health"):
		hud.set_health(current, max_value)
