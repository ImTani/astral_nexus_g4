extends Node

# Signal when a quest stage changes
signal quest_stage_changed(quest_id: String, stage_id: String, stage_data: Dictionary)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

# Stores all loaded quest resources
# Key: quest_id, Value: Quest resource
var loaded_quests: Dictionary = {}

# Stores active quest progression
# Key: quest_id, Value: Dictionary with current stage and state
var active_quests: Dictionary = {}

# Quest stage types for generating appropriate UI/gameplay nodes
enum StageType {
	NARRATIVE,      # Simple narrative text
	CHOICE,        # Player makes a choice
	INPUT,         # Player needs to input text
	COMBAT,        # Combat encounter
	REWARD,        # Reward distribution
	END            # Quest end state
}

class QuestStage extends Resource:
	@export var stage_id: String
	@export var stage_type: StageType
	@export var narration: String
	@export var choices: Array
	@export var input_prompt: String
	@export var rewards: Array[Rewards]
	@export var combat_encounter: String
	@export var flags: Dictionary
	@export var next_stage: String

	func _init(data: Dictionary = {}) -> void:
		if data.is_empty():
			return
			
		stage_id = data.get("stage_id", "")
		narration = data.get("narration", "")
		choices = data.get("choices", [])
		input_prompt = data.get("text_input_prompt", "")
		rewards = _parse_rewards(data)
		combat_encounter = data.get("combat_encounter", "")
		flags = data.get("flags_triggered", {})
		
		# Determine stage type based on content
		stage_type = _determine_stage_type(data)
	
	func _determine_stage_type(data: Dictionary) -> StageType:
		if data.get("end_quest", false):
			return StageType.END
		elif data.has("combat_encounter"):
			return StageType.COMBAT
		elif data.has("text_input_prompt"):
			return StageType.INPUT
		elif not data.get("choices", []).is_empty():
			return StageType.CHOICE
		elif _has_rewards(data):
			return StageType.REWARD
		else:
			return StageType.NARRATIVE
	
	func _has_rewards(data: Dictionary) -> bool:
		return data.has("reward_items") or data.has("reward_exp") or data.has("reward_currency")
	
	func _parse_rewards(data: Dictionary) -> Array[Rewards]:
		var reward_list: Array[Rewards] = []
		if _has_rewards(data):
			var new_reward = Rewards.new()
			new_reward.xp = data.get("reward_exp", 0)
			new_reward.currency = data.get("reward_currency", 0)
			# TODO: Parse items when we have item database
			reward_list.append(new_reward)
		return reward_list

func _ready() -> void:
	# Initialize any required systems
	pass

# Load a quest from a Quest resource
func load_quest(quest_resource_path: String) -> Error:
	var quest_res = load(quest_resource_path) as Quest
	if not quest_res:
		return ERR_FILE_NOT_FOUND
		
	var json_data = _load_quest_json(quest_res.json_path)
	if json_data.is_empty():
		return ERR_PARSE_ERROR
		
	var quest_id = json_data.get("quest_id", "")
	if quest_id.is_empty():
		return ERR_INVALID_DATA
		
	# Store the quest resource and initialize progression
	loaded_quests[quest_id] = quest_res
	active_quests[quest_id] = {
		"current_stage": "prologue",
		"state": {},
		"stages": _parse_quest_stages(json_data)
	}
	
	return OK

# Parse the quest JSON data into stage resources
func _parse_quest_stages(quest_data: Dictionary) -> Dictionary:
	var stages = {}
	var raw_stages = quest_data.get("stages", {})
	
	for stage_id in raw_stages:
		var stage_data = raw_stages[stage_id]
		stage_data["stage_id"] = stage_id
		stages[stage_id] = QuestStage.new(stage_data)
	
	return stages

# Get the current stage for a quest
func get_current_stage(quest_id: String) -> QuestStage:
	if not active_quests.has(quest_id):
		return null
		
	var current_stage_id = active_quests[quest_id]["current_stage"]
	return active_quests[quest_id]["stages"].get(current_stage_id)

# Generate appropriate node for the current stage
func generate_stage_node(quest_id: String) -> Node:
	var stage = get_current_stage(quest_id)
	if not stage:
		return null
		
	match stage.stage_type:
		StageType.NARRATIVE:
			return _create_narrative_node(stage)
		StageType.CHOICE:
			return _create_choice_node(stage)
		StageType.INPUT:
			return _create_input_node(stage)
		StageType.COMBAT:
			return _create_combat_node(stage)
		StageType.REWARD:
			return _create_reward_node(stage)
		StageType.END:
			return _create_end_node(stage)
	
	return null

# Node generation methods
func _create_narrative_node(stage: QuestStage) -> Node:
	var narrative_scene = preload("res://core/ui/narrative_text.tscn")
	var narrative_node = narrative_scene.instantiate()
	
	# Replace any dynamic content in narration text
	var narration = stage.narration
	if "@player_name@" in narration:
		# Assuming player name is stored in game state somewhere
		narration = narration.replace("@player_name@", PlayerManager.player_name)
	
	# Set the narration text
	narrative_node.display_text(narration)
	return narrative_node

