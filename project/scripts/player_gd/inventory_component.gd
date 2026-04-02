extends Node
class_name InventoryComponent

@export var max_spells: int = 8

var spell_inventory: Array[SpellData] = []

func add_spell(new_spell: SpellData) -> bool:
	if new_spell == null:
		return false

	if is_full():
		print("Inventar voll: ", max_spells, " / ", max_spells)
		return false

	spell_inventory.append(new_spell)
	print("Ins Inventar gelegt: ", new_spell.display_name)
	print("Inventar-Anzahl: ", spell_inventory.size())
	return true

func get_spells() -> Array[SpellData]:
	return spell_inventory

func get_spell_at(index: int) -> SpellData:
	if index < 0 or index >= spell_inventory.size():
		return null
	return spell_inventory[index]

func remove_spell_at(index: int) -> SpellData:
	if index < 0 or index >= spell_inventory.size():
		return null

	var spell: SpellData = spell_inventory[index]
	spell_inventory.remove_at(index)
	return spell

func is_full() -> bool:
	return spell_inventory.size() >= max_spells

func get_count() -> int:
	return spell_inventory.size()

func get_max_count() -> int:
	return max_spells
