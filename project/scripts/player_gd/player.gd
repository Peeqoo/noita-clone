extends CharacterBody2D

@export_group("Step Visual Smoothing")
@export var step_visual_smoothing_speed: float = 100.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var player_camera: Camera2D = $PlayerCamera
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

var _saved_collision_layer: int = 2
var _saved_collision_mask: int = 1585
var _base_camera_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	animated_sprite.play("idle")
	was_on_floor_last_frame = is_on_floor()

	if aim_component != null:
		aim_component.setup_initial_state()
		_update_aim_and_wand()

	if player_camera != null:
		_base_camera_position = player_camera.position
		player_camera.make_current()

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

	var allow_step_up: bool = is_on_floor() and absf(velocity.x) > 0.01
	if health_component != null and health_component.is_hurt:
		allow_step_up = false
	if allow_step_up and ActorStepMover.is_on_walkable_slope(self):
		allow_step_up = false

	if allow_step_up:
		var step_height: float = ActorStepMover.try_step_up(self, delta, signf(velocity.x))
		if step_height > 0.0:
			_apply_step_visual_offset(step_height)

	move_and_slide()
	_update_step_visual_smoothing(delta)

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

func on_death_started() -> void:
	_reset_step_visual_offset()
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0

	if dash_component != null:
		dash_component.force_stop_all()

	if aim_component != null and aim_component.has_method("update_wand_input"):
		aim_component.update_wand_input(false)

func is_dead() -> bool:
	return health_component != null and health_component.is_dead

func stabilize_after_scene_change() -> void:
	if is_dead():
		return

	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask

	velocity = Vector2.ZERO
	is_stopping_run = false
	idle_flip_lock_time = 0.0

	if dash_component != null:
		dash_component.force_stop_all()

	if health_component != null and health_component.has_method("stabilize_after_scene_change"):
		health_component.stabilize_after_scene_change()

	_reset_step_visual_offset()

	if animated_sprite != null:
		animated_sprite.visible = true
		animated_sprite.play("idle")

	if aim_component != null:
		aim_component.setup_initial_state()

	var wand := get_node_or_null("Visuals/WandPivot/Wand")
	if wand != null:
		if wand.has_method("_update_hud_mana"):
			wand._update_hud_mana()
		if wand.has_method("_update_hud_spell"):
			wand._update_hud_spell()

	if player_camera != null:
		player_camera.make_current()

func respawn_after_death() -> void:
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask

	velocity = Vector2.ZERO
	is_stopping_run = false
	idle_flip_lock_time = 0.0
	facing_left = false

	if health_component != null and health_component.has_method("reset_for_respawn"):
		health_component.reset_for_respawn()

	if dash_component != null and dash_component.has_method("reset_for_respawn"):
		dash_component.reset_for_respawn()

	if combat_state_component != null and combat_state_component.has_method("reset_for_respawn"):
		combat_state_component.reset_for_respawn()

	_reset_step_visual_offset()

	if animated_sprite != null:
		animated_sprite.visible = true
		animated_sprite.play("idle")

	var wand := get_node_or_null("Visuals/WandPivot/Wand")
	if wand != null:
		if wand.get("wand_data") != null:
			var wd = wand.get("wand_data")
			if wd != null and "mana_max" in wd:
				wand.current_mana = wd.mana_max
		wand.cast_cooldown = 0.0
		wand.recharge_cooldown = 0.0
		if wand.has_method("reset_spell_cycle"):
			wand.reset_spell_cycle()
		if wand.has_method("_update_hud_mana"):
			wand._update_hud_mana()
		if wand.has_method("_update_hud_spell"):
			wand._update_hud_spell()

	if aim_component != null:
		aim_component.setup_initial_state()

	if player_camera != null:
		player_camera.make_current()

func _handle_dead_state(delta: float, raw_input_dir: float) -> void:
	_reset_step_visual_offset()

	if dash_component != null:
		dash_component.force_stop_all()

	if movement_component != null:
		movement_component.apply_dead_gravity(delta)

	move_and_slide()

	if animation_controller != null:
		animation_controller.update_animation(
			raw_input_dir,
			was_on_floor_last_frame,
			was_running_last_frame
		)

	_update_facing_combined(raw_input_dir)
	_disable_wand_and_keep_current_aim()

	was_on_floor_last_frame = is_on_floor()
	was_running_last_frame = false

	if movement_component != null:
		movement_component.reset_footstep_state()

func _handle_block_dash_state(delta: float, raw_input_dir: float) -> void:
	_reset_step_visual_offset()

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
	_reset_step_visual_offset()

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


func _apply_step_visual_offset(step_height: float) -> void:
	if step_height <= 0.0:
		return

	if visuals != null:
		visuals.position.y += step_height

	if player_camera != null:
		player_camera.position.y += step_height


func _update_step_visual_smoothing(delta: float) -> void:
	var step_delta: float = step_visual_smoothing_speed * delta

	if visuals != null:
		if is_equal_approx(visuals.position.y, 0.0):
			visuals.position.y = 0.0
		else:
			visuals.position.y = move_toward(visuals.position.y, 0.0, step_delta)
			if absf(visuals.position.y) < 0.05:
				visuals.position.y = 0.0

	if player_camera == null:
		return

	if is_equal_approx(player_camera.position.y, _base_camera_position.y):
		player_camera.position.y = _base_camera_position.y
		return

	player_camera.position.y = move_toward(
		player_camera.position.y,
		_base_camera_position.y,
		step_delta
	)

	if absf(player_camera.position.y - _base_camera_position.y) < 0.05:
		player_camera.position = _base_camera_position


func _reset_step_visual_offset() -> void:
	if visuals != null:
		visuals.position.y = 0.0

	if player_camera != null:
		player_camera.position = _base_camera_position
