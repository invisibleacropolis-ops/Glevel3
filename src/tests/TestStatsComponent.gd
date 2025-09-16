# src/tests/TestStatsComponent.gd
extends Node

## Tests for the expanded StatsComponent resource and its exported data contract.
## Designed for Godot 4.4.1 headless testing.

const StatsComponentScript := preload("res://src/components/StatsComponent.gd")

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- StatsComponent Tests --")

    var stats := StatsComponentScript.new()

    # Test 1: Default values reflect an unconfigured archetype surface.
    total += 1
    var defaults_valid := str(stats.job_id).is_empty() \
        and stats.health == 0 \
        and stats.max_health == 0 \
        and stats.energy == 0 \
        and stats.max_energy == 0 \
        and stats.action_points == 0 \
        and stats.max_action_points == 0 \
        and stats.short_term_statuses.is_empty() \
        and stats.long_term_statuses.is_empty() \
        and stats.resistances.is_empty() \
        and stats.vulnerabilities.is_empty() \
        and stats.experience_points == 0 \
        and stats.level == 1 \
        and stats.traits.is_empty() \
        and stats.skill_levels.is_empty() \
        and stats.skill_options.is_empty()
    if defaults_valid:
        print("PASS: StatsComponent defaults to a clean designer workspace.")
        successes += 1
    else:
        push_error("FAIL: StatsComponent defaults deviate from the documented baseline.")
        passed = false

    # Test 2: Damage and healing operations respect clamps.
    total += 1
    stats.max_health = 20
    stats.health = 20
    stats.apply_damage(25)
    stats.heal(5)
    var combat_valid := stats.health == 5
    stats.heal(40)
    combat_valid = combat_valid and stats.health == 20
    if combat_valid:
        print("PASS: Damage and healing clamp to 0 and max_health as expected.")
        successes += 1
    else:
        push_error("FAIL: Damage/heal helpers produced unexpected values.")
        passed = false

    # Test 3: apply_stat_mod handles multiple deltas and status/trait changes.
    total += 1
    stats.max_energy = 6
    stats.energy = 2
    stats.max_action_points = 4
    stats.action_points = 1
    stats.experience_points = 10
    stats.level = 2
    stats.apply_stat_mod({
        "energy_delta": 5,
        "action_points_delta": 3,
        "xp_delta": 15,
        "level_delta": 1,
        "add_short_status": [StringName("poisoned")],
        "add_long_status": [StringName("cursed")],
        "traits_to_add": [StringName("goblin_slayer")]
    })
    var mod_valid := stats.energy == 6 \
        and stats.action_points == 4 \
        and stats.experience_points == 25 \
        and stats.level == 3 \
        and StringName("poisoned") in stats.short_term_statuses \
        and StringName("cursed") in stats.long_term_statuses \
        and StringName("goblin_slayer") in stats.traits
    stats.apply_stat_mod({
        "energy_delta": -2,
        "action_points_delta": -1,
        "remove_status": [StringName("poisoned")],
        "traits_to_remove": [StringName("goblin_slayer")]
    })
    mod_valid = mod_valid and stats.energy == 4 \
        and stats.action_points == 3 \
        and not (StringName("poisoned") in stats.short_term_statuses) \
        and not (StringName("goblin_slayer") in stats.traits)
    if mod_valid:
        print("PASS: apply_stat_mod processes bundled adjustments correctly.")
        successes += 1
    else:
        push_error("FAIL: apply_stat_mod did not produce expected results.")
        passed = false

    # Test 4: reset_for_new_run restores runtime pools and clears short-term status.
    total += 1
    stats.short_term_statuses.append(StringName("burning"))
    stats.energy = 1
    stats.action_points = 0
    stats.health = 3
    stats.reset_for_new_run()
    var reset_valid := stats.energy == stats.max_energy \
        and stats.action_points == stats.max_action_points \
        and stats.health == stats.max_health \
        and stats.short_term_statuses.is_empty() \
        and StringName("cursed") in stats.long_term_statuses
    if reset_valid:
        print("PASS: reset_for_new_run preserves long-term state and refreshes encounter pools.")
        successes += 1
    else:
        push_error("FAIL: reset_for_new_run did not refresh runtime stats correctly.")
        passed = false

    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
