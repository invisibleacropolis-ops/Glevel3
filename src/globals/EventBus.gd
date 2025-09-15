extends Node

## Global event bus used as an autoload singleton.
## Provides signals for various gameplay events.
## Designed for Godot 4.4.1.

signal entity_killed(data: Dictionary) # payload: {"entity_id": String, "killer_id": String}
signal item_acquired(data: Dictionary) # payload: {"item_id": String, "quantity": int}
signal quest_state_changed(data: Dictionary) # payload: {"quest_id": String, "state": StringName}

func _ready() -> void:
    # This node is intended to be added as an autoload singleton.
    pass
