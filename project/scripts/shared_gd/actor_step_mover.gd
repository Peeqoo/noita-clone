extends RefCounted
class_name ActorStepMover

## Shared 1-tile step-up for CharacterBody2D actors (8px tiles, max ~9px rise).

const TILE_HEIGHT_PX: float = 8.0
const DEFAULT_MAX_STEP_HEIGHT: float = 9.0
const DEFAULT_STEP_INCREMENT: float = 1.0
const DEFAULT_MIN_FORWARD_CHECK: float = 4.0
const DEFAULT_FORWARD_PADDING: float = 2.0
const FLOOR_PROBE_DOWN: float = 14.0
const FLOOR_PROBE_START_OFFSET_Y: float = 2.0
const WORLD_COLLISION_MASK: int = 1
## Min |floor_normal.x| to treat surface as a ramp (not a flat 1-tile ledge).
const SLOPE_FLOOR_NORMAL_X_THRESHOLD: float = 0.05


static func is_on_walkable_slope(body: CharacterBody2D) -> bool:
	if body == null:
		return false
	return body.is_on_floor() and absf(body.get_floor_normal().x) > SLOPE_FLOOR_NORMAL_X_THRESHOLD


static func try_step_up(
	body: CharacterBody2D,
	delta: float,
	move_dir: float = 0.0,
	max_step_height: float = DEFAULT_MAX_STEP_HEIGHT,
	step_height_increment: float = DEFAULT_STEP_INCREMENT,
	min_step_forward_check: float = DEFAULT_MIN_FORWARD_CHECK,
	step_forward_padding: float = DEFAULT_FORWARD_PADDING
) -> float:
	if body == null:
		return 0.0

	if not body.is_on_floor():
		return 0.0

	if is_on_walkable_slope(body):
		return 0.0

	if body.velocity.y < 0.0:
		return 0.0

	var dir: float = move_dir
	if absf(dir) < 0.01:
		dir = signf(body.velocity.x)

	if dir == 0.0:
		return 0.0

	var step_height: float = _find_step_height(
		body,
		dir,
		delta,
		max_step_height,
		step_height_increment,
		min_step_forward_check,
		step_forward_padding
	)

	if step_height <= 0.0:
		return 0.0

	body.global_position.y -= step_height
	return step_height


static func can_step_over_obstacle(
	body: CharacterBody2D,
	dir: float,
	delta: float = 0.0,
	max_step_height: float = DEFAULT_MAX_STEP_HEIGHT,
	step_height_increment: float = DEFAULT_STEP_INCREMENT,
	min_step_forward_check: float = DEFAULT_MIN_FORWARD_CHECK,
	step_forward_padding: float = DEFAULT_FORWARD_PADDING
) -> bool:
	if body == null or dir == 0.0:
		return false

	if not body.is_on_floor():
		return false

	return _find_step_height(
		body,
		dir,
		delta,
		max_step_height,
		step_height_increment,
		min_step_forward_check,
		step_forward_padding
	) > 0.0


static func _find_step_height(
	body: CharacterBody2D,
	dir: float,
	delta: float,
	max_step_height: float,
	step_height_increment: float,
	min_step_forward_check: float,
	step_forward_padding: float
) -> float:
	var forward_check: float = maxf(
		absf(body.velocity.x * delta) + step_forward_padding,
		min_step_forward_check
	)
	var forward_motion := Vector2(dir * forward_check, 0.0)

	if not body.test_move(body.global_transform, forward_motion):
		return 0.0

	var step_height: float = step_height_increment
	while step_height <= max_step_height:
		var raised_transform: Transform2D = body.global_transform.translated(Vector2(0.0, -step_height))

		if body.test_move(raised_transform, Vector2.ZERO):
			step_height += step_height_increment
			continue

		if body.test_move(raised_transform, forward_motion):
			step_height += step_height_increment
			continue

		if not _has_floor_ahead(body, raised_transform.origin, dir, forward_check):
			step_height += step_height_increment
			continue

		return step_height

	return 0.0


static func _has_floor_ahead(
	body: CharacterBody2D,
	raised_origin: Vector2,
	dir: float,
	forward_check: float
) -> bool:
	var world: World2D = body.get_world_2d()
	if world == null:
		return false

	var space_state: PhysicsDirectSpaceState2D = world.direct_space_state
	if space_state == null:
		return false

	var probe_x: float = raised_origin.x + dir * forward_check * 0.5
	var from: Vector2 = Vector2(probe_x, raised_origin.y + FLOOR_PROBE_START_OFFSET_Y)
	var to: Vector2 = from + Vector2(0.0, FLOOR_PROBE_DOWN)

	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = WORLD_COLLISION_MASK
	query.exclude = [body.get_rid()]

	var hit: Dictionary = space_state.intersect_ray(query)
	return not hit.is_empty()
