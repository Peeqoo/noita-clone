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
@export var border_size: int = 10

@export_group("Noise")
@export var noise: FastNoiseLite
@export var noise_threshold: float = 0.2

@export_group("Start Room")
@export var start_room_center_x: int = 18
@export var start_room_center_y: int = 24
@export var start_room_radius_x: int = 12
@export var start_room_radius_y: int = 8

@export_group("Exit Room Position")
@export var exit_room_center_x: int = 110
@export var exit_room_center_y: int = 124

@export_group("Exit Room Shape")
@export var use_exit_funnel: bool = true
@export var exit_funnel_top_half_width: int = 0
@export var exit_funnel_neck_half_width: int = 0
@export var exit_funnel_wall_irregularity: int = 0
@export var exit_room_half_width: int = 50
@export var exit_room_half_height: int = 6
@export var exit_room_flat_floor_half_width: int = 0
@export var exit_room_flat_floor_height: int = 0
@export var exit_room_side_extra_width: int = 0

@export_group("Vertical Bias")
@export var bias_right_strength: float = 0.0
@export var bias_down_strength: float = 0.2

@export_group("Worms")
@export var use_worms: bool = true
@export var worm_count: int = 8
@export var worm_radius_min: int = 2
@export var worm_radius_max: int = 4
@export var worm_steps_min: int = 45
@export var worm_steps_max: int = 110
@export var worm_turn_strength: float = 0.28
@export var worm_vertical_bias: float = 0.03
@export var worm_angle_start_deg: float = 8.0
@export var worm_angle_end_deg: float = 82.0
@export var worm_angle_randomness_deg: float = 8.0
@export var worm_outward_spread_strength: float = 0.22
@export var worm_snake_strength: float = 0.40
@export var worm_snake_frequency: float = 0.22

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
@export var remove_other_open_areas: bool = false

@export_group("Painting")
@export var use_terrain_connect: bool = true
@export var terrain_set_id: int = 0
@export var solid_terrain_id: int = 0
@export var fallback_source_id: int = 0
@export var fallback_atlas_coords: Vector2i = Vector2i.ZERO
@export var fallback_alternative_tile: int = 0
@export var use_better_terrain: bool = true
@export var better_terrain_type: int = 0

@export_tool_button("Generate Noise Cave") var generate_level_button = _generate_level_from_button
@export_tool_button("Clear Cave") var clear_level_button = _clear_level_from_button

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
		push_error("fast_noise_generator.gd: solid_layer is missing.")
		return

	solid_layer.clear()
	solid_layer.update_internals()
	_grid.clear()


func generate_level() -> void:
	if solid_layer == null:
		push_error("fast_noise_generator.gd: solid_layer is missing.")
		return

	if noise == null:
		push_error("fast_noise_generator.gd: noise is missing. Assign a FastNoiseLite resource in the inspector.")
		return

	_setup_rng()
	_setup_noise()
	_create_filled_grid()

	var local_border: int = _safe_int(border_size, 10)
	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)

	var start_center: Vector2i = Vector2i(
		_safe_int(start_room_center_x, 18),
		_safe_int(start_room_center_y, 24)
	)
	start_center.x = clampi(start_center.x, local_border + 10, local_map_width - local_border - 10)
	start_center.y = clampi(start_center.y, local_border + 10, local_map_height - local_border - 10)

	var exit_center: Vector2i = Vector2i(
		_safe_int(exit_room_center_x, int(local_map_width / 2.0)),
		_safe_int(exit_room_center_y, local_map_height - 16)
	)
	exit_center.x = clampi(
		exit_center.x,
		local_border + _safe_int(exit_room_half_width, 50) + 4,
		local_map_width - local_border - _safe_int(exit_room_half_width, 50) - 4
	)
	exit_center.y = clampi(
		exit_center.y,
		local_border + 20,
		local_map_height - local_border - _safe_int(exit_room_half_height, 6) - 2
	)

	_carve_start_room(start_center)
	_carve_exit_room(exit_center)
	_apply_noise_pass()

	var local_smoothing_passes: int = _safe_int(smoothing_passes, 2)
	for _i in range(local_smoothing_passes):
		_smooth_map()

	_carve_start_room(start_center)
	_carve_exit_room(exit_center)

	if use_worms:
		_carve_worms_from_start(start_center)
		_carve_start_room(start_center)
		_carve_exit_room(exit_center)

	if widen_mid_platforms:
		var local_platform_passes: int = _safe_int(platform_passes, 2)
		for _i in range(local_platform_passes):
			_expand_horizontal_platforms_once()

	_carve_start_room(start_center)
	_carve_exit_room(exit_center)

	if remove_other_open_areas:
		_remove_open_areas_connected_to_rooms_only(start_center, exit_center)
		_carve_start_room(start_center)
		_carve_exit_room(exit_center)

	_paint_tiles()
	_update_spawn_markers(start_center, exit_center)


