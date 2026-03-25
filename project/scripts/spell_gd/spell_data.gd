extends Resource
class_name SpellData

@export var display_name: String = "Spell Name"
@export var icon: Texture2D

@export_group("Cast")
@export var mana_cost: float = 5.0
@export var cast_delay_add: float = 0.0

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0
@export var speed: float = 600.0
@export var lifetime: float = 2.0

@export_group("Damage")
@export var damage: int = 10
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.10
@export var crit_multiplier: float = 1.5
