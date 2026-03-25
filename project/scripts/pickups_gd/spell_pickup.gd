extends Area2D
class_name SpellPickup

@export var spell_data: SpellData
@onready var sprite: Sprite2D = $Sprite2D

var player_in_range: Node = null

func _ready() -> void:
	update_visual()

func update_visual() -> void:
	if spell_data != null and spell_data.icon != null:
		sprite.texture = spell_data.icon

func _process(_delta: float) -> void:
	if player_in_range == null:
		return

	if Input.is_action_just_pressed("interact"):
		if player_in_range.has_method("add_spell_to_inventory"):
			var added: bool = player_in_range.add_spell_to_inventory(spell_data)
			if added:
				queue_free()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = body

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null
