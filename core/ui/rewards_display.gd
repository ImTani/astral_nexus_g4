extends Control

signal rewards_acknowledged

@export_subgroup("UI")
@export var xp_label: Label
@export var currency_label: Label
@export var choice_button: ChoiceButton

var continue_button: Button

func _ready() -> void:
	continue_button = choice_button.button
	continue_button.pressed.connect(_on_continue_pressed)

func display_rewards(rewards: Array[Rewards]) -> void:
	var total_xp := 0
	var total_currency := 0
	var items_container := ""
	
	for reward in rewards:
		total_xp += reward.xp
		total_currency += reward.currency
	
	xp_label.text = "XP Gained: %d" % total_xp
	currency_label.text = "Currency Gained: %d" % total_currency

func _on_continue_pressed() -> void:
	emit_signal("rewards_acknowledged")
