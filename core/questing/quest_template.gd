extends Resource
class_name QuestTemplate

# Template Metadata
@export var template_id: String
@export var title: String
@export var author: String
@export var version: String = "1.0"
@export var tags: Array[String] = []
@export var difficulty: int = 1
@export var min_player_level: int = 1
@export_multiline var description: String
@export var is_educational: bool = false
@export var is_sponsored: bool = false
@export var sponsor_id: String = ""

# Template Structure
@export var quest_stages: Dictionary = {}
@export var starting_stage: String = "prologue"

# AI Generation Configuration
@export_multiline var theme_prompt: String
@export var tone_options: Array[String] = ["heroic", "mysterious", "humorous", "dramatic"]
@export var selected_tone: String = "heroic"
@export var allow_character_creation: bool = true  # AI can create new NPCs
@export var character_constraints: Dictionary = {}

# Reward Configuration
@export var base_xp: int = 100
@export var base_currency: int = 50
@export var possible_items: Array[String] = []  # Item template IDs
@export var guaranteed_items: Array[String] = []  # Always awarded items

# Template Validation Status
var validation_errors: Array[String] = []

func is_valid() -> bool:
	validation_errors.clear()
	
	# Basic validation
	if template_id.is_empty():
		validation_errors.append("Template ID is required")
	if title.is_empty():
		validation_errors.append("Title is required")
	if quest_stages.is_empty():
		validation_errors.append("Quest must have at least one stage")
	if not quest_stages.has(starting_stage):
		validation_errors.append("Starting stage doesn't exist in quest stages")
	
	return validation_errors.is_empty()

# Stage types
enum StageType {
	NARRATIVE,  # Story text
	CHOICE,     # Player makes a choice
	INPUT,      # Player inputs text
	COMBAT,     # Combat encounter
	REWARD,     # Give rewards
	AI_DIALOGUE, # Dynamic AI-based conversation
	END         # End stage
}

# Stage definition
class QuestTemplateStage:
	var stage_id: String
	var stage_type: StageType
	var title: String = ""
	
	# Basic content
	var static_narration: String = ""  # Fixed narrative text
	var ai_narration_prompt: String = ""  # Prompt for AI to generate narration
	
	# Choice options for CHOICE type
	var choices: Array = []  # Array of Dictionaries with {text, next_stage, conditions}
	
	# For INPUT type
	var input_prompt: String = ""
	var input_validation: String = ""  # Optional regex or criteria
	var ai_response_to_input: bool = false  # If true, AI will respond to player input
	
	# For COMBAT type
	var combat_type: String = "standard"  # standard, boss, puzzle, etc.
	var enemy_templates: Array = []  # Enemy template IDs
	var difficulty_scaling: bool = true
	
	# For REWARD type
	var xp_modifier: float = 1.0
	var currency_modifier: float = 1.0
	var item_chances: Dictionary = {}  # item_id: drop_chance (0-100)
	
	# For AI_DIALOGUE type
	var npc_id: String = ""
	var npc_description: String = ""
	var dialogue_context: String = ""
	var knowledge_integration: Array = []  # Player knowledge fields to use
	
	# Progression
	var next_stage: String = ""  # Default next stage
	var conditions: Dictionary = {}  # Conditions for stage visibility/availability
	
	# Flags and state changes
	var sets_flags: Dictionary = {}  # Flags this stage sets when completed
	
	func _init(data: Dictionary = {}) -> void:
		if data.is_empty():
			return
		
		stage_id = data.get("stage_id", "")
		title = data.get("title", "")
		
		# Determine stage type from content
		if data.get("is_end", false):
			stage_type = StageType.END
		elif data.has("combat_type"):
			stage_type = StageType.COMBAT
		elif data.has("input_prompt"):
			stage_type = StageType.INPUT
		elif not data.get("choices", []).is_empty():
			stage_type = StageType.CHOICE
		elif data.has("dialogue_context"):
			stage_type = StageType.AI_DIALOGUE
		elif data.has("xp_modifier") or data.has("currency_modifier"):
			stage_type = StageType.REWARD
		else:
			stage_type = StageType.NARRATIVE
		
		# Copy all other properties
		static_narration = data.get("static_narration", "")
		ai_narration_prompt = data.get("ai_narration_prompt", "")
		choices = data.get("choices", [])
		input_prompt = data.get("input_prompt", "")
		input_validation = data.get("input_validation", "")
		ai_response_to_input = data.get("ai_response_to_input", false)
		combat_type = data.get("combat_type", "standard")
		enemy_templates = data.get("enemy_templates", [])
		difficulty_scaling = data.get("difficulty_scaling", true)
		xp_modifier = data.get("xp_modifier", 1.0)
		currency_modifier = data.get("currency_modifier", 1.0)
		item_chances = data.get("item_chances", {})
		npc_id = data.get("npc_id", "")
		npc_description = data.get("npc_description", "")
		dialogue_context = data.get("dialogue_context", "")
		knowledge_integration = data.get("knowledge_integration", [])
		next_stage = data.get("next_stage", "")
		conditions = data.get("conditions", {})
		sets_flags = data.get("sets_flags", {})

