extends Button

func _on_pressed() -> void:
		# Load and start quest0000
	var result = QuestManager.load_quest("res://quests/quest0000/quest_resource.tres")
	if result == OK:
		# Since QuestManager.active_quests is a dictionary, get first key
		var quest_ids: Array = QuestManager.get_active_quests()
		if not quest_ids.is_empty():
			# Get the quest_id (first key from the dictionary)
			var quest_id = quest_ids[0]
			
			# Generate the first stage node
			var stage_node = QuestManager.generate_stage_node(quest_id)
			if stage_node:
				# Get the SceneHolder node to add the quest UI
				var scene_holder = get_tree().get_root().find_child("SceneHolder", true, false)
				if scene_holder:
					# Remove the main menu
					var main_menu = scene_holder.get_child(0)
					scene_holder.remove_child(main_menu)
					main_menu.queue_free()
					
					# Add the quest stage node
					scene_holder.add_child(stage_node)