func _setup_rng() -> void:
	if use_random_seed:
		_rng.seed = Time.get_ticks_usec()
	else:
		_rng.seed = _safe_int(fixed_seed, 1001)


func _setup_noise() -> void:
	_noise = noise.duplicate(true) as FastNoiseLite

	if use_random_seed:
		_noise.seed = int(_rng.randi())
	else:
		_noise.seed = _safe_int(fixed_seed, 1001)


func _create_filled_grid() -> void:
	_grid.clear()

	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)

	for _y in range(local_map_height):
		var row: PackedByteArray = PackedByteArray()
		row.resize(local_map_width)

		for x in range(local_map_width):
			row[x] = 1

		_grid.append(row)


func _carve_start_room(center: Vector2i) -> void:
	_carve_ellipse(
		center,
		_safe_int(start_room_radius_x, 12),
		_safe_int(start_room_radius_y, 8)
	)


func _carve_exit_room(center: Vector2i) -> void:
	var local_map_height: int = _safe_int(map_height, 140)
	var local_border: int = _safe_int(border_size, 10)
	var local_exit_room_half_width: int = _safe_int(exit_room_half_width, 50)
	var local_exit_room_half_height: int = _safe_int(exit_room_half_height, 6)
	var local_exit_room_flat_floor_half_width: int = _safe_int(exit_room_flat_floor_half_width, 0)
	var local_exit_room_flat_floor_height: int = _safe_int(exit_room_flat_floor_height, 0)
	var local_exit_room_side_extra_width: int = _safe_int(exit_room_side_extra_width, 0)
	var local_exit_funnel_top_half_width: int = _safe_int(exit_funnel_top_half_width, 0)
	var local_exit_funnel_neck_half_width: int = _safe_int(exit_funnel_neck_half_width, 0)
	var local_exit_funnel_wall_irregularity: int = _safe_int(exit_funnel_wall_irregularity, 0)

	var chamber_center_y: int = center.y
	var chamber_top_y: int = chamber_center_y - local_exit_room_half_height
	var neck_top_y: int = maxi(local_border + 2, chamber_top_y - 12)
	var neck_bottom_y: int = chamber_top_y + 1

	if use_exit_funnel and local_exit_funnel_top_half_width > 0 and local_exit_funnel_neck_half_width > 0:
		for y in range(neck_top_y, neck_bottom_y + 1):
			var t: float = inverse_lerp(float(neck_top_y), float(maxi(neck_top_y + 1, neck_bottom_y)), float(y))
			var current_half_width: int = int(round(lerpf(float(local_exit_funnel_top_half_width), float(local_exit_funnel_neck_half_width), t)))

			var left_x: int = center.x - current_half_width + _rng.randi_range(-local_exit_funnel_wall_irregularity, local_exit_funnel_wall_irregularity)
			var right_x: int = center.x + current_half_width + _rng.randi_range(-local_exit_funnel_wall_irregularity, local_exit_funnel_wall_irregularity)

			for x in range(left_x, right_x + 1):
				if _is_inside(x, y):
					_set_open(x, y)

	_carve_ellipse(center, local_exit_room_half_width, local_exit_room_half_height)

	if local_exit_room_side_extra_width > 0:
		for y in range(chamber_center_y, chamber_center_y + local_exit_room_half_height + 1):
			var depth_t: float = inverse_lerp(float(chamber_center_y), float(chamber_center_y + local_exit_room_half_height), float(y))
			var extra_width: int = int(round(lerpf(2.0, float(local_exit_room_side_extra_width), depth_t)))

			for x in range(center.x - local_exit_room_half_width - extra_width, center.x + local_exit_room_half_width + extra_width + 1):
				if _is_inside(x, y):
					_set_open(x, y)

	if local_exit_room_flat_floor_half_width > 0 and local_exit_room_flat_floor_height > 0:
		var flat_floor_start_y: int = chamber_center_y + local_exit_room_half_height - local_exit_room_flat_floor_height
		var flat_floor_end_y: int = chamber_center_y + local_exit_room_half_height

		for y in range(flat_floor_start_y, flat_floor_end_y + 1):
			if y < local_border or y >= local_map_height - local_border:
				continue

			for x in range(center.x - local_exit_room_flat_floor_half_width, center.x + local_exit_room_flat_floor_half_width + 1):
				if _is_inside(x, y):
					_set_open(x, y)


