extends Node

## Global event bus used as an autoload singleton.
## Provides signals for various gameplay events.
## Designed for Godot 4.4.1.

signal entity_killed(data: Dictionary)
signal item_acquired(data: Dictionary)
signal quest_state_changed(data: Dictionary)

func _ready() -> void:
    # This node is intended to be added as an autoload singleton.
    pass
