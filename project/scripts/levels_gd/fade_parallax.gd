extends Parallax2D

@onready var forest_ground: Sprite2D = $ForestNNG
@onready var forest_krone: Sprite2D = $ForestKroneNNG

@export var normal_alpha: float = 1.0
@export var faded_alpha_ground: float = 0.65
@export var faded_alpha_krone: float = 0.45
@export var fade_in_speed: float = 6.0
@export var fade_out_speed: float = 3.0

var inside_ground := 0
var inside_krone := 0

var target_alpha_ground := 1.0
var target_alpha_krone := 1.0

func _process(delta: float) -> void:
	_update_fade(forest_ground, target_alpha_ground, delta)
	_update_fade(forest_krone, target_alpha_krone, delta)

func _update_fade(sprite: CanvasItem, target_alpha: float, delta: float) -> void:
	if sprite == null:
		return

	var c := sprite.modulate
	var speed := fade_in_speed if c.a > target_alpha else fade_out_speed
	c.a = move_toward(c.a, target_alpha, speed * delta)
	sprite.modulate = c

func _on_fade_area_ground_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		inside_ground += 1
		target_alpha_ground = faded_alpha_ground

func _on_fade_area_ground_body_exited(body: Node) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		inside_ground = max(0, inside_ground - 1)
		if inside_ground == 0:
			target_alpha_ground = normal_alpha

func _on_fade_area_krone_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		inside_krone += 1
		target_alpha_krone = faded_alpha_krone

func _on_fade_area_krone_body_exited(body: Node) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		inside_krone = max(0, inside_krone - 1)
		if inside_krone == 0:
			target_alpha_krone = normal_alpha
