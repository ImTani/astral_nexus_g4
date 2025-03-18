extends Node
class_name EnhancedQuestManager

# Signals
signal quest_loaded(quest_id: String)
signal quest_stage_changed(quest_id: String, stage_id: String)
signal quest_completed(quest_id: String, rewards: Dictionary)
signal quest_failed(quest_id: String, reason: String)
signal quest_generation_progress(progress: float)

# Quest templates and instances
var template_library: Dictionary = {}  # Template ID -> QuestTemplate
var active_quests: Dictionary = {}     # Quest ID -> ActiveQuest
var quest_history: Dictionary = {}     # Completed quest IDs -> completion data

# Player state
var player_state: Dictionary = {}

# UI node references
@export var ui_container: Control
@export var narrative_scene: PackedScene
@export var choice_scene: PackedScene
@export var input_scene: PackedScene
@export var rewards_scene: PackedScene

# Quest generator
var quest_generator: QuestGenerator

# Ollama integration
var ollama_client: Ollama

# Active quest data structure
class ActiveQuest:
    var quest_id: String
    var template_id: String
    var generated_content: QuestGenerator.GeneratedQuest
    var current_stage: String
    var player_choices: Dictionary = {}  # Stage ID -> Choice made
    var player_inputs: Dictionary = {}   # Stage ID -> Input text
    var completion_flags: Dictionary = {} # Flags set during quest
    var start_time: int = 0
    var end_time: int = 0
    var is_completed: bool = false
    var is_failed: bool = false
    var failure_reason: String = ""

func _ready() -> void:
    quest_generator = QuestGenerator.new()
    add_child(quest_generator)
    
    ollama_client = Ollama.new()
    add_child(ollama_client)
    
    quest_generator.generation_progress.connect(_on_generation_progress)
    quest_generator.generation_complete.connect(_on_generation_complete)
    quest_generator.generation_failed.connect(_on_generation_failed)
    
    # Initialize player state
    player_state = {
        "name": PlayerManager.player_name,
        "level": 1,
        "class": "Adventurer",
        "experience": 0,
        "flags": {},
        "inventory": [],
        "currency": 0,
        "knowledge": {}
    }

# Load quest template from file
func load_template(path: String) -> QuestTemplate:
    if not FileAccess.file_exists(path):
        push_error("Template file not found: " + path)
        return null
    
    var file = FileAccess.open(path, FileAccess.READ)
    var json = file.get_as_text()
    file.close()
    
    var template = QuestTemplate.new()
    if template.from_json(json) != OK:
        push_error("Failed to parse template JSON: " + path)
        return null
    
    # Store in template library
    template_library[template.template_id] = template
    return template

# Generate a quest from template
func generate_quest_from_template(template_id: String) -> void:
    if not template_library.has(template_id):
        push_error("Template not found: " + template_id)
        return
    
    var template = template_library[template_id]
    
    # Start generation
    quest_generator.generate_quest(template, player_state)

# Event when quest generation makes progress
func _on_generation_progress(stage: String, progress: float) -> void:
    quest_generation_progress.emit(progress)

# Event when quest generation completes
func _on_generation_complete(generated_quest: QuestGenerator.GeneratedQuest) -> void:
    var quest_id = "quest_" + generated_quest.template_id + "_" + str(Time.get_unix_time_from_system())
    
    # Create active quest instance
    var active_quest = ActiveQuest.new()
    active_quest.quest_id = quest_id
    active_quest.template_id = generated_quest.template_id
    active_quest.generated_content = generated_quest
    active_quest.current_stage = template_library[generated_quest.template_id].starting_stage
    active_quest.start_time = Time.get_unix_time_from_system()
    
    # Store active quest
    active_quests[quest_id] = active_quest
    
    # Notify listeners
    quest_loaded.emit(quest_id)

# Event when quest generation fails
func _on_generation_failed(error: String) -> void:
    push_error("Quest generation failed: " + error)

