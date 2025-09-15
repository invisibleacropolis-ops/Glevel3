extends Node
class_name System

## Abstract base class for gameplay systems that operate on entities.
## Systems are expected to iterate over entities each frame and perform logic.
## Designed for Godot 4.4.1.

## Called by subclasses to process a specific entity.
func _process_entity(entity_node: Node, delta: float) -> void:
    pass
