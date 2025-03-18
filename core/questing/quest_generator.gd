extends Node
class_name QuestGenerator

signal generation_progress(stage: String, progress: float)
signal generation_complete(generated_quest: GeneratedQuest)
signal generation_failed(error: String)

# Ollama integration
var ollama_client: Ollama
var player_data: Dictionary = {}
var world_state: Dictionary = {}

# Generation task tracking
var _current_template: QuestTemplate
var _generated_quest: GeneratedQuest
var _generation_queue: Array = []
var _is_generating: bool = false

# System prompts for different generation tasks
const NARRATION_SYSTEM_PROMPT = """
You are an AI quest writer for a fantasy RPG called Astral Nexus. Generate creative narrative text based on the prompt.
Keep your responses concise (maximum 3 paragraphs) and engaging.
Format your response as plain text without additional explanations.
Use the specified tone and incorporate the player's name and relevant attributes naturally.
Include [NARRATION] at the start of your response.
"""

const DIALOGUE_SYSTEM_PROMPT = """
You are an AI acting as a character in the fantasy RPG Astral Nexus. 
Generate dialogue based on the character description and context.
Keep responses in character and concise (1-3 paragraphs).
Format as plain text without explanations or descriptions.
Respond directly as the character would speak to the player.
Include [DIALOGUE] at the start of your response.
"""

const CHOICE_SYSTEM_PROMPT = """
You are an AI quest writer for the fantasy RPG Astral Nexus.
Generate {number} distinct and interesting choices for the player based on the provided context.
Each choice should be 1-2 sentences only.
Format your response as a JSON array of choice objects:
[{{"text": "Choice text here", "consequences": "Brief description of likely outcome"}}]
Keep consequences very short (5-15 words).
"""

func _init() -> void:
	ollama_client = Ollama.new()
	ollama_client.response_complete.connect(_on_ollama_response_complete)
	ollama_client.request_failed.connect(_on_ollama_request_failed)

func _ready() -> void:
	pass

# Main function to generate a quest from template
func generate_quest(template: QuestTemplate, player_info: Dictionary = {}) -> void:
	if _is_generating:
		generation_failed.emit("Already generating a quest")
		return
	
	if not template.is_valid():
		generation_failed.emit("Invalid template: " + ", ".join(template.validation_errors))
		return
	
	_current_template = template
	player_data = player_info
	_generated_quest = GeneratedQuest.new()
	_generated_quest.template_id = template.template_id
	_generated_quest.title = template.title
	_generated_quest.description = template.description
	
	# Queue generation tasks
	_generation_queue.clear()
	
	# First queue metadata generation
	_generation_queue.append({
		"type": "metadata",
		"task": "theme"
	})
	
	# Then queue each stage for generation
	for stage_id in template.quest_stages:
		var stage = template.quest_stages[stage_id]
		
		# Queue different tasks based on stage type
		match stage.stage_type:
			QuestTemplate.StageType.NARRATIVE, QuestTemplate.StageType.CHOICE, QuestTemplate.StageType.INPUT:
				if not stage.ai_narration_prompt.is_empty():
					_generation_queue.append({
						"type": "narration",
						"stage_id": stage_id,
						"prompt": stage.ai_narration_prompt
					})
					
			QuestTemplate.StageType.AI_DIALOGUE:
				_generation_queue.append({
					"type": "dialogue",
					"stage_id": stage_id,
					"npc_desc": stage.npc_description,
					"context": stage.dialogue_context
				})
				
			QuestTemplate.StageType.CHOICE:
				if stage.choices.is_empty() and not stage.ai_narration_prompt.is_empty():
					_generation_queue.append({
						"type": "choices",
						"stage_id": stage_id,
						"count": 3,  # Default 3 choices
						"context": stage.ai_narration_prompt
					})
	
	# Start generation process
	_is_generating = true
	_process_next_in_queue()

# Process the next generation task in queue
func _process_next_in_queue() -> void:
	if _generation_queue.is_empty():
		# We're done!
		_is_generating = false
		generation_complete.emit(_generated_quest)
		return
	
	var task = _generation_queue.pop_front()
	generation_progress.emit(task.get("stage_id", "metadata"), 
							1.0 - float(_generation_queue.size()) / (_generation_queue.size() + 1))
	
	match task.type:
		"metadata":
			_generate_metadata(task)
		"narration":
			_generate_narration(task)
		"dialogue":
			_generate_dialogue(task)
		"choices":
			_generate_choices(task)
		_:
			# Unknown task, skip it
			_process_next_in_queue()

# Metadata generation (theme, overall narrative flow)
func _generate_metadata(task: Dictionary) -> void:
	var prompt = "Generate a brief thematic description for a quest titled '%s'. " % _current_template.title
	prompt += "Include key themes, atmosphere, and narrative focus. "
	prompt += "Keep it short (50-70 words) and engaging."
	
	if not _current_template.theme_prompt.is_empty():
		prompt = _current_template.theme_prompt
	
	ollama_client.send_prompt(prompt, "You are a quest theme writer for an RPG. Respond with only the theme text.", false)

# Generate narrative text for a stage
func _generate_narration(task: Dictionary) -> void:
	var stage_id = task.stage_id
	var prompt = task.prompt
	
	# Enhance prompt with player info
	var enhanced_prompt = prompt + "\n\n"
	enhanced_prompt += "Player name: %s\n" % player_data.get("name", "Adventurer")
	
	if player_data.has("background"):
		enhanced_prompt += "Player background: %s\n" % player_data.get("background", "")
	
	if player_data.has("class"):
		enhanced_prompt += "Player class: %s\n" % player_data.get("class", "")
	
	enhanced_prompt += "Tone: " + _current_template.selected_tone
	
	# Send to Ollama
	ollama_client.model_name = "qwen2.5:14b"  # Model with good creative writing
	ollama_client.send_prompt(enhanced_prompt, NARRATION_SYSTEM_PROMPT, false)

