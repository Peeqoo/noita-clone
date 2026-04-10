@tool
extends Node2D

@export_group("References")
@export var tilemap_layer: TileMapLayer
@export var player_spawn_marker: Node2D
@export var exit_spawn_marker: Node2D

@export_group("Editor")
@export var regenerate_on_ready: bool = false
@export var generate_now: bool = false:
	set(value):
		if value:
			generate()
		generate_now = false

@export_group("Tile Settings")
@export var ground_source_id: int = 0
@export var ground_atlas_coords: Vector2i = Vector2i(0, 0)
@export var ground_alternative_tile: int = 0

@export_group("Better Terrain")
@export var use_better_terrain: bool = true
@export var better_terrain_type: int = 0

@export_group("Map Size")
@export var map_width: int = 160
@export var map_height: int = 90

@export_group("Generation")
@export var random_seed: int = 0
@export var use_random_seed: bool = true

@export_group("Upper Cave Noise")
@export var upper_noise_fill_chance: float = 0.47
@export var cellular_steps: int = 5
@export var birth_limit: int = 4
@export var death_limit: int = 3
@export var upper_cave_start_y_ratio: float = 0.42

@export_group("Main Funnel")
@export var funnel_top_y_ratio: float = 0.72
@export var funnel_bottom_y_ratio: float = 0.93
@export var funnel_center_width: int = 14
@export var funnel_edge_margin: int = 3
@export var funnel_curve_strength: float = 1.35

@export_group("Central Space")
@export var central_room_width: int = 42
@export var central_room_height: int = 16
@export var central_room_y_ratio: float = 0.60

@export_group("Platforms")
@export var platform_count: int = 12
@export var platform_min_length: int = 10
@export var platform_max_length: int = 24
@export var platform_thickness: int = 2
@export var platform_min_gap_y: int = 4
@export var platform_area_top_ratio: float = 0.38
@export var platform_area_bottom_ratio: float = 0.72

@export_group("Polish")
@export var side_pocket_count: int = 6
@export var side_pocket_radius_min: int = 4
@export var side_pocket_radius_max: int = 8
@export var smoothing_passes_after_platforms: int = 1

var _rng: RandomNumberGenerator
var _grid: Array = []

func _ready() -> void:
	if regenerate_on_ready:
		call_deferred("generate")

func generate() -> void:
	if tilemap_layer == null:
		push_error("tilemap_layer is not assigned.")
		return

	if tilemap_layer.tile_set == null:
		push_error("tilemap_layer.tile_set is missing.")
		return

	if map_width < 20 or map_height < 20:
		push_error("map_width/map_height are too small.")
		return

	_setup_rng()
	_create_solid_map()
	_carve_upper_caves()
	_run_cellular_automata()
	_carve_main_funnel()
	_carve_central_room()
	_carve_side_pockets()
	_build_large_horizontal_platforms()
	_clear_spawn_and_exit_areas()
	_polish_ground()
	_draw_to_tilemap()
	_position_markers()

	if Engine.is_editor_hint():
		notify_property_list_changed()
		update_configuration_warnings()

func _setup_rng() -> void:
	_rng = RandomNumberGenerator.new()
	if use_random_seed:
		_rng.randomize()
	else:
		_rng.seed = random_seed

func _create_solid_map() -> void:
	_grid.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append(true)
		_grid.append(row)

func _carve_upper_caves() -> void:
	var upper_limit: int = int(map_height * upper_cave_start_y_ratio)

	for y in range(1, upper_limit):
		for x in range(1, map_width - 1):
			if _rng.randf() > upper_noise_fill_chance:
				_grid[y][x] = false

func _run_cellular_automata() -> void:
	for _i in range(cellular_steps):
		var new_grid: Array = []

		for y in range(map_height):
			var row: Array = []
			for x in range(map_width):
				var solid_neighbors: int = _count_solid_neighbors(x, y)

				if _grid[y][x]:
					row.append(solid_neighbors >= death_limit)
				else:
					row.append(solid_neighbors > birth_limit)

			new_grid.append(row)

		_grid = new_grid

func _count_solid_neighbors(cx: int, cy: int) -> int:
	var count: int = 0

	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue

			var nx: int = cx + ox
			var ny: int = cy + oy

			if nx < 0 or nx >= map_width or ny < 0 or ny >= map_height:
				count += 1
			elif _grid[ny][nx]:
				count += 1

	return count

