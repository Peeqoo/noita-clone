extends Node
class_name PlayerInventoryComponent

@onready var inventory: InventoryComponent = $"../Inventory"
@onready var wand = $"../WandPivot/Wand"

func equip_inventory_spell_to_wand(inventory_index: int, slot_index: int) -> bool:
	if inventory == null:
		return false

	if wand == null:
		return false

	var new_spell: SpellData = inventory.remove_spell_at(inventory_index)
	if new_spell == null:
		return false

	var old_spell: SpellData = wand.get_spell_in_slot(slot_index)

	if old_spell != null:
		inventory.add_spell(old_spell)

	var success: bool = wand.set_spell_in_slot(slot_index, new_spell)

	if success:
		print("Spell aus Inventory in Wand gelegt: ", new_spell.display_name, " -> Slot ", slot_index)
		return true

	inventory.add_spell(new_spell)
	return false

func unequip_wand_spell_to_inventory(slot_index: int) -> bool:
	if inventory == null:
		return false

	if wand == null:
		return false

	var spell: SpellData = wand.remove_spell_from_slot(slot_index)
	if spell == null:
		return false

	inventory.add_spell(spell)
	print("Spell aus Wand ins Inventory gelegt: ", spell.display_name)
	return true
