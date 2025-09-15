# src/tests/TestModuleRegistry.gd
extends Node

## Tests for ModuleRegistry functionality.
## Designed for Godot 4.4.1.

# Instantiate ModuleRegistry manually to satisfy test dependencies.
var ModuleRegistry = preload("res://src/globals/ModuleRegistry.gd").new()

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- ModuleRegistry Tests --")

    # Test 1: Register & retrieve module
    total += 1
    var fake_module := Node.new()
    fake_module.name = "FakeGenerator"

    ModuleRegistry.register_module("fake_gen", fake_module)

    var retrieved = ModuleRegistry.modules.get("fake_gen", null)
    if retrieved == null:
        push_error("FAIL: Could not retrieve registered module.")
        passed = false
    elif retrieved != fake_module:
        push_error("FAIL: Retrieved module does not match registered one.")
        passed = false
    else:
        print("PASS: ModuleRegistry registered and retrieved module correctly.")
        successes += 1

    # Test 2: Overwriting an existing module
    total += 1
    var new_module := Node.new()
    new_module.name = "NewGenerator"

    ModuleRegistry.register_module("fake_gen", new_module)

    var overwritten = ModuleRegistry.modules.get("fake_gen", null)
    if overwritten != new_module:
        push_error("FAIL: ModuleRegistry did not overwrite module correctly.")
        passed = false
    else:
        print("PASS: ModuleRegistry overwrote existing module as expected.")
        successes += 1

    # Test 3: Retrieve missing module
    total += 1
    var missing = ModuleRegistry.modules.get("non_existent", null)
    if missing != null:
        push_error("FAIL: Expected null for non-existent module, got something else.")
        passed = false
    else:
        print("PASS: ModuleRegistry returned null for missing module as expected.")
        successes += 1

    # Summary
    print("Summary: %d/%d tests passed." % [successes, total])

    return {"passed": passed, "successes": successes, "total": total}