# Start a quest
func start_quest(quest_id: String) -> void:
    if not active_quests.has(quest_id):
        push_error("Quest not found: " + quest_id)
        return
    
    var active_quest = active_quests[quest_id]
    var template = template_library[active_quest.template_id]
    
    # Set initial stage
    active_quest.current_stage = template.starting_stage
    
    # Show first stage
    show_quest_stage(quest_id)

# Show the current stage of a quest
func show_quest_stage(quest_id: String) -> void:
    if not active_quests.has(quest_id):
        push_error("Quest not found: " + quest_id)
        return
    
    var active_quest = active_quests[quest_id]
    var template = template_library[active_quest.template_id]
    var stage_id = active_quest.current_stage
    var stage = template.get_stage(stage_id)
    
    if not stage:
        push_error("Stage not found: " + stage_id)
        return
    
    # Clear existing UI
    for child in ui_container.get_children():
        child.queue_free()
    
    # Create UI based on stage type
    match stage.stage_type:
        QuestTemplate.StageType.NARRATIVE:
            _show_narrative_stage(active_quest, stage)
        QuestTemplate.StageType.CHOICE:
            _show_choice_stage(active_quest, stage)
        QuestTemplate.StageType.INPUT:
            _show_input_stage(active_quest, stage)
        QuestTemplate.StageType.AI_DIALOGUE:
            _show_dialogue_stage(active_quest, stage)
        QuestTemplate.StageType.REWARD:
            _show_reward_stage(active_quest, stage)
        QuestTemplate.StageType.END:
            _show_end_stage(active_quest, stage)
        QuestTemplate.StageType.COMBAT:
            _show_combat_stage(active_quest, stage)
    
    # Emit stage changed signal
    quest_stage_changed.emit(quest_id, stage_id)

# Show narrative stage
func _show_narrative_stage(active_quest: ActiveQuest, stage: QuestTemplate.QuestTemplateStage) -> void:
    var narrative_ui = narrative_scene.instantiate()
    ui_container.add_child(narrative_ui)
    
    # Set title
    narrative_ui.set_title(stage.title if not stage.title.is_empty() else "")
    
    # Set narrative text - prefer AI-generated if available
    var generated_narrative = active_quest.generated_content.get_stage_content(stage.stage_id, "narrative")
    var narrative_text = generated_narrative if generated_narrative else stage.static_narration
    narrative_ui.set_narrative(narrative_text)
    
    # Set continue button
    narrative_ui.set_continue_button("Continue", func(): _advance_to_next_stage(active_quest, stage))

# Show choice stage
func _show_choice_stage(active_quest: ActiveQuest, stage: QuestTemplate.QuestTemplateStage) -> void:
    var choice_ui = choice_scene.instantiate()
    ui_container.add_child(choice_ui)
    
    # Set title
    choice_ui.set_title(stage.title if not stage.title.is_empty() else "Make Your Choice")
    
    # Set narrative text if available
    var generated_narrative = active_quest.generated_content.get_stage_content(stage.stage_id, "narrative")
    var narrative_text = generated_narrative if generated_narrative else stage.static_narration
    if not narrative_text.is_empty():
        choice_ui.set_narrative(narrative_text)
    
    # Get choices - prefer AI-generated if available
    var choices = active_quest.generated_content.get_stage_content(stage.stage_id, "choices")
    if not choices:
        choices = stage.choices
    
    # Add choices to UI
    for i in range(choices.size()):
        var choice = choices[i]
        var choice_text = choice.get("text", "Choice " + str(i+1))
        
        # Create choice button with callback
        choice_ui.add_choice(choice_text, func(): 
            # Record choice
            active_quest.player_choices[stage.stage_id] = i
            
            # Determine next stage
            var next_stage_id = ""
            if stage.choices.size() > i and stage.choices[i].has("next_stage"):
                next_stage_id = stage.choices[i].get("next_stage")
            else:
                next_stage_id = stage.next_stage
            
            # Set flags if any
            if stage.choices.size() > i and stage.choices[i].has("sets_flags"):
                for flag_name in stage.choices[i].get("sets_flags", {}):
                    active_quest.completion_flags[flag_name] = stage.choices[i].get("sets_flags")[flag_name]
            
            # Advance to next stage
            _advance_to_stage(active_quest, next_stage_id)
        )

