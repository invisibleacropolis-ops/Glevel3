extends Node
class_name TestDummyEntity

## Test harness node that exposes entity data for validation scenes.
## Designed for Godot 4.4.1.

@export var entity_data: EntityData

func _ready() -> void:
    ## Registers the node into the global 'entities' group for system processing.
    add_to_group("entities")
