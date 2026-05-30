extends CanvasLayer

const SPELL_SLOT_UI_SCRIPT: Script = preload("res://project/scripts/hud_gd/spell_slot_ui.gd")
const WAND_SLOT_COUNT: int = 5

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


func _ready() -> void:
	add_to_group("hud")
	inventory_panel.visible = false
	_clear_all_icons()
	_setup_drag_slots()
	_refresh_player_reference()
	_refresh_all_ui()


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_refresh_player_reference()

	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_inventory()

	_refresh_all_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not inventory_open:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_8:
		selected_inventory_index = key_event.keycode - KEY_1
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_BRACKETLEFT:
		selected_wand_slot_index = maxi(0, selected_wand_slot_index - 1)
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_BRACKETRIGHT:
		selected_wand_slot_index = mini(spell_slot_panels.size() - 1, selected_wand_slot_index + 1)
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

	if inventory_open:
		_clamp_inventory_selection()
		_clamp_wand_slot_selection()


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


func is_drag_source_slot(container: StringName, index: int) -> bool:
	return (
		is_spell_drag_active
		and drag_source_container == container
		and drag_source_index == index
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
	var player_inventory: PlayerInventoryComponent = _get_player_inventory_component()
	if player_inventory == null:
		print("Equip fehlgeschlagen: PlayerInventoryComponent nicht gefunden.")
		return

	var inventory: InventoryComponent = _get_inventory_component()
	if inventory == null:
		print("Equip fehlgeschlagen: InventoryComponent nicht gefunden.")
		return

	if inventory.get_spell_at(selected_inventory_index) == null:
		print("Kein Spell im Inventory-Slot ", selected_inventory_index + 1, ".")
		return

	if player_inventory.equip_inventory_spell_to_wand(
		selected_inventory_index,
		selected_wand_slot_index
	):
		refresh_after_slot_change()


func _try_unequip_wand_slot() -> void:
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
	player = get_tree().get_first_node_in_group("player")


func _refresh_all_ui() -> void:
	_refresh_health_ui()
	_refresh_wand_ui()
	_refresh_inventory_ui()
	_refresh_dash_ui()
	_apply_spell_selection_visual()
	_apply_inventory_selection_visual()


func _refresh_health_ui() -> void:
	if player == null:
		return

	var health_component: Node = player.get_node_or_null("Components/HealthComponent")
	if health_component == null:
		return

	var current_health = health_component.get("health")
	var max_health = health_component.get("max_health")

	if current_health != null and max_health != null:
		set_health(int(current_health), int(max_health))


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

	var current_mana = wand.get("current_mana")
	if current_mana != null and wand_data != null:
		var mana_max = wand_data.get("mana_max")
		if mana_max != null:
			update_mana(float(current_mana), float(mana_max))


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


func _apply_spell_selection_visual() -> void:
	var highlight_index: int = selected_spell_index
	if inventory_open:
		highlight_index = selected_wand_slot_index

	for i in range(spell_slot_panels.size()):
		var panel := spell_slot_panels[i]
		if panel == null:
			continue

		if i == highlight_index:
			panel.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			panel.modulate = Color(1, 1, 1, 1)


func _apply_inventory_selection_visual() -> void:
	for i in range(inventory_slot_panels.size()):
		var panel := inventory_slot_panels[i]
		if panel == null:
			continue

		if not inventory_open:
			panel.modulate = Color(1, 1, 1, 1)
			continue

		if i == selected_inventory_index:
			panel.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			panel.modulate = Color(1, 1, 1, 1)


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