# Show input stage
func _show_input_stage(active_quest: ActiveQuest, stage: QuestTemplate.QuestTemplateStage) -> void:
    var input_ui = input_scene.instantiate()
    ui_container.add_child(input_ui)
    
    # Set title
    input_ui.set_title(stage.title if not stage.title.is_empty() else "Your Response")
    
    # Set prompt
    input_ui.set_prompt(stage.input_prompt)
    
    # Set submit button
    input_ui.set_submit_button("Submit", func(input_text: String): 
        # Validate input if needed
        if not stage.input_validation.is_empty():
            var regex = RegEx.new()
            var validation_error = regex.compile(stage.input_validation)
            if validation_error != OK or not regex.search(input_text):
                input_ui.show_error("Invalid input. Please try again.")
                return
        
        # Record input
        active_quest.player_inputs[stage.stage_id] = input_text
        
        # If AI should respond, generate a response
        if stage.ai_response_to_input:
            # Create a prompt for the AI response
            var prompt = "The player has provided the following input: \n\n"
            prompt += input_text + "\n\n"
            prompt += "Respond to this in a way that makes sense for the quest."
            
            # Generate AI response
            _generate_ai_response_to_input(active_quest, stage, prompt)
        else:
            # Advance to next stage
            _advance_to_next_stage(active_quest, stage)
    )

# Generate AI response to input
func _generate_ai_response_to_input(active_quest: ActiveQuest, stage: QuestTemplate.QuestTemplateStage, prompt: String) -> void:
    # Set up a one-time connection for the response
    var callable = func(response: String):
        # Disconnect after receiving
        if ollama_client.response_complete.is_connected(callable):
            ollama_client.response_complete.disconnect(callable)
        
        # Store the response
        if not active_quest.generated_content.generated_stages.has(stage.stage_id):
            active_quest.generated_content.generated_stages[stage.stage_id] = {}
        active_quest.generated_content.generated_stages[stage.stage_id]["response"] = response
        
        # Show the response in a narrative UI
        var response_ui = narrative_scene.instantiate()
        ui_container.add_child(response_ui)
        response_ui.set_title("Response")
        response_ui.set_narrative(response)
        response_ui.set_continue_button("Continue", func(): _advance_to_next_stage(active_quest, stage))
    
    # Connect the response handler
    ollama_client.response_complete.connect(callable)
    
    # Send the prompt
    ollama_client.send_prompt(prompt, "You are an AI responding to player input in a quest. Keep your response in character and relevant to the context.", false)

# Show dialogue stage
func _show_dialogue_stage(active_quest: ActiveQuest, stage: QuestTemplate.QuestTemplateStage) -> void:
    var dialogue_ui = narrative_scene.instantiate()  # Reuse narrative scene for dialogue
    ui_container.add_child(dialogue_ui)
    
    # Set title (NPC name)
    dialogue_ui.set_title(stage.title if not stage.title.is_empty() else "Conversation")
    
    # Set dialogue text - prefer AI-generated
    var generated_dialogue = active_quest.generated_content.get_stage_content(stage.stage_id, "dialogue")
    var dialogue_text = generated_dialogue if generated_dialogue else "..."
    dialogue_ui.set_narrative(dialogue_text)
    
    # Add response buttons if specified
    if stage.choices.size() > 0:
        # Add response choices
        for i in range(stage.choices.size()):
            var choice = stage.choices[i]
            dialogue_ui.add_response_button(choice.get("text", "Response " + str(i+1)), func():
                # Record choice
                active_quest.player_choices[stage.stage_id] = i
                
                # Determine next stage
                var next_stage_id = ""
                if choice.has("next_stage"):
                    next_stage_id = choice.get("next_stage")
                else:
                    next_stage_id = stage.next_stage
                
                # Advance to next stage
                _advance_to_stage(active_quest, next_stage_id)
            )
    else:
        # Simple continue button
        dialogue_ui.set_continue_button("Continue", func(): _advance_to_next_stage(active_quest, stage))

