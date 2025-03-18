extends VBoxContainer

@export var choices = [
	{"id": 0, "text": "Attack"},
	{"id": 1, "text": "Defend"},
	{"id": 2, "text": "Run Away"}
]

func _ready() -> void:
	var first_choice: ChoiceButton = get_child(0)
	first_choice.button.grab_focus.call_deferred()
