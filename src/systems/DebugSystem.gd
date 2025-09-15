extends "res://src/systems/System.gd"
class_name DebugSystem

const EntityData = preload("res://src/core/EntityData.gd")
const StatsComponent = preload("res://src/systems/StatsComponent.gd")

## Optional EventBus reference to allow dependency injection in tests.
var event_bus: Node = null

## Simple system that prints entity statistics to the console each physics frame.
## Designed for Godot 4.4.1.

func _physics_process(delta: float) -> void:
    for entity in get_tree().get_nodes_in_group("entities"):
        var data: EntityData = entity.get("entity_data")
        if data and data.components.has("stats"):
            var stats: StatsComponent = data.components["stats"]
            print("%s HP: %d" % [entity.name, stats.health])
            var bus := _get_event_bus()
            if bus:
                bus.emit_signal(
                    "debug_stats_reported",
                    {
                        "entity_id": _resolve_entity_id(entity, data),
                        "stats": _snapshot_stats(stats),
                    }
                )

## Attempts to locate the global EventBus if it was not injected manually.
func _get_event_bus() -> Node:
    if event_bus:
        return event_bus

    var tree := get_tree()
    if tree:
        var root := tree.get_root()
        if root:
            event_bus = root.get_node_or_null("EventBus")
    return event_bus

## Ensures we always emit a usable entity identifier for debug payloads.
func _resolve_entity_id(entity: Node, data: EntityData) -> String:
    if data.entity_id != "":
        return data.entity_id
    return entity.name

## Produces a serializable snapshot of the stats component for signal payloads.
func _snapshot_stats(stats: StatsComponent) -> Dictionary:
    return {
        "health": stats.health,
        "action_points": stats.action_points,
    }
