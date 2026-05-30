extends CanvasLayer

const SPELL_SLOT_UI_SCRIPT: Script = preload("res://project/scripts/hud_gd/spell_slot_ui.gd")
const WAND_SLOT_COUNT: int = 5

const SLOT_MODULATE_EMPTY := Color(0.55, 0.55, 0.6, 1.0)
const SLOT_MODULATE_FILLED := Color(1.0, 1.0, 1.0, 1.0)
const SLOT_MODULATE_SELECTED_SCALE := 1.2
const SLOT_MODULATE_DROP_SCALE := Color(1.05, 1.15, 1.0, 1.0)

@onready var root_ui: Control = $HUD

@onready var health_bar: Range = $HUD/HealthManaPanel/HealthManaMarginContainer/HealthManaBox/HealthBar
@onready var mana_bar: Range = $HUD/HealthManaPanel/HealthManaMarginContainer/HealthManaBox/ManaBar

@onready var dash_charge_fills: Array[ColorRect] = [
	$HUD/HealthManaPanel/HealthManaMarginContainer/DashChargeBox/DashCharge1/Fill,
	$HUD/HealthManaPanel/HealthManaMarginContainer/DashChargeBox/DashCharge2/Fill
]

@onready var wand_icon: TextureRect = $HUD/WandPanel/WandMargin/WandVBox/WandSlotBar/WandSlot/Center/Icon

@onready var spell_slot_panels: Array[Panel] = [
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot1,
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot2,
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot3,
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot4,
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot5
]

@onready var spell_icons: Array[TextureRect] = [
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot1/Center/Icon,
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot2/Center/Icon,
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot3/Center/Icon,
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot4/Center/Icon,
	$HUD/WandPanel/WandMargin/WandVBox/SpellSlotBar/SpellSlot5/Center/Icon
]

@onready var inventory_panel: Control = $HUD/InventoryPanel

@onready var inventory_slot_panels: Array[Panel] = [
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot1,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot2,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot3,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot4,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot5,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot6,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot7,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot8
]

@onready var inventory_icons: Array[TextureRect] = [
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot1/Center/Icon,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot2/Center/Icon,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot3/Center/Icon,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot4/Center/Icon,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot5/Center/Icon,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot6/Center/Icon,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot7/Center/Icon,
	$HUD/InventoryPanel/InventoryMargin/InventoryGrid/Slot8/Center/Icon
]

var player: Node = null
var inventory_open: bool = false
var selected_spell_index: int = 0
var selected_inventory_index: int = 0
var selected_wand_slot_index: int = 0

var drag_source_container: StringName = &""
var drag_source_index: int = -1
var is_spell_drag_active: bool = false

var drop_hover_container: StringName = &""
var drop_hover_index: int = -1

var _health_component: PlayerHealthComponent = null
var _inventory_full_flash_tween: Tween = null


func _ready() -> void:
	add_to_group("hud")
	inventory_panel.visible = false
	_clear_all_icons()
	_setup_drag_slots()
	_refresh_player_reference()
	_refresh_wand_ui()
	_refresh_inventory_ui()
	_apply_spell_selection_visual()
	_apply_inventory_selection_visual()
	_sync_mana_from_wand_once()
	_refresh_dash_ui()


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_refresh_player_reference()

	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_inventory()

	_refresh_dash_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not inventory_open:
		return

	if is_spell_drag_active:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_8:
		selected_inventory_index = key_event.keycode - KEY_1
		_apply_inventory_selection_visual()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_BRACKETLEFT:
		selected_wand_slot_index = maxi(0, selected_wand_slot_index - 1)
		_apply_spell_selection_visual()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_BRACKETRIGHT:
		selected_wand_slot_index = mini(spell_slot_panels.size() - 1, selected_wand_slot_index + 1)
		_apply_spell_selection_visual()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact"):
		_try_equip_selected_spell()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_R:
		_try_unequip_wand_slot()
		get_viewport().set_input_as_handled()


func toggle_inventory() -> void:
	inventory_open = not inventory_open
	inventory_panel.visible = inventory_open
	_set_wand_input_enabled(not inventory_open)

	if not inventory_open:
		end_spell_drag_visual()
	else:
		_clamp_inventory_selection()
		_clamp_wand_slot_selection()

	refresh_after_slot_change()


