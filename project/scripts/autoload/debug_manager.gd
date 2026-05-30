extends Node

const ACTION_TOGGLE_OVERLAY := "debug_toggle_overlay"
const ACTION_TOGGLE_GOD_MODE := "debug_toggle_god_mode"
const ACTION_REFILL_RESOURCES := "debug_refill_resources"
const ACTION_RESET_DASH := "debug_reset_dash"
const ACTION_RESTART_ROOM := "debug_restart_room"
const ACTION_SPAWN_SPELL := "debug_spawn_spell"
const ACTION_GIVE_WAND := "debug_spawn_wand"
const ACTION_SPAWN_ENEMY := "debug_spawn_enemy"
const ACTION_TOGGLE_SLOWMO := "debug_toggle_slowmo"
const ACTION_TELEPORT_TO_SPAWN := "debug_teleport_spawn"

const PLAYER_GROUP := "player"
const HUD_GROUP := "hud"
const PLAYER_SPAWN_NAME := "PlayerSpawn"

const TEST_ENEMY_SCENE_PATH := "res://project/scenes/enemies_tscn/enemy_monster.tscn"
const TEST_SPELL_PICKUP_SCENE_PATH := "res://project/scenes/pickups_tscn/spell_pickup.tscn"
const TEST_WAND_SCENE_PATH := "res://project/scenes/wand_tscn/starter_wand.tscn"
const TEST_SPELL_RESOURCE_PATH := "res://project/resources/spells_tres/magic_bolt.tres"

const WAND_NODE_PATH := "Visuals/WandPivot/Wand"
const DASH_NODE_PATH := "Components/DashComponent"
const HEALTH_NODE_PATH := "Components/HealthComponent"

const NORMAL_TIME_SCALE := 1.0
const SLOW_TIME_SCALE := 0.2

var debug_enabled: bool = true
var overlay_visible: bool = true
var god_mode: bool = false
var slow_motion_enabled: bool = false

var overlay_layer: CanvasLayer
var overlay_panel: PanelContainer
var overlay_label: RichTextLabel

var test_enemy_scene: PackedScene
var test_spell_pickup_scene: PackedScene
var test_wand_scene: PackedScene
var test_spell_resource: Resource

var last_log: String = "Ready"

func _ready() -> void:
	test_enemy_scene = load(TEST_ENEMY_SCENE_PATH)
	test_spell_pickup_scene = load(TEST_SPELL_PICKUP_SCENE_PATH)
	test_wand_scene = load(TEST_WAND_SCENE_PATH)
	test_spell_resource = load(TEST_SPELL_RESOURCE_PATH)

	_create_overlay()
	_apply_time_scale()
	_update_overlay()
	_log("DebugManager ready")

func _input(event: InputEvent) -> void:
	if not debug_enabled:
		return

	if event.is_action_pressed(ACTION_TOGGLE_OVERLAY):
		overlay_visible = not overlay_visible
		_set_overlay_visible(overlay_visible)
		_log("Overlay toggled")
		return

	if event.is_action_pressed(ACTION_TOGGLE_GOD_MODE):
		god_mode = not god_mode
		_log("God Mode toggled")
		return

	if event.is_action_pressed(ACTION_REFILL_RESOURCES):
		refill_resources()
		return

	if event.is_action_pressed(ACTION_RESET_DASH):
		reset_dash()
		return

	if event.is_action_pressed(ACTION_RESTART_ROOM):
		restart_room()
		return

	if event.is_action_pressed(ACTION_SPAWN_SPELL):
		spawn_test_spell_pickup()
		return

	if event.is_action_pressed(ACTION_GIVE_WAND):
		give_test_wand()
		return

	if event.is_action_pressed(ACTION_SPAWN_ENEMY):
		spawn_test_enemy()
		return

	if event.is_action_pressed(ACTION_TOGGLE_SLOWMO):
		slow_motion_enabled = not slow_motion_enabled
		_apply_time_scale()
		_log("Slow motion toggled")
		return

	if event.is_action_pressed(ACTION_TELEPORT_TO_SPAWN):
		teleport_player_to_spawn()
		return

func _process(_delta: float) -> void:
	if overlay_visible:
		_update_overlay()

func is_god_mode_enabled() -> bool:
	return god_mode

