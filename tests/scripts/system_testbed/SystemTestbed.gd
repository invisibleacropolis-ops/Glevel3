extends Control
class_name SystemTestbed
"""Root controller for the System Testbed scene.

The controller currently tracks the entity selected by the Scene Inspector so
other panels can query or react to the active target. Additional coordination
logic will be layered on top of this node as more tooling modules come online.
"""

signal active_target_entity_changed(target: Node)

var _active_target_entity: Node

var active_target_entity: Node:
    get:
        return _active_target_entity
    set(value):
        if _active_target_entity == value:
            return
        _active_target_entity = value
        active_target_entity_changed.emit(_active_target_entity)

func set_active_target_entity(target: Node) -> void:
    """Setter shim exposed for clarity when called from other modules."""
    active_target_entity = target

func clear_active_target_entity() -> void:
    """Clears the currently selected entity reference."""
    active_target_entity = null
