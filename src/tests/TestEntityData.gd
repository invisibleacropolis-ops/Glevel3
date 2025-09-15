# src/tests/TestEntityData.gd
extends Node

## Tests for the EntityData resource and its component dictionary helpers.
## Designed for Godot 4.4.1 headless testing.

const EntityDataScript := preload("res://src/core/EntityData.gd")
const ComponentScript := preload("res://src/core/Component.gd")

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- EntityData Tests --")

    var entity := EntityDataScript.new()

    # Test 1: add_component stores and returns the same instance.
    total += 1
    var stats_component := ComponentScript.new()
    entity.add_component("stats", stats_component)
    var retrieved := entity.get_component("stats")
    if retrieved == stats_component:
        print("PASS: add_component stored and retrieved the Component instance.")
        successes += 1
    else:
        push_error("FAIL: add_component did not return the stored Component instance.")
        passed = false

    # Test 2: get_component returns null when entry is missing.
    total += 1
    var missing := entity.get_component("missing")
    if missing == null:
        print("PASS: get_component returned null for a missing key.")
        successes += 1
    else:
        push_error("FAIL: get_component should return null for a missing key.")
        passed = false

    # Test 3: add_component replaces an existing entry.
    total += 1
    var replacement := ComponentScript.new()
    entity.add_component("stats", replacement)
    if entity.get_component("stats") == replacement:
        print("PASS: add_component replaced the existing Component entry.")
        successes += 1
    else:
        push_error("FAIL: add_component did not replace the existing entry.")
        passed = false

    entity.components.clear()
    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