func _carve_main_funnel() -> void:
	var top_y: int = clampi(int(map_height * funnel_top_y_ratio), 0, map_height - 1)
	var bottom_y: int = clampi(int(map_height * funnel_bottom_y_ratio), 0, map_height - 1)
	var center_x: int = map_width / 2

	for y in range(top_y, bottom_y + 1):
		var t: float = inverse_lerp(float(top_y), float(bottom_y), float(y))
		t = pow(t, funnel_curve_strength)

		var left_x: int = int(lerp(float(funnel_edge_margin), float(center_x - funnel_center_width / 2), t))
		var right_x: int = int(lerp(float(map_width - 1 - funnel_edge_margin), float(center_x + funnel_center_width / 2), t))

		for x in range(left_x, right_x + 1):
			_grid[y][x] = false

		if y > top_y and y < bottom_y:
			if left_x - 1 >= 0:
				_grid[y][left_x - 1] = _rng.randf() < 0.35
			if right_x + 1 < map_width:
				_grid[y][right_x + 1] = _rng.randf() < 0.35

func _carve_central_room() -> void:
	var center_x: int = map_width / 2
	var center_y: int = int(map_height * central_room_y_ratio)

	var half_w: int = central_room_width / 2
	var half_h: int = central_room_height / 2

	for y in range(center_y - half_h, center_y + half_h + 1):
		if y < 1 or y >= map_height - 1:
			continue

		for x in range(center_x - half_w, center_x + half_w + 1):
			if x < 1 or x >= map_width - 1:
				continue

			var dx: float = abs(float(x - center_x)) / max(1.0, float(half_w))
			var dy: float = abs(float(y - center_y)) / max(1.0, float(half_h))
			var dist: float = dx * dx + dy * dy

			if dist <= 1.15:
				_grid[y][x] = false
			elif dist <= 1.35 and _rng.randf() < 0.55:
				_grid[y][x] = false

func _carve_side_pockets() -> void:
	var min_y: int = int(map_height * 0.35)
	var max_y: int = int(map_height * 0.75)

	for _i in range(side_pocket_count):
		var left_side: bool = _rng.randi_range(0, 1) == 0
		var radius: int = _rng.randi_range(side_pocket_radius_min, side_pocket_radius_max)
		var cy: int = _rng.randi_range(min_y, max_y)
		var cx: int

		if left_side:
			cx = _rng.randi_range(radius + 2, int(map_width * 0.28))
		else:
			cx = _rng.randi_range(int(map_width * 0.72), map_width - radius - 3)

		_carve_blob(cx, cy, radius)

		var target_x: int = map_width / 2 + _rng.randi_range(-12, 12)
		var target_y: int = cy + _rng.randi_range(-5, 5)
		_carve_tunnel(Vector2i(cx, cy), Vector2i(target_x, target_y), 2)

func _carve_blob(cx: int, cy: int, radius: int) -> void:
	for y in range(cy - radius - 1, cy + radius + 2):
		if y < 1 or y >= map_height - 1:
			continue

		for x in range(cx - radius - 1, cx + radius + 2):
			if x < 1 or x >= map_width - 1:
				continue

			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			var d: float = sqrt(dx * dx + dy * dy)
			var threshold: float = float(radius) + _rng.randf_range(-1.2, 1.2)

			if d <= threshold:
				_grid[y][x] = false

func _carve_tunnel(from_cell: Vector2i, to_cell: Vector2i, half_width: int) -> void:
	var current: Vector2 = Vector2(from_cell)
	var target: Vector2 = Vector2(to_cell)
	var steps: int = int(current.distance_to(target))

	if steps <= 0:
		return

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = current.lerp(target, t)
		_carve_circle(int(round(p.x)), int(round(p.y)), half_width)

func _carve_circle(cx: int, cy: int, radius: int) -> void:
	for y in range(cy - radius, cy + radius + 1):
		if y < 1 or y >= map_height - 1:
			continue

		for x in range(cx - radius, cx + radius + 1):
			if x < 1 or x >= map_width - 1:
				continue

			var dx: int = x - cx
			var dy: int = y - cy
			if dx * dx + dy * dy <= radius * radius:
				_grid[y][x] = false

func _build_large_horizontal_platforms() -> void:
	var min_y: int = int(map_height * platform_area_top_ratio)
	var max_y: int = int(map_height * platform_area_bottom_ratio)

	var used_y: Array[int] = []

	for _i in range(platform_count):
		var py: int = _pick_platform_y(min_y, max_y, used_y)
		used_y.append(py)

		var length: int = _rng.randi_range(platform_min_length, platform_max_length)

		var center_bias_min: int = int(map_width * 0.18)
		var center_bias_max: int = int(map_width * 0.82)
		var px: int = _rng.randi_range(center_bias_min, max(center_bias_min, center_bias_max - length))

		if _rng.randf() < 0.65:
			px = clampi((map_width - length) / 2 + _rng.randi_range(-18, 18), 2, map_width - length - 2)

		for y in range(py, py + platform_thickness):
			if y < 1 or y >= map_height - 1:
				continue

			for x in range(px, px + length):
				if x < 1 or x >= map_width - 1:
					continue
				_grid[y][x] = true

		for y in range(py - 4, py):
			if y < 1 or y >= map_height - 1:
				continue

			for x in range(px - 1, px + length + 1):
				if x < 1 or x >= map_width - 1:
					continue
				_grid[y][x] = false

		for y in range(py + platform_thickness, py + platform_thickness + 2):
			if y < 1 or y >= map_height - 1:
				continue

			for x in range(px + 1, px + length - 1):
				if x < 1 or x >= map_width - 1:
					continue
				if _rng.randf() < 0.75:
					_grid[y][x] = false

