extends Area2D

@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var shooter: Node = null
var is_exploding: bool = false

var hit_data: Dictionary = {
	"damage": 10,
	"is_crit": false,
	"source": null
}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if animated_sprite.sprite_frames.has_animation("moving"):
		animated_sprite.play("moving")

func setup(dir: Vector2, new_speed: float, new_shooter: Node, new_hit_data: Dictionary, new_lifetime: float = 2.0) -> void:
	direction = dir.normalized()
	speed = new_speed
	shooter = new_shooter
	lifetime = new_lifetime
	hit_data = new_hit_data.duplicate(true)
	rotation = direction.angle()

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

	if area == shooter:
		return

	# Schaden läuft über Hurtbox.
	# Explosion passiert danach über on_hit_enemy().

func _explode() -> void:
	if is_exploding:
		return

	is_exploding = true
	speed = 0.0
	direction = Vector2.ZERO

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if animated_sprite.sprite_frames.has_animation("explode"):
		animated_sprite.play("explode")
	else:
		queue_free()

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "explode":
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
