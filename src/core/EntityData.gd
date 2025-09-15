extends Resource
class_name EntityData

const Component = preload("res://src/core/Component.gd")

## Data container describing an in-game entity.
## Holds identifying information and a dictionary of components.
## Intended to be used as a resource assigned to nodes representing entities.

@export var entity_id: String
@export var display_name: String
@export var entity_type: int
@export var archetype_id: String
@export var components: Dictionary = {}

## Adds or replaces a component entry by name.
func add_component(name: String, component: Component) -> void:
    components[name] = component

## Retrieves a component by name. Returns null if not present.
func get_component(name: String) -> Component:
    return components.get(name)
