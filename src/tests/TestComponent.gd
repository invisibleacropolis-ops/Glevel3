# src/tests/TestComponent.gd
extends Node

## Sanity checks for the base Component resource.
## Designed for Godot 4.4.1 headless testing.

const ComponentScript := preload("res://src/core/Component.gd")

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- Component Tests --")

    # Test 1: Component instantiates correctly as a Resource subtype.
    total += 1
    var component_a := ComponentScript.new()
    if component_a is Resource and component_a is ComponentScript:
        print("PASS: Base Component instantiates as a Resource.")
        successes += 1
    else:
        push_error("FAIL: Component did not instantiate correctly.")
        passed = false

    # Test 2: Multiple instances are unique objects.
    total += 1
    var component_b := ComponentScript.new()
    if component_a != component_b:
        print("PASS: Each Component instance is unique.")
        successes += 1
    else:
        push_error("FAIL: Component instances should be distinct objects.")
        passed = false

    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