# Generate dialogue for a stage
func _generate_dialogue(task: Dictionary) -> void:
	var stage_id = task.stage_id
	var npc_desc = task.npc_desc
	var context = task.context
	
	var prompt = "You are an NPC described as: " + npc_desc + "\n\n"
	prompt += "Context: " + context + "\n\n"
	prompt += "Player name: " + player_data.get("name", "Adventurer") + "\n"
	
	if player_data.has("background"):
		prompt += "Player is: " + player_data.get("background", "") + "\n"
	
	prompt += "Respond as this character would to the player."
	
	# Send to Ollama
	ollama_client.model_name = "qwen2.5:14b"
	ollama_client.send_prompt(prompt, DIALOGUE_SYSTEM_PROMPT, false)

# Generate choices for a stage
func _generate_choices(task: Dictionary) -> void:
	var stage_id = task.stage_id
	var count = task.count
	var context = task.context
	
	var prompt = "Based on this scenario: " + context + "\n\n"
	prompt += "Generate %d interesting and distinct choices for the player." % count
	prompt += "Each choice should represent a different approach or attitude."
	
	var system_prompt = CHOICE_SYSTEM_PROMPT.replace("{number}", str(count))
	
	# Send to Ollama
	ollama_client.model_name = "qwen2.5:14b"
	ollama_client.send_prompt(prompt, system_prompt, false)

# Handle Ollama response
func _on_ollama_response_complete(response: String) -> void:
	var current_task = _generation_queue[0] if not _generation_queue.is_empty() else null
	
	# Clean up response
	response = response.strip_edges()
	if response.begins_with("[NARRATION]"):
		response = response.substr(11).strip_edges()
	elif response.begins_with("[DIALOGUE]"):
		response = response.substr(10).strip_edges()
	
	# Process based on current task
	if current_task == null or current_task.type == "metadata":
		# This is a metadata response
		_generated_quest.theme_description = response
	elif current_task.type == "narration":
		# Store narration in the generated quest
		var stage_id = current_task.stage_id
		_generated_quest.set_stage_narrative(stage_id, response)
	elif current_task.type == "dialogue":
		# Store dialogue in the generated quest
		var stage_id = current_task.stage_id
		_generated_quest.set_stage_dialogue(stage_id, response)
	elif current_task.type == "choices":
		# Process choice JSON
		var choices = _parse_choices_from_response(response)
		var stage_id = current_task.stage_id
		_generated_quest.set_stage_choices(stage_id, choices)
	
	# Process next task
	_process_next_in_queue()

# Parse choices from JSON response
func _parse_choices_from_response(response: String) -> Array:
	# Try to find and parse JSON
	var choices = []
	
	# First try to extract just the JSON part
	var json_start = response.find("[")
	var json_end = response.rfind("]")
	
	if json_start != -1 and json_end != -1 and json_end > json_start:
		var json_str = response.substr(json_start, json_end - json_start + 1)
		var json = JSON.parse_string(json_str)
		
		if json != null and json is Array:
			for choice in json:
				if choice is Dictionary and choice.has("text"):
					choices.append({
						"text": choice.get("text"),
						"consequence": choice.get("consequences", "")
					})
	
	# If that failed, create some generic choices
	if choices.is_empty():
		choices = [
			{"text": "Accept the challenge", "consequence": "Face what lies ahead"},
			{"text": "Ask for more information", "consequence": "Learn more details"},
			{"text": "Decline and leave", "consequence": "Miss this opportunity"}
		]
	
	return choices

# Handle Ollama error
func _on_ollama_request_failed(error: String) -> void:
	generation_failed.emit("AI generation failed: " + error)
	_is_generating = false

# Clean up
func _exit_tree() -> void:
	if ollama_client:
		ollama_client.cleanup()

# Generated Quest class to store AI-generated content
class GeneratedQuest:
	var template_id: String
	var title: String
	var description: String
	var theme_description: String
	var generated_stages: Dictionary = {}
	
	func set_stage_narrative(stage_id: String, narrative: String) -> void:
		if not generated_stages.has(stage_id):
			generated_stages[stage_id] = {}
		generated_stages[stage_id]["narrative"] = narrative
	
	func set_stage_dialogue(stage_id: String, dialogue: String) -> void:
		if not generated_stages.has(stage_id):
			generated_stages[stage_id] = {}
		generated_stages[stage_id]["dialogue"] = dialogue
	
	func set_stage_choices(stage_id: String, choices: Array) -> void:
		if not generated_stages.has(stage_id):
			generated_stages[stage_id] = {}
		generated_stages[stage_id]["choices"] = choices
	
	func get_stage_content(stage_id: String, content_type: String) -> Variant:
		if not generated_stages.has(stage_id):
			return null
		return generated_stages[stage_id].get(content_type, null)
	
	func to_json() -> String:
		return JSON.stringify({
			"template_id": template_id,
			"title": title,
			"description": description,
			"theme_description": theme_description,
			"generated_stages": generated_stages
		})
	
	func from_json(json_text: String) -> Error:
		var json = JSON.parse_string(json_text)
		if json == null:
			return ERR_PARSE_ERROR
			
		template_id = json.get("template_id", "")
		title = json.get("title", "")
		description = json.get("description", "")
		theme_description = json.get("theme_description", "")
		generated_stages = json.get("generated_stages", {})
		
		return OK
