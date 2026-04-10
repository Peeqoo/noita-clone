@tool
extends Node2D

@export_group("References")
@export var solid_layer: TileMapLayer
@export var player_spawn_marker: Marker2D
@export var exit_spawn_marker: Marker2D

@export_group("Generation")
@export var generate_on_ready: bool = false
@export var use_random_seed: bool = false
@export var fixed_seed: int = 1001

@export_group("Map Size")
@export var map_width: int = 180
@export var map_height: int = 72
@export var border_size: int = 2

@export_group("Main Route")
@export var main_room_count: int = 6
@export var route_vertical_jitter: int = 10
@export var main_room_radius_x_min: int = 7
@export var main_room_radius_x_max: int = 13
@export var main_room_radius_y_min: int = 5
@export var main_room_radius_y_max: int = 9

@export_group("Side Rooms")
@export var side_room_count: int = 3
@export var side_room_offset_x_min: int = 10
@export var side_room_offset_x_max: int = 20
@export var side_room_offset_y_min: int = 10
@export var side_room_offset_y_max: int = 18
@export var side_room_radius_x_min: int = 4
@export var side_room_radius_x_max: int = 8
@export var side_room_radius_y_min: int = 3
@export var side_room_radius_y_max: int = 6

@export_group("Corridors")
@export var corridor_radius: int = 2
@export_range(0.0, 1.0, 0.01) var corridor_wobble: float = 0.18

@export_group("Smoothing")
@export var smoothing_passes: int = 2
@export_range(0, 8, 1) var solid_if_neighbor_count_at_least: int = 5

@export_group("Painting")
@export var use_terrain_connect: bool = true
@export var terrain_set_id: int = 0
@export var solid_terrain_id: int = 0
@export var fallback_source_id: int = 0
@export var fallback_atlas_coords: Vector2i = Vector2i.ZERO
@export var fallback_alternative_tile: int = 0

@export var use_better_terrain: bool = true
@export var better_terrain_type: int = 0

@export_tool_button("Generate Cave Level") var generate_level_button := _generate_level_from_button
@export_tool_button("Clear Cave Level") var clear_level_button := _clear_level_from_button

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _grid: Array[PackedByteArray] = []

# 1 = solid, 0 = open

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if generate_on_ready:
		generate_level()


func _generate_level_from_button() -> void:
	generate_level()


func _clear_level_from_button() -> void:
	clear_level()


func clear_level() -> void:
	if solid_layer == null:
		push_error("level_cave.gd: solid_layer is missing.")
		return

	solid_layer.clear()
	solid_layer.update_internals()


func generate_level() -> void:
	if solid_layer == null:
		push_error("level_cave.gd: solid_layer is missing.")
		return

	_setup_rng()
	_create_filled_grid()

	var main_rooms: Array[Dictionary] = _create_main_rooms()
	var side_rooms: Array[Dictionary] = _create_side_rooms(main_rooms)

	_connect_main_rooms(main_rooms)
	_connect_side_rooms(side_rooms)

	for i in range(smoothing_passes):
		_smooth_map()

	_recarve_rooms(main_rooms)
	_recarve_rooms(side_rooms)
	_connect_main_rooms(main_rooms)
	_connect_side_rooms(side_rooms)

	var start_center: Vector2i = main_rooms.front()["center"]
	var exit_center: Vector2i = main_rooms.back()["center"]

	_force_connection_if_needed(start_center, exit_center)
	_remove_unreachable_open_areas(start_center)

	_paint_tiles()
	_update_spawn_markers(start_center, exit_center)


func _setup_rng() -> void:
	if use_random_seed:
		_rng.seed = Time.get_ticks_usec()
	else:
		_rng.seed = fixed_seed


func _create_filled_grid() -> void:
	_grid.clear()

	for y in range(map_height):
		var row := PackedByteArray()
		row.resize(map_width)

		for x in range(map_width):
			row[x] = 1

		_grid.append(row)


func _create_main_rooms() -> Array[Dictionary]:
	var rooms: Array[Dictionary] = []

	var start_x: int = border_size + 12
	var end_x: int = map_width - border_size - 12
	var center_y: int = map_height / 2

	for i in range(main_room_count):
		var t: float = 0.0
		if main_room_count > 1:
			t = float(i) / float(main_room_count - 1)

		var x: int = int(round(lerpf(start_x, end_x, t)))
		var y: int = center_y + _rng.randi_range(-route_vertical_jitter, route_vertical_jitter)

		x = clampi(x, border_size + 8, map_width - border_size - 8)
		y = clampi(y, border_size + 8, map_height - border_size - 8)

		var rx: int = _rng.randi_range(main_room_radius_x_min, main_room_radius_x_max)
		var ry: int = _rng.randi_range(main_room_radius_y_min, main_room_radius_y_max)

		var room := {
			"center": Vector2i(x, y),
			"rx": rx,
			"ry": ry
		}

		rooms.append(room)
		_carve_ellipse(room["center"], room["rx"], room["ry"])

	return rooms