func is_inventory_open() -> bool:
	return inventory_open


func get_player_inventory_component() -> Node:
	return _get_player_inventory_component()


func get_inventory_component() -> Node:
	return _get_inventory_component()


func refresh_after_slot_change() -> void:
	_refresh_wand_ui()
	_refresh_inventory_ui()
	_apply_spell_selection_visual()
	_apply_inventory_selection_visual()


func begin_spell_drag_visual(container: StringName, index: int) -> void:
	drag_source_container = container
	drag_source_index = index
	is_spell_drag_active = true
	_refresh_inventory_ui()
	_refresh_wand_ui()


func end_spell_drag_visual() -> void:
	if not is_spell_drag_active:
		return

	is_spell_drag_active = false
	drag_source_container = &""
	drag_source_index = -1
	clear_drop_hover_target()


func is_drag_source_slot(container: StringName, index: int) -> bool:
	return (
		is_spell_drag_active
		and drag_source_container == container
		and drag_source_index == index
	)


func set_drop_hover_target(container: StringName, index: int) -> void:
	if not is_spell_drag_active:
		return
	if drop_hover_container == container and drop_hover_index == index:
		return
	drop_hover_container = container
	drop_hover_index = index
	_apply_spell_selection_visual()
	_apply_inventory_selection_visual()


func clear_drop_hover_target() -> void:
	if drop_hover_container == &"" and drop_hover_index < 0:
		return
	drop_hover_container = &""
	drop_hover_index = -1
	_apply_spell_selection_visual()
	_apply_inventory_selection_visual()


func clear_drop_hover_if_match(container: StringName, index: int) -> void:
	if drop_hover_container == container and drop_hover_index == index:
		clear_drop_hover_target()


func show_inventory_full_feedback() -> void:
	var flash_target: CanvasItem = inventory_panel if inventory_open else root_ui
	if flash_target == null:
		return

	if _inventory_full_flash_tween != null and _inventory_full_flash_tween.is_valid():
		_inventory_full_flash_tween.kill()

	var original_modulate: Color = flash_target.modulate
	flash_target.modulate = Color(1.35, 0.45, 0.45, 1.0)

	_inventory_full_flash_tween = create_tween()
	_inventory_full_flash_tween.tween_property(
		flash_target,
		"modulate",
		original_modulate,
		0.28
	)


func set_health(current: int, max_value: int) -> void:
	if health_bar == null:
		return

	health_bar.max_value = max_value
	health_bar.value = clamp(current, 0, max_value)


func update_mana(current: float, max_value: float) -> void:
	if mana_bar == null:
		return

	mana_bar.max_value = max_value
	mana_bar.value = clamp(current, 0.0, max_value)


func update_spell_selection(index: int) -> void:
	selected_spell_index = index
	_apply_spell_selection_visual()


func _setup_drag_slots() -> void:
	for i in range(inventory_slot_panels.size()):
		_attach_slot_script(inventory_slot_panels[i], &"inventory", i)

	for i in range(spell_slot_panels.size()):
		_attach_slot_script(spell_slot_panels[i], &"wand", i)


