extends Area2D

@export var owner_enemy: EnemyBase

func _ready() -> void:
	if owner_enemy == null:
		var parent := get_parent()
		if parent is EnemyBase:
			owner_enemy = parent

func _on_area_entered(area: Area2D) -> void:
	if owner_enemy == null:
		return

	if not is_instance_valid(owner_enemy):
		return

	if area.has_method("get_hit_data"):
		var hit_data: Dictionary = area.get_hit_data()

		if area is Node2D:
			hit_data["source_position"] = area.global_position

		owner_enemy.take_hit(hit_data)

		if area.has_method("on_hit_enemy"):
			area.on_hit_enemy()
		return

	if area.has_method("get_damage"):
		var damage: int = int(area.get_damage())
		var source_position: Vector2 = area.global_position if area is Node2D else owner_enemy.global_position

		owner_enemy.take_damage(damage, false, source_position)

		if area.has_method("on_hit_enemy"):
			area.on_hit_enemy()
