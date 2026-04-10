@tool
extends Node2D

@export_group("References")
@export var solid_layer: TileMapLayer
@export var player_spawn_marker: Marker2D
@export var exit_spawn_marker: Marker2D

@export_group("Seed")
@export var use_random_seed: bool = false
@export var fixed_seed: int = 1001
@export var generate_on_ready: bool = false

@export_group("Map Size")
@export var map_width: int = 220
@export var map_height: int = 140
@export var border_size: int = 3

@export_group("Start Room")
@export var start_room_center_x: int = 22
@export var start_room_center_y: int = 28
@export var start_room_radius_x: int = 12
@export var start_room_radius_y: int = 8

@export_group("Main Worms")
@export var main_worm_count: int = 5
@export var main_worm_steps_min: int = 120
@export var main_worm_steps_max: int = 220
@export var main_worm_radius_min: int = 2
@export var main_worm_radius_max: int = 4
@export_range(0.0, 1.0, 0.01) var worm_bias_right: float = 0.58
@export_range(0.0, 1.0, 0.01) var worm_bias_down: float = 0.24
@export_range(0.0, 1.0, 0.01) var worm_turn_chance: float = 0.28

@export_group("Branch Worms")
@export var branch_worm_count: int = 16
@export var branch_worm_steps_min: int = 26
@export var branch_worm_steps_max: int = 75
@export var branch_worm_radius_min: int = 1
@export var branch_worm_radius_max: int = 3
@export_range(0.0, 1.0, 0.01) var branch_from_open_cell_chance: float = 1.0

@export_group("Noise Caverns")
@export var cavern_attempts: int = 28
@export var cavern_radius_x_min: int = 4
@export var cavern_radius_x_max: int = 10
@export var cavern_radius_y_min: int = 3
@export var cavern_radius_y_max: int = 8
@export_range(0.0, 1.0, 0.01) var cavern_attach_bias_to_open_cells: float = 0.75

@export_group("Cleanup")
@export var smoothing_passes: int = 2
@export_range(0, 8, 1) var solid_if_neighbor_count_at_least: int = 5
@export var connect_pockets_to_main: bool = true
@export var remove_unreachable_open_areas: bool = true

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
var _open_cells_cache: Array[Vector2i] = []

# 1 = solid
# 0 = open

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

	var start_center := Vector2i(start_room_center_x, start_room_center_y)
	start_center.x = clampi(start_center.x, border_size + 10, map_width - border_size - 10)
	start_center.y = clampi(start_center.y, border_size + 10, map_height - border_size - 10)

	_carve_ellipse(start_center, start_room_radius_x, start_room_radius_y)
	_refresh_open_cells_cache()

	var worm_endpoints: Array[Vector2i] = []
	_run_main_worms(start_center, worm_endpoints)
	_refresh_open_cells_cache()

	_run_branch_worms()
	_refresh_open_cells_cache()

	_add_noise_caverns()
	_refresh_open_cells_cache()

	for i in range(smoothing_passes):
		_smooth_map()

	# wichtige offene Zonen wieder sichern
	_carve_ellipse(start_center, start_room_radius_x, start_room_radius_y)
	_refresh_open_cells_cache()

	if connect_pockets_to_main:
		_connect_all_open_regions_to_main(start_center)

	if remove_unreachable_open_areas:
		_remove_unreachable_open_areas_from(start_center)

	_refresh_open_cells_cache()

	var exit_guess := _find_far_right_down_open_cell(start_center)
	if exit_guess == Vector2i(-1, -1):
		exit_guess = _find_farthest_open_cell_from(start_center)

	_paint_tiles()
	_update_spawn_markers(start_center, exit_guess)


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


func _run_main_worms(start_center: Vector2i, worm_endpoints: Array[Vector2i]) -> void:
	for i in range(main_worm_count):
		var current := start_center + Vector2i(
			_rng.randi_range(-3, 3),
			_rng.randi_range(-2, 2)
		)

		var dir := Vector2i(1, 0)
		var steps := _rng.randi_range(main_worm_steps_min, main_worm_steps_max)
		var radius := _rng.randi_range(main_worm_radius_min, main_worm_radius_max)

		for step_index in range(steps):
			_carve_circle(current, radius)

			if _rng.randf() < worm_turn_chance:
				dir = _pick_biased_direction(dir)

			current += dir
			current.x = clampi(current.x, border_size + 2, map_width - border_size - 3)
			current.y = clampi(current.y, border_size + 2, map_height - border_size - 3)

			if _rng.randf() < 0.08:
				radius = _rng.randi_range(main_worm_radius_min, main_worm_radius_max)

		worm_endpoints.append(current)
		_carve_circle(current, radius + 2)


