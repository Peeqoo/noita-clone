extends Area2D

@export_file("*.tscn") var next_scene_path: String
@export var target_spawn_name: String = "PlayerSpawn"

var is_transitioning := false

func _on_body_entered(body: Node) -> void:
	if is_transitioning:
		return
	if body != GameManager.player:
		return
	if next_scene_path.is_empty():
		push_warning("ExitToDungeon: next_scene_path is empty.")
		return

	is_transitioning = true
	GameManager.change_level(next_scene_path, target_spawn_name)
