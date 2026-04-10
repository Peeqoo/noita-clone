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
@export var start_room_center_x: int = 18
@export var start_room_center_y: int = 24
@export var start_room_radius_x: int = 12
@export var start_room_radius_y: int = 8

@export_group("Noise")
@export var noise_frequency: float = 0.045
@export var noise_threshold: float = 0.08
@export var noise_octaves: int = 4
@export var noise_lacunarity: float = 2.0
@export var noise_gain: float = 0.5

@export_group("Vertical Bias")
@export var bias_right_strength: float = 0.10
@export var bias_down_strength: float = 0.18

@export_group("Bottom Funnel")
@export var use_bottom_funnel: bool = true
@export_range(0.0, 1.0, 0.01) var funnel_center_x_ratio: float = 0.50
@export_range(0.0, 1.0, 0.01) var funnel_top_y_ratio: float = 0.76
@export_range(0.0, 1.0, 0.01) var funnel_bottom_y_ratio: float = 0.96
@export var funnel_top_half_width: int = 90
@export var funnel_bottom_half_width: int = 18
@export var funnel_wall_irregularity: int = 2
@export var funnel_flat_bottom_extra_width: int = 12
@export var funnel_flat_bottom_height: int = 3

@export_group("Horizontal Platform Pass")
@export var widen_mid_platforms: bool = true
@export var platform_passes: int = 2
@export var platform_zone_top_ratio: float = 0.25
@export var platform_zone_bottom_ratio: float = 0.78
@export var min_platform_span_to_keep: int = 4
@export var max_platform_span_to_expand: int = 18
@export var platform_expand_each_side: int = 2
@export var platform_required_headroom: int = 4

@export_group("Cleanup")
@export var smoothing_passes: int = 2
@export_range(0, 8, 1) var solid_if_neighbor_count_at_least: int = 5
@export var connect_regions: bool = true
@export var remove_unreachable_open_areas: bool = true
@export var connector_radius: int = 2

@export_group("Painting")
@export var use_terrain_connect: bool = true
@export var terrain_set_id: int = 0
@export var solid_terrain_id: int = 0
@export var fallback_source_id: int = 0
@export var fallback_atlas_coords: Vector2i = Vector2i.ZERO
@export var fallback_alternative_tile: int = 0

@export var use_better_terrain: bool = true
@export var better_terrain_type: int = 0

@export_tool_button("Generate Noise Cave") var generate_level_button := _generate_level_from_button
@export_tool_button("Clear Cave") var clear_level_button := _clear_level_from_button

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _noise: FastNoiseLite
var _grid: Array[PackedByteArray] = []

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
		push_error("noise_cave_generator.gd: solid_layer is missing.")
		return

	solid_layer.clear()
	solid_layer.update_internals()


func generate_level() -> void:
	if solid_layer == null:
		push_error("noise_cave_generator.gd: solid_layer is missing.")
		return

	_setup_rng()
	_setup_noise()
	_create_filled_grid()

	var start_center := Vector2i(start_room_center_x, start_room_center_y)
	start_center.x = clampi(start_center.x, border_size + 10, map_width - border_size - 10)
	start_center.y = clampi(start_center.y, border_size + 10, map_height - border_size - 10)

	_carve_start_room(start_center)
	_apply_noise_pass()

	for i in range(smoothing_passes):
		_smooth_map()

	_carve_start_room(start_center)

	if connect_regions:
		_connect_all_open_regions_to_main(start_center)

	if remove_unreachable_open_areas:
		_remove_unreachable_open_areas_from(start_center)

	if widen_mid_platforms:
		for i in range(platform_passes):
			_expand_horizontal_platforms_once()

	if use_bottom_funnel:
		_apply_bottom_funnel_pass()

	if connect_regions:
		_connect_all_open_regions_to_main(start_center)

	if remove_unreachable_open_areas:
		_remove_unreachable_open_areas_from(start_center)

	if widen_mid_platforms:
		for i in range(platform_passes):
			_expand_horizontal_platforms_once()

	_paint_tiles()
	_update_spawn_markers(start_center)


func _setup_rng() -> void:
	if use_random_seed:
		_rng.seed = Time.get_ticks_usec()
	else:
		_rng.seed = fixed_seed


func _setup_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = int(_rng.randi())
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = noise_octaves
	_noise.fractal_lacunarity = noise_lacunarity
	_noise.fractal_gain = noise_gain


func _create_filled_grid() -> void:
	_grid.clear()

	for y in range(map_height):
		var row := PackedByteArray()
		row.resize(map_width)

		for x in range(map_width):
			row[x] = 1

		_grid.append(row)


func _carve_start_room(center: Vector2i) -> void:
	_carve_ellipse(center, start_room_radius_x, start_room_radius_y)


