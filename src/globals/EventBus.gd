extends Node

## Global event bus used as an autoload singleton.
## Provides signals for various gameplay events.
## Designed for Godot 4.4.1.

## Emitted whenever DebugSystem reports an entity snapshot.
## Payload keys:
## - "entity_id" (String): Unique identifier for the reported entity.
## - "stats" (Dictionary): Snapshot of the StatsComponent values (health, action_points).
signal debug_stats_reported(data: Dictionary)
signal entity_killed(data: Dictionary)
signal item_acquired(data: Dictionary)
signal quest_state_changed(data: Dictionary)

func _ready() -> void:
    # This node is intended to be added as an autoload singleton.
    pass
