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

    var retrieved = ModuleRegistry.get_module("fake_gen")
    var registration_success := ModuleRegistry.has_module("fake_gen") and retrieved == fake_module
    assert(registration_success, "ModuleRegistry should return the same node instance that was registered.")
    if registration_success:
        print("PASS: ModuleRegistry registered and retrieved module correctly.")
        successes += 1
    else:
        push_error("FAIL: ModuleRegistry failed to expose registered module.")
        passed = false

    # Test 2: Overwriting an existing module
    total += 1
    var new_module := Node.new()
    new_module.name = "NewGenerator"

    ModuleRegistry.register_module("fake_gen", new_module)

    var overwritten := ModuleRegistry.get_module("fake_gen") == new_module
    assert(overwritten, "ModuleRegistry should overwrite existing module registrations.")
    if overwritten:
        print("PASS: ModuleRegistry overwrote existing module as expected.")
        successes += 1
    else:
        push_error("FAIL: ModuleRegistry did not overwrite module correctly.")
        passed = false

    # Test 3: Retrieve missing module
    total += 1
    var missing := not ModuleRegistry.has_module("non_existent") and ModuleRegistry.get_module("non_existent") == null
    assert(missing, "ModuleRegistry should report false/ null for unregistered modules.")
    if missing:
        print("PASS: ModuleRegistry returned null for missing module as expected.")
        successes += 1
    else:
        push_error("FAIL: ModuleRegistry incorrectly reported a missing module as present.")
        passed = false

    # Test 4: Manual unregister removes module
    total += 1
    ModuleRegistry.unregister_module("fake_gen")
    var unregistered := not ModuleRegistry.has_module("fake_gen") and ModuleRegistry.get_module("fake_gen") == null
    assert(unregistered, "ModuleRegistry should remove entries when unregister_module is called.")
    if unregistered:
        print("PASS: ModuleRegistry unregistered module successfully.")
        successes += 1
    else:
        push_error("FAIL: ModuleRegistry did not unregister module as expected.")
        passed = false

    # Test 5: tree_exiting cleanup removes modules automatically
    total += 1
    var cleanup_module := Node.new()
    cleanup_module.name = "CleanupGenerator"
    ModuleRegistry.register_module("cleanup_gen", cleanup_module)
    cleanup_module.emit_signal("tree_exiting")
    var cleaned := not ModuleRegistry.has_module("cleanup_gen") and ModuleRegistry.get_module("cleanup_gen") == null
    assert(cleaned, "ModuleRegistry should drop modules when their nodes exit the scene tree.")
    if cleaned:
        print("PASS: ModuleRegistry cleaned up module after tree_exiting signal.")
        successes += 1
    else:
        push_error("FAIL: ModuleRegistry failed to remove module after tree_exiting signal.")
        passed = false

    # Summary
    print("Summary: %d/%d tests passed." % [successes, total])
    fake_module.free()
    new_module.free()
    cleanup_module.free()
    ModuleRegistry.free()
    return {"passed": passed, "successes": successes, "total": total}
