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

func _remove_file_if_exists(path: String) -> void:
    if path == "":
        return

    if not FileAccess.file_exists(path):
        return

    var absolute_path := ProjectSettings.globalize_path(path)
    var error := DirAccess.remove_absolute(absolute_path)
    if error != OK:
        push_warning(
            "TestDebugSystem could not remove temporary log file %s (error %d)." % [path, error]
        )

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
    entity.set_meta("entity_data", data)

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

    var first_master_path := debug_system.get_master_error_log_path()
    var first_log_path := debug_system.get_log_file_path()
    debug_system._finalize_log_capture()
    _remove_file_if_exists(first_master_path)
    _remove_file_if_exists(first_log_path)

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

    total += 1
    debug_system._initialize_log_capture()
    var master_path := debug_system.get_master_error_log_path()
    var session_log_path := debug_system.get_log_file_path()

    debug_system.capture_log_message("Non-error heartbeat", 1, "UnitTest", "2024-01-01T00:00:00Z")
    debug_system.capture_log_message("Critical failure flagged", 3, "UnitTest", "2024-01-01T00:00:01Z")
    debug_system.capture_log_message("Fatal meltdown", 4, "UnitTest", "2024-01-01T00:00:02Z")
    debug_system._finalize_log_capture()

    if master_path == "":
        push_error("FAIL: DebugSystem did not report a master error log path.")
        passed = false
    elif not FileAccess.file_exists(master_path):
        push_error("FAIL: Master error log file missing at %s." % master_path)
        passed = false
    else:
        var master_file := FileAccess.open(master_path, FileAccess.READ)
        if master_file == null:
            push_error("FAIL: Unable to read master error log at %s." % master_path)
            passed = false
        else:
            var contents := master_file.get_as_text()
            master_file.close()
            if contents.find("Critical failure flagged") == -1:
                push_error("FAIL: Master error log did not capture error-level entries.")
                passed = false
            elif contents.find("Fatal meltdown") == -1:
                push_error("FAIL: Master error log did not capture fatal entries.")
                passed = false
            elif contents.find("Non-error heartbeat") != -1:
                push_error("FAIL: Master error log included non-error messages.")
                passed = false
            else:
                print("PASS: Master error log captured only error-class messages in the project root.")
                successes += 1

    _remove_file_if_exists(master_path)
    _remove_file_if_exists(session_log_path)

    print("Summary: %d/%d tests passed." % [successes, total])

    debug_system.queue_free()
    entity.queue_free()
    event_bus.queue_free()

    return {"passed": passed, "successes": successes, "total": total}
