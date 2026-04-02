extends Area2D

@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var shooter: Node = null
var is_exploding: bool = false
var spell_data: SpellData = null

var hit_data: Dictionary = {
	"damage": 10,
	"is_crit": false,
	"source": null
}

@onready var moving_sprite: AnimatedSprite2D = $MovingSprite
@onready var explode_sprite: AnimatedSprite2D = $ExplodeSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var shoot_player: AudioStreamPlayer2D = $ShootPlayer
@onready var impact_player: AudioStreamPlayer2D = $ImpactPlayer

func _ready() -> void:
	moving_sprite.visible = true
	explode_sprite.visible = false

	if moving_sprite.sprite_frames.has_animation("moving"):
		moving_sprite.play("moving")

func setup(
	dir: Vector2,
	new_speed: float,
	new_shooter: Node,
	new_hit_data: Dictionary,
	new_lifetime: float = 2.0,
	new_spell_data: SpellData = null
) -> void:
	direction = dir.normalized()
	speed = new_speed
	shooter = new_shooter
	lifetime = new_lifetime
	hit_data = new_hit_data.duplicate(true)
	spell_data = new_spell_data
	rotation = direction.angle()

	_play_shoot_sound()

func _physics_process(delta: float) -> void:
	if is_exploding:
		return

	global_position += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func get_hit_data() -> Dictionary:
	return hit_data.duplicate(true)

func get_damage() -> int:
	return int(hit_data.get("damage", 0))

func is_critical_hit() -> bool:
	return bool(hit_data.get("is_crit", false))

func on_hit_enemy() -> void:
	_explode()

func _on_body_entered(body: Node) -> void:
	if is_exploding:
		return

	if body == shooter:
		return

	_explode()

func _on_area_entered(area: Area2D) -> void:
	if is_exploding:
		return

	if area == null:
		return

	if area == shooter:
		return

	if shooter != null and area.get_parent() == shooter:
		return

	_explode()

func _explode() -> void:
	if is_exploding:
		return

	is_exploding = true
	speed = 0.0
	direction = Vector2.ZERO

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	_play_impact_sound()

	moving_sprite.visible = false
	explode_sprite.visible = true

	if explode_sprite.sprite_frames.has_animation("explode"):
		explode_sprite.play("explode")
	else:
		if impact_player != null and impact_player.playing:
			await impact_player.finished
		queue_free()

func _play_shoot_sound() -> void:
	if spell_data == null:
		return
	if spell_data.shoot_sound == null:
		return
	if shoot_player == null:
		return

	shoot_player.stream = spell_data.shoot_sound
	shoot_player.pitch_scale = randf_range(0.97, 1.03)
	shoot_player.volume_db = 0.0
	shoot_player.play()

func _play_impact_sound() -> void:
	if spell_data == null:
		return
	if spell_data.impact_sound == null:
		return
	if impact_player == null:
		return

	impact_player.stream = spell_data.impact_sound
	impact_player.pitch_scale = randf_range(0.97, 1.03)
	impact_player.volume_db = 0.0
	impact_player.play()

func _on_explode_sprite_animation_finished() -> void:
	if explode_sprite.animation != "explode":
		return

	if impact_player != null and impact_player.playing:
		await impact_player.finished

	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
