# src/tests/TestStatsComponent.gd
extends Node

## Tests for the StatsComponent resource and its damage handling logic.
## Designed for Godot 4.4.1 headless testing.

const StatsComponentScript := preload("res://src/systems/StatsComponent.gd")

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- StatsComponent Tests --")

    var stats := StatsComponentScript.new()
    stats.health = 10
    stats.action_points = 3

    # Test 1: Damage reduces health by the expected amount.
    total += 1
    stats.apply_damage(3)
    if stats.health == 7:
        print("PASS: apply_damage subtracts the specified amount from health.")
        successes += 1
    else:
        push_error("FAIL: apply_damage did not reduce health correctly.")
        passed = false

    # Test 2: Damage clamps health at zero.
    total += 1
    stats.apply_damage(20)
    if stats.health == 0:
        print("PASS: apply_damage clamps health at zero when damage exceeds current value.")
        successes += 1
    else:
        push_error("FAIL: apply_damage failed to clamp health at zero.")
        passed = false

    # Test 3: Damage does not affect action points.
    total += 1
    if stats.action_points == 3:
        print("PASS: apply_damage left action points unchanged.")
        successes += 1
    else:
        push_error("FAIL: apply_damage should not modify action points.")
        passed = false

    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
