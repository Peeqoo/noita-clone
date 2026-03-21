extends Area2D

@export var owner_enemy: EnemyBase

func _on_area_entered(area: Area2D) -> void:
	if owner_enemy == null:
		return

	if not is_instance_valid(owner_enemy):
		return

	if area.has_method("get_hit_data"):
		var hit_data: Dictionary = area.get_hit_data()
		owner_enemy.take_hit(hit_data)

		if area.has_method("on_hit_enemy"):
			area.on_hit_enemy()
		return

	# Fallback für alte Projectiles / ältere Tests
	if area.has_method("get_damage"):
		var damage: int = int(area.get_damage())
		owner_enemy.take_damage(damage, false)

		if area.has_method("on_hit_enemy"):
			area.on_hit_enemy()
