extends Node2D

@export var wand_data: WandData

@onready var muzzle: Marker2D = $Muzzle

var current_mana: float = 0.0
var cast_cooldown: float = 0.0
var recharge_cooldown: float = 0.0
var slot_index: int = 0
var trigger_held: bool = false
var actor_owner: Node = null

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

	if wand_data == null:
		return

	current_mana = wand_data.mana_max

func _process(delta: float) -> void:
	if wand_data == null:
		return

	current_mana = min(current_mana + wand_data.mana_regen * delta, wand_data.mana_max)

	if cast_cooldown > 0.0:
		cast_cooldown = max(cast_cooldown - delta, 0.0)

	if recharge_cooldown > 0.0:
		recharge_cooldown = max(recharge_cooldown - delta, 0.0)

	if trigger_held:
		try_cast()

func set_trigger_held(held: bool) -> void:
	trigger_held = held

func set_actor_owner(new_owner: Node) -> void:
	actor_owner = new_owner

func try_cast() -> void:
	if wand_data == null:
		return
	if cast_cooldown > 0.0:
		return
	if recharge_cooldown > 0.0:
		return
	if wand_data.spell_slots.is_empty():
		return

	if slot_index < 0 or slot_index >= wand_data.spell_slots.size():
		slot_index = 0

	var spell: SpellData = wand_data.spell_slots[slot_index]
	if spell == null:
		_advance_slot()
		return

	if current_mana < spell.mana_cost:
		return

	current_mana -= spell.mana_cost
	cast_cooldown = wand_data.cast_delay + spell.cast_delay_add

	_cast_spell(spell)
	_advance_slot()

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
			var t: float = float(i) / float(count - 1)
			var angle_offset: float = lerp(-spread_rad * 0.5, spread_rad * 0.5, t)
			direction = direction.rotated(angle_offset)

		projectile.global_rotation = direction.angle()

		var hit_data := _build_hit_data(spell)

		if projectile.has_method("setup"):
			projectile.setup(direction, spell.speed, actor_owner, hit_data, spell.lifetime)

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

func _advance_slot() -> void:
	slot_index += 1

	if slot_index >= wand_data.spell_slots.size():
		slot_index = 0
		recharge_cooldown = wand_data.recharge_time
