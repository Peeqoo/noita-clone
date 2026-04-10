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
			call_deferred("generate")
		generate_now = false

@export_group("Tile Settings")
@export var ground_source_id: int = 0
@export var ground_atlas_coords: Vector2i = Vector2i(0, 0)
@export var ground_alternative_tile: int = 0

@export_group("Map Size")
@export var map_width: int = 180
@export var map_height: int = 100

@export_group("Generation")
@export var random_seed: int = 0
@export var use_random_seed: bool = true

@export_group("Main Path")
@export var main_room_count: int = 8
@export var main_room_width_min: int = 26
@export var main_room_width_max: int = 52
@export var main_room_height_min: int = 10
@export var main_room_height_max: int = 18
@export var main_room_vertical_step_min: int = 5
@export var main_room_vertical_step_max: int = 10
@export var start_x_ratio: float = 0.20
@export var end_x_ratio: float = 0.50
@export var start_y_ratio: float = 0.18
@export var end_y_ratio: float = 0.78

@export_group("Connections")
@export var corridor_half_width: int = 3
@export var corridor_jitter: int = 2
@export var ramp_half_width: int = 2

@export_group("Branches")
@export var branch_room_count: int = 8
@export var branch_room_width_min: int = 12
@export var branch_room_width_max: int = 24
@export var branch_room_height_min: int = 7
@export var branch_room_height_max: int = 12
@export var branch_attach_distance_min: int = 14
@export var branch_attach_distance_max: int = 28

@export_group("Bottom Funnel")
@export var funnel_top_y_ratio: float = 0.80
@export var funnel_bottom_y_ratio: float = 0.94
@export var funnel_center_width: int = 16
@export var funnel_edge_margin: int = 3
@export var funnel_curve_strength: float = 1.45
@export var exit_platform_width: int = 10

@export_group("Noise Polish")
@export var blob_count: int = 18
@export var blob_radius_min: int = 3
@export var blob_radius_max: int = 8
@export var cleanup_iterations: int = 2
@export var cleanup_birth_limit: int = 5
@export var cleanup_death_limit: int = 3

var _rng: RandomNumberGenerator
var _grid: Array = []
var _main_centers: Array[Vector2i] = []
var _player_cell: Vector2i
var _exit_cell: Vector2i

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

	if map_width < 60 or map_height < 50:
		push_error("map size too small for this generator.")
		return

	_setup_rng()
	_create_solid_map()
	_main_centers.clear()

	_build_main_path_rooms()
	_connect_main_path()
	_build_branch_rooms()
	_carve_bottom_funnel()
	_carve_bottom_exit_basin()
	_add_noise_blobs()
	_cleanup_map()
	_finalize_spawn_and_exit()
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

func _build_main_path_rooms() -> void:
	var start_x: int = int(map_width * start_x_ratio)
	var end_x: int = int(map_width * end_x_ratio)
	var start_y: int = int(map_height * start_y_ratio)
	var end_y: int = int(map_height * end_y_ratio)

	var current_x: int = start_x
	var current_y: int = start_y

	for i in range(main_room_count):
		var t: float = 0.0
		if main_room_count > 1:
			t = float(i) / float(main_room_count - 1)

		var target_x: int = int(lerp(float(start_x), float(end_x), t))
		var room_w: int = _rng.randi_range(main_room_width_min, main_room_width_max)
		var room_h: int = _rng.randi_range(main_room_height_min, main_room_height_max)

		if i == 0:
			current_x = start_x
			current_y = start_y
		else:
			current_x = int(lerp(float(current_x), float(target_x), 0.55)) + _rng.randi_range(-8, 8)
			current_y += _rng.randi_range(main_room_vertical_step_min, main_room_vertical_step_max)

		current_x = clampi(current_x, room_w / 2 + 4, map_width - room_w / 2 - 5)
		current_y = clampi(current_y, room_h / 2 + 4, end_y)

		var center: Vector2i = Vector2i(current_x, current_y)
		_main_centers.append(center)
		_carve_room(center, room_w, room_h)

		if i > 0:
			_widen_room_horizontally(center, room_w, room_h)

	if _main_centers.size() > 0:
		_player_cell = _main_centers[0] + Vector2i(-main_room_width_max / 4, 0)