func _apply_noise_pass() -> void:
	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)
	var local_threshold: float = _safe_float(noise_threshold, 0.2)
	var local_bias_right: float = _safe_float(bias_right_strength, 0.0)
	var local_bias_down: float = _safe_float(bias_down_strength, 0.2)

	for y in range(local_map_height):
		for x in range(local_map_width):
			if _is_border_cell(x, y):
				_set_solid(x, y)
				continue

			var n: float = _noise.get_noise_2d(float(x), float(y))
			var right_bias: float = (float(x) / float(maxi(1, local_map_width - 1))) * local_bias_right
			var down_bias: float = (float(y) / float(maxi(1, local_map_height - 1))) * local_bias_down
			var biased_value: float = n + right_bias + down_bias

			if biased_value > local_threshold:
				_set_open(x, y)


func _carve_worms_from_start(start_center: Vector2i) -> void:
	var local_count: int = maxi(1, _safe_int(worm_count, 8))
	var local_radius_min: int = maxi(1, _safe_int(worm_radius_min, 2))
	var local_radius_max: int = maxi(local_radius_min, _safe_int(worm_radius_max, 4))
	var local_steps_min: int = maxi(1, _safe_int(worm_steps_min, 45))
	var local_steps_max: int = maxi(local_steps_min, _safe_int(worm_steps_max, 110))
	var local_turn_strength: float = _safe_float(worm_turn_strength, 0.28)
	var local_vertical_bias: float = _safe_float(worm_vertical_bias, 0.03)

	var sector_start: float = deg_to_rad(_safe_float(worm_angle_start_deg, 8.0))
	var sector_end: float = deg_to_rad(_safe_float(worm_angle_end_deg, 82.0))
	var angle_randomness: float = deg_to_rad(_safe_float(worm_angle_randomness_deg, 8.0))
	var outward_spread_strength: float = _safe_float(worm_outward_spread_strength, 0.22)
	var snake_strength: float = _safe_float(worm_snake_strength, 0.40)
	var snake_frequency: float = _safe_float(worm_snake_frequency, 0.22)

	var local_border: int = _safe_int(border_size, 10)
	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)

	for worm_index in range(local_count):
		var position: Vector2 = Vector2(start_center)

		var spread_t: float = 0.5 if local_count == 1 else float(worm_index) / float(local_count - 1)
		var fan_angle: float = lerpf(sector_start, sector_end, spread_t)
		fan_angle += _rng.randf_range(-angle_randomness, angle_randomness)
		fan_angle = clampf(fan_angle, sector_start, sector_end)

		var angle: float = fan_angle + _rng.randf_range(-0.18, 0.18)
		angle = clampf(angle, sector_start, sector_end)

		var steps: int = _rng.randi_range(local_steps_min, local_steps_max)
		var radius: int = _rng.randi_range(local_radius_min, local_radius_max)

		var snake_phase: float = _rng.randf_range(0.0, TAU)
		var snake_dir: float = 1.0 if _rng.randf() < 0.5 else -1.0

		for step_index in range(steps):
			_carve_circle(Vector2i(roundi(position.x), roundi(position.y)), radius)

			var progress: float = float(step_index) / float(maxi(1, steps - 1))

			# Schlangenbewegung
			snake_phase += snake_frequency
			var snake_offset: float = sin(snake_phase) * snake_strength * snake_dir

			# Zufälliges Kurvenverhalten
			angle += _rng.randf_range(-local_turn_strength, local_turn_strength)

			# Leichte Tendenz nach unten
			angle += local_vertical_bias

			# Mit der Distanz weiter in den eigenen Fächerbereich auseinanderdriften,
			# aber nicht als harte Gerade.
			angle += (fan_angle - angle) * outward_spread_strength * progress

			# Schlangenoffset dazu
			angle += snake_offset * 0.08

			# Im positiven Bereich halten
			angle = clampf(angle, sector_start, sector_end)

			var direction: Vector2 = Vector2.RIGHT.rotated(angle)
			var step_length: float = _rng.randf_range(0.85, 1.55)
			position += direction * step_length

			position.x = clampf(position.x, float(local_border + 2), float(local_map_width - local_border - 3))
			position.y = clampf(position.y, float(local_border + 2), float(local_map_height - local_border - 3))

			if _rng.randf() < 0.10:
				radius = _rng.randi_range(local_radius_min, local_radius_max)


