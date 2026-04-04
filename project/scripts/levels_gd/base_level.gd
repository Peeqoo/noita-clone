extends Node2D

@export var fade_rect_path: NodePath = ^"CanvasLayer/FadeRect"
@export var default_spawn_name: String = "PlayerSpawn"

@export var camera_room_offset: Vector2 = Vector2.ZERO

@export var camera_limit_left: int = -100000
@export var camera_limit_top: int = -100000
@export var camera_limit_right: int = 100000
@export var camera_limit_bottom: int = 100000

@onready var fade_rect: ColorRect = get_node_or_null(fade_rect_path) as ColorRect


func _ready() -> void:
	if fade_rect == null:
		push_warning("BaseLevel: FadeRect not found at path: %s" % fade_rect_path)
	else:
		GameManager.set_fade_rect(fade_rect)

	GameManager.place_player_in_current_scene(default_spawn_name)
	call_deferred("_apply_camera_settings")


func _apply_camera_settings() -> void:
	var player := get_node_or_null("Player")
	if player == null:
		player = find_child("Player", true, false)

	if player == null:
		push_warning("BaseLevel: Player not found after spawn.")
		return

	var camera := player.get_node_or_null("PlayerCamera") as Camera2D
	if camera == null:
		push_warning("BaseLevel: PlayerCamera not found on Player.")
		return

	camera.set_room_offset(camera_room_offset)

	camera.limit_enabled = true
	camera.limit_left = camera_limit_left
	camera.limit_top = camera_limit_top
	camera.limit_right = camera_limit_right
	camera.limit_bottom = camera_limit_bottom