func _apply_noise_pass() -> void:
	for y in range(map_height):
		for x in range(map_width):
			if _is_border_cell(x, y):
				_set_solid(x, y)
				continue

			var n := _noise.get_noise_2d(float(x), float(y))

			var right_bias := (float(x) / float(max(1, map_width - 1))) * bias_right_strength
			var down_bias := (float(y) / float(max(1, map_height - 1))) * bias_down_strength
			var biased_value := n + right_bias + down_bias

			if biased_value > noise_threshold:
				_set_open(x, y)


func _apply_bottom_funnel_pass() -> void:
	var center_x := int(round(map_width * funnel_center_x_ratio))
	var top_y := int(round(map_height * funnel_top_y_ratio))
	var bottom_y := int(round(map_height * funnel_bottom_y_ratio))

	top_y = clampi(top_y, border_size + 8, map_height - border_size - 8)
	bottom_y = clampi(bottom_y, top_y + 6, map_height - border_size - 2)
	center_x = clampi(center_x, border_size + funnel_top_half_width + 1, map_width - border_size - funnel_top_half_width - 2)

	for y in range(top_y, bottom_y + 1):
		var t := inverse_lerp(float(top_y), float(bottom_y), float(y))
		var current_half_width := int(round(lerpf(float(funnel_top_half_width), float(funnel_bottom_half_width), t)))

		var left_x := center_x - current_half_width + _rng.randi_range(-funnel_wall_irregularity, funnel_wall_irregularity)
		var right_x := center_x + current_half_width + _rng.randi_range(-funnel_wall_irregularity, funnel_wall_irregularity)

		left_x = clampi(left_x, border_size + 1, map_width - border_size - 2)
		right_x = clampi(right_x, border_size + 1, map_width - border_size - 2)

		for x in range(left_x, right_x + 1):
			_set_open(x, y)

	var flat_bottom_y_start := bottom_y - funnel_flat_bottom_height + 1
	for y in range(flat_bottom_y_start, bottom_y + 1):
		if y < border_size or y >= map_height - border_size:
			continue

		var half_width := funnel_bottom_half_width + funnel_flat_bottom_extra_width
		var left_x := center_x - half_width
		var right_x := center_x + half_width

		for x in range(left_x, right_x + 1):
			if _is_inside(x, y):
				_set_open(x, y)


func _expand_horizontal_platforms_once() -> void:
	var to_open: Dictionary = {}
	var zone_top_y := int(round(map_height * platform_zone_top_ratio))
	var zone_bottom_y := int(round(map_height * platform_zone_bottom_ratio))

	zone_top_y = clampi(zone_top_y, border_size + 2, map_height - border_size - 4)
	zone_bottom_y = clampi(zone_bottom_y, zone_top_y + 1, map_height - border_size - 3)

	for y in range(zone_top_y, zone_bottom_y + 1):
		for x in range(border_size + 2, map_width - border_size - 2):
			if not _is_standable(x, y):
				continue

			if use_bottom_funnel and _is_in_bottom_funnel_zone(x, y):
				continue

			var span := _get_platform_span(x, y)
			if span < min_platform_span_to_keep:
				_mark_platform_expansion(to_open, x, y, platform_expand_each_side + 1)
			elif span <= max_platform_span_to_expand and _has_enough_platform_headroom(x, y):
				_mark_platform_expansion(to_open, x, y, platform_expand_each_side)

	for key in to_open.keys():
		var cell: Vector2i = key
		_set_open(cell.x, cell.y)


func _mark_platform_expansion(target: Dictionary, x: int, y: int, expand_each_side: int) -> void:
	var left_x := x
	while left_x - 1 >= border_size + 1 and _is_standable(left_x - 1, y):
		left_x -= 1

	var right_x := x
	while right_x + 1 < map_width - border_size - 1 and _is_standable(right_x + 1, y):
		right_x += 1

	for nx in range(left_x - expand_each_side, right_x + expand_each_side + 1):
		if not _is_inside(nx, y):
			continue
		if _is_border_cell(nx, y):
			continue
		if _can_open_platform_cell(nx, y):
			target[Vector2i(nx, y)] = true


func _can_open_platform_cell(x: int, y: int) -> bool:
	if not _is_inside(x, y):
		return false
	if y - platform_required_headroom < 0:
		return false
	if y + 1 >= map_height:
		return false

	if not _is_solid(x, y):
		return false

	if not _is_solid(x, y + 1):
		return false

	for i in range(1, platform_required_headroom + 1):
		if not _is_open(x, y - i):
			return false

	return true