func _create_side_rooms(main_rooms: Array[Dictionary]) -> Array[Dictionary]:
	var rooms: Array[Dictionary] = []

	if main_rooms.size() < 3:
		return rooms

	for i in range(side_room_count):
		var anchor_index: int = _rng.randi_range(1, main_rooms.size() - 2)
		var anchor_center: Vector2i = main_rooms[anchor_index]["center"]

		var dir_x: int = -1 if _rng.randf() < 0.5 else 1
		var dir_y: int = -1 if _rng.randf() < 0.5 else 1

		var offset_x: int = dir_x * _rng.randi_range(side_room_offset_x_min, side_room_offset_x_max)
		var offset_y: int = dir_y * _rng.randi_range(side_room_offset_y_min, side_room_offset_y_max)

		var center := Vector2i(anchor_center.x + offset_x, anchor_center.y + offset_y)
		center.x = clampi(center.x, border_size + 8, map_width - border_size - 8)
		center.y = clampi(center.y, border_size + 8, map_height - border_size - 8)

		var rx: int = _rng.randi_range(side_room_radius_x_min, side_room_radius_x_max)
		var ry: int = _rng.randi_range(side_room_radius_y_min, side_room_radius_y_max)

		var room := {
			"center": center,
			"rx": rx,
			"ry": ry,
			"anchor_center": anchor_center
		}

		rooms.append(room)
		_carve_ellipse(room["center"], room["rx"], room["ry"])

	return rooms


func _connect_main_rooms(rooms: Array[Dictionary]) -> void:
	for i in range(rooms.size() - 1):
		var from_center: Vector2i = rooms[i]["center"]
		var to_center: Vector2i = rooms[i + 1]["center"]
		_carve_corridor(from_center, to_center, corridor_radius)


func _connect_side_rooms(rooms: Array[Dictionary]) -> void:
	for room in rooms:
		var from_center: Vector2i = room["center"]
		var to_center: Vector2i = room["anchor_center"]
		_carve_corridor(from_center, to_center, max(1, corridor_radius - 1))


func _recarve_rooms(rooms: Array[Dictionary]) -> void:
	for room in rooms:
		_carve_ellipse(room["center"], room["rx"], room["ry"])


func _carve_ellipse(center: Vector2i, rx: int, ry: int) -> void:
	for y in range(center.y - ry - 1, center.y + ry + 2):
		for x in range(center.x - rx - 1, center.x + rx + 2):
			if not _is_inside(x, y):
				continue

			var dx: float = float(x - center.x) / float(max(1, rx))
			var dy: float = float(y - center.y) / float(max(1, ry))

			if dx * dx + dy * dy <= 1.0:
				_set_open(x, y)


func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i, radius: int) -> void:
	var current := from_cell
	var safety: int = 0
	var max_steps: int = map_width * map_height

	while current != to_cell and safety < max_steps:
		_carve_circle(current, radius)

		var dx: int = to_cell.x - current.x
		var dy: int = to_cell.y - current.y

		var step := Vector2i.ZERO

		if dx != 0 and dy != 0:
			if _rng.randf() < 0.5:
				step.x = signi(dx)
			else:
				step.y = signi(dy)
		elif dx != 0:
			step.x = signi(dx)
		elif dy != 0:
			step.y = signi(dy)

		if _rng.randf() < corridor_wobble:
			if _rng.randf() < 0.5:
				step = Vector2i(_rng.randi_range(-1, 1), 0)
			else:
				step = Vector2i(0, _rng.randi_range(-1, 1))

		current.x = clampi(current.x + step.x, border_size + 1, map_width - border_size - 2)
		current.y = clampi(current.y + step.y, border_size + 1, map_height - border_size - 2)

		safety += 1

	_carve_circle(to_cell, radius)