func _attach_slot_script(panel: Panel, container: StringName, index: int) -> void:
	if panel == null:
		return

	panel.set_script(SPELL_SLOT_UI_SCRIPT)
	panel.set("slot_container", container)
	panel.set("slot_index", index)
	panel.set("hud_ref", self)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var center: Node = panel.get_node_or_null("Center")
	if center is Control:
		(center as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon: Node = panel.get_node_or_null("Center/Icon")
	if icon is Control:
		(icon as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _try_equip_selected_spell() -> void:
	if is_spell_drag_active:
		return

	var player_inventory: PlayerInventoryComponent = _get_player_inventory_component()
	if player_inventory == null:
		push_warning("HUD: PlayerInventoryComponent not found for equip.")
		return

	var inventory: InventoryComponent = _get_inventory_component()
	if inventory == null:
		push_warning("HUD: InventoryComponent not found for equip.")
		return

	if inventory.get_spell_at(selected_inventory_index) == null:
		return

	if player_inventory.equip_inventory_spell_to_wand(
		selected_inventory_index,
		selected_wand_slot_index
	):
		refresh_after_slot_change()


func _try_unequip_wand_slot() -> void:
	if is_spell_drag_active:
		return

	var player_inventory: PlayerInventoryComponent = _get_player_inventory_component()
	if player_inventory == null:
		return

	var wand: Node = player.get_node_or_null("Visuals/WandPivot/Wand") if player != null else null
	if wand == null or not wand.has_method("get_spell_in_slot"):
		return

	if wand.get_spell_in_slot(selected_wand_slot_index) == null:
		return

	if player_inventory.unequip_wand_spell_to_inventory(
		selected_wand_slot_index,
		selected_inventory_index
	):
		refresh_after_slot_change()


func _get_player_inventory_component() -> PlayerInventoryComponent:
	if player == null:
		return null
	return player.get_node_or_null("Components/PlayerInventoryComponent") as PlayerInventoryComponent


func _get_inventory_component() -> InventoryComponent:
	if player == null:
		return null
	return player.get_node_or_null("Components/InventoryComponent") as InventoryComponent


func _get_player_health_component() -> PlayerHealthComponent:
	if player == null:
		return null
	return player.get_node_or_null("Components/HealthComponent") as PlayerHealthComponent


func _set_wand_input_enabled(enabled: bool) -> void:
	if player == null:
		return

	var wand: Node = player.get_node_or_null("Visuals/WandPivot/Wand")
	if wand == null:
		return

	if wand.has_method("set_input_enabled"):
		wand.set_input_enabled(enabled)


func _clamp_inventory_selection() -> void:
	selected_inventory_index = clampi(
		selected_inventory_index,
		0,
		inventory_slot_panels.size() - 1
	)


func _clamp_wand_slot_selection() -> void:
	selected_wand_slot_index = clampi(
		selected_wand_slot_index,
		0,
		spell_slot_panels.size() - 1
	)


func _refresh_player_reference() -> void:
	var new_player: Node = get_tree().get_first_node_in_group("player")
	if new_player == player and is_instance_valid(player):
		return

	_disconnect_health_signal()
	player = new_player

	if player != null:
		_health_component = _get_player_health_component()
		if _health_component != null:
			if not _health_component.health_changed.is_connected(_on_health_changed):
				_health_component.health_changed.connect(_on_health_changed)
			_on_health_changed(_health_component.health, _health_component.max_health)

	refresh_after_slot_change()
	_sync_mana_from_wand_once()
	_refresh_dash_ui()


func _disconnect_health_signal() -> void:
	if _health_component == null:
		return
	if _health_component.health_changed.is_connected(_on_health_changed):
		_health_component.health_changed.disconnect(_on_health_changed)
	_health_component = null


func _on_health_changed(current: int, max_value: int) -> void:
	set_health(current, max_value)


func _sync_mana_from_wand_once() -> void:
	if player == null:
		return

	var wand: Node = player.get_node_or_null("Visuals/WandPivot/Wand")
	if wand == null:
		return

	var wand_data = wand.get("wand_data")
	var current_mana = wand.get("current_mana")
	if current_mana != null and wand_data != null:
		var mana_max = wand_data.get("mana_max")
		if mana_max != null:
			update_mana(float(current_mana), float(mana_max))


func _refresh_wand_ui() -> void:
	if player == null:
		return

	var wand: Node = player.get_node_or_null("Visuals/WandPivot/Wand")
	if wand == null:
		return

	var wand_data = wand.get("wand_data")
	if wand_data != null and wand_data.icon != null:
		wand_icon.texture = wand_data.icon
		wand_icon.visible = true
	else:
		wand_icon.texture = null
		wand_icon.visible = false

	var spells: Array[SpellData] = []
	if wand.has_method("get_spell_slots"):
		spells = wand.get_spell_slots()

	for i in range(spell_icons.size()):
		var icon_rect := spell_icons[i]
		if icon_rect == null:
			continue

		var spell: SpellData = null
		if i < spells.size():
			spell = spells[i]

		if is_drag_source_slot(&"wand", i):
			icon_rect.texture = null
			icon_rect.visible = false
		elif spell != null and spell.icon != null:
			icon_rect.texture = spell.icon
			icon_rect.visible = true
		else:
			icon_rect.texture = null
			icon_rect.visible = false

	if not inventory_open:
		var current_spell_index_value = wand.get("current_spell_index")
		if current_spell_index_value != null:
			selected_spell_index = int(current_spell_index_value)

	_apply_spell_selection_visual()


func _refresh_inventory_ui() -> void:
	if player == null:
		return

	var inventory: InventoryComponent = _get_inventory_component()
	if inventory == null:
		return

	var spells: Array[SpellData] = inventory.get_spells()

	for i in range(inventory_icons.size()):
		var icon_rect := inventory_icons[i]
		if icon_rect == null:
			continue

		var spell: SpellData = null
		if i < spells.size():
			spell = spells[i]

		if is_drag_source_slot(&"inventory", i):
			icon_rect.texture = null
			icon_rect.visible = false
		elif spell != null and spell.icon != null:
			icon_rect.texture = spell.icon
			icon_rect.visible = true
		else:
			icon_rect.texture = null
			icon_rect.visible = false

	_apply_inventory_selection_visual()


func _refresh_dash_ui() -> void:
	for fill in dash_charge_fills:
		if fill != null:
			fill.visible = false

	if player == null:
		return

	var dash_component: Node = player.get_node_or_null("Components/DashComponent")
	if dash_component == null:
		return

	if not dash_component.has_method("get_dash_charges"):
		return

	var charges: int = dash_component.get_dash_charges()
	var max_charges: int = dash_charge_fills.size()

	if dash_component.has_method("get_max_dash_charges"):
		max_charges = min(dash_component.get_max_dash_charges(), dash_charge_fills.size())

	for i in range(dash_charge_fills.size()):
		var fill: ColorRect = dash_charge_fills[i]
		if fill == null:
			continue

		if i < max_charges and i < charges:
			fill.visible = true
		else:
			fill.visible = false


func _slot_panel_modulate(has_spell: bool, is_selected: bool, is_drop_hover: bool) -> Color:
	var base: Color = SLOT_MODULATE_FILLED if has_spell else SLOT_MODULATE_EMPTY

	if is_selected:
		base = Color(
			base.r * SLOT_MODULATE_SELECTED_SCALE,
			base.g * SLOT_MODULATE_SELECTED_SCALE,
			base.b * SLOT_MODULATE_SELECTED_SCALE,
			1.0
		)

	if is_drop_hover and is_spell_drag_active:
		base = Color(
			base.r * SLOT_MODULATE_DROP_SCALE.r,
			base.g * SLOT_MODULATE_DROP_SCALE.g,
			base.b * SLOT_MODULATE_DROP_SCALE.b,
			1.0
		)

	return base


func _apply_spell_selection_visual() -> void:
	var highlight_index: int = selected_spell_index
	if inventory_open:
		highlight_index = selected_wand_slot_index

	for i in range(spell_slot_panels.size()):
		var panel := spell_slot_panels[i]
		if panel == null:
			continue

		var has_spell: bool = false
		if player != null:
			var wand: Node = player.get_node_or_null("Visuals/WandPivot/Wand")
			if wand != null and wand.has_method("get_spell_in_slot"):
				has_spell = wand.get_spell_in_slot(i) != null

		var is_selected: bool = inventory_open and i == highlight_index
		var is_drop_hover: bool = (
			is_spell_drag_active
			and drop_hover_container == &"wand"
			and drop_hover_index == i
		)
		panel.modulate = _slot_panel_modulate(has_spell, is_selected, is_drop_hover)


func _apply_inventory_selection_visual() -> void:
	for i in range(inventory_slot_panels.size()):
		var panel := inventory_slot_panels[i]
		if panel == null:
			continue

		if not inventory_open:
			panel.modulate = SLOT_MODULATE_FILLED
			continue

		var has_spell: bool = false
		var inventory: InventoryComponent = _get_inventory_component()
		if inventory != null:
			has_spell = inventory.get_spell_at(i) != null

		var is_selected: bool = i == selected_inventory_index
		var is_drop_hover: bool = (
			is_spell_drag_active
			and drop_hover_container == &"inventory"
			and drop_hover_index == i
		)
		panel.modulate = _slot_panel_modulate(has_spell, is_selected, is_drop_hover)


func _clear_all_icons() -> void:
	if wand_icon != null:
		wand_icon.texture = null
		wand_icon.visible = false

	for icon_rect in spell_icons:
		if icon_rect != null:
			icon_rect.texture = null
			icon_rect.visible = false

	for icon_rect in inventory_icons:
		if icon_rect != null:
			icon_rect.texture = null
			icon_rect.visible = false

	for fill in dash_charge_fills:
		if fill != null:
			fill.visible = true
