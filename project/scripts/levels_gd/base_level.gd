extends Node2D

@export var fade_rect_path: NodePath = ^"CanvasLayer/FadeRect"
@export var default_spawn_name: String = "PlayerSpawn"

@onready var fade_rect: ColorRect = get_node_or_null(fade_rect_path) as ColorRect

func _ready() -> void:
	if fade_rect == null:
		push_warning("BaseLevel: FadeRect not found at path: %s" % fade_rect_path)
	else:
		print("FadeRect path:", fade_rect_path)
		print("FadeRect node:", fade_rect)
		GameManager.set_fade_rect(fade_rect)

	GameManager.place_player_in_current_scene(default_spawn_name)
