extends Node

var player_scene: PackedScene = preload("res://project/scenes/player_tscn/player_02.tscn")

var player: Node2D = null
var current_spawn_name: String = "PlayerSpawn"
var fade_rect: ColorRect = null

func _ready() -> void:
	call_deferred("_place_player_after_start")

func _place_player_after_start() -> void:
	place_player_in_current_scene(current_spawn_name)

func ensure_player_exists() -> void:
	if player == null:
		player = player_scene.instantiate() as Node2D
		player.name = "Player"

func set_fade_rect(node: ColorRect) -> void:
	fade_rect = node

func place_player_in_current_scene(spawn_name: String = "PlayerSpawn") -> void:
	ensure_player_exists()

	var scene := get_tree().current_scene
	if scene == null:
		push_warning("GameManager: current_scene is null.")
		return

	var spawn := _find_spawn(scene, spawn_name)

	if spawn == null:
		push_warning("GameManager: Spawn '%s' not found in scene '%s'." % [spawn_name, scene.name])

		if player.get_parent() != scene:
			if player.get_parent():
				player.get_parent().remove_child(player)
			scene.add_child(player)
		return

	if player.get_parent() != scene:
		if player.get_parent():
			player.get_parent().remove_child(player)
		scene.add_child(player)

	player.global_position = spawn.global_position

func _find_spawn(scene: Node, spawn_name: String) -> Marker2D:
	var direct_spawn := scene.get_node_or_null(spawn_name) as Marker2D
	if direct_spawn != null:
		return direct_spawn

	var recursive_spawn := scene.find_child(spawn_name, true, false) as Marker2D
	if recursive_spawn != null:
		return recursive_spawn

	return null

func fade_out(duration: float = 0.6) -> void:
	if fade_rect == null:
		push_warning("GameManager: fade_rect is null in fade_out")
		return

	var c := fade_rect.modulate
	c.a = 0.0
	fade_rect.modulate = c

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.6) -> void:
	if fade_rect == null:
		push_warning("GameManager: fade_rect is null in fade_in")
		return

	var c := fade_rect.modulate
	c.a = 1.0
	fade_rect.modulate = c

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	await tween.finished

func change_level(scene_path: String, spawn_name: String = "PlayerSpawn") -> void:
	current_spawn_name = spawn_name
	call_deferred("_change_level_deferred", scene_path)

func _change_level_deferred(scene_path: String) -> void:
	ensure_player_exists()

	await fade_out(0.6)

	if player.get_parent():
		player.get_parent().remove_child(player)

	get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	place_player_in_current_scene(current_spawn_name)

	await get_tree().process_frame

	await fade_in(0.6)
