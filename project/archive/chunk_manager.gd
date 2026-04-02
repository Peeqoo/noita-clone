extends Node

@export var chunk_parent_path: NodePath
@export var player_path: NodePath
@export var chunk_scenes: Array[PackedScene] = []
@export var initial_chunks: int = 3
@export var spawn_threshold: float = 2500.0
@export var delete_distance: float = 5000.0

var chunk_parent: Node2D
var player: Node2D
var active_chunks: Array[Node2D] = []
var next_spawn_x: float = 0.0

func _ready() -> void:
	chunk_parent = get_node(chunk_parent_path)
	player = get_node(player_path)

	randomize()

	for i in range(initial_chunks):
		_spawn_next_chunk()

func _process(_delta: float) -> void:
	if player.global_position.x + spawn_threshold > next_spawn_x:
		_spawn_next_chunk()

	_cleanup_old_chunks()

func _spawn_next_chunk() -> void:
	if chunk_scenes.is_empty():
		push_warning("ChunkManager: No chunk scenes assigned.")
		return

	var scene: PackedScene = chunk_scenes[randi() % chunk_scenes.size()]
	var chunk := scene.instantiate() as Node2D

	chunk_parent.add_child(chunk)
	chunk.global_position = Vector2(next_spawn_x, 0)
	active_chunks.append(chunk)

	var end_marker := chunk.get_node_or_null("EndMarker") as Marker2D
	if end_marker == null:
		push_warning("ChunkManager: Chunk has no EndMarker: " + chunk.name)
		next_spawn_x += 2304.0
		return

	next_spawn_x = end_marker.global_position.x

func _cleanup_old_chunks() -> void:
	for i in range(active_chunks.size() - 1, -1, -1):
		var chunk := active_chunks[i]
		var chunk_end := chunk.get_node_or_null("EndMarker") as Marker2D
		if chunk_end == null:
			continue

		if player.global_position.x - chunk_end.global_position.x > delete_distance:
			active_chunks.remove_at(i)
			chunk.queue_free()
