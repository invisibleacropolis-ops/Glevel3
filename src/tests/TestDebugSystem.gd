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

func _build_test_entity() -> Dictionary:
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

    return {
        "entity": entity,
        "stats": stats,
    }

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

    var setup := _build_test_entity()
    var entity: Node = setup["entity"]
    var stats: StatsComponent = setup["stats"]

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
        var expected_stats := stats.to_dictionary()
        if received_payload.get("entity_id", "") != "entity_debug_001":
            push_error("FAIL: debug_stats_reported entity_id mismatch.")
            passed = false
        elif received_payload.get("stats", {}) != expected_stats:
            push_error("FAIL: debug_stats_reported stats payload mismatch.")
            passed = false
        else:
            print("PASS: DebugSystem emitted debug_stats_reported with expected payload.")
            successes += 1

    total += 1
    debug_system._captured_log_entries.clear()
    debug_system._logging_active = true
    debug_system._log_scene_name = "UnitTestScene"
    debug_system._log_session_id = "session_001"
    debug_system._log_file = null
    debug_system.capture_log_message("Synthetic log entry", 1, "UnitTest", "2024-01-01T00:00:00Z")

    var log_entries := debug_system.get_captured_log_entries()
    if log_entries.is_empty():
        push_error("FAIL: DebugSystem did not record captured log entries.")
        passed = false
    else:
        var latest := log_entries.back()
        if latest.get("message", "") != "Synthetic log entry":
            push_error("FAIL: DebugSystem stored incorrect log message metadata.")
            passed = false
        elif latest.get("category", "") != "UnitTest":
            push_error("FAIL: DebugSystem stored incorrect log category metadata.")
            passed = false
        else:
            print("PASS: DebugSystem captured redirected logger output.")
            successes += 1

    debug_system._logging_active = false

    print("Summary: %d/%d tests passed." % [successes, total])

    debug_system.queue_free()
    entity.queue_free()
    event_bus.queue_free()

    return {"passed": passed, "successes": successes, "total": total}