func get_player() -> Node2D:
	if GameManager != null:
		if "player" in GameManager:
			if GameManager.player != null:
				if is_instance_valid(GameManager.player):
					return GameManager.player

	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player is Node2D:
		return player

	return null

func get_current_scene_root() -> Node:
	return get_tree().current_scene

func get_player_spawn() -> Marker2D:
	var scene := get_current_scene_root()
	if scene == null:
		return null

	var direct := scene.get_node_or_null(PLAYER_SPAWN_NAME)
	if direct != null:
		return direct as Marker2D

	var found := scene.find_child(PLAYER_SPAWN_NAME, true, false)
	if found != null:
		return found as Marker2D

	return null

func refill_resources() -> void:
	var player := get_player()
	if player == null:
		_log("No player")
		return

	var health := player.get_node_or_null(HEALTH_NODE_PATH)
	if health != null:
		if "max_health" in health:
			if "health" in health:
				health.health = health.max_health
				health.health_changed.emit(health.health, health.max_health)

	var wand := player.get_node_or_null(WAND_NODE_PATH)
	if wand != null:
		if wand.get("wand_data") != null:
			var wd = wand.get("wand_data")
			if wd != null:
				if "mana_max" in wd:
					wand.current_mana = wd.mana_max
					wand.cast_cooldown = 0.0
					wand.recharge_cooldown = 0.0

					if wand.has_method("reset_spell_cycle"):
						wand.reset_spell_cycle()

					if wand.has_method("_update_hud_mana"):
						wand._update_hud_mana()

					if wand.has_method("_update_hud_spell"):
						wand._update_hud_spell()

					if wand.has_method("_update_mana_visual"):
						wand._update_mana_visual(0.0)

	_log("Refilled")

func reset_dash() -> void:
	var player := get_player()
	if player == null:
		_log("No player for dash reset")
		return

	var dash := player.get_node_or_null(DASH_NODE_PATH)
	if dash == null:
		_log("No DashComponent")
		return

	dash.current_dash_charges = dash.max_dash_charges
	dash.dash_charge_recovery_timer = 0.0
	dash.block_dash_cooldown_timer = 0.0
	dash.is_dashing = false
	dash.is_block_dashing = false
	dash.dash_timer = 0.0
	dash.block_dash_timer = 0.0
	dash.can_air_block_dash = true

	_log("Dash reset")

func restart_room() -> void:
	if GameManager != null:
		if GameManager.has_method("reload_current_level"):
			GameManager.reload_current_level()
			_log("Restarted")
			return

	_log("Restart failed")

func teleport_player_to_spawn() -> void:
	var player := get_player()
	if player == null:
		_log("No player")
		return

	var spawn := get_player_spawn()
	if spawn == null:
		_log("No PlayerSpawn")
		return

	player.global_position = spawn.global_position

	if "velocity" in player:
		player.velocity = Vector2.ZERO

	_log("Teleported")

func spawn_test_enemy() -> void:
	if test_enemy_scene == null:
		_log("Enemy scene missing")
		return

	var player := get_player()
	var scene := get_current_scene_root()

	if player == null:
		_log("No player")
		return

	if scene == null:
		_log("No scene")
		return

	var e = test_enemy_scene.instantiate()
	scene.add_child(e)

	if e is Node2D:
		e.global_position = player.global_position + Vector2(80, 0)

	_log("Enemy")

func spawn_test_spell_pickup() -> void:
	if test_spell_pickup_scene == null:
		_log("Spell pickup scene missing")
		return

	var player := get_player()
	var scene := get_current_scene_root()

	if player == null:
		_log("No player")
		return

	if scene == null:
		_log("No scene")
		return

	var p = test_spell_pickup_scene.instantiate()
	scene.add_child(p)

	if p is Node2D:
		p.global_position = player.global_position + Vector2(50, 0)

	if test_spell_resource != null:
		if p.has_method("set_spell_data"):
			p.set_spell_data(test_spell_resource)

	_log("Spell")

