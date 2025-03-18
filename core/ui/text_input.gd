extends Control

signal input_submitted(text: String)

@export_subgroup("UI")
@export var prompt_label: Label
@export var input_field: LineEdit

func _ready() -> void:
	input_field.text_submitted.connect(_on_text_submitted)

func set_prompt(prompt: String) -> void:
	prompt_label.text = prompt
	input_field.grab_focus()

func _on_submit_pressed() -> void:
	_submit_input()

func _on_text_submitted(text: String) -> void:
	_submit_input()

func _submit_input() -> void:
	if not input_field.text.strip_edges().is_empty():
		emit_signal("input_submitted", input_field.text)