func _connect_main_path() -> void:
	for i in range(_main_centers.size() - 1):
		var from_center: Vector2i = _main_centers[i]
		var to_center: Vector2i = _main_centers[i + 1]
		_carve_soft_ramp_tunnel(from_center, to_center, corridor_half_width)

func _build_branch_rooms() -> void:
	if _main_centers.is_empty():
		return

	for i in range(branch_room_count):
		var anchor: Vector2i = _main_centers[_rng.randi_range(1, max(1, _main_centers.size() - 2))]
		var side: int = -1 if _rng.randf() < 0.5 else 1
		var distance_x: int = _rng.randi_range(branch_attach_distance_min, branch_attach_distance_max) * side
		var distance_y: int = _rng.randi_range(-4, 6)

		var room_w: int = _rng.randi_range(branch_room_width_min, branch_room_width_max)
		var room_h: int = _rng.randi_range(branch_room_height_min, branch_room_height_max)

		var center := Vector2i(
			clampi(anchor.x + distance_x, room_w / 2 + 3, map_width - room_w / 2 - 4),
			clampi(anchor.y + distance_y, room_h / 2 + 3, map_height - room_h / 2 - 4)
		)

		_carve_room(center, room_w, room_h)
		_carve_soft_ramp_tunnel(anchor, center, ramp_half_width)

func _carve_bottom_funnel() -> void:
	var top_y: int = clampi(int(map_height * funnel_top_y_ratio), 0, map_height - 1)
	var bottom_y: int = clampi(int(map_height * funnel_bottom_y_ratio), 0, map_height - 1)
	var center_x: int = map_width / 2

	for y in range(top_y, bottom_y + 1):
		var t: float = inverse_lerp(float(top_y), float(bottom_y), float(y))
		t = pow(t, funnel_curve_strength)

		var left_x: int = int(lerp(float(funnel_edge_margin), float(center_x - funnel_center_width / 2), t))
		var right_x: int = int(lerp(float(map_width - 1 - funnel_edge_margin), float(center_x + funnel_center_width / 2), t))

		for x in range(left_x, right_x + 1):
			_set_empty(x, y)

		if y > top_y:
			_set_empty(left_x + 1, y)
			_set_empty(right_x - 1, y)

	var last_main: Vector2i = _main_centers[_main_centers.size() - 1]
	var funnel_entry: Vector2i = Vector2i(map_width / 2, top_y + 2)
	_carve_soft_ramp_tunnel(last_main, funnel_entry, corridor_half_width)

	for i in range(_main_centers.size() - 2, -1, -1):
		var from_center: Vector2i = _main_centers[i]
		var target_y: int = top_y + _rng.randi_range(-2, 2)
		var target_x: int = map_width / 2 + _rng.randi_range(-10, 10)
		_carve_soft_ramp_tunnel(from_center, Vector2i(target_x, target_y), 2)

func _carve_bottom_exit_basin() -> void:
	var basin_center := Vector2i(map_width / 2, int(map_height * 0.90))
	var basin_w: int = 34
	var basin_h: int = 12
	_carve_room(basin_center, basin_w, basin_h)

	_exit_cell = Vector2i(map_width / 2, int(map_height * funnel_bottom_y_ratio) - 2)

	_clear_area(_exit_cell.x, _exit_cell.y, 4, 3)
	_make_floor(_exit_cell.x - exit_platform_width / 2, _exit_cell.x + exit_platform_width / 2, _exit_cell.y + 2, 2)

func _add_noise_blobs() -> void:
	for i in range(blob_count):
		var cx: int = _rng.randi_range(6, map_width - 7)
		var cy: int = _rng.randi_range(6, map_height - 7)
		var radius: int = _rng.randi_range(blob_radius_min, blob_radius_max)

		if cy > int(map_height * 0.82):
			continue

		if _rng.randf() < 0.55:
			_carve_blob(cx, cy, radius)
		else:
			_add_solid_blob(cx, cy, radius)

