extends Panel
class_name SpellSlotUI

const DRAG_TYPE: StringName = &"spell_slot_drag"

@export var slot_container: StringName = &"inventory"
@export var slot_index: int = 0

var hud_ref: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center: Node = get_node_or_null("Center")
	if center is Control:
		(center as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon: Node = get_node_or_null("Center/Icon")
	if icon is Control:
		(icon as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_drag_data(_at_position: Vector2) -> Variant:
	if hud_ref == null or not hud_ref.has_method("is_inventory_open"):
		return null

	if not hud_ref.is_inventory_open():
		return null

	var spell: SpellData = _get_spell_at_slot()
	if spell == null:
		return null

	if hud_ref.has_method("begin_spell_drag_visual"):
		hud_ref.begin_spell_drag_visual(slot_container, slot_index)

	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(16, 16)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if spell.icon != null:
		preview.texture = spell.icon
	set_drag_preview(preview)

	return {
		"type": DRAG_TYPE,
		"source_container": slot_container,
		"source_index": slot_index,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _is_valid_drag_data(data):
		return false

	if hud_ref == null or not hud_ref.is_inventory_open():
		return false

	var source_container: StringName = data["source_container"]
	var source_index: int = int(data["source_index"])
	if source_container == slot_container and source_index == slot_index:
		return false

	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _is_valid_drag_data(data):
		return

	if hud_ref == null:
		return

	var player_inventory: Node = hud_ref.get_player_inventory_component()
	if player_inventory == null:
		return

	if not player_inventory.has_method("apply_spell_slot_operation"):
		return

	var source_container: StringName = data["source_container"]
	var source_index: int = int(data["source_index"])

	var success: bool = player_inventory.apply_spell_slot_operation(
		source_container,
		source_index,
		slot_container,
		slot_index
	)

	if success and hud_ref.has_method("refresh_after_slot_change"):
		hud_ref.refresh_after_slot_change()


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return

	if hud_ref == null:
		return

	if hud_ref.has_method("end_spell_drag_visual"):
		hud_ref.end_spell_drag_visual()

	if hud_ref.has_method("refresh_after_slot_change"):
		hud_ref.refresh_after_slot_change()


func _is_valid_drag_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("type", "") != DRAG_TYPE:
		return false
	if not data.has("source_container") or not data.has("source_index"):
		return false
	return true


func _get_spell_at_slot() -> SpellData:
	if hud_ref == null:
		return null

	if slot_container == &"inventory":
		var inventory: InventoryComponent = hud_ref.get_inventory_component()
		if inventory != null:
			return inventory.get_spell_at(slot_index)

	if slot_container == &"wand":
		var player: Node = hud_ref.get("player")
		if player == null:
			return null
		var wand: Node = player.get_node_or_null("Visuals/WandPivot/Wand")
		if wand != null and wand.has_method("get_spell_in_slot"):
			return wand.get_spell_in_slot(slot_index)

	return null
