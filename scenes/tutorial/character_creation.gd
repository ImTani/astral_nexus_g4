extends VBoxContainer

signal character_created(character_data)

const CHARACTER_CLASSES = {
	"warrior": {
		"name": "Warrior",
		"description": "A skilled fighter with high strength and defense",
		"base_stats": {
			"strength": 8,
			"agility": 5,
			"intelligence": 3,
			"health": 100,
			"mana": 20
		}
	},
	"mage": {
		"name": "Mage",
		"description": "A master of arcane arts with powerful spells",
		"base_stats": {
			"strength": 3,
			"agility": 4,
			"intelligence": 9,
			"health": 70,
			"mana": 100
		}
	},
	"rogue": {
		"name": "Rogue",
		"description": "A nimble adventurer specializing in stealth",
		"base_stats": {
			"strength": 4,
			"agility": 9,
			"intelligence": 5,
			"health": 80,
			"mana": 40
		}
	},
	"scholar": {
		"name": "Scholar",
		"description": "A knowledgeable explorer with unique insights",
		"base_stats": {
			"strength": 3,
			"agility": 4,
			"intelligence": 8,
			"health": 75,
			"mana": 80
		}
	}
}

var current_step = 0
var character_data = {
	"class": "",
	"name": "",
	"background": "",
	"stats": {}
}

@onready var choice_button_scene = preload("res://scenes/core/choice_button.tscn")

func _ready():
	show_class_selection()

func show_class_selection():
	clear_choices()
	
	for class_id in CHARACTER_CLASSES:
		var class_info = CHARACTER_CLASSES[class_id]
		var choice = create_choice_button(
			class_info.name,
			func(): select_class(class_id)
		)
		add_child(choice)

func select_class(class_id):
	character_data.class = class_id
	character_data.stats = CHARACTER_CLASSES[class_id].base_stats.duplicate()
	show_name_input()

func show_name_input():
	clear_choices()
	# Name input implementation
	# For now, just use a placeholder name
	character_data.name = "Adventurer"
	show_background_selection()

func show_background_selection():
	clear_choices()
	
	var backgrounds = [
		{"id": "noble", "name": "Noble Born", "description": "You come from a prestigious family"},
		{"id": "street", "name": "Street Smart", "description": "You learned life's lessons the hard way"},
		{"id": "merchant", "name": "Merchant Family", "description": "You grew up learning the art of trade"},
		{"id": "nomad", "name": "Wandering Nomad", "description": "You've never called one place home"}
	]
	
	for bg in backgrounds:
		var choice = create_choice_button(
			bg.name,
			func(): select_background(bg.id)
		)
		add_child(choice)

func select_background(background_id):
	character_data.background = background_id
	emit_signal("character_created", character_data)

func create_choice_button(text: String, callback: Callable) -> Node:
	var choice_button = choice_button_scene.instantiate()
	choice_button.button_text = text
	choice_button.button.pressed.connect(callback)
	return choice_button

func clear_choices():
	for child in get_children():
		child.queue_free()