func _cleanup_map() -> void:
	for i in range(cleanup_iterations):
		var new_grid: Array = []

		for y in range(map_height):
			var row: Array = []
			for x in range(map_width):
				if x == 0 or y == 0 or x == map_width - 1 or y == map_height - 1:
					row.append(true)
					continue

				var solid_neighbors: int = _count_solid_neighbors(x, y)

				if _grid[y][x]:
					row.append(solid_neighbors >= cleanup_death_limit)
				else:
					row.append(solid_neighbors > cleanup_birth_limit)

			new_grid.append(row)

		_grid = new_grid

	for center in _main_centers:
		_clear_area(center.x, center.y, 8, 4)

	_connect_main_path()
	_carve_bottom_funnel()
	_carve_bottom_exit_basin()

func _finalize_spawn_and_exit() -> void:
	if _main_centers.is_empty():
		return

	var start_center: Vector2i = _main_centers[0]
	_player_cell = Vector2i(
		clampi(start_center.x - main_room_width_max / 4, 3, map_width - 4),
		start_center.y - 1
	)

	_clear_area(_player_cell.x, _player_cell.y, 3, 4)
	_make_floor(_player_cell.x - 4, _player_cell.x + 4, _player_cell.y + 2, 2)

	_clear_area(_exit_cell.x, _exit_cell.y, 4, 4)
	_make_floor(_exit_cell.x - exit_platform_width / 2, _exit_cell.x + exit_platform_width / 2, _exit_cell.y + 2, 2)

	for i in range(_main_centers.size() - 1):
		_carve_soft_ramp_tunnel(_main_centers[i], _main_centers[i + 1], corridor_half_width)

	_carve_soft_ramp_tunnel(_main_centers[_main_centers.size() - 1], Vector2i(map_width / 2, int(map_height * funnel_top_y_ratio) + 2), corridor_half_width)

func _carve_room(center: Vector2i, room_w: int, room_h: int) -> void:
	var half_w: int = room_w / 2
	var half_h: int = room_h / 2

	for y in range(center.y - half_h, center.y + half_h + 1):
		for x in range(center.x - half_w, center.x + half_w + 1):
			if not _is_inside(x, y):
				continue

			var nx: float = abs(float(x - center.x)) / max(1.0, float(half_w))
			var ny: float = abs(float(y - center.y)) / max(1.0, float(half_h))
			var dist: float = (nx * nx * 0.55) + (ny * ny * 1.35)

			if dist <= 1.0:
				_set_empty(x, y)
			elif dist <= 1.12 and _rng.randf() < 0.75:
				_set_empty(x, y)

func _widen_room_horizontally(center: Vector2i, room_w: int, room_h: int) -> void:
	var band_h: int = max(3, room_h / 3)
	var width_bonus: int = _rng.randi_range(6, 14)

	for y in range(center.y - band_h, center.y + band_h + 1):
		for x in range(center.x - room_w / 2 - width_bonus, center.x + room_w / 2 + width_bonus + 1):
			if not _is_inside(x, y):
				continue

			if _rng.randf() < 0.92:
				_set_empty(x, y)

func _carve_soft_ramp_tunnel(from_cell: Vector2i, to_cell: Vector2i, half_width: int) -> void:
	var steps: int = max(abs(to_cell.x - from_cell.x), abs(to_cell.y - from_cell.y))
	if steps <= 0:
		return

	var last_y: int = from_cell.y

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = Vector2(from_cell).lerp(Vector2(to_cell), t)

		var px: int = int(round(p.x)) + _rng.randi_range(-corridor_jitter, corridor_jitter) if i > 0 and i < steps else int(round(p.x))
		var py: int = int(round(p.y))

		if py < last_y - 1:
			py = last_y - 1
		if py > last_y + 2:
			py = last_y + 2

		last_y = py

		for oy in range(-half_width, half_width + 1):
			for ox in range(-half_width - 1, half_width + 2):
				var nx: int = px + ox
				var ny: int = py + oy
				if not _is_inside(nx, ny):
					continue

				var ellipse: float = (float(ox * ox) / float((half_width + 1) * (half_width + 1))) + (float(oy * oy) / float(max(1, half_width * half_width)))
				if ellipse <= 1.2:
					_set_empty(nx, ny)

		for support_y in range(py + 1, py + 4):
			for support_x in range(px - half_width, px + half_width + 1):
				if _is_inside(support_x, support_y) and _rng.randf() < 0.35:
					_grid[support_y][support_x] = true

