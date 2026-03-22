extends CanvasLayer

@onready var health_bar = $Control/MarginContainer/VBoxContainer/HealthBar
@onready var mana_bar = $Control/MarginContainer/VBoxContainer/ManaBar

@onready var spell_slot_1 = $Control/SpellBar/MarginContainer/HBoxSpell/SpellSlot1
@onready var spell_slot_2 = $Control/SpellBar/MarginContainer/HBoxSpell/SpellSlot2
@onready var spell_slot_3 = $Control/SpellBar/MarginContainer/HBoxSpell/SpellSlot3

func _ready() -> void:
	update_spell_selection(0)

func update_health(current: float, max_value: float) -> void:
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
	_reset_spell_slots()

	match active_index:
		0:
			if spell_slot_1 != null:
				spell_slot_1.modulate = Color(1, 1, 0.6)
		1:
			if spell_slot_2 != null:
				spell_slot_2.modulate = Color(1, 1, 0.6)
		2:
			if spell_slot_3 != null:
				spell_slot_3.modulate = Color(1, 1, 0.6)

func _reset_spell_slots() -> void:
	if spell_slot_1 != null:
		spell_slot_1.modulate = Color(1, 1, 1)

	if spell_slot_2 != null:
		spell_slot_2.modulate = Color(1, 1, 1)

	if spell_slot_3 != null:
		spell_slot_3.modulate = Color(1, 1, 1)