func _carve_circle(center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _is_inside(x, y):
				continue

			if center.distance_to(Vector2(x, y)) <= float(radius) + 0.35:
				_set_open(x, y)


func _smooth_map() -> void:
	var new_grid: Array[PackedByteArray] = []

	for y in range(map_height):
		var row := PackedByteArray()
		row.resize(map_width)

		for x in range(map_width):
			if _is_border_cell(x, y):
				row[x] = 1
				continue

			var solid_neighbors: int = _count_solid_neighbors_8(x, y)
			row[x] = 1 if solid_neighbors >= solid_if_neighbor_count_at_least else 0

		new_grid.append(row)

	_grid = new_grid


func _count_solid_neighbors_8(x: int, y: int) -> int:
	var count: int = 0

	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue

			var nx: int = x + ox
			var ny: int = y + oy

			if not _is_inside(nx, ny):
				count += 1
				continue

			if _is_solid(nx, ny):
				count += 1

	return count


func _force_connection_if_needed(start_guess: Vector2i, exit_guess: Vector2i) -> void:
	var start_open: Vector2i = _find_nearest_open_to(start_guess)
	var exit_open: Vector2i = _find_nearest_open_to(exit_guess)

	if start_open == Vector2i(-1, -1) or exit_open == Vector2i(-1, -1):
		return

	var reachable := _flood_fill_open(start_open)

	if not reachable.has(exit_open):
		_carve_corridor(start_open, exit_open, corridor_radius + 1)


func _remove_unreachable_open_areas(start_guess: Vector2i) -> void:
	var start_open: Vector2i = _find_nearest_open_to(start_guess)

	if start_open == Vector2i(-1, -1):
		return

	var reachable := _flood_fill_open(start_open)

	for y in range(map_height):
		for x in range(map_width):
			var cell := Vector2i(x, y)
			if _is_open(x, y) and not reachable.has(cell):
				_set_solid(x, y)


func _flood_fill_open(start_cell: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_cell]
	visited[start_cell] = true

	var index: int = 0

	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1

		var neighbors: Array[Vector2i] = [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]

		for next in neighbors:
			if not _is_inside(next.x, next.y):
				continue
			if not _is_open(next.x, next.y):
				continue
			if visited.has(next):
				continue

			visited[next] = true
			queue.append(next)

	return visited


func _paint_tiles() -> void:
	solid_layer.clear()

	var solid_cells: Array[Vector2i] = []

	for y in range(map_height):
		for x in range(map_width):
			if _is_solid(x, y):
				solid_cells.append(Vector2i(x, y))

	if solid_cells.is_empty():
		solid_layer.update_internals()
		return

	if use_better_terrain:
		BetterTerrain.set_cells(solid_layer, solid_cells, better_terrain_type)
		BetterTerrain.update_terrain_cells(solid_layer, solid_cells, true)
	elif use_terrain_connect:
		solid_layer.set_cells_terrain_connect(
			solid_cells,
			terrain_set_id,
			solid_terrain_id,
			true
		)
	else:
		for cell in solid_cells:
			solid_layer.set_cell(
				cell,
				fallback_source_id,
				fallback_atlas_coords,
				fallback_alternative_tile
			)

	solid_layer.update_internals()

func _update_spawn_markers(start_guess: Vector2i, exit_guess: Vector2i) -> void:
	var start_cell: Vector2i = _find_standable_cell_near(start_guess)
	var exit_cell: Vector2i = _find_standable_cell_near(exit_guess)

	if player_spawn_marker != null and start_cell != Vector2i(-1, -1):
		player_spawn_marker.global_position = solid_layer.to_global(solid_layer.map_to_local(start_cell))

	if exit_spawn_marker != null and exit_cell != Vector2i(-1, -1):
		exit_spawn_marker.global_position = solid_layer.to_global(solid_layer.map_to_local(exit_cell))


func _find_standable_cell_near(center: Vector2i) -> Vector2i:
	for radius in range(0, 24):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if not _is_inside(x, y):
					continue
				if _is_standable(x, y):
					return Vector2i(x, y)

	return Vector2i(-1, -1)


func _is_standable(x: int, y: int) -> bool:
	if not _is_inside(x, y):
		return false
	if not _is_inside(x, y - 1):
		return false
	if not _is_inside(x, y + 1):
		return false

	if not _is_open(x, y):
		return false
	if not _is_open(x, y - 1):
		return false
	if not _is_solid(x, y + 1):
		return false

	return true


func _find_nearest_open_to(center: Vector2i) -> Vector2i:
	for radius in range(0, 30):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if not _is_inside(x, y):
					continue
				if _is_open(x, y):
					return Vector2i(x, y)

	return Vector2i(-1, -1)


func _is_inside(x: int, y: int) -> bool:
	return x >= 0 and x < map_width and y >= 0 and y < map_height


func _is_border_cell(x: int, y: int) -> bool:
	return (
		x < border_size
		or x >= map_width - border_size
		or y < border_size
		or y >= map_height - border_size
	)


func _is_solid(x: int, y: int) -> bool:
	return _grid[y][x] == 1


func _is_open(x: int, y: int) -> bool:
	return _grid[y][x] == 0


func _set_solid(x: int, y: int) -> void:
	_grid[y][x] = 1


func _set_open(x: int, y: int) -> void:
	_grid[y][x] = 0
