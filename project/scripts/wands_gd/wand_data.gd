extends Resource
class_name WandData

@export var display_name: String = "Wand Name"

@export_group("Mana")
@export var mana_max: float = 100.0
@export var mana_regen: float = 20.0

@export_group("Timing")
@export var cast_delay: float = 0.18
@export var recharge_time: float = 0.5
@export var shuffle: bool = false

@export_group("Modifiers")
@export var damage_multiplier: float = 1.0
@export var crit_chance_bonus: float = 0.0
@export var crit_multiplier_bonus: float = 0.0

@export_group("Spells")
@export var spell_slots: Array[SpellData] = []
