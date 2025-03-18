extends Resource
class_name Item

@export var item_id: int
@export_enum("Weapon", "Armor", "Consumable", "Key Item") var item_type: int
@export var name: String
@export var description: String
