extends Panel
class_name SpellStatsHoverPanel

const STAT_FONT_SIZE := 11
const HEADER_FONT_SIZE := 13
const SCREEN_MARGIN := 8.0
const BOTTOM_MARGIN := 16.0

@onready var _spell_name_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/SpellNameLabel
@onready var _damage_label: Label = $MarginContainer/VBoxContainer/DamageLabel
@onready var _mana_cost_label: Label = $MarginContainer/VBoxContainer/ManaCostLabel
@onready var _cast_delay_add_label: Label = $MarginContainer/VBoxContainer/CastDelayAddLabel
@onready var _projectiles_label: Label = $MarginContainer/VBoxContainer/ProjectilesLabel
@onready var _spread_label: Label = $MarginContainer/VBoxContainer/SpreadLabel
@onready var _crit_label: Label = $MarginContainer/VBoxContainer/CritLabel
@onready var _speed_label: Label = $MarginContainer/VBoxContainer/SpeedLabel
@onready var _lifetime_label: Label = $MarginContainer/VBoxContainer/LifetimeLabel
@onready var _wand_summary_separator: HSeparator = $MarginContainer/VBoxContainer/WandSummarySeparator
@onready var _wand_summary_box: VBoxContainer = $MarginContainer/VBoxContainer/WandSummaryBox
@onready var _wand_summary_name_label: Label = (
	$MarginContainer/VBoxContainer/WandSummaryBox/WandSummaryNameLabel
)
@onready var _wand_summary_mana_label: Label = (
	$MarginContainer/VBoxContainer/WandSummaryBox/WandSummaryManaLabel
)
@onready var _wand_summary_cast_delay_label: Label = (
	$MarginContainer/VBoxContainer/WandSummaryBox/WandSummaryCastDelayLabel
)
@onready var _wand_summary_recharge_label: Label = (
	$MarginContainer/VBoxContainer/WandSummaryBox/WandSummaryRechargeLabel
)
@onready var _wand_summary_damage_mult_label: Label = (
	$MarginContainer/VBoxContainer/WandSummaryBox/WandSummaryDamageMultLabel
)
@onready var _effective_damage_label: Label = (
	$MarginContainer/VBoxContainer/WandSummaryBox/EffectiveDamageLabel
)
@onready var _effective_crit_label: Label = (
	$MarginContainer/VBoxContainer/WandSummaryBox/EffectiveCritLabel
)
@onready var _root_vbox: VBoxContainer = $MarginContainer/VBoxContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_label_font_sizes()
	_set_wand_summary_visible(false)


func hide_panel() -> void:
	visible = false


func show_spell(spell: SpellData, screen_position: Vector2) -> void:
	if spell == null:
		hide_panel()
		return

	_set_wand_summary_visible(false)
	_fill_spell_header(spell)
	_fill_spell_stats(spell)
	_show_and_position(screen_position)


func show_spell_with_wand(spell: SpellData, wand: Node, screen_position: Vector2) -> void:
	if spell == null:
		hide_panel()
		return

	_fill_spell_header(spell)
	_fill_spell_stats(spell)
	_set_wand_summary_visible(true)
	_fill_wand_summary(spell, wand)
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
	_spell_name_label.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)

	for label in [
		_damage_label,
		_mana_cost_label,
		_cast_delay_add_label,
		_projectiles_label,
		_spread_label,
		_crit_label,
		_speed_label,
		_lifetime_label,
		_wand_summary_name_label,
		_wand_summary_mana_label,
		_wand_summary_cast_delay_label,
		_wand_summary_recharge_label,
		_wand_summary_damage_mult_label,
		_effective_damage_label,
		_effective_crit_label,
	]:
		label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)


func _set_wand_summary_visible(visible_flag: bool) -> void:
	_wand_summary_separator.visible = visible_flag
	_wand_summary_box.visible = visible_flag


func _fill_spell_header(spell: SpellData) -> void:
	_spell_name_label.text = spell.display_name if not spell.display_name.is_empty() else "Spell"


func _fill_spell_stats(spell: SpellData) -> void:
	_damage_label.text = "Damage: %d" % spell.damage
	_mana_cost_label.text = "Mana Cost: %s" % _fmt_float(spell.mana_cost)
	_cast_delay_add_label.text = "Cast Delay: +%ss" % _fmt_seconds(spell.cast_delay_add)
	_projectiles_label.text = "Projectiles: %d" % spell.projectile_count
	_spread_label.text = "Spread: %s°" % _fmt_float(spell.spread_degrees)
	_crit_label.text = "Crit: %s%% / %sx" % [
		_fmt_percent(spell.crit_chance),
		_fmt_float(spell.crit_multiplier),
	]
	_speed_label.text = "Speed: %s" % _fmt_float(spell.speed)
	_lifetime_label.text = "Lifetime: %ss" % _fmt_seconds(spell.lifetime)


func _fill_wand_summary(spell: SpellData, wand: Node) -> void:
	var wand_data: WandData = wand.get("wand_data") as WandData
	if wand_data == null:
		_wand_summary_name_label.text = "Current Wand: —"
		_wand_summary_mana_label.visible = false
		_wand_summary_cast_delay_label.visible = false
		_wand_summary_recharge_label.visible = false
		_wand_summary_damage_mult_label.visible = false
		_effective_damage_label.visible = false
		_effective_crit_label.visible = false
		return

	_wand_summary_name_label.text = wand_data.display_name
	var current_mana: float = float(wand.get("current_mana"))
	_wand_summary_mana_label.text = "Mana: %s / %s" % [_fmt_float(current_mana), _fmt_float(wand_data.mana_max)]
	_wand_summary_mana_label.visible = true
	_wand_summary_cast_delay_label.text = "Cast Delay: %ss" % _fmt_seconds(wand_data.cast_delay)
	_wand_summary_cast_delay_label.visible = true
	_wand_summary_recharge_label.text = "Recharge: %ss" % _fmt_seconds(wand_data.recharge_time)
	_wand_summary_recharge_label.visible = true
	_wand_summary_damage_mult_label.text = "Damage Mult: %sx" % _fmt_float(wand_data.damage_multiplier)
	_wand_summary_damage_mult_label.visible = true

	var effective_damage: int = maxi(
		1,
		int(round(float(spell.damage) * wand_data.damage_multiplier))
	)
	_effective_damage_label.text = "Eff. Damage: %d" % effective_damage
	_effective_damage_label.visible = true

	var effective_crit: float = clampf(
		spell.crit_chance + wand_data.crit_chance_bonus,
		0.0,
		1.0
	)
	var effective_crit_mult: float = maxf(
		1.0,
		spell.crit_multiplier + wand_data.crit_multiplier_bonus
	)
	_effective_crit_label.text = "Eff. Crit: %s%% / %sx" % [
		_fmt_percent(effective_crit),
		_fmt_float(effective_crit_mult),
	]
	_effective_crit_label.visible = true


func _fmt_float(value: float) -> String:
	return str(snappedf(value, 0.01))


func _fmt_seconds(value: float) -> String:
	return _fmt_float(value)


func _fmt_percent(ratio: float) -> String:
	return _fmt_float(ratio * 100.0)
