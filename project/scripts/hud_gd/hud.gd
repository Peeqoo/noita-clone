extends CanvasLayer

@onready var root_ui: Control = $HUD

@onready var health_bar: Range = $HUD/HealthManaPanel/HealthManaMarginContainer/HealthManaBox/HealthBar
@onready var mana_bar: Range = $HUD/HealthManaPanel/HealthManaMarginContainer/HealthManaBox/ManaBar

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

func _ready() -> void:
	add_to_group("hud")
	inventory_panel.visible = false
	_clear_all_icons()
	_refresh_player_reference()
	_refresh_all_ui()

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_refresh_player_reference()

	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_inventory()

	_refresh_all_ui()

func toggle_inventory() -> void:
	inventory_open = not inventory_open
	inventory_panel.visible = inventory_open

func is_inventory_open() -> bool:
	return inventory_open

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

func _refresh_player_reference() -> void:
	player = get_tree().get_first_node_in_group("player")

func _refresh_all_ui() -> void:
	_refresh_health_ui()
	_refresh_wand_ui()
	_refresh_inventory_ui()
	_apply_spell_selection_visual()

func _refresh_health_ui() -> void:
	if player == null:
		return

	var health_component: Node = player.get_node_or_null("HealthComponent")
	if health_component == null:
		health_component = player.get_node_or_null("PlayerHealthComponent")

	if health_component == null:
		return

	var current_health = health_component.get("health")
	var max_health = health_component.get("max_health")

	if current_health != null and max_health != null:
		set_health(int(current_health), int(max_health))

func _refresh_wand_ui() -> void:
	if player == null:
		return

	var wand: Node = player.get_node_or_null("WandPivot/Wand")
	if wand == null:
		return

	var wand_data = wand.get("wand_data")
	if wand_data != null and wand_data.icon != null:
		wand_icon.texture = wand_data.icon
		wand_icon.visible = true
	else:
		wand_icon.texture = null
		wand_icon.visible = false

	var spells = []
	if wand_data != null:
		var slot_data = wand_data.get("spell_slots")
		if slot_data != null:
			spells = slot_data

	for i in range(spell_icons.size()):
		var icon_rect := spell_icons[i]
		if icon_rect == null:
			continue

		if i < spells.size() and spells[i] != null and spells[i].icon != null:
			icon_rect.texture = spells[i].icon
			icon_rect.visible = true
		else:
			icon_rect.texture = null
			icon_rect.visible = false

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

	var inventory: Node = player.get_node_or_null("Inventory")
	if inventory == null:
		return

	var spells = inventory.get("spell_inventory")
	if spells == null and inventory.has_method("get_spells"):
		spells = inventory.get_spells()

	if spells == null:
		spells = []

	for i in range(inventory_icons.size()):
		var icon_rect := inventory_icons[i]
		if icon_rect == null:
			continue

		if i < spells.size() and spells[i] != null and spells[i].icon != null:
			icon_rect.texture = spells[i].icon
			icon_rect.visible = true
		else:
			icon_rect.texture = null
			icon_rect.visible = false

func _apply_spell_selection_visual() -> void:
	for i in range(spell_slot_panels.size()):
		var panel := spell_slot_panels[i]
		if panel == null:
			continue

		if i == selected_spell_index:
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
