extends "res://src/systems/System.gd"
class_name DebugSystem

const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")

const EntityData = preload("res://src/core/EntityData.gd")
const StatsComponent = preload("res://src/components/StatsComponent.gd")
const ULTEnums = preload("res://src/globals/ULTEnums.gd")

## Optional EventBus reference to allow dependency injection in tests.
var event_bus: EventBusSingleton = null

## Simple system that prints entity statistics to the console each physics frame.
## Designed for Godot 4.4.1.

func _ready() -> void:
    _ensure_event_bus_subscription()

func _physics_process(delta: float) -> void:
    for entity in get_tree().get_nodes_in_group("entities"):
        var data: EntityData = entity.get("entity_data")
        if data and data.has_component(ULTEnums.ComponentKeys.STATS):
            var stats: StatsComponent = data.get_component(ULTEnums.ComponentKeys.STATS)
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

func _ensure_event_bus_subscription() -> void:
    if event_bus and _connect_event_bus(event_bus):
        return

    if typeof(EventBus) == TYPE_OBJECT and EventBus is Node:
        event_bus = EventBus
        var error := EventBus.connect(
            "entity_killed",
            Callable(self, "_on_entity_killed"),
            Object.CONNECT_REFERENCE_COUNTED,
        )
        if error != OK and error != ERR_ALREADY_IN_USE:
            push_warning("DebugSystem failed to connect to EventBus.entity_killed (error %d)." % error)
        return

    if EVENT_BUS_SCRIPT.is_singleton_ready():
        event_bus = EVENT_BUS_SCRIPT.get_singleton()
        if _connect_event_bus(event_bus):
            return

    var resolved_bus := _get_event_bus()
    if resolved_bus:
        event_bus = resolved_bus
        _connect_event_bus(event_bus)

func _connect_event_bus(bus: Node) -> bool:
    if not is_instance_valid(bus):
        return false

    if not bus.has_signal("entity_killed"):
        push_warning("EventBus reference missing entity_killed signal; cannot subscribe.")
        return false

    var error := bus.connect(
        "entity_killed",
        Callable(self, "_on_entity_killed"),
        Object.CONNECT_REFERENCE_COUNTED,
    )
    if error != OK and error != ERR_ALREADY_IN_USE:
        push_warning("DebugSystem failed to connect to entity_killed (error %d)." % error)
        return false

    return true

## Attempts to locate the global EventBus if it was not injected manually.
func _get_event_bus() -> EventBusSingleton:
    if event_bus:
        return event_bus

    if EVENT_BUS_SCRIPT.is_singleton_ready():
        event_bus = EVENT_BUS_SCRIPT.get_singleton()
        return event_bus

    if typeof(EventBus) == TYPE_OBJECT and EventBus is Node:
        event_bus = EventBus
        return event_bus

    var tree := get_tree()
    if tree:
        var root := tree.get_root()
        if root:
            event_bus = root.get_node_or_null("EventBus") as EventBusSingleton
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
        "max_health": stats.max_health,
        "action_points": stats.action_points,
        "max_action_points": stats.max_action_points,
        "strength": stats.strength,
        "dexterity": stats.dexterity,
        "constitution": stats.constitution,
        "intelligence": stats.intelligence,
        "willpower": stats.willpower,
        "speed": stats.speed,
        "resistances": stats.resistances.duplicate(),
        "vulnerabilities": stats.vulnerabilities.duplicate(),
    }

## Receives notifications when other systems broadcast entity_killed.
## The payload is retained for future diagnostics or extended instrumentation.
func _on_entity_killed(payload: Dictionary) -> void:
    if not payload.has("entity_id"):
        return

    # Coerce the identifier to a String so downstream tooling receives a stable type.
    var entity_id: String = str(payload["entity_id"])
    print("DebugSystem observed entity_killed for %s" % str(entity_id))
