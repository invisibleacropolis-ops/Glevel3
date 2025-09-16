# src/tests/TestEntityData.gd
extends Node

## Tests for the EntityData resource and its component dictionary helpers.
## Designed for Godot 4.4.1 headless testing.

const EntityDataScript := preload("res://src/core/EntityData.gd")
const ComponentScript := preload("res://src/core/Component.gd")
const ULTEnums := preload("res://src/globals/ULTEnums.gd")

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- EntityData Tests --")

    var entity := EntityDataScript.new()

    # Test 1: add_component stores and returns the same instance while normalising the key.
    total += 1
    var stats_component := ComponentScript.new()
    entity.add_component("stats", stats_component)
    var retrieved := entity.get_component(ULTEnums.ComponentKeys.STATS)
    if retrieved == stats_component:
        print("PASS: add_component stored and retrieved the Component instance using a canonical key.")
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

    # Test 3: has_component reflects registration state.
    total += 1
    if entity.has_component("stats") and not entity.has_component("inventory"):
        print("PASS: has_component accurately reports component presence.")
        successes += 1
    else:
        push_error("FAIL: has_component produced incorrect results.")
        passed = false

    # Test 4: add_component replaces an existing entry.
    total += 1
    var replacement := ComponentScript.new()
    entity.add_component("stats", replacement)
    if entity.get_component("stats") == replacement:
        print("PASS: add_component replaced the existing Component entry.")
        successes += 1
    else:
        push_error("FAIL: add_component did not replace the existing entry.")
        passed = false

    # Test 5: remove_component detaches the stored component.
    total += 1
    var removed := entity.remove_component("stats")
    if removed == replacement and not entity.has_component("stats"):
        print("PASS: remove_component returned and removed the expected Component instance.")
        successes += 1
    else:
        push_error("FAIL: remove_component failed to return or purge the Component instance.")
        passed = false

    # Test 6: list_components provides a shallow copy that can be iterated safely.
    total += 1
    entity.add_component("stats", ComponentScript.new())
    var manifest := entity.list_components()
    manifest.clear()
    if entity.has_component("stats"):
        print("PASS: list_components returns a defensive copy of the manifest.")
        successes += 1
    else:
        push_error("FAIL: list_components should not expose the internal manifest directly.")
        passed = false

    entity.components.clear()
    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