func _run_branch_worms() -> void:
	if _open_cells_cache.is_empty():
		return

	for i in range(branch_worm_count):
		if _open_cells_cache.is_empty():
			return

		var start_cell := _open_cells_cache[_rng.randi_range(0, _open_cells_cache.size() - 1)]
		var current := start_cell
		var dir := _pick_random_direction()
		var steps := _rng.randi_range(branch_worm_steps_min, branch_worm_steps_max)
		var radius := _rng.randi_range(branch_worm_radius_min, branch_worm_radius_max)

		for step_index in range(steps):
			_carve_circle(current, radius)

			if _rng.randf() < 0.42:
				dir = _pick_branch_direction(dir)

			current += dir
			current.x = clampi(current.x, border_size + 2, map_width - border_size - 3)
			current.y = clampi(current.y, border_size + 2, map_height - border_size - 3)

			if _rng.randf() < 0.10:
				radius = _rng.randi_range(branch_worm_radius_min, branch_worm_radius_max)

		_carve_circle(current, radius + 1)


func _add_noise_caverns() -> void:
	for i in range(cavern_attempts):
		var center := Vector2i.ZERO

		if not _open_cells_cache.is_empty() and _rng.randf() < cavern_attach_bias_to_open_cells:
			var anchor := _open_cells_cache[_rng.randi_range(0, _open_cells_cache.size() - 1)]
			center = anchor + Vector2i(
				_rng.randi_range(-16, 16),
				_rng.randi_range(-12, 12)
			)
		else:
			center = Vector2i(
				_rng.randi_range(border_size + 8, map_width - border_size - 9),
				_rng.randi_range(border_size + 8, map_height - border_size - 9)
			)

		center.x = clampi(center.x, border_size + 4, map_width - border_size - 5)
		center.y = clampi(center.y, border_size + 4, map_height - border_size - 5)

		var rx := _rng.randi_range(cavern_radius_x_min, cavern_radius_x_max)
		var ry := _rng.randi_range(cavern_radius_y_min, cavern_radius_y_max)

		_carve_noisy_blob(center, rx, ry)
		_refresh_open_cells_cache()


func _carve_noisy_blob(center: Vector2i, rx: int, ry: int) -> void:
	for y in range(center.y - ry - 2, center.y + ry + 3):
		for x in range(center.x - rx - 2, center.x + rx + 3):
			if not _is_inside(x, y):
				continue

			var dx := float(x - center.x) / float(max(1, rx))
			var dy := float(y - center.y) / float(max(1, ry))
			var ellipse_value := dx * dx + dy * dy

			var chance := 0.0
			if ellipse_value <= 0.85:
				chance = 1.0
			elif ellipse_value <= 1.1:
				chance = 0.72
			elif ellipse_value <= 1.28:
				chance = 0.34

			if chance > 0.0 and _rng.randf() < chance:
				_set_open(x, y)


func _pick_biased_direction(previous_dir: Vector2i) -> Vector2i:
	var roll := _rng.randf()

	if roll < worm_bias_right:
		return Vector2i(1, _rng.randi_range(-1, 1))
	elif roll < worm_bias_right + worm_bias_down:
		return Vector2i(_rng.randi_range(-1, 1), 1)

	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(-1, 0)
	]

	return dirs[_rng.randi_range(0, dirs.size() - 1)]


func _pick_branch_direction(previous_dir: Vector2i) -> Vector2i:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1)
	]

	if _rng.randf() < 0.35:
		return previous_dir

	return dirs[_rng.randi_range(0, dirs.size() - 1)]


func _pick_random_direction() -> Vector2i:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1)
	]
	return dirs[_rng.randi_range(0, dirs.size() - 1)]


func _carve_ellipse(center: Vector2i, rx: int, ry: int) -> void:
	for y in range(center.y - ry - 1, center.y + ry + 2):
		for x in range(center.x - rx - 1, center.x + rx + 2):
			if not _is_inside(x, y):
				continue

			var dx := float(x - center.x) / float(max(1, rx))
			var dy := float(y - center.y) / float(max(1, ry))

			if dx * dx + dy * dy <= 1.0:
				_set_open(x, y)


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

			var solid_neighbors := _count_solid_neighbors_8(x, y)
			row[x] = 1 if solid_neighbors >= solid_if_neighbor_count_at_least else 0

		new_grid.append(row)

	_grid = new_grid