func _expand_horizontal_platforms_once() -> void:
	var to_open: Dictionary = {}
	var local_map_height: int = _safe_int(map_height, 140)
	var local_map_width: int = _safe_int(map_width, 220)
	var local_border: int = _safe_int(border_size, 10)
	var local_platform_zone_top_ratio: float = _safe_float(platform_zone_top_ratio, 0.25)
	var local_platform_zone_bottom_ratio: float = _safe_float(platform_zone_bottom_ratio, 0.78)
	var local_min_platform_span_to_keep: int = _safe_int(min_platform_span_to_keep, 4)
	var local_max_platform_span_to_expand: int = _safe_int(max_platform_span_to_expand, 18)
	var local_platform_expand_each_side: int = _safe_int(platform_expand_each_side, 2)

	var zone_top_y: int = int(round(local_map_height * local_platform_zone_top_ratio))
	var zone_bottom_y: int = int(round(local_map_height * local_platform_zone_bottom_ratio))

	zone_top_y = clampi(zone_top_y, local_border + 2, local_map_height - local_border - 4)
	zone_bottom_y = clampi(zone_bottom_y, zone_top_y + 1, local_map_height - local_border - 3)

	for y in range(zone_top_y, zone_bottom_y + 1):
		for x in range(local_border + 2, local_map_width - local_border - 2):
			if not _is_standable(x, y):
				continue

			if _is_in_exit_room_zone(x, y):
				continue
			if _is_in_start_room_zone(x, y):
				continue

			var span: int = _get_platform_span(x, y)

			if span < local_min_platform_span_to_keep:
				_mark_platform_expansion(to_open, x, y, local_platform_expand_each_side + 1)
			elif span <= local_max_platform_span_to_expand and _has_enough_platform_headroom(x, y):
				_mark_platform_expansion(to_open, x, y, local_platform_expand_each_side)

	for key in to_open.keys():
		var cell: Vector2i = key as Vector2i
		_set_open(cell.x, cell.y)


func _mark_platform_expansion(target: Dictionary, x: int, y: int, expand_each_side: int) -> void:
	var local_border: int = _safe_int(border_size, 10)
	var local_map_width: int = _safe_int(map_width, 220)

	var left_x: int = x
	while left_x - 1 >= local_border + 1 and _is_standable(left_x - 1, y):
		left_x -= 1

	var right_x: int = x
	while right_x + 1 < local_map_width - local_border - 1 and _is_standable(right_x + 1, y):
		right_x += 1

	for nx in range(left_x - expand_each_side, right_x + expand_each_side + 1):
		if not _is_inside(nx, y):
			continue
		if _is_border_cell(nx, y):
			continue
		if _can_open_platform_cell(nx, y):
			target[Vector2i(nx, y)] = true


