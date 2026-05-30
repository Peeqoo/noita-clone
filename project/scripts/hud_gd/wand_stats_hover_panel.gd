extends Panel
class_name WandStatsHoverPanel

const STAT_FONT_SIZE := 11
const HEADER_FONT_SIZE := 13
const SCREEN_MARGIN := 8.0
const BOTTOM_MARGIN := 16.0

@onready var _empty_slot_label: Label = $MarginContainer/VBoxContainer/EmptySlotLabel
@onready var _wand_name_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/WandNameLabel
@onready var _mana_label: Label = $MarginContainer/VBoxContainer/ManaLabel
@onready var _mana_regen_label: Label = $MarginContainer/VBoxContainer/ManaRegenLabel
@onready var _cast_delay_label: Label = $MarginContainer/VBoxContainer/CastDelayLabel
@onready var _recharge_label: Label = $MarginContainer/VBoxContainer/RechargeLabel
@onready var _slots_label: Label = $MarginContainer/VBoxContainer/SlotsLabel
@onready var _damage_mult_label: Label = $MarginContainer/VBoxContainer/DamageMultLabel
@onready var _crit_bonus_label: Label = $MarginContainer/VBoxContainer/CritBonusLabel
@onready var _crit_mult_bonus_label: Label = $MarginContainer/VBoxContainer/CritMultBonusLabel
@onready var _shuffle_label: Label = $MarginContainer/VBoxContainer/ShuffleLabel
@onready var _root_vbox: VBoxContainer = $MarginContainer/VBoxContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_label_font_sizes()


func hide_panel() -> void:
	visible = false


func show_wand(wand: Node, screen_position: Vector2) -> void:
	if wand == null:
		hide_panel()
		return

	_empty_slot_label.visible = false
	_fill_wand_stats(wand)
	_show_and_position(screen_position)


func show_empty_wand_slot(wand: Node, screen_position: Vector2) -> void:
	if wand == null:
		hide_panel()
		return

	_empty_slot_label.visible = true
	_fill_wand_stats(wand)
	_show_and_position(screen_position)


func set_screen_position(screen_position: Vector2) -> void:
	global_position = _clamp_to_viewport(screen_position)


func _clamp_to_viewport(pos: Vector2) -> Vector2:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var panel_size: Vector2 = size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = get_combined_minimum_size()

	pos.x = clampf(
		pos.x,
		viewport_rect.position.x + SCREEN_MARGIN,
		viewport_rect.position.x + viewport_rect.size.x - SCREEN_MARGIN - panel_size.x
	)
	pos.y = clampf(
		pos.y,
		viewport_rect.position.y + SCREEN_MARGIN,
		viewport_rect.position.y + viewport_rect.size.y - BOTTOM_MARGIN - panel_size.y
	)
	return pos


func _show_and_position(screen_position: Vector2) -> void:
	_root_vbox.reset_size()
	reset_size()
	visible = true
	set_screen_position(screen_position)


func _apply_label_font_sizes() -> void:
	_wand_name_label.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	_empty_slot_label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)

	for label in [
		_mana_label,
		_mana_regen_label,
		_cast_delay_label,
		_recharge_label,
		_slots_label,
		_damage_mult_label,
		_crit_bonus_label,
		_crit_mult_bonus_label,
		_shuffle_label,
	]:
		label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)


func _fill_wand_stats(wand: Node) -> void:
	var wand_data: WandData = wand.get("wand_data") as WandData
	if wand_data == null:
		_wand_name_label.text = "Wand"
		_mana_label.text = "No wand data"
		_mana_regen_label.visible = false
		_cast_delay_label.visible = false
		_recharge_label.visible = false
		_slots_label.visible = false
		_damage_mult_label.visible = false
		_crit_bonus_label.visible = false
		_crit_mult_bonus_label.visible = false
		_shuffle_label.visible = false
		return

	_wand_name_label.text = wand_data.display_name

	var current_mana: float = float(wand.get("current_mana"))
	_mana_label.text = "Mana: %s / %s" % [_fmt_float(current_mana), _fmt_float(wand_data.mana_max)]
	_mana_label.visible = true
	_mana_regen_label.text = "Regen: %s/s" % _fmt_float(wand_data.mana_regen)
	_mana_regen_label.visible = true
	_cast_delay_label.text = "Cast Delay: %ss" % _fmt_seconds(wand_data.cast_delay)
	_cast_delay_label.visible = true
	_recharge_label.text = "Recharge: %ss" % _fmt_seconds(wand_data.recharge_time)
	_recharge_label.visible = true

	var used_slots: int = 0
	var total_slots: int = 0
	if wand.has_method("get_spell_slots"):
		var slots: Array = wand.get_spell_slots()
		total_slots = slots.size()
		for slot_spell in slots:
			if slot_spell != null:
				used_slots += 1
	elif wand.has_method("get_wand_spell_slot_count"):
		total_slots = wand.get_wand_spell_slot_count()

	_slots_label.text = "Slots: %d / %d" % [used_slots, total_slots]
	_slots_label.visible = true
	_damage_mult_label.text = "Damage Mult: %sx" % _fmt_float(wand_data.damage_multiplier)
	_damage_mult_label.visible = true

	if wand_data.crit_chance_bonus != 0.0:
		_crit_bonus_label.text = "Crit Bonus: +%s%%" % _fmt_percent(wand_data.crit_chance_bonus)
		_crit_bonus_label.visible = true
	else:
		_crit_bonus_label.visible = false

	if wand_data.crit_multiplier_bonus != 0.0:
		_crit_mult_bonus_label.text = "Crit Mult Bonus: +%s" % _fmt_float(wand_data.crit_multiplier_bonus)
		_crit_mult_bonus_label.visible = true
	else:
		_crit_mult_bonus_label.visible = false

	_shuffle_label.text = "Shuffle: %s" % ("On" if wand_data.shuffle else "Off")
	_shuffle_label.visible = true


func _fmt_float(value: float) -> String:
	return str(snappedf(value, 0.01))


func _fmt_seconds(value: float) -> String:
	return _fmt_float(value)


func _fmt_percent(ratio: float) -> String:
	return _fmt_float(ratio * 100.0)