func give_test_wand() -> void:
	var player := get_player()
	if player == null:
		_log("No player")
		return

	var wand := player.get_node_or_null(WAND_NODE_PATH)
	if wand == null:
		_log("No player wand")
		return

	if test_wand_scene == null:
		_log("Test wand scene missing")
		return

	var temp = test_wand_scene.instantiate()
	if temp == null:
		_log("Temp wand instantiate failed")
		return

	if "wand_data" in temp:
		wand.wand_data = temp.wand_data.duplicate(true)
		wand.current_mana = wand.wand_data.mana_max
		wand.cast_cooldown = 0.0
		wand.recharge_cooldown = 0.0

		if wand.has_method("reset_spell_cycle"):
			wand.reset_spell_cycle()

		if wand.has_method("_update_hud_mana"):
			wand._update_hud_mana()

		if wand.has_method("_update_hud_spell"):
			wand._update_hud_spell()

		if wand.has_method("_update_mana_visual"):
			wand._update_mana_visual(0.0)

	temp.queue_free()
	_log("Wand")

func _apply_time_scale() -> void:
	if slow_motion_enabled:
		Engine.time_scale = SLOW_TIME_SCALE
	else:
		Engine.time_scale = NORMAL_TIME_SCALE

func _create_overlay() -> void:
	var offset_x: float = 4.0
	var offset_y: float = 100.0

	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 100

	overlay_panel = PanelContainer.new()
	overlay_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay_panel.position = Vector2(offset_x, offset_y)
	overlay_panel.custom_minimum_size = Vector2(160, 90)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)

	overlay_label = RichTextLabel.new()
	overlay_label.bbcode_enabled = false
	overlay_label.fit_content = true
	overlay_label.scroll_active = false
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var font := ThemeDB.fallback_font
	overlay_label.add_theme_font_override("normal_font", font)
	overlay_label.add_theme_font_size_override("normal_font_size", 9)

	margin.add_child(overlay_label)
	overlay_panel.add_child(margin)
	overlay_layer.add_child(overlay_panel)

	get_tree().root.add_child.call_deferred(overlay_layer)

	_set_overlay_visible(overlay_visible)

func _set_overlay_visible(value: bool) -> void:
	overlay_visible = value
	if overlay_layer != null:
		overlay_layer.visible = value

func _update_overlay() -> void:
	if overlay_label == null:
		return

	var player := get_player()
	var text := ""

	text += "GM:%s\n" % _on_off(god_mode)
	text += "SM:%s\n" % _on_off(slow_motion_enabled)

	var scene := get_current_scene_root()
	if scene != null:
		text += "Sc:%s\n" % str(scene.name)
	else:
		text += "Sc:null\n"

	if player == null:
		overlay_label.text = text
		return

	var health_component := player.get_node_or_null(HEALTH_NODE_PATH)
	if health_component != null:
		text += "HP:%d/%d\n" % [health_component.health, health_component.max_health]
		text += "Dead:%s\n" % _on_off(health_component.is_dead)
		text += "Hurt:%s\n" % _on_off(health_component.is_hurt)

	var dash_component := player.get_node_or_null(DASH_NODE_PATH)
	if dash_component != null:
		text += "D:%d/%d\n" % [dash_component.current_dash_charges, dash_component.max_dash_charges]
		text += "Dsh:%s\n" % _on_off(dash_component.is_dashing)
		text += "Blk:%s\n" % _on_off(dash_component.is_block_dashing)
		text += "BCD:%.2f\n" % dash_component.block_dash_cooldown_timer

	var wand := player.get_node_or_null(WAND_NODE_PATH)
	if wand != null:
		if wand.get("wand_data") != null:
			var wand_data = wand.get("wand_data")
			text += "M:%.0f/%.0f\n" % [wand.current_mana, wand_data.mana_max]
			text += "SI:%d\n" % wand.current_spell_index

	var hud := get_tree().get_first_node_in_group(HUD_GROUP)
	if hud != null:
		if hud.has_method("is_inventory_open"):
			text += "Inv:%s\n" % _on_off(hud.is_inventory_open())

	var spawn := get_player_spawn()
	if spawn != null:
		text += "Sp:%s\n" % str(spawn.global_position)

	text += "x:%.0f y:%.0f\n" % [player.global_position.x, player.global_position.y]
	text += "Last:%s\n" % last_log

	overlay_label.text = text

func _log(message: String) -> void:
	last_log = message
	print("[Debug] " + message)
	_update_overlay()

func _on_off(value: bool) -> String:
	if value:
		return "ON"
	return "OFF"
