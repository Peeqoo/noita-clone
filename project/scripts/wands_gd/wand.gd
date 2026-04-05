extends Node2D

@export var wand_data: WandData

@export_group("Mana Visual Feedback")
@export_range(0.0, 1.0, 0.01) var low_mana_start_ratio: float = 0.35
@export_range(0.0, 1.0, 0.01) var critical_mana_ratio: float = 0.12
@export var blink_speed_slow: float = 3.0
@export var blink_speed_fast: float = 10.0
@export_range(0.0, 1.0, 0.01) var low_mana_flash_alpha: float = 0.08
@export_range(0.0, 1.0, 0.01) var critical_mana_flash_alpha: float = 0.22
@export var empty_flash_duration: float = 0.12
@export_range(0.0, 1.0, 0.01) var empty_flash_alpha: float = 0.35

@onready var muzzle: Marker2D = $Muzzle
@onready var flash_sprite: Sprite2D = $Visuals/FlashSprite
@onready var hud = get_tree().get_first_node_in_group("hud")

var current_mana: float = 0.0
var cast_cooldown: float = 0.0
var recharge_cooldown: float = 0.0
var current_spell_index: int = 0
var spells_cast_in_cycle: int = 0
var trigger_held: bool = false
var input_enabled: bool = true
var actor_owner: Node = null

var empty_flash_timer: float = 0.0
var blink_time: float = 0.0

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

	if flash_sprite != null:
		flash_sprite.modulate = Color(1, 1, 1, 0)

	if wand_data == null:
		return

	current_mana = wand_data.mana_max
	_update_hud_mana()
	_update_hud_spell()
	_update_mana_visual(0.0)

func _process(delta: float) -> void:
	if wand_data == null:
		return

	if input_enabled:
		trigger_held = Input.is_action_pressed("shoot")
	else:
		trigger_held = false

	var old_mana: float = current_mana
	current_mana = min(current_mana + wand_data.mana_regen * delta, wand_data.mana_max)

	if current_mana != old_mana:
		_update_hud_mana()

	if cast_cooldown > 0.0:
		cast_cooldown = max(cast_cooldown - delta, 0.0)

	if recharge_cooldown > 0.0:
		recharge_cooldown = max(recharge_cooldown - delta, 0.0)

	if empty_flash_timer > 0.0:
		empty_flash_timer = max(empty_flash_timer - delta, 0.0)

	if trigger_held:
		try_cast()

	_update_mana_visual(delta)

func set_trigger_held(held: bool) -> void:
	trigger_held = held

func set_actor_owner(new_owner: Node) -> void:
	actor_owner = new_owner

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not input_enabled:
		trigger_held = false

func try_cast() -> void:
	if wand_data == null:
		return
	if cast_cooldown > 0.0:
		return
	if recharge_cooldown > 0.0:
		return
	if wand_data.spell_slots.is_empty():
		return

	var spell: SpellData = _get_current_spell()
	if spell == null:
		return

	if current_mana < spell.mana_cost:
		_trigger_empty_mana_flash()
		return

	current_mana -= spell.mana_cost
	_update_hud_mana()

	cast_cooldown = wand_data.cast_delay + spell.cast_delay_add

	_cast_spell(spell)

	spells_cast_in_cycle += 1

	if spells_cast_in_cycle >= _get_spell_count():
		_start_recharge()
	else:
		_advance_spell_index()

	_update_hud_spell()

func _get_current_spell() -> SpellData:
	if wand_data == null:
		return null

	if wand_data.spell_slots.is_empty():
		return null

	if current_spell_index < 0 or current_spell_index >= wand_data.spell_slots.size():
		current_spell_index = 0

	var tries: int = 0

	while tries < wand_data.spell_slots.size():
		var spell: SpellData = wand_data.spell_slots[current_spell_index]
		if spell != null:
			return spell

		current_spell_index += 1
		if current_spell_index >= wand_data.spell_slots.size():
			current_spell_index = 0

		tries += 1

	return null

func _advance_spell_index() -> void:
	if wand_data == null:
		return

	if wand_data.spell_slots.is_empty():
		current_spell_index = 0
		return

	var tries: int = 0

	while tries < wand_data.spell_slots.size():
		current_spell_index += 1

		if current_spell_index >= wand_data.spell_slots.size():
			current_spell_index = 0

		if wand_data.spell_slots[current_spell_index] != null:
			return

		tries += 1

	current_spell_index = 0

