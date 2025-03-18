extends Resource
class_name ActiveQuest

var quest_id: String
var template_id: String
var generated_content: QuestGenerator.GeneratedQuest
var current_stage: String

# Player progress tracking
var player_choices: Dictionary = {}  # Stage ID -> Choice made
var player_inputs: Dictionary = {}   # Stage ID -> Input text
var completion_flags: Dictionary = {} # Flags set during quest
var start_time: int = 0
var end_time: int = 0
var is_completed: bool = false
var is_failed: bool = false
var failure_reason: String = ""

# Metadata
var completion_percentage: float = 0.0

func _init() -> void:
    start_time = Time.get_unix_time_from_system()

# Calculate completion percentage based on stages visited
func calculate_completion_percentage(template: QuestTemplate) -> float:
    var total_stages = template.quest_stages.size()
    var visited_stages = player_choices.size() + player_inputs.size()
    
    if total_stages == 0:
        return 0.0
    
    return min(100.0, (float(visited_stages) / float(total_stages)) * 100.0)

# Get the time elapsed since quest started
func get_elapsed_time() -> int:
    if end_time > 0:
        return end_time - start_time
    return Time.get_unix_time_from_system() - start_time

# Get all flags set during this quest
func get_all_flags() -> Dictionary:
    return completion_flags

# Check if a specific flag is set
func has_flag(flag_name: String) -> bool:
    return completion_flags.has(flag_name)

# Get the value of a specific flag
func get_flag_value(flag_name: String, default_value = null) -> Variant:
    return completion_flags.get(flag_name, default_value)

# Save quest progress
func to_dict() -> Dictionary:
    return {
        "quest_id": quest_id,
        "template_id": template_id,
        "current_stage": current_stage,
        "player_choices": player_choices,
        "player_inputs": player_inputs,
        "completion_flags": completion_flags,
        "start_time": start_time,
        "end_time": end_time,
        "is_completed": is_completed,
        "is_failed": is_failed,
        "failure_reason": failure_reason
    }

# Load quest progress
func from_dict(data: Dictionary) -> void:
    quest_id = data.get("quest_id", "")
    template_id = data.get("template_id", "")
    current_stage = data.get("current_stage", "")
    player_choices = data.get("player_choices", {})
    player_inputs = data.get("player_inputs", {})
    completion_flags = data.get("completion_flags", {})
    start_time = data.get("start_time", 0)
    end_time = data.get("end_time", 0)
    is_completed = data.get("is_completed", false)
    is_failed = data.get("is_failed", false)
    failure_reason = data.get("failure_reason", "")