func _pick_platform_y(min_y: int, max_y: int, used_y: Array[int]) -> int:
	var tries: int = 40

	while tries > 0:
		var candidate: int = _rng.randi_range(min_y, max_y)
		var valid: bool = true

		for y in used_y:
			if abs(candidate - y) < platform_min_gap_y:
				valid = false
				break

		if valid:
			return candidate

		tries -= 1

	return _rng.randi_range(min_y, max_y)

func _clear_spawn_and_exit_areas() -> void:
	var player_cell: Vector2i = Vector2i(8, int(map_height * funnel_top_y_ratio) + 2)
	var exit_cell: Vector2i = Vector2i(map_width / 2, int(map_height * funnel_bottom_y_ratio) - 1)

	_clear_area(player_cell.x, player_cell.y, 4, 5)
	_clear_area(exit_cell.x, exit_cell.y, 5, 5)

	_make_floor(player_cell.x - 3, player_cell.x + 3, player_cell.y + 2, 2)
	_make_floor(exit_cell.x - 4, exit_cell.x + 4, exit_cell.y + 2, 2)

	var start_tunnel_from: Vector2i = Vector2i(player_cell.x + 3, player_cell.y + 1)
	var start_tunnel_to: Vector2i = Vector2i(map_width / 2 - 20, int(map_height * 0.63))
	_carve_tunnel(start_tunnel_from, start_tunnel_to, 2)

func _clear_area(cx: int, cy: int, half_w: int, half_h: int) -> void:
	for y in range(cy - half_h, cy + half_h + 1):
		if y < 1 or y >= map_height - 1:
			continue

		for x in range(cx - half_w, cx + half_w + 1):
			if x < 1 or x >= map_width - 1:
				continue
			_grid[y][x] = false

func _make_floor(x1: int, x2: int, y: int, thickness: int) -> void:
	for yy in range(y, y + thickness):
		if yy < 1 or yy >= map_height - 1:
			continue

		for xx in range(x1, x2 + 1):
			if xx < 1 or xx >= map_width - 1:
				continue
			_grid[yy][xx] = true

func _polish_ground() -> void:
	for _i in range(smoothing_passes_after_platforms):
		var new_grid: Array = []

		for y in range(map_height):
			var row: Array = []
			for x in range(map_width):
				if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
					row.append(true)
					continue

				var solid_neighbors: int = _count_solid_neighbors(x, y)

				if _grid[y][x]:
					row.append(solid_neighbors >= 3)
				else:
					row.append(solid_neighbors >= 6)

			new_grid.append(row)

		_grid = new_grid

	_carve_main_funnel()
	_carve_central_room()
	_clear_spawn_and_exit_areas()

func _draw_to_tilemap() -> void:
	tilemap_layer.clear()

	var solid_cells: Array[Vector2i] = []

	for y in range(map_height):
		for x in range(map_width):
			if _grid[y][x]:
				solid_cells.append(Vector2i(x, y))

	if solid_cells.is_empty():
		return

	if use_better_terrain:
		BetterTerrain.set_cells(tilemap_layer, solid_cells, better_terrain_type)
		BetterTerrain.update_terrain_cells(tilemap_layer, solid_cells, true)
	else:
		for cell in solid_cells:
			tilemap_layer.set_cell(
				cell,
				ground_source_id,
				ground_atlas_coords,
				ground_alternative_tile
			)

func _position_markers() -> void:
	var tile_size: Vector2 = tilemap_layer.tile_set.tile_size

	var player_cell: Vector2i = Vector2i(8, int(map_height * funnel_top_y_ratio) + 1)
	var exit_cell: Vector2i = Vector2i(map_width / 2, int(map_height * funnel_bottom_y_ratio) - 1)

	if player_spawn_marker != null:
		player_spawn_marker.global_position = tilemap_layer.to_global(Vector2(
			(player_cell.x + 0.5) * tile_size.x,
			(player_cell.y + 0.5) * tile_size.y
		))

	if exit_spawn_marker != null:
		exit_spawn_marker.global_position = tilemap_layer.to_global(Vector2(
			(exit_cell.x + 0.5) * tile_size.x,
			(exit_cell.y + 0.5) * tile_size.y
		))

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if tilemap_layer == null:
		warnings.append("tilemap_layer is not assigned.")

	if tilemap_layer != null and tilemap_layer.tile_set == null:
		warnings.append("tilemap_layer has no TileSet assigned.")

	return warnings
