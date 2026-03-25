extends CharacterBody2D


@export var move_speed: float = 220.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -360.0
@export var gravity: float = 1000.0
@export var max_fall_speed: float = 900.0
@export var wand_angle_offset_degrees: float = 0.0
@export var wand_pivot_right_position: Vector2 = Vector2(4, -4)
@export var wand_pivot_left_position: Vector2 = Vector2(-4, -4)

@onready var wand_pivot: Node2D = $WandPivot
@onready var wand: Node2D = $WandPivot/Wand
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hud = get_tree().get_first_node_in_group("hud")
@onready var inventory: InventoryComponent = $Inventory
@onready var health_component: PlayerHealthComponent = $HealthComponent
@onready var animation_controller: PlayerAnimationController = $AnimationController
@onready var player_inventory: PlayerInventoryComponent = $PlayerInventoryComponent

var is_stopping_run: bool = false
var facing_left: bool = false

var was_on_floor_last_frame: bool = false
var was_running_last_frame: bool = false
var idle_flip_lock_time: float = 0.0

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

	health_component.take_damage(amount, source_position, is_crit)

func _physics_process(delta: float) -> void:
	var raw_input_dir: float = Input.get_axis("move_left", "move_right")
	var input_dir: float = raw_input_dir

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

	if health_component != null:
		if Input.is_action_just_pressed("jump") and is_on_floor() and not health_component.is_hurt and not is_stopping_run:
			velocity.y = jump_velocity

		velocity += health_component.knockback_velocity
		health_component.knockback_velocity = health_component.knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	else:
		if Input.is_action_just_pressed("jump") and is_on_floor() and not is_stopping_run:
			velocity.y = jump_velocity

	move_and_slide()

	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0

	if animation_controller != null:
		animation_controller.update_animation(input_dir, was_on_floor_last_frame, was_running_last_frame)

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