func _carve_blob(cx: int, cy: int, radius: int) -> void:
	for y in range(cy - radius - 1, cy + radius + 2):
		for x in range(cx - radius - 1, cx + radius + 2):
			if not _is_inside(x, y):
				continue

			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			var d: float = sqrt(dx * dx + dy * dy)
			var threshold: float = float(radius) + _rng.randf_range(-1.4, 1.4)

			if d <= threshold:
				_set_empty(x, y)

func _add_solid_blob(cx: int, cy: int, radius: int) -> void:
	for y in range(cy - radius - 1, cy + radius + 2):
		for x in range(cx - radius - 1, cx + radius + 2):
			if not _is_inside(x, y):
				continue

			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			var d: float = sqrt(dx * dx + dy * dy)
			var threshold: float = float(radius) + _rng.randf_range(-1.0, 1.0)

			if d <= threshold:
				_grid[y][x] = true

func _count_solid_neighbors(cx: int, cy: int) -> int:
	var count: int = 0

	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue

			var nx: int = cx + ox
			var ny: int = cy + oy

			if nx < 0 or ny < 0 or nx >= map_width or ny >= map_height:
				count += 1
			elif _grid[ny][nx]:
				count += 1

	return count

func _clear_area(cx: int, cy: int, half_w: int, half_h: int) -> void:
	for y in range(cy - half_h, cy + half_h + 1):
		for x in range(cx - half_w, cx + half_w + 1):
			if _is_inside(x, y):
				_set_empty(x, y)

func _make_floor(x1: int, x2: int, y: int, thickness: int) -> void:
	for yy in range(y, y + thickness):
		for xx in range(x1, x2 + 1):
			if _is_inside(xx, yy):
				_grid[yy][xx] = true

func _set_empty(x: int, y: int) -> void:
	if _is_inside(x, y):
		_grid[y][x] = false

func _is_inside(x: int, y: int) -> bool:
	return x > 0 and y > 0 and x < map_width - 1 and y < map_height - 1

func _draw_to_tilemap() -> void:
	tilemap_layer.clear()

	var solid_cells: Array[Vector2i] = []

	for y in range(map_height):
		for x in range(map_width):
			if _grid[y][x]:
				solid_cells.append(Vector2i(x, y))

	if solid_cells.is_empty():
		return

	BetterTerrain.set_cells(tilemap_layer, solid_cells, 0)
	BetterTerrain.update_terrain_cells(tilemap_layer, solid_cells, true)
	
func _position_markers() -> void:
	var tile_size: Vector2 = tilemap_layer.tile_set.tile_size

	if player_spawn_marker != null:
		player_spawn_marker.global_position = tilemap_layer.to_global(Vector2(
			(_player_cell.x + 0.5) * tile_size.x,
			(_player_cell.y + 0.5) * tile_size.y
		))

	if exit_spawn_marker != null:
		exit_spawn_marker.global_position = tilemap_layer.to_global(Vector2(
			(_exit_cell.x + 0.5) * tile_size.x,
			(_exit_cell.y + 0.5) * tile_size.y
		))

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if tilemap_layer == null:
		warnings.append("tilemap_layer is not assigned.")

	if tilemap_layer != null and tilemap_layer.tile_set == null:
		warnings.append("tilemap_layer has no TileSet assigned.")

	return warnings
