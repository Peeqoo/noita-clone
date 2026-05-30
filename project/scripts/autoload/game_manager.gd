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
	if player != null and is_instance_valid(player):
		return

	player = null
	player = player_scene.instantiate() as Node2D
	player.name = "Player"

func get_player() -> Node2D:
	ensure_player_exists()
	return player

func is_player_alive() -> bool:
	return player != null and is_instance_valid(player)

func set_fade_rect(node: ColorRect) -> void:
	fade_rect = node

func place_player_in_current_scene(spawn_name: String = "PlayerSpawn") -> void:
	ensure_player_exists()

	if not is_instance_valid(player):
		push_warning("GameManager: player invalid in place_player_in_current_scene.")
		return

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

	_ensure_player_camera_current()

func handle_player_death() -> void:
	call_deferred("respawn_player_in_current_level")

func respawn_player_in_current_level() -> void:
	ensure_player_exists()

	if not is_instance_valid(player):
		push_warning("GameManager: cannot respawn, player invalid.")
		return

	place_player_in_current_scene(current_spawn_name)

	if player.has_method("respawn_after_death"):
		player.respawn_after_death()

func _find_spawn(scene: Node, spawn_name: String) -> Marker2D:
	var direct_spawn := scene.get_node_or_null(spawn_name) as Marker2D
	if direct_spawn != null:
		return direct_spawn

	var recursive_spawn := scene.find_child(spawn_name, true, false) as Marker2D
	if recursive_spawn != null:
		return recursive_spawn

	return null

func _ensure_player_camera_current() -> void:
	if not is_instance_valid(player):
		return

	var camera := player.get_node_or_null("PlayerCamera") as Camera2D
	if camera != null:
		camera.make_current()

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

	if is_instance_valid(player) and player.get_parent():
		player.get_parent().remove_child(player)

	get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	place_player_in_current_scene(current_spawn_name)
	_reset_player_state_after_scene_change()

	await get_tree().process_frame
	await fade_in(0.6)

func reload_current_level() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_warning("GameManager: current_scene is null in reload_current_level")
		return

	var scene_path := current_scene.scene_file_path
	if scene_path.is_empty():
		push_warning("GameManager: scene_file_path is empty in reload_current_level")
		return

	call_deferred("_reload_current_level_deferred", scene_path)

func _reload_current_level_deferred(scene_path: String) -> void:
	ensure_player_exists()

	if is_instance_valid(player) and player.get_parent():
		player.get_parent().remove_child(player)

	get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	place_player_in_current_scene(current_spawn_name)
	_reset_player_state_after_scene_change()

func _is_player_dead() -> bool:
	if not is_instance_valid(player):
		return false

	if player.has_method("is_dead"):
		return player.is_dead()

	return false

func _reset_player_state_after_scene_change() -> void:
	if not is_instance_valid(player):
		return

	if _is_player_dead():
		if player.has_method("respawn_after_death"):
			player.respawn_after_death()
	elif player.has_method("stabilize_after_scene_change"):
		player.stabilize_after_scene_change()
