extends Node

@export var player_path: NodePath
@export var enemies_parent_path: NodePath
@export var basic_enemy_scene: PackedScene

@export var start_spawn_interval: float = 2.5
@export var min_spawn_interval: float = 0.8
@export var difficulty_ramp: float = 0.03
@export var max_alive_enemies: int = 6
@export var spawn_distance_x: float = 900.0

var player: Node2D
var enemies_parent: Node2D

var spawn_timer: float = 0.0
var run_time: float = 0.0
var current_spawn_interval: float

func _ready() -> void:
	player = get_node(player_path)
	enemies_parent = get_node(enemies_parent_path)

	current_spawn_interval = start_spawn_interval
	randomize()

func _process(delta: float) -> void:
	run_time += delta

	# Schwierigkeit steigt (spawn wird schneller)
	current_spawn_interval = max(
		min_spawn_interval,
		start_spawn_interval - run_time * difficulty_ramp
	)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_try_spawn_wave()
		spawn_timer = current_spawn_interval

func _try_spawn_wave() -> void:
	if basic_enemy_scene == null:
		return

	if enemies_parent.get_child_count() >= max_alive_enemies:
		return

	var alive := enemies_parent.get_child_count()

	# kleine escalation
	var wave_size := 1
	if run_time > 20.0:
		wave_size = 2
	if run_time > 45.0:
		wave_size = 3

	wave_size = min(wave_size, max_alive_enemies - alive)

	for i in range(wave_size):
		_spawn_enemy()

func _spawn_enemy() -> void:
	var enemy := basic_enemy_scene.instantiate() as Node2D
	enemies_parent.add_child(enemy)

	var side := -1 if randi() % 2 == 0 else 1

	var x := player.global_position.x + side * spawn_distance_x
	var y := player.global_position.y

	enemy.global_position = Vector2(x, y)
