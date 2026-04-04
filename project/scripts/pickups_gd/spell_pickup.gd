extends Area2D
class_name SpellPickup

@export var spell_data: SpellData
@export var target_icon_size: Vector2 = Vector2(18, 18)

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D
@onready var flash_sprite: Sprite2D = $VisualRoot/FlashSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var player_in_range: Node = null

func _ready() -> void:
	update_visual()

	if animation_player != null and animation_player.has_animation("idle_flash"):
		animation_player.play("idle_flash")

func set_spell_data(new_spell_data: SpellData) -> void:
	spell_data = new_spell_data
	update_visual()

func update_visual() -> void:
	if sprite == null:
		return

	if spell_data != null and spell_data.icon != null:
		sprite.texture = spell_data.icon
		_fit_sprite_to_target_size(sprite)

		if flash_sprite != null:
			flash_sprite.texture = spell_data.icon
			_fit_sprite_to_target_size(flash_sprite)
	else:
		sprite.texture = null
		sprite.scale = Vector2.ONE

		if flash_sprite != null:
			flash_sprite.texture = null
			flash_sprite.scale = Vector2.ONE

func _fit_sprite_to_target_size(target_sprite: Sprite2D) -> void:
	if target_sprite == null:
		return

	var tex: Texture2D = target_sprite.texture
	if tex == null:
		target_sprite.scale = Vector2.ONE
		return

	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		target_sprite.scale = Vector2.ONE
		return

	var scale_x: float = target_icon_size.x / tex_size.x
	var scale_y: float = target_icon_size.y / tex_size.y
	var uniform_scale: float = minf(scale_x, scale_y)

	target_sprite.scale = Vector2(uniform_scale, uniform_scale)

func _process(_delta: float) -> void:
	if player_in_range == null:
		return

	if spell_data == null:
		return

	if Input.is_action_just_pressed("interact"):
		if player_in_range.has_method("add_spell_to_inventory"):
			var added: bool = player_in_range.add_spell_to_inventory(spell_data)
			if added:
				queue_free()
			else:
				print("Pickup nicht aufgenommen: Inventar ist voll.")

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = body

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null
