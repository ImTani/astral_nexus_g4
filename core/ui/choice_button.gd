class_name ChoiceButton
extends HBoxContainer

@export_subgroup("Parameters")
@export var button_text: String = "Text"

@export_subgroup("UI") 
@export var button: Button
@export var arrow_label: Label

func _ready() -> void:
	button.text = button_text

func _on_button_focus_exited() -> void:
	arrow_label.modulate.a = 0.0

func _on_button_focus_entered() -> void:
	arrow_label.modulate.a = 1.0
