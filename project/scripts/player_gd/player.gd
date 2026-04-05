extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var movement_component: PlayerMovementComponent = $Components/MovementComponent
@onready var dash_component: PlayerDashComponent = $Components/DashComponent
@onready var combat_state_component: PlayerCombatStateComponent = $Components/CombatStateComponent
@onready var aim_component: PlayerAimComponent = $Components/AimComponent
@onready var health_component: PlayerHealthComponent = $Components/HealthComponent
@onready var animation_controller: PlayerAnimationController = $Components/AnimationController
@onready var player_inventory: PlayerInventoryComponent = $Components/PlayerInventoryComponent

var facing_left: bool = false
var is_stopping_run: bool = false
var idle_flip_lock_time: float = 0.0
var was_on_floor_last_frame: bool = false
var was_running_last_frame: bool = false

func _ready() -> void:
	add_to_group("player")
	animated_sprite.play("idle")
	was_on_floor_last_frame = is_on_floor()

	if aim_component != null:
		aim_component.setup_initial_state()
		_update_aim_and_wand()

func _physics_process(delta: float) -> void:
	var raw_input_dir: float = Input.get_axis("move_left", "move_right")

	if health_component != null and health_component.is_dead:
		_handle_dead_state(delta, raw_input_dir)
		return

	if idle_flip_lock_time > 0.0:
		idle_flip_lock_time -= delta

	if dash_component != null:
		dash_component.tick_cooldowns(delta)

	if is_on_floor() and dash_component != null:
		dash_component.reset_air_actions()

	if dash_component != null:
		if Input.is_action_just_pressed("block_dash"):
			dash_component.try_start_block_dash(raw_input_dir)
		elif Input.is_action_just_pressed("dash"):
			dash_component.try_start_dash(raw_input_dir)

	if dash_component != null and dash_component.is_block_dashing:
		_handle_block_dash_state(delta, raw_input_dir)
		return

	if dash_component != null and dash_component.is_dashing:
		_handle_dash_state(delta, raw_input_dir)
		return

	var movement_input: float = raw_input_dir
	if is_stopping_run:
		movement_input = 0.0

	if movement_component != null:
		movement_component.physics_step(delta, movement_input)

	move_and_slide()

	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0

	if animation_controller != null:
		animation_controller.update_animation(
			movement_input,
			was_on_floor_last_frame,
			was_running_last_frame
		)

	if movement_component != null:
		movement_component.update_footsteps_from_animation()

	_update_aim_and_wand()
	_update_facing_combined(raw_input_dir)

	was_on_floor_last_frame = is_on_floor()
	was_running_last_frame = absf(movement_input) > 0.0 and is_on_floor()

func _handle_dead_state(delta: float, raw_input_dir: float) -> void:
	if dash_component != null:
		dash_component.force_stop_all()

	if movement_component != null:
		movement_component.apply_dead_gravity(delta)

	move_and_slide()

	_update_facing_combined(raw_input_dir)
	_disable_wand_and_keep_current_aim()

	was_on_floor_last_frame = is_on_floor()
	was_running_last_frame = false

	if movement_component != null:
		movement_component.reset_footstep_state()

func _handle_block_dash_state(delta: float, raw_input_dir: float) -> void:
	if dash_component != null:
		dash_component.physics_process_block_dash(delta)

	move_and_slide()

	if animation_controller != null:
		animation_controller.update_animation(
			raw_input_dir,
			was_on_floor_last_frame,
			was_running_last_frame
		)

	_update_facing(0.0)
	_disable_wand_and_keep_current_aim()

	was_on_floor_last_frame = is_on_floor()
	was_running_last_frame = false

	if movement_component != null:
		movement_component.reset_footstep_state()

func _handle_dash_state(delta: float, raw_input_dir: float) -> void:
	if dash_component != null:
		dash_component.physics_process_dash(delta)

	move_and_slide()

	if animation_controller != null:
		animation_controller.update_animation(
			raw_input_dir,
			was_on_floor_last_frame,
			was_running_last_frame
		)

	_update_facing(dash_component.dash_direction)
	_disable_wand_and_keep_current_aim()

	was_on_floor_last_frame = is_on_floor()
	was_running_last_frame = false

	if movement_component != null:
		movement_component.reset_footstep_state()

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	if combat_state_component != null:
		combat_state_component.set_in_combat()

	if health_component != null:
		health_component.take_damage(amount, source_position, is_crit)

func set_in_combat() -> void:
	if combat_state_component != null:
		combat_state_component.set_in_combat()

func try_leave_combat() -> void:
	if combat_state_component != null:
		combat_state_component.try_leave_combat()

func is_in_dash_iframe() -> bool:
	if dash_component == null:
		return false
	return dash_component.is_in_dash_iframe()

func is_in_dash_guard_window() -> bool:
	if dash_component == null:
		return false
	return dash_component.is_in_dash_guard_window()

func is_in_block_dash_iframe() -> bool:
	if dash_component == null:
		return false
	return dash_component.is_in_block_dash_iframe()

func is_in_block_dash_guard_window() -> bool:
	if dash_component == null:
		return false
	return dash_component.is_in_block_dash_guard_window()

func _can_use_wand() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("is_inventory_open") and hud.is_inventory_open():
		return false

	if health_component != null:
		if health_component.is_hurt or health_component.is_dead:
			return false

	if is_stopping_run:
		return false

	if dash_component != null and (dash_component.is_dashing or dash_component.is_block_dashing):
		return false

	return true

func _update_aim_and_wand() -> void:
	if aim_component == null:
		return

	if _can_use_wand():
		aim_component.update_after_movement()
		aim_component.update_wand_input(true)
	else:
		_disable_wand_and_keep_current_aim()

func _disable_wand_and_keep_current_aim() -> void:
	if aim_component == null:
		return

	aim_component.update_wand_input(false)

func _update_facing_combined(input_dir: float) -> void:
	if aim_component != null:
		var aim_dir: Vector2 = aim_component.get_aim_direction()
		if absf(aim_dir.x) > 0.01:
			facing_left = aim_dir.x < 0.0
			animated_sprite.flip_h = facing_left
			return

	if absf(input_dir) > 0.0:
		facing_left = input_dir < 0.0
		animated_sprite.flip_h = facing_left
		return

	if idle_flip_lock_time > 0.0:
		animated_sprite.flip_h = facing_left
		return

	animated_sprite.flip_h = facing_left

func _update_facing(input_dir: float) -> void:
	if absf(input_dir) > 0.0:
		facing_left = input_dir < 0.0
		animated_sprite.flip_h = facing_left
		return

	if idle_flip_lock_time > 0.0:
		animated_sprite.flip_h = facing_left
		return

	animated_sprite.flip_h = facing_left