# Helper methods to create and manage stages
func add_stage(stage_id: String, stage_data: Dictionary) -> void:
	var stage = QuestTemplateStage.new(stage_data)
	stage.stage_id = stage_id
	quest_stages[stage_id] = stage

func get_stage(stage_id: String) -> QuestTemplateStage:
	if quest_stages.has(stage_id):
		return quest_stages[stage_id]
	return null

# Export to JSON for storage and sharing
func to_json() -> String:
	var export_data = {
		"template_id": template_id,
		"title": title,
		"author": author,
		"version": version,
		"tags": tags,
		"difficulty": difficulty,
		"min_player_level": min_player_level,
		"description": description,
		"is_educational": is_educational,
		"is_sponsored": is_sponsored,
		"sponsor_id": sponsor_id,
		"starting_stage": starting_stage,
		"theme_prompt": theme_prompt,
		"selected_tone": selected_tone,
		"allow_character_creation": allow_character_creation,
		"character_constraints": character_constraints,
		"base_xp": base_xp,
		"base_currency": base_currency,
		"possible_items": possible_items,
		"guaranteed_items": guaranteed_items,
		
		# Convert stages to serializable format
		"stages": _serialize_stages()
	}
	
	return JSON.stringify(export_data)

# Import from JSON
func from_json(json_text: String) -> Error:
	var json = JSON.parse_string(json_text)
	if json == null:
		return ERR_PARSE_ERROR
		
	# Load basic properties
	template_id = json.get("template_id", "")
	title = json.get("title", "")
	author = json.get("author", "")
	version = json.get("version", "1.0")
	tags = json.get("tags", [])
	difficulty = json.get("difficulty", 1)
	min_player_level = json.get("min_player_level", 1)
	description = json.get("description", "")
	is_educational = json.get("is_educational", false)
	is_sponsored = json.get("is_sponsored", false)
	sponsor_id = json.get("sponsor_id", "")
	starting_stage = json.get("starting_stage", "prologue")
	theme_prompt = json.get("theme_prompt", "")
	selected_tone = json.get("selected_tone", "heroic")
	allow_character_creation = json.get("allow_character_creation", true)
	character_constraints = json.get("character_constraints", {})
	base_xp = json.get("base_xp", 100)
	base_currency = json.get("base_currency", 50)
	possible_items = json.get("possible_items", [])
	guaranteed_items = json.get("guaranteed_items", [])
	
	# Load stages
	_deserialize_stages(json.get("stages", {}))
	
	return OK

# Helper for stage serialization
func _serialize_stages() -> Dictionary:
	var serialized = {}
	for stage_id in quest_stages:
		var stage = quest_stages[stage_id]
		serialized[stage_id] = {
			"title": stage.title,
			"stage_type": stage.stage_type,
			"static_narration": stage.static_narration,
			"ai_narration_prompt": stage.ai_narration_prompt,
			"choices": stage.choices,
			"input_prompt": stage.input_prompt,
			"input_validation": stage.input_validation,
			"ai_response_to_input": stage.ai_response_to_input,
			"combat_type": stage.combat_type,
			"enemy_templates": stage.enemy_templates,
			"difficulty_scaling": stage.difficulty_scaling,
			"xp_modifier": stage.xp_modifier,
			"currency_modifier": stage.currency_modifier,
			"item_chances": stage.item_chances,
			"npc_id": stage.npc_id,
			"npc_description": stage.npc_description,
			"dialogue_context": stage.dialogue_context,
			"knowledge_integration": stage.knowledge_integration,
			"next_stage": stage.next_stage,
			"conditions": stage.conditions,
			"sets_flags": stage.sets_flags
		}
	return serialized

# Helper for stage deserialization
func _deserialize_stages(stage_data: Dictionary) -> void:
	quest_stages.clear()
	for stage_id in stage_data:
		add_stage(stage_id, stage_data[stage_id])