# Show reward stage
func _show_reward_stage(active_quest: ActiveQuest, stage: QuestTemplate.QuestTemplateStage) -> void:
    var rewards_ui = rewards_scene.instantiate()
    ui_container.add_child(rewards_ui)
    
    var template = template_library[active_quest.template_id]
    
    # Calculate rewards
    var xp = template.base_xp * stage.xp_modifier
    var currency = template.base_currency * stage.currency_modifier
    
    # Items
    var items = []
    
    # Add guaranteed items
    for item_id in template.guaranteed_items:
        items.append(item_id)
    
    # Roll for chance-based items
    for item_id in stage.item_chances:
        var chance = stage.item_chances[item_id]
        if randf() * 100 <= chance:
            items.append(item_id)
    
    # Set rewards in UI
    rewards_ui.set_rewards(xp, currency, items)
    
    # Apply rewards to player state
    player_state.experience += xp
    player_state.currency += currency
    for item_id in items:
        player_state.inventory.append(item_id)
    
    # Prepare reward data for signal
    var reward_data = {
        "xp": xp,
        "currency": currency,
        "items": items
    }
    
    # Set continue button
    rewards_ui.set_continue_button("Continue", func(): 
        # If this is the final reward, mark quest as completed
        if stage.next_stage == "" or stage.next_stage == "end":
            _complete_quest(active_quest, reward_data)
        else:
            # Advance to next stage
            _advance_to_next_stage(active_quest, stage)
    )

# Show end stage
func _show_end_stage(active_quest: ActiveQuest, stage: QuestTemplate.QuestTemplateStage) -> void:
    var narrative_ui = narrative_scene.instantiate()
    ui_container.add_child(narrative_ui)
    
    # Set title
    narrative_ui.set_title(stage.title if not stage.title.is_empty() else "Quest Complete")
    
    # Set narrative text - prefer AI-generated if available
    var generated_narrative = active_quest.generated_content.get_stage_content(stage.stage_id, "narrative")
    var narrative_text = generated_narrative if generated_narrative else stage.static_narration
    narrative_ui.set_narrative(narrative_text)
    
    # Set continue button
    narrative_ui.set_continue_button("Finish", func(): 
        # Mark quest as completed
        _complete_quest(active_quest, {})
    )

# Show combat stage
func _show_combat_stage(active_quest: ActiveQuest, stage: QuestTemplate.QuestTemplateStage) -> void:
    # Placeholder for combat - in actual implementation, this would launch the combat system
    var narrative_ui = narrative_scene.instantiate()
    ui_container.add_child(narrative_ui)
    
    # Set title
    narrative_ui.set_title("Combat")
    
    # Set combat description
    var combat_desc = "You enter combat with "
    for i in range(stage.enemy_templates.size()):
        if i > 0:
            combat_desc += ", "
        combat_desc += stage.enemy_templates[i]
    
    narrative_ui.set_narrative(combat_desc + "\n\n[Combat simulation placeholder]")
    
    # Set win/lose buttons for demo
    narrative_ui.add_response_button("Win Combat", func():
        _advance_to_next_stage(active_quest, stage)
    )
    
    narrative_ui.add_response_button("Lose Combat", func():
        _fail_quest(active_quest, "Defeated in combat")
    )

# Advance to next stage based on stage configuration
func _advance_to_next_stage(active_quest: ActiveQuest, stage: QuestTemplate.QuestTemplateStage) -> void:
    # Set any flags from this stage
    for flag_name in stage.sets_flags:
        active_quest.completion_flags[flag_name] = stage.sets_flags[flag_name]
    
    # Determine next stage
    var next_stage_id = stage.next_stage
    
    if next_stage_id.is_empty():
        # If no next stage, check if there's an end stage
        var template = template_library[active_quest.template_id]
        for stage_id in template.quest_stages:
            var check_stage = template.get_stage(stage_id)
            if check_stage.stage_type == QuestTemplate.StageType.END:
                next_stage_id = stage_id
                break
    
    if next_stage_id.is_empty():
        # If still no next stage, complete the quest
        _complete_quest(active_quest, {})
    else:
        # Advance to next stage
        _advance_to_stage(active_quest, next_stage_id)

