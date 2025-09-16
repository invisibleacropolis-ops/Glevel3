# src/tests/TestDebugSystem.gd
extends Node

## Tests validating that DebugSystem emits debug_stats_reported through the EventBus.
## Designed for Godot 4.4.1.

const DebugSystem = preload("res://src/systems/DebugSystem.gd")
const EntityData = preload("res://src/core/EntityData.gd")
const StatsComponent = preload("res://src/components/StatsComponent.gd")
const ULTEnums = preload("res://src/globals/ULTEnums.gd")
const EventBusScene = preload("res://src/globals/EventBus.gd")

var event_bus: Node
var signal_received := false
var received_payload: Dictionary = {}

func _on_debug_stats_reported(data: Dictionary) -> void:
    signal_received = true
    received_payload = data

func _build_test_entity() -> Node:
    var entity := Node.new()
    entity.name = "DebugEntity"
    entity.add_to_group("entities")

    var data := EntityData.new()
    data.entity_id = "entity_debug_001"

    var stats := StatsComponent.new()
    stats.health = 15
    stats.max_health = 15
    stats.action_points = 4
    stats.max_action_points = 4

    data.add_component(ULTEnums.ComponentKeys.STATS, stats)
    entity.set("entity_data", data)

    return entity

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- DebugSystem Tests --")

    signal_received = false
    received_payload = {}

    event_bus = EventBusScene.new()
    event_bus.name = "EventBus"

    var debug_system := DebugSystem.new()
    debug_system.event_bus = event_bus

    var entity := _build_test_entity()

    add_child(event_bus)
    add_child(debug_system)
    add_child(entity)

    event_bus.debug_stats_reported.connect(_on_debug_stats_reported)

    total += 1
    debug_system._physics_process(0.0)

    if not signal_received:
        push_error("FAIL: DebugSystem did not emit debug_stats_reported.")
        passed = false
    else:
        var expected_stats := {
            "health": 15,
            "max_health": 15,
            "action_points": 4,
            "max_action_points": 4,
            "strength": 0,
            "dexterity": 0,
            "constitution": 0,
            "intelligence": 0,
            "willpower": 0,
            "speed": 0.0,
            "resistances": {},
            "vulnerabilities": {},
        }
        if received_payload.get("entity_id", "") != "entity_debug_001":
            push_error("FAIL: debug_stats_reported entity_id mismatch.")
            passed = false
        elif received_payload.get("stats", {}) != expected_stats:
            push_error("FAIL: debug_stats_reported stats payload mismatch.")
            passed = false
        else:
            print("PASS: DebugSystem emitted debug_stats_reported with expected payload.")
            successes += 1

    print("Summary: %d/%d tests passed." % [successes, total])

    debug_system.queue_free()
    entity.queue_free()
    event_bus.queue_free()

    return {"passed": passed, "successes": successes, "total": total}
