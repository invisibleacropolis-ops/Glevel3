extends Resource
class_name BaseItem

## Base class for all item resources in the game.
## Defines common properties like weight, cost, and stat modifiers.

@export_group("Identity")
@export var item_id: StringName = &"" ## Unique identifier for this item.
@export var item_name: String = "" ## Display name of the item.
@export_multiline var description: String = "" ## Detailed description of the item.

@export_group("Economics & Logistics")
@export var weight: float = 0.0 ## Weight of the item, affecting inventory capacity.
@export var cost: int = 0 ## Monetary value of the item.

@export_group("Combat Stats")
@export var damage: int = 0 ## Base damage value if this is a weapon.
@export var armor_rating: int = 0 ## Base armor value if this is armor.

@export_group("Modifiers")
## Dictionary of stat modifiers this item applies when equipped or used.
## Keys are stat names (StringName), values are the modifier amounts (int/float).
@export var stat_modifiers: Dictionary = {}

@export_group("Questing & Events")
## List of StringNames that represent quest IDs or event triggers associated with this item.
@export var quest_triggers: Array[StringName] = []
