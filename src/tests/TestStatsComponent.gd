# src/tests/TestStatsComponent.gd
extends Node

## Tests for the StatsComponent resource and its exported data contract.
## Designed for Godot 4.4.1 headless testing.

const StatsComponentScript := preload("res://src/components/StatsComponent.gd")

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- StatsComponent Tests --")

    var stats := StatsComponentScript.new()

    # Test 1: Default values match the documented data contract.
    total += 1
    var defaults_valid := stats.health == 0 \
        and stats.max_health == 0 \
        and stats.action_points == 0 \
        and stats.max_action_points == 0 \
        and stats.strength == 0 \
        and stats.dexterity == 0 \
        and stats.constitution == 0 \
        and stats.intelligence == 0 \
        and stats.willpower == 0 \
        and stats.speed == 0.0 \
        and stats.resistances.is_empty() \
        and stats.vulnerabilities.is_empty()
    if defaults_valid:
        print("PASS: StatsComponent defaults to documented baseline values.")
        successes += 1
    else:
        push_error("FAIL: StatsComponent default values deviate from the documented baseline.")
        passed = false

    # Test 2: Assigning combat stats preserves the configured values.
    total += 1
    stats.health = 20
    stats.max_health = 30
    stats.action_points = 5
    stats.max_action_points = 6
    stats.strength = 8
    stats.dexterity = 7
    stats.constitution = 9
    stats.intelligence = 6
    stats.willpower = 5
    stats.speed = 1.5

    var values_persist := stats.health == 20 \
        and stats.max_health == 30 \
        and stats.action_points == 5 \
        and stats.max_action_points == 6 \
        and stats.strength == 8 \
        and stats.dexterity == 7 \
        and stats.constitution == 9 \
        and stats.intelligence == 6 \
        and stats.willpower == 5 \
        and stats.speed == 1.5
    if values_persist:
        print("PASS: StatsComponent stores assigned combat statistics.")
        successes += 1
    else:
        push_error("FAIL: StatsComponent failed to retain assigned combat statistics.")
        passed = false

    # Test 3: Resistances and vulnerabilities support StringName keys and float values.
    total += 1
    stats.resistances[StringName("fire")] = 0.25
    stats.vulnerabilities[StringName("cold")] = 1.5

    var dictionaries_valid := stats.resistances.get(StringName("fire"), -1.0) == 0.25 \
        and stats.vulnerabilities.get(StringName("cold"), -1.0) == 1.5
    if dictionaries_valid:
        print("PASS: StatsComponent damage maps accept StringName keys with float payloads.")
        successes += 1
    else:
        push_error("FAIL: StatsComponent damage maps did not retain expected entries.")
        passed = false

    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
