extends Node
class_name PlayerInventoryComponent

const CONTAINER_INVENTORY: StringName = &"inventory"
const CONTAINER_WAND: StringName = &"wand"

@onready var inventory: InventoryComponent = $"../InventoryComponent"
@onready var wand = $"../../Visuals/WandPivot/Wand"


func apply_spell_slot_operation(
	from_container: StringName,
	from_index: int,
	to_container: StringName,
	to_index: int
) -> bool:
	if inventory == null or wand == null:
		return false

	if from_container == to_container and from_index == to_index:
		return false

	if not _is_valid_slot(from_container, from_index):
		return false

	if not _is_valid_slot(to_container, to_index):
		return false

	var from_spell: SpellData = _get_spell_ref(from_container, from_index)
	if from_spell == null:
		return false

	var to_spell: SpellData = _get_spell_ref(to_container, to_index)

	if to_spell == null:
		if not _set_spell_ref(to_container, to_index, from_spell):
			return false
		if not _set_spell_ref(from_container, from_index, null):
			_set_spell_ref(to_container, to_index, null)
			return false
	else:
		if not _set_spell_ref(from_container, from_index, to_spell):
			return false
		if not _set_spell_ref(to_container, to_index, from_spell):
			_set_spell_ref(from_container, from_index, from_spell)
			_set_spell_ref(to_container, to_index, to_spell)
			return false

	_notify_wand_slots_changed()
	return true


func equip_inventory_spell_to_wand(inventory_index: int, slot_index: int) -> bool:
	return apply_spell_slot_operation(
		CONTAINER_INVENTORY,
		inventory_index,
		CONTAINER_WAND,
		slot_index
	)


func unequip_wand_spell_to_inventory(wand_slot_index: int, inventory_index: int) -> bool:
	return apply_spell_slot_operation(
		CONTAINER_WAND,
		wand_slot_index,
		CONTAINER_INVENTORY,
		inventory_index
	)


func _get_spell_ref(container: StringName, index: int) -> SpellData:
	if container == CONTAINER_INVENTORY:
		return inventory.get_spell_at(index)
	if container == CONTAINER_WAND:
		return wand.get_spell_in_slot(index)
	return null


func _set_spell_ref(container: StringName, index: int, spell: SpellData) -> bool:
	if container == CONTAINER_INVENTORY:
		return inventory.set_spell_at(index, spell)
	if container == CONTAINER_WAND:
		return wand.set_spell_in_slot(index, spell)
	return false


func _is_valid_slot(container: StringName, index: int) -> bool:
	if container == CONTAINER_INVENTORY:
		return index >= 0 and index < inventory.get_max_count()
	if container == CONTAINER_WAND:
		if wand == null:
			return false
		if wand.has_method("get_wand_spell_slot_count"):
			return index >= 0 and index < wand.get_wand_spell_slot_count()
		return index >= 0 and index < 5
	return false


func _notify_wand_slots_changed() -> void:
	if wand == null:
		return

	if wand.has_method("notify_spell_slots_changed"):
		wand.notify_spell_slots_changed()