func _create_choice_node(stage: QuestStage) -> Node:
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add narrative text if present
	if not stage.narration.is_empty():
		var narrative = _create_narrative_node(stage)
		container.add_child(narrative)
	
	# Create choice buttons
	var button_container = VBoxContainer.new()
	button_container.set_anchors_preset(Control.PRESET_CENTER)
	button_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var choice_button_scene = preload("res://core/ui/choice_button.tscn")
	
	for i in range(stage.choices.size()):
		var choice = stage.choices[i]
		var choice_button = choice_button_scene.instantiate()
		choice_button.button_text = choice.get("option_text", "Choice " + str(i))
		
		# Connect button press to quest progression
		var choice_index = i  # Create a copy for the closure
		choice_button.button.pressed.connect(
			func(): progress_quest(active_quests.keys()[0], choice_index)
		)
		
		button_container.add_child(choice_button)
	
	container.add_child(button_container)
	return container

func _create_input_node(stage: QuestStage) -> Node:
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add narrative text if present
	if not stage.narration.is_empty():
		var narrative = _create_narrative_node(stage)
		container.add_child(narrative)
	
	# Create text input
	var input_scene = preload("res://core/ui/text_input.tscn")
	var input_node = input_scene.instantiate()
	input_node.set_prompt(stage.input_prompt)
	
	# Connect input submission to quest progression
	input_node.input_submitted.connect(
		func(text: String): progress_quest(active_quests.keys()[0], -1, text)
	)
	
	container.add_child(input_node)
	return container

func _create_combat_node(stage: QuestStage) -> Node:
	# For now, we'll create a simple combat announcement
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add combat introduction narrative
	if not stage.narration.is_empty():
		var narrative = _create_narrative_node(stage)
		container.add_child(narrative)
	
	# Add a button to start/simulate combat
	var choice_button_scene = preload("res://core/ui/choice_button.tscn")
	var combat_button = choice_button_scene.instantiate()
	combat_button.button_text = "Begin Combat"
	combat_button.button.pressed.connect(
		func(): progress_quest(active_quests.keys()[0])
	)
	
	container.add_child(combat_button)
	return container

func _create_reward_node(stage: QuestStage) -> Node:
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add narrative text if present
	if not stage.narration.is_empty():
		var narrative = _create_narrative_node(stage)
		container.add_child(narrative)
	
	# Create rewards display
	var rewards_scene = preload("res://core/ui/rewards_display.tscn")
	var rewards_node = rewards_scene.instantiate()
	rewards_node.display_rewards(stage.rewards)
	
	# Connect reward acknowledgment to quest progression
	rewards_node.rewards_acknowledged.connect(
		func(): progress_quest(active_quests.keys()[0])
	)
	
	container.add_child(rewards_node)
	return container

func _create_end_node(stage: QuestStage) -> Node:
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Show final narrative
	if not stage.narration.is_empty():
		var narrative = _create_narrative_node(stage)
		container.add_child(narrative)
	
	# Add any final rewards if present
	if not stage.rewards.is_empty():
		var rewards_node = _create_reward_node(stage)
		container.add_child(rewards_node)
	
	# Add a button to close/finish the quest
	var choice_button_scene = preload("res://core/ui/choice_button.tscn")
	var finish_button = choice_button_scene.instantiate()
	finish_button.button_text = "Complete Quest"
	finish_button.button.pressed.connect(
		func(): 
			var quest_id = active_quests.keys()[0]
			emit_signal("quest_completed", quest_id)
	)
	
	container.add_child(finish_button)
	return container

# Progress to the next stage based on choice/input
func progress_quest(quest_id: String, choice_index: int = -1, input_text: String = "") -> void:
	var current_stage = get_current_stage(quest_id)
	if not current_stage:
		return
		
	var next_stage_id = ""
	
	# Determine next stage based on stage type and input
	match current_stage.stage_type:
		StageType.CHOICE:
			if choice_index >= 0 and choice_index < current_stage.choices.size():
				next_stage_id = current_stage.choices[choice_index].get("next_stage", "")
		StageType.INPUT:
			if not input_text.is_empty():
				# Store input in quest state
				active_quests[quest_id]["state"][current_stage.stage_id + "_input"] = input_text
				next_stage_id = current_stage.next_stage
		_:
			next_stage_id = current_stage.next_stage
	
	if next_stage_id.is_empty():
		return
		
	# Update current stage
	active_quests[quest_id]["current_stage"] = next_stage_id
	emit_signal("quest_stage_changed", quest_id, next_stage_id, get_current_stage(quest_id))
	
	# Check for quest completion
	var new_stage = get_current_stage(quest_id)
	if new_stage and new_stage.stage_type == StageType.END:
		emit_signal("quest_completed", quest_id)

# Load quest JSON data
func _load_quest_json(json_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path):
		return {}
		
	var file = FileAccess.open(json_path, FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	
	return json if json is Dictionary else {}

# Get all active quests
func get_active_quests() -> Array:
	return active_quests.keys()

# Check if a quest is loaded
func is_quest_loaded(quest_id: String) -> bool:
	return loaded_quests.has(quest_id)

# Reset a quest to its initial state
func reset_quest(quest_id: String) -> void:
	if active_quests.has(quest_id):
		active_quests[quest_id]["current_stage"] = "prologue"
		active_quests[quest_id]["state"] = {}
