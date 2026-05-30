extends Node
class_name InventoryComponent

@export var max_spells: int = 8

var spell_inventory: Array[SpellData] = []


func _ready() -> void:
	_ensure_slot_capacity()


func _ensure_slot_capacity() -> void:
	if spell_inventory.size() == max_spells:
		return

	if spell_inventory.size() > 0 and spell_inventory.size() < max_spells:
		var migrated: Array[SpellData] = []
		for spell in spell_inventory:
			migrated.append(spell)
		spell_inventory.clear()
		for _i in range(max_spells):
			spell_inventory.append(null)
		for i in range(mini(migrated.size(), max_spells)):
			spell_inventory[i] = migrated[i]
		return

	while spell_inventory.size() < max_spells:
		spell_inventory.append(null)


func add_spell(new_spell: SpellData) -> bool:
	if new_spell == null:
		return false

	var empty_index: int = first_empty_slot()
	if empty_index < 0:
		print("Inventar voll: ", max_spells, " / ", max_spells)
		return false

	set_spell_at(empty_index, new_spell)
	print("Ins Inventar gelegt: ", new_spell.display_name, " -> Slot ", empty_index + 1)
	return true


func get_spells() -> Array[SpellData]:
	_ensure_slot_capacity()
	return spell_inventory


func get_spell_at(index: int) -> SpellData:
	if not _is_valid_index(index):
		return null
	return spell_inventory[index]


func set_spell_at(index: int, spell: SpellData) -> bool:
	if not _is_valid_index(index):
		return false

	spell_inventory[index] = spell
	return true


func remove_spell_at(index: int) -> SpellData:
	if not _is_valid_index(index):
		return null

	var spell: SpellData = spell_inventory[index]
	spell_inventory[index] = null
	return spell


func swap_slots(a: int, b: int) -> bool:
	if not _is_valid_index(a) or not _is_valid_index(b):
		return false

	if a == b:
		return false

	var temp: SpellData = spell_inventory[a]
	spell_inventory[a] = spell_inventory[b]
	spell_inventory[b] = temp
	return true


func first_empty_slot() -> int:
	_ensure_slot_capacity()
	for i in range(max_spells):
		if spell_inventory[i] == null:
			return i
	return -1


func is_full() -> bool:
	return first_empty_slot() < 0


func get_count() -> int:
	_ensure_slot_capacity()
	var count: int = 0
	for spell in spell_inventory:
		if spell != null:
			count += 1
	return count


func get_max_count() -> int:
	return max_spells


func _is_valid_index(index: int) -> bool:
	_ensure_slot_capacity()
	return index >= 0 and index < max_spells
