extends CanvasLayer

@onready var health_bar: ProgressBar = $Control/HealthManaMarginContainer/VBoxContainer/HealthBar
@onready var mana_bar: ProgressBar = $Control/HealthManaMarginContainer/VBoxContainer/ManaBar

@onready var spell_slot_1: Panel = $Control/WandSpellBar/MarginContainer/HBoxSpell/SpellSlot1
@onready var spell_slot_2: Panel = $Control/WandSpellBar/MarginContainer/HBoxSpell/SpellSlot2
@onready var spell_slot_3: Panel = $Control/WandSpellBar/MarginContainer/HBoxSpell/SpellSlot3

@onready var spell_slot_1_icon: TextureRect = $Control/WandSpellBar/MarginContainer/HBoxSpell/SpellSlot1/Icon
@onready var spell_slot_2_icon: TextureRect = $Control/WandSpellBar/MarginContainer/HBoxSpell/SpellSlot2/Icon
@onready var spell_slot_3_icon: TextureRect = $Control/WandSpellBar/MarginContainer/HBoxSpell/SpellSlot3/Icon

@onready var wand_slot_icon: TextureRect = $Control/WandSpellBar/MarginContainer/HBoxWand/WandSlot/Icon

@onready var inventory_panel: PanelContainer = $Control/InventoryPanel

@onready var inventory_slot_1_icon: TextureRect = $Control/InventoryPanel/MarginContainer/InventoryGrid/Slot_1/Icon
@onready var inventory_slot_2_icon: TextureRect = $Control/InventoryPanel/MarginContainer/InventoryGrid/Slot_2/Icon
@onready var inventory_slot_3_icon: TextureRect = $Control/InventoryPanel/MarginContainer/InventoryGrid/Slot_3/Icon
@onready var inventory_slot_4_icon: TextureRect = $Control/InventoryPanel/MarginContainer/InventoryGrid/Slot_4/Icon
@onready var inventory_slot_5_icon: TextureRect = $Control/InventoryPanel/MarginContainer/InventoryGrid/Slot_5/Icon
@onready var inventory_slot_6_icon: TextureRect = $Control/InventoryPanel/MarginContainer/InventoryGrid/Slot_6/Icon
@onready var inventory_slot_7_icon: TextureRect = $Control/InventoryPanel/MarginContainer/InventoryGrid/Slot_7/Icon
@onready var inventory_slot_8_icon: TextureRect = $Control/InventoryPanel/MarginContainer/InventoryGrid/Slot_8/Icon

var player: Node = null
var selected_wand_slot: int = 0
var inventory_open: bool = false

var inventory_icons: Array[TextureRect] = []

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	inventory_icons = [
		inventory_slot_1_icon,
		inventory_slot_2_icon,
		inventory_slot_3_icon,
		inventory_slot_4_icon,
		inventory_slot_5_icon,
		inventory_slot_6_icon,
		inventory_slot_7_icon,
		inventory_slot_8_icon
	]

	inventory_panel.visible = false
	update_spell_selection(0)
	refresh_all_ui()

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_inventory()

func toggle_inventory() -> void:
	inventory_open = not inventory_open
	inventory_panel.visible = inventory_open

	if inventory_open:
		refresh_all_ui()

func is_inventory_open() -> bool:
	return inventory_open

func set_health(current: int, max_value: int) -> void:
	if health_bar == null:
		return

	health_bar.max_value = max_value
	health_bar.value = current

func update_mana(current: float, max_value: float) -> void:
	if mana_bar == null:
		return

	mana_bar.max_value = max_value
	mana_bar.value = current

func update_spell_selection(active_index: int) -> void:
	if not is_node_ready():
		call_deferred("update_spell_selection", active_index)
		return

	selected_wand_slot = active_index
	_reset_spell_slots()

	match active_index:
		0:
			spell_slot_1.modulate = Color(1, 1, 0.6)
		1:
			spell_slot_2.modulate = Color(1, 1, 0.6)
		2:
			spell_slot_3.modulate = Color(1, 1, 0.6)

func refresh_all_ui() -> void:
	refresh_inventory_ui()
	refresh_wand_ui()

func refresh_inventory_ui() -> void:
	if player == null:
		return
	if not player.has_node("Inventory"):
		return

	var inventory: InventoryComponent = player.get_node("Inventory")
	if inventory == null:
		return

	var spells: Array[SpellData] = inventory.get_spells()

	for i in range(inventory_icons.size()):
		var icon_rect: TextureRect = inventory_icons[i]
		if icon_rect == null:
			continue

		if i < spells.size() and spells[i] != null and spells[i].icon != null:
			icon_rect.texture = spells[i].icon
			icon_rect.visible = true
		else:
			icon_rect.texture = null
			icon_rect.visible = false

func refresh_wand_ui() -> void:
	if player == null:
		return
	if not player.has_node("WandPivot/Wand"):
		return

	var wand = player.get_node("WandPivot/Wand")
	if wand == null:
		return

	_update_single_wand_slot(spell_slot_1_icon, wand, 0)
	_update_single_wand_slot(spell_slot_2_icon, wand, 1)
	_update_single_wand_slot(spell_slot_3_icon, wand, 2)

	var wand_data = wand.get("wand_data")
	if wand_slot_icon != null and wand_data != null and wand_data.icon != null:
		wand_slot_icon.texture = wand_data.icon
		wand_slot_icon.visible = true
	else:
		wand_slot_icon.texture = null
		wand_slot_icon.visible = false

func _update_single_wand_slot(icon_rect: TextureRect, wand, slot_index: int) -> void:
	if icon_rect == null:
		return

	var spell: SpellData = wand.get_spell_in_slot(slot_index)
	if spell != null and spell.icon != null:
		icon_rect.texture = spell.icon
		icon_rect.visible = true
	else:
		icon_rect.texture = null
		icon_rect.visible = false

func _on_inventory_slot_pressed(slot_index: int) -> void:
	if not inventory_open:
		return
	if player == null:
		return

	if player.has_method("equip_inventory_spell_to_wand"):
		player.equip_inventory_spell_to_wand(slot_index, selected_wand_slot)

	refresh_all_ui()

func _on_spell_slot_pressed(slot_index: int) -> void:
	if not inventory_open:
		return
	if player == null:
		return

	if selected_wand_slot == slot_index:
		if player.has_method("unequip_wand_spell_to_inventory"):
			player.unequip_wand_spell_to_inventory(slot_index)
	else:
		update_spell_selection(slot_index)

	refresh_all_ui()

func _reset_spell_slots() -> void:
	if spell_slot_1 == null or spell_slot_2 == null or spell_slot_3 == null:
		return

	spell_slot_1.modulate = Color(1, 1, 1)
	spell_slot_2.modulate = Color(1, 1, 1)
	spell_slot_3.modulate = Color(1, 1, 1)

func _on_slot_1_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(0)

func _on_slot_2_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(1)

func _on_slot_3_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(2)

func _on_slot_4_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(3)

func _on_slot_5_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(4)

func _on_slot_6_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(5)

func _on_slot_7_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(6)

func _on_slot_8_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(7)

func _on_spell_slot_1_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_spell_slot_pressed(0)

func _on_spell_slot_2_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_spell_slot_pressed(1)

func _on_spell_slot_3_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_spell_slot_pressed(2)
