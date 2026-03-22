extends CharacterBody2D

@export var max_health: int = 100
@export var move_speed: float = 220.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -360.0
@export var gravity: float = 1000.0
@export var max_fall_speed: float = 900.0
@export var wand_angle_offset_degrees: float = 0.0
@export var wand_pivot_right_position: Vector2 = Vector2(4, -4)
@export var wand_pivot_left_position: Vector2 = Vector2(-4, -4)
@export var invincibility_time: float = 0.4
@export var knockback_force_x: float = 80.0
@export var knockback_force_y: float = -30.0

@onready var wand_pivot: Node2D = $WandPivot
@onready var wand: Node2D = $WandPivot/Wand
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hud = get_tree().get_first_node_in_group("hud")
@export var damage_number_scene: PackedScene
@export var crit_damage_number_scene: PackedScene
@export var damage_number_offset: Vector2 = Vector2(0, -40)

var health: int
var is_hurt: bool = false
var is_dead: bool = false
var is_stopping_run: bool = false
var facing_left: bool = false
var is_invincible: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

var was_on_floor_last_frame: bool = false
var was_running_last_frame: bool = false
var idle_flip_lock_time: float = 0.0

func _ready() -> void:
	health = max_health
	animated_sprite.play("idle")
	was_on_floor_last_frame = is_on_floor()
	_update_wand_pivot_position()
	_update_hud()

	if wand.has_method("set_actor_owner"):
		wand.set_actor_owner(self)

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	if is_dead:
		return

	if is_invincible:
		return

	health -= amount
	health = clamp(health, 0, max_health)
	show_damage_number(amount, is_crit)
	print("Player HP:", health)
	_update_hud()

	apply_knockback(source_position)

	if health <= 0:
		play_death()
	else:
		play_hit()
		start_invincibility()
		
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
		randf_range(-4.0, 4.0)
	)

	if is_crit:
		random_offset.y -= 8.0

	number.global_position = global_position + damage_number_offset + random_offset

	if number.has_method("setup"):
		number.setup(amount, is_crit)

func start_invincibility() -> void:
	is_invincible = true

	var blink_time: float = invincibility_time
	var t: float = 0.0

	while t < blink_time:
		animated_sprite.visible = not animated_sprite.visible
		await get_tree().create_timer(0.05).timeout
		t += 0.05

	animated_sprite.visible = true
	is_invincible = false

func apply_knockback(source_position: Vector2) -> void:
	if source_position == Vector2.ZERO:
		return

	var dir_x: float = signf(global_position.x - source_position.x)

	if dir_x == 0.0:
		dir_x = -1.0 if facing_left else 1.0

	knockback_velocity.x = dir_x * knockback_force_x
	knockback_velocity.y = knockback_force_y

func _physics_process(delta: float) -> void:
	var raw_input_dir: float = Input.get_axis("move_left", "move_right")
	var input_dir: float = raw_input_dir

	if is_dead:
		velocity.x = 0.0
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		move_and_slide()

		_update_facing(raw_input_dir)
		_update_wand_pivot_position()
		_update_aim()
		_update_wand_input(false)

		was_on_floor_last_frame = is_on_floor()
		was_running_last_frame = false
		return

	if idle_flip_lock_time > 0.0:
		idle_flip_lock_time -= delta

	if is_stopping_run:
		input_dir = 0.0

	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * move_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_hurt and not is_stopping_run:
		velocity.y = jump_velocity

	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)

	move_and_slide()

	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0

	_update_animation(input_dir)
	_update_facing(raw_input_dir)
	_update_wand_pivot_position()
	_update_aim()
	_update_wand_input(not is_hurt and not is_stopping_run and not is_dead)

	was_on_floor_last_frame = is_on_floor()
	was_running_last_frame = absf(input_dir) > 0.0 and is_on_floor()

func _update_aim() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var dir: Vector2 = mouse_pos - wand_pivot.global_position
	wand_pivot.rotation = dir.angle() + deg_to_rad(wand_angle_offset_degrees)

func _update_wand_input(can_shoot: bool) -> void:
	if wand.has_method("set_trigger_held"):
		wand.set_trigger_held(can_shoot and Input.is_action_pressed("shoot"))

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

func _update_animation(input_dir: float) -> void:
	if is_dead:
		if animated_sprite.animation != "death":
			animated_sprite.play("death")
		return

	if is_hurt:
		if animated_sprite.animation != "hit":
			animated_sprite.play("hit")
		return

	if not is_on_floor():
		if velocity.y < 0.0:
			if animated_sprite.animation != "jump":
				animated_sprite.play("jump")
		else:
			if animated_sprite.animation != "fall":
				animated_sprite.play("fall")
		return

	if not was_on_floor_last_frame and is_on_floor():
		is_stopping_run = false
		idle_flip_lock_time = 0.35

		if absf(input_dir) > 0.0:
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		return

	if is_stopping_run:
		return

	if absf(input_dir) > 0.0:
		if animated_sprite.animation != "run":
			animated_sprite.play("run")
		return

	if was_running_last_frame and absf(input_dir) == 0.0:
		is_stopping_run = true
		if animated_sprite.animation != "stop_run":
			animated_sprite.play("stop_run")
		return

	if animated_sprite.animation != "idle":
		animated_sprite.play("idle")

func _on_animation_finished() -> void:
	if animated_sprite.animation == "stop_run":
		is_stopping_run = false
		animated_sprite.play("idle")
	elif animated_sprite.animation == "hit":
		is_hurt = false
	elif animated_sprite.animation == "death":
		queue_free()

func play_hit() -> void:
	if is_dead:
		return

	is_hurt = true
	is_stopping_run = false
	animated_sprite.play("hit")

func die() -> void:
	play_death()

func play_death() -> void:
	if is_dead:
		return

	is_dead = true
	is_hurt = false
	is_stopping_run = false
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	_update_wand_input(false)
	animated_sprite.play("death")

func _update_hud() -> void:
	if hud == null:
		return

	if hud.has_method("update_health"):
		hud.update_health(health, max_health)

	if hud.has_method("update_spell_selection"):
		hud.update_spell_selection(0)