func _has_enough_platform_headroom(x: int, y: int) -> bool:
	for i in range(1, platform_required_headroom + 1):
		if not _is_inside(x, y - i):
			return false
		if not _is_open(x, y - i):
			return false

	var left_open := 0
	var right_open := 0

	for i in range(1, 6):
		if _is_inside(x - i, y - 1) and _is_open(x - i, y - 1):
			left_open += 1
		if _is_inside(x + i, y - 1) and _is_open(x + i, y - 1):
			right_open += 1

	return left_open >= 2 and right_open >= 2


func _get_platform_span(x: int, y: int) -> int:
	var left_x := x
	while left_x - 1 >= border_size + 1 and _is_standable(left_x - 1, y):
		left_x -= 1

	var right_x := x
	while right_x + 1 < map_width - border_size - 1 and _is_standable(right_x + 1, y):
		right_x += 1

	return right_x - left_x + 1


func _is_in_bottom_funnel_zone(x: int, y: int) -> bool:
	var center_x := int(round(map_width * funnel_center_x_ratio))
	var top_y := int(round(map_height * funnel_top_y_ratio))
	var bottom_y := int(round(map_height * funnel_bottom_y_ratio))

	if y < top_y or y > bottom_y:
		return false

	var t := inverse_lerp(float(top_y), float(bottom_y), float(y))
	var half_width := int(round(lerpf(float(funnel_top_half_width), float(funnel_bottom_half_width), t)))
	half_width += funnel_wall_irregularity + funnel_flat_bottom_extra_width + 2

	return x >= center_x - half_width and x <= center_x + half_width


func _carve_ellipse(center: Vector2i, rx: int, ry: int) -> void:
	for y in range(center.y - ry - 1, center.y + ry + 2):
		for x in range(center.x - rx - 1, center.x + rx + 2):
			if not _is_inside(x, y):
				continue

			var dx := float(x - center.x) / float(max(1, rx))
			var dy := float(y - center.y) / float(max(1, ry))

			if dx * dx + dy * dy <= 1.0:
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

	var main_region := _flood_fill_open(main_open)
	var other_regions := _collect_open_regions(main_region)

	for region in other_regions:
		if region.is_empty():
			continue

		var region_cell: Vector2i = region[_rng.randi_range(0, region.size() - 1)]
		var target := _find_closest_cell_in_region(region_cell, main_region)

		if target != Vector2i(-1, -1):
			_carve_line_tunnel(region_cell, target, connector_radius)
			main_region = _flood_fill_open(main_open)


func _collect_open_regions(main_region: Dictionary) -> Array[Array]:
	var regions: Array[Array] = []
	var checked: Dictionary = {}

	for key in main_region.keys():
		checked[key] = true

	for y in range(map_height):
		for x in range(map_width):
			var cell := Vector2i(x, y)

			if checked.has(cell):
				continue
			if not _is_open(x, y):
				continue

			var region_dict := _flood_fill_open(cell)
			var region_cells: Array = []

			for region_key in region_dict.keys():
				checked[region_key] = true
				region_cells.append(region_key)

			if not region_cells.is_empty():
				regions.append(region_cells)

	return regions


func _find_closest_cell_in_region(from_cell: Vector2i, region: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := INF

	for key in region.keys():
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


func _carve_circle(center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _is_inside(x, y):
				continue

			if center.distance_to(Vector2(x, y)) <= float(radius) + 0.35:
				_set_open(x, y)


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

func _update_spawn_markers(start_guess: Vector2i) -> void:
	var start_cell := _find_standable_cell_near(start_guess)
	var exit_cell := _find_exit_cell_in_bottom_funnel()

	if exit_cell == Vector2i(-1, -1):
		var fallback_exit_guess := Vector2i(int(round(map_width * 0.5)), int(round(map_height * 0.9)))
		exit_cell = _find_standable_cell_near(fallback_exit_guess)

	if player_spawn_marker != null and start_cell != Vector2i(-1, -1):
		player_spawn_marker.global_position = solid_layer.to_global(solid_layer.map_to_local(start_cell))

	if exit_spawn_marker != null and exit_cell != Vector2i(-1, -1):
		exit_spawn_marker.global_position = solid_layer.to_global(solid_layer.map_to_local(exit_cell))


func _find_exit_cell_in_bottom_funnel() -> Vector2i:
	var center_x := int(round(map_width * funnel_center_x_ratio))
	var top_y := int(round(map_height * funnel_top_y_ratio))
	var bottom_y := int(round(map_height * funnel_bottom_y_ratio))

	for y in range(bottom_y, top_y - 1, -1):
		for offset in range(0, map_width):
			var candidates: Array[int] = [center_x + offset]
			if offset != 0:
				candidates.append(center_x - offset)

			for x in candidates:
				if not _is_inside(x, y):
					continue
				if _is_standable(x, y):
					return Vector2i(x, y)

	return Vector2i(-1, -1)


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