func _can_open_platform_cell(x: int, y: int) -> bool:
	var local_platform_required_headroom: int = _safe_int(platform_required_headroom, 4)
	var local_map_height: int = _safe_int(map_height, 140)

	if not _is_inside(x, y):
		return false
	if y - local_platform_required_headroom < 0:
		return false
	if y + 1 >= local_map_height:
		return false
	if not _is_solid(x, y):
		return false
	if not _is_solid(x, y + 1):
		return false

	for i in range(1, local_platform_required_headroom + 1):
		if not _is_open(x, y - i):
			return false

	return true


func _has_enough_platform_headroom(x: int, y: int) -> bool:
	var local_platform_required_headroom: int = _safe_int(platform_required_headroom, 4)

	for i in range(1, local_platform_required_headroom + 1):
		if not _is_inside(x, y - i):
			return false
		if not _is_open(x, y - i):
			return false

	var left_open: int = 0
	var right_open: int = 0

	for i in range(1, 6):
		if _is_inside(x - i, y - 1) and _is_open(x - i, y - 1):
			left_open += 1
		if _is_inside(x + i, y - 1) and _is_open(x + i, y - 1):
			right_open += 1

	return left_open >= 2 and right_open >= 2


func _get_platform_span(x: int, y: int) -> int:
	var local_border: int = _safe_int(border_size, 10)
	var local_map_width: int = _safe_int(map_width, 220)

	var left_x: int = x
	while left_x - 1 >= local_border + 1 and _is_standable(left_x - 1, y):
		left_x -= 1

	var right_x: int = x
	while right_x + 1 < local_map_width - local_border - 1 and _is_standable(right_x + 1, y):
		right_x += 1

	return right_x - left_x + 1


func _is_in_start_room_zone(x: int, y: int) -> bool:
	var cx: int = _safe_int(start_room_center_x, 18)
	var cy: int = _safe_int(start_room_center_y, 24)
	var rx: int = _safe_int(start_room_radius_x, 12)
	var ry: int = _safe_int(start_room_radius_y, 8)

	return x >= cx - rx - 6 and x <= cx + rx + 6 and y >= cy - ry - 6 and y <= cy + ry + 6


func _is_in_exit_room_zone(x: int, y: int) -> bool:
	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)

	var local_exit_room_center_x: int = _safe_int(exit_room_center_x, int(local_map_width / 2.0))
	var local_exit_room_center_y: int = _safe_int(exit_room_center_y, local_map_height - 16)
	var local_exit_room_half_width: int = _safe_int(exit_room_half_width, 50)
	var local_exit_room_half_height: int = _safe_int(exit_room_half_height, 6)
	var local_exit_funnel_top_half_width: int = _safe_int(exit_funnel_top_half_width, 0)

	var zone_left: int = local_exit_room_center_x - local_exit_room_half_width - 12
	var zone_right: int = local_exit_room_center_x + local_exit_room_half_width + 12
	var zone_top: int = local_exit_room_center_y - local_exit_room_half_height - 16
	var zone_bottom: int = local_exit_room_center_y + local_exit_room_half_height + 4

	if use_exit_funnel and local_exit_funnel_top_half_width > 0:
		zone_left = mini(zone_left, local_exit_room_center_x - local_exit_funnel_top_half_width - 4)
		zone_right = maxi(zone_right, local_exit_room_center_x + local_exit_funnel_top_half_width + 4)

	return x >= zone_left and x <= zone_right and y >= zone_top and y <= zone_bottom


func _carve_ellipse(center: Vector2i, rx: int, ry: int) -> void:
	for y in range(center.y - ry - 1, center.y + ry + 2):
		for x in range(center.x - rx - 1, center.x + rx + 2):
			if not _is_inside(x, y):
				continue

			var dx: float = float(x - center.x) / float(maxi(1, rx))
			var dy: float = float(y - center.y) / float(maxi(1, ry))

			if dx * dx + dy * dy <= 1.0:
				_set_open(x, y)


