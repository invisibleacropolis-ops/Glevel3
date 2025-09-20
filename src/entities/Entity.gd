extends Node
class_name Entity

## Runtime node representing a spawned gameplay entity within the testbed.
## Wraps an EntityData manifest so systems can operate on canonical data while
## keeping the scene graph lightweight.
@export var entity_data: EntityData

func _ready() -> void:
    """Registers the node with the canonical entities group for system discovery."""
    add_to_group("entities")
    if entity_data == null:
        push_warning("Entity node instantiated without EntityData. Assign a manifest before running systems.")