# Advance to a specific stage
func _advance_to_stage(active_quest: ActiveQuest, stage_id: String) -> void:
    # Set current stage
    active_quest.current_stage = stage_id
    
    # Get the template
    var template = template_library[active_quest.template_id]
    
    # Check if this is a valid stage
    if not template.quest_stages.has(stage_id):
        push_error("Invalid stage ID: " + stage_id)
        return
    
    # Show the stage
    show_quest_stage(active_quest.quest_id)

# Complete a quest
func _complete_quest(active_quest: ActiveQuest, rewards: Dictionary) -> void:
    active_quest.is_completed = true
    active_quest.end_time = Time.get_unix_time_from_system()
    
    # Store quest completion data
    quest_history[active_quest.quest_id] = {
        "template_id": active_quest.template_id,
        "start_time": active_quest.start_time,
        "end_time": active_quest.end_time,
        "duration": active_quest.end_time - active_quest.start_time,
        "choices": active_quest.player_choices,
        "inputs": active_quest.player_inputs,
        "flags": active_quest.completion_flags,
        "rewards": rewards
    }
    
    # Apply to player state
    for flag_name in active_quest.completion_flags:
        player_state.flags[flag_name] = active_quest.completion_flags[flag_name]
    
    # Emit completion signal
    quest_completed.emit(active_quest.quest_id, rewards)
    
    # Remove from active quests
    active_quests.erase(active_quest.quest_id)

# Fail a quest
func _fail_quest(active_quest: ActiveQuest, reason: String) -> void:
    active_quest.is_failed = true
    active_quest.failure_reason = reason
    active_quest.end_time = Time.get_unix_time_from_system()
    
    # Store quest failure data
    quest_history[active_quest.quest_id] = {
        "template_id": active_quest.template_id,
        "start_time": active_quest.start_time,
        "end_time": active_quest.end_time,
        "duration": active_quest.end_time - active_quest.start_time,
        "choices": active_quest.player_choices,
        "inputs": active_quest.player_inputs,
        "flags": active_quest.completion_flags,
        "failed": true,
        "failure_reason": reason
    }
    
    # Emit failure signal
    quest_failed.emit(active_quest.quest_id, reason)
    
    # Remove from active quests
    active_quests.erase(active_quest.quest_id)

# Get active quest by ID
func get_active_quest(quest_id: String) -> ActiveQuest:
    return active_quests.get(quest_id, null)

# Get quest history for a quest
func get_quest_history(quest_id: String) -> Dictionary:
    return quest_history.get(quest_id, {})

# Get all available quest templates
func get_available_quest_templates() -> Array:
    var available_templates = []
    
    for template_id in template_library:
        var template = template_library[template_id]
        
        # Check if player meets level requirement
        if player_state.level >= template.min_player_level:
            available_templates.append(template)
    
    return available_templates

# Save quest history to file
func save_quest_history(path: String) -> Error:
    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file:
        return ERR_CANT_OPEN
    
    var json = JSON.stringify(quest_history)
    file.store_string(json)
    file.close()
    return OK

# Load quest history from file
func load_quest_history(path: String) -> Error:
    if not FileAccess.file_exists(path):
        return ERR_FILE_NOT_FOUND
    
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return ERR_CANT_OPEN
    
    var json = file.get_as_text()
    file.close()
    
    var parse_result = JSON.parse_string(json)
    if parse_result == null:
        return ERR_PARSE_ERROR
    
    quest_history = parse_result
    return OK

# Update player knowledge
func update_player_knowledge(knowledge_key: String, knowledge_value: String) -> void:
    player_state.knowledge[knowledge_key] = knowledge_value

# Get player knowledge
func get_player_knowledge(knowledge_key: String) -> String:
    return player_state.knowledge.get(knowledge_key, "")

# Set player state
func set_player_state(new_state: Dictionary) -> void:
    player_state = new_state