func _smooth_map() -> void:
	var new_grid: Array[PackedByteArray] = []
	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)
	var local_solid_if_neighbor_count_at_least: int = _safe_int(solid_if_neighbor_count_at_least, 5)

	for y in range(local_map_height):
		var row: PackedByteArray = PackedByteArray()
		row.resize(local_map_width)

		for x in range(local_map_width):
			if _is_border_cell(x, y):
				row[x] = 1
				continue

			var solid_neighbors: int = _count_solid_neighbors_8(x, y)
			row[x] = 1 if solid_neighbors >= local_solid_if_neighbor_count_at_least else 0

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


func _remove_open_areas_connected_to_rooms_only(start_center: Vector2i, exit_center: Vector2i) -> void:
	var preserve: Dictionary = {}

	var start_open: Vector2i = _find_nearest_open_to(start_center)
	if start_open != Vector2i(-1, -1):
		var start_region: Dictionary = _flood_fill_open(start_open)
		for key in start_region.keys():
			preserve[key] = true

	var exit_open: Vector2i = _find_nearest_open_to(exit_center)
	if exit_open != Vector2i(-1, -1):
		var exit_region: Dictionary = _flood_fill_open(exit_open)
		for key in exit_region.keys():
			preserve[key] = true

	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)

	for y in range(local_map_height):
		for x in range(local_map_width):
			var cell: Vector2i = Vector2i(x, y)
			if _is_open(x, y) and not preserve.has(cell):
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

	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)
	var solid_cells: Array[Vector2i] = []

	for y in range(local_map_height):
		for x in range(local_map_width):
			if _is_solid(x, y):
				solid_cells.append(Vector2i(x, y))

	if solid_cells.is_empty():
		solid_layer.update_internals()
		return

	if use_better_terrain:
		BetterTerrain.set_cells(solid_layer, solid_cells, _safe_int(better_terrain_type, 0))
		BetterTerrain.update_terrain_cells(solid_layer, solid_cells, true)
	elif use_terrain_connect:
		solid_layer.set_cells_terrain_connect(
			solid_cells,
			_safe_int(terrain_set_id, 0),
			_safe_int(solid_terrain_id, 0),
			true
		)
	else:
		for cell in solid_cells:
			solid_layer.set_cell(
				cell,
				_safe_int(fallback_source_id, 0),
				fallback_atlas_coords,
				_safe_int(fallback_alternative_tile, 0)
			)

	solid_layer.update_internals()


func _update_spawn_markers(start_center: Vector2i, exit_center: Vector2i) -> void:
	var start_cell: Vector2i = _find_standable_cell_near(start_center)
	var exit_cell: Vector2i = _find_standable_cell_near(
		Vector2i(exit_center.x, exit_center.y + maxi(1, _safe_int(exit_room_half_height, 6) - 2))
	)

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
	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)
	return x >= 0 and x < local_map_width and y >= 0 and y < local_map_height


func _is_border_cell(x: int, y: int) -> bool:
	var local_border: int = _safe_int(border_size, 10)
	var local_map_width: int = _safe_int(map_width, 220)
	var local_map_height: int = _safe_int(map_height, 140)

	return (
		x < local_border
		or x >= local_map_width - local_border
		or y < local_border
		or y >= local_map_height - local_border
	)


func _is_solid(x: int, y: int) -> bool:
	return _grid[y][x] == 1


func _is_open(x: int, y: int) -> bool:
	return _grid[y][x] == 0


func _set_solid(x: int, y: int) -> void:
	_grid[y][x] = 1


func _set_open(x: int, y: int) -> void:
	_grid[y][x] = 0


func _carve_circle(center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _is_inside(x, y):
				continue

			if center.distance_to(Vector2(x, y)) <= float(radius) + 0.35:
				_set_open(x, y)


func _safe_int(value: Variant, default_value: int) -> int:
	match typeof(value):
		TYPE_INT:
			return value as int
		TYPE_FLOAT:
			return int(value)
		_:
			return default_value


func _safe_float(value: Variant, default_value: float) -> float:
	match typeof(value):
		TYPE_FLOAT:
			return value as float
		TYPE_INT:
			return float(value)
		_:
			return default_value
