extends Node

var TUTORIAL_STEPS = {
	"INTRO": {
		"text": """In the vast expanse of the Astral Nexus, countless stories unfold across the cosmos. Your journey begins here, as you take your first steps into a universe of infinite possibilities.

Choose your path carefully, for every decision shapes the tapestry of your destiny.""",
		"choices": []
	},
	"AWAKENING": {
		"text": """Your consciousness stirs, memories fragmented like scattered starlight. The familiar hum of a quantum engine fills your ears as you open your eyes to the soft blue glow of emergency lighting.

A voice echoes through your mind: 'Wake up, traveler. Your journey begins now.'""",
		"choices": [
			{"id": "look_around", "text": "Look around the room"},
			{"id": "check_self", "text": "Check yourself for injuries"},
			{"id": "call_out", "text": "Call out for help"}
		]
	}
}

var current_step = "INTRO"
var character_data = null
@onready var story_display = $"../MarginContainer/VBoxContainer/StoryDisplay"
@onready var character_creation = $"../MarginContainer/VBoxContainer/CharacterCreation"
@onready var choices_container = $"../MarginContainer/VBoxContainer/ChoicesContainer"

func _ready():
	character_creation.character_created.connect(_on_character_created)
	show_current_step()

func show_current_step():
	var step_data = TUTORIAL_STEPS[current_step]
	story_display.display_text(step_data.text)
	
	if step_data.has("choices") and step_data.choices.size() > 0:
		show_choices(step_data.choices)

func show_choices(choices):
	# Clear existing choices
	for child in choices_container.get_children():
		child.queue_free()
	
	# Create new choice buttons
	for choice in choices:
		var button = create_choice_button(choice.text)
		button.pressed.connect(func(): handle_choice(choice.id))
		choices_container.add_child(button)

func create_choice_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.x = 200
	return button

func handle_choice(choice_id: String):
	match choice_id:
		"look_around":
			advance_to_look_around()
		"check_self":
			advance_to_check_self()
		"call_out":
			advance_to_call_out()

func _on_character_created(data):
	character_data = data
	current_step = "AWAKENING"
	show_current_step()

func advance_to_look_around():
	var class_specific_text = ""
	match character_data.class:
		"warrior":
			class_specific_text = "Your trained eye immediately spots potential weapons among the debris."
		"mage":
			class_specific_text = "You sense residual magical energy permeating the room."
		"rogue":
			class_specific_text = "You notice several potential escape routes and hiding spots."
		"scholar":
			class_specific_text = "You recognize various technological artifacts from your studies."
	
	var text = """The room comes into focus as your eyes adjust to the dim light. You find yourself in what appears to be a small spacecraft's medical bay, though much of the equipment lies damaged or offline. %s

Through the viewport, an unfamiliar starfield stretches into infinity.""" % class_specific_text
	
	story_display.display_text(text)

func advance_to_check_self():
	# Similar implementation for checking self
	pass

func advance_to_call_out():
	# Similar implementation for calling out
	pass
