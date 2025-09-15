# src/tests/TestEventBus.gd
extends Node

## Automated tests for the EventBus singleton.
## Designed for Godot 4.4.1.

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- EventBus Tests --")

    var received := false

    # Listener for entity_killed
    func _on_entity_killed(data: Dictionary) -> void:
        nonlocal received
        received = (data.get("entity_id", "") == "test_entity")

    EventBus.connect("entity_killed", Callable(self, "_on_entity_killed"))

    # Test 1: Emit and receive signal
    total += 1
    var payload := {"entity_id": "test_entity", "killer_id": "tester"}
    EventBus.emit_signal("entity_killed", payload)

    await get_tree().process_frame

    if not received:
        push_error("FAIL: EventBus did not deliver entity_killed correctly.")
        passed = false
    else:
        print("PASS: EventBus emitted and received entity_killed successfully.")
        successes += 1

    # Summary
    print("Summary: %d/%d tests passed." % [successes, total])

    return {"passed": passed, "successes": successes, "total": total}