func _count_solid_neighbors_8(x: int, y: int) -> int:
	var count := 0

	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue

			var nx := x + ox
			var ny := y + oy

			if not _is_inside(nx, ny):
				count += 1
				continue

			if _is_solid(nx, ny):
				count += 1

	return count


func _connect_all_open_regions_to_main(start_guess: Vector2i) -> void:
	var main_open := _find_nearest_open_to(start_guess)
	if main_open == Vector2i(-1, -1):
		return

	var visited := _flood_fill_open(main_open)
	var regions := _collect_open_regions(visited)

	for region in regions:
		if region.is_empty():
			continue

		var region_cell: Vector2i = region[_rng.randi_range(0, region.size() - 1)]
		var target := _find_closest_cell_in_visited(region_cell, visited)

		if target != Vector2i(-1, -1):
			_carve_line_tunnel(region_cell, target, 2)

	var refreshed_main := _find_nearest_open_to(start_guess)
	if refreshed_main != Vector2i(-1, -1):
		visited = _flood_fill_open(refreshed_main)


func _collect_open_regions(already_visited: Dictionary) -> Array[Array]:
	var regions: Array[Array] = []
	var checked: Dictionary = {}

	for key in already_visited.keys():
		checked[key] = true

	for y in range(map_height):
		for x in range(map_width):
			var cell := Vector2i(x, y)

			if checked.has(cell):
				continue
			if not _is_open(x, y):
				continue

			var region := _flood_fill_open(cell)
			var region_cells: Array = []

			for region_key in region.keys():
				checked[region_key] = true
				region_cells.append(region_key)

			if not region_cells.is_empty():
				regions.append(region_cells)

	return regions


func _find_closest_cell_in_visited(from_cell: Vector2i, visited: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := INF

	for key in visited.keys():
		var cell: Vector2i = key
		var dist := from_cell.distance_squared_to(cell)
		if dist < best_dist:
			best_dist = dist
			best = cell

	return best


func _remove_unreachable_open_areas_from(start_guess: Vector2i) -> void:
	var start_open := _find_nearest_open_to(start_guess)
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

	var index := 0

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


func _carve_line_tunnel(from_cell: Vector2i, to_cell: Vector2i, radius: int) -> void:
	var current := from_cell
	var safety := 0
	var max_steps := map_width * map_height

	while current != to_cell and safety < max_steps:
		_carve_circle(current, radius)

		var dx := to_cell.x - current.x
		var dy := to_cell.y - current.y

		if abs(dx) > abs(dy):
			current.x += signi(dx)
		elif dy != 0:
			current.y += signi(dy)
		elif dx != 0:
			current.x += signi(dx)

		current.x = clampi(current.x, border_size + 1, map_width - border_size - 2)
		current.y = clampi(current.y, border_size + 1, map_height - border_size - 2)

		safety += 1

	_carve_circle(to_cell, radius)


func _refresh_open_cells_cache() -> void:
	_open_cells_cache.clear()

	for y in range(map_height):
		for x in range(map_width):
			if _is_open(x, y):
				_open_cells_cache.append(Vector2i(x, y))


func _find_far_right_down_open_cell(start_center: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -INF

	for y in range(map_height):
		for x in range(map_width):
			if not _is_open(x, y):
				continue

			var score := float(x) * 1.35 + float(y) * 0.85
			score += start_center.distance_to(Vector2(x, y)) * 0.35

			if score > best_score:
				best_score = score
				best = Vector2i(x, y)

	return best


func _find_farthest_open_cell_from(origin: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := -1.0

	for y in range(map_height):
		for x in range(map_width):
			if not _is_open(x, y):
				continue

			var dist := origin.distance_to(Vector2(x, y))
			if dist > best_dist:
				best_dist = dist
				best = Vector2i(x, y)

	return best


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
	var start_cell := _find_standable_cell_near(start_guess)
	var exit_cell := _find_standable_cell_near(exit_guess)

	if player_spawn_marker != null and start_cell != Vector2i(-1, -1):
		player_spawn_marker.global_position = solid_layer.to_global(solid_layer.map_to_local(start_cell))

	if exit_spawn_marker != null and exit_cell != Vector2i(-1, -1):
		exit_spawn_marker.global_position = solid_layer.to_global(solid_layer.map_to_local(exit_cell))


func _find_standable_cell_near(center: Vector2i) -> Vector2i:
	for radius in range(0, 40):
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
	for radius in range(0, 48):
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