func _get_spell_count() -> int:
	if wand_data == null:
		return 0

	var count: int = 0
	for spell in wand_data.spell_slots:
		if spell != null:
			count += 1

	return count

func _start_recharge() -> void:
	recharge_cooldown = wand_data.recharge_time
	spells_cast_in_cycle = 0
	current_spell_index = 0

func _cast_spell(spell: SpellData) -> void:
	if spell.projectile_scene == null:
		return

	var count: int = max(spell.projectile_count, 1)
	var spread_rad: float = deg_to_rad(spell.spread_degrees)

	for i: int in range(count):
		var projectile: Node2D = spell.projectile_scene.instantiate() as Node2D
		if projectile == null:
			continue

		get_tree().current_scene.add_child(projectile)
		projectile.global_position = muzzle.global_position

		var direction: Vector2 = muzzle.global_transform.x.normalized()

		if count > 1:
			var t: float = 0.5
			if count > 1:
				t = float(i) / float(count - 1)
			var angle_offset: float = lerp(-spread_rad * 0.5, spread_rad * 0.5, t)
			direction = direction.rotated(angle_offset)

		projectile.global_rotation = direction.angle()

		var hit_data := _build_hit_data(spell)

		if projectile.has_method("setup"):
			projectile.setup(direction, spell.speed, actor_owner, hit_data, spell.lifetime, spell)

func _build_hit_data(spell: SpellData) -> Dictionary:
	var final_damage: int = maxi(1, int(round(spell.damage * wand_data.damage_multiplier)))

	var final_crit_chance: float = clamp(spell.crit_chance + wand_data.crit_chance_bonus, 0.0, 1.0)
	var final_crit_multiplier: float = maxf(1.0, spell.crit_multiplier + wand_data.crit_multiplier_bonus)

	var is_crit: bool = rng.randf() <= final_crit_chance
	if is_crit:
		final_damage = maxi(1, int(round(final_damage * final_crit_multiplier)))

	return {
		"damage": final_damage,
		"is_crit": is_crit,
		"source": actor_owner
	}

func get_spell_in_slot(slot: int) -> SpellData:
	if wand_data == null:
		return null
	if slot < 0 or slot >= wand_data.spell_slots.size():
		return null
	return wand_data.spell_slots[slot]

func set_spell_in_slot(slot: int, spell: SpellData) -> bool:
	if wand_data == null:
		return false
	if slot < 0 or slot >= wand_data.spell_slots.size():
		return false

	wand_data.spell_slots[slot] = spell

	if current_spell_index < 0 or current_spell_index >= wand_data.spell_slots.size():
		current_spell_index = 0

	_update_hud_spell()
	return true

func remove_spell_from_slot(slot: int) -> SpellData:
	if wand_data == null:
		return null
	if slot < 0 or slot >= wand_data.spell_slots.size():
		return null

	var spell: SpellData = wand_data.spell_slots[slot]
	wand_data.spell_slots[slot] = null

	if current_spell_index >= wand_data.spell_slots.size():
		current_spell_index = 0

	_update_hud_spell()
	return spell

func reset_spell_cycle() -> void:
	current_spell_index = 0
	spells_cast_in_cycle = 0
	_update_hud_spell()

func _update_hud_mana() -> void:
	if hud == null or not is_instance_valid(hud):
		hud = get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("update_mana") and wand_data != null:
		hud.update_mana(current_mana, wand_data.mana_max)

func _update_hud_spell() -> void:
	if hud == null or not is_instance_valid(hud):
		hud = get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("update_spell_selection"):
		hud.update_spell_selection(current_spell_index)

func _trigger_empty_mana_flash() -> void:
	empty_flash_timer = empty_flash_duration

func _update_mana_visual(delta: float) -> void:
	if flash_sprite == null or wand_data == null or wand_data.mana_max <= 0.0:
		return

	if empty_flash_timer > 0.0:
		flash_sprite.modulate.a = empty_flash_alpha
		return

	var mana_ratio: float = current_mana / wand_data.mana_max

	if mana_ratio <= critical_mana_ratio:
		blink_time += delta * blink_speed_fast
		flash_sprite.modulate.a = (sin(blink_time) * 0.5 + 0.5) * critical_mana_flash_alpha
	elif mana_ratio <= low_mana_start_ratio:
		blink_time += delta * blink_speed_slow
		flash_sprite.modulate.a = (sin(blink_time) * 0.5 + 0.5) * low_mana_flash_alpha
	else:
		blink_time = 0.0
		flash_sprite.modulate.a = 0.0
