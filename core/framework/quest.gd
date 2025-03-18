extends Resource
class_name Quest

@export_file("*.json") var json_path: String  # Path to the JSON data for this quest.

# Example of how you might store default rewards for completing the quest as a whole.
# It's an Array of "Reward" resources or something similar.
@export var rewards: Array[Rewards] = []
