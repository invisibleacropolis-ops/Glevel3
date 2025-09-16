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

    # Test 5: to_dictionary captures all exported fields and returns defensive copies.
    total += 1
    var snapshot_component := StatsComponentScript.new()
    snapshot_component.job_id = StringName("merchant")
    snapshot_component.job_title = "Merchant"
    snapshot_component.job_pool_tags = [StringName("core_pool")]
    snapshot_component.health = 12
    snapshot_component.max_health = 18
    snapshot_component.energy = 3
    snapshot_component.max_energy = 5
    snapshot_component.armor_rating = 2
    snapshot_component.action_points = 3
    snapshot_component.max_action_points = 5
    snapshot_component.short_term_statuses = [StringName("poisoned")]
    snapshot_component.long_term_statuses = [StringName("cursed")]
    snapshot_component.resistances = {StringName("fire"): 0.5}
    snapshot_component.vulnerabilities = {StringName("cold"): 1.5}
    snapshot_component.experience_points = 42
    snapshot_component.level = 7
    snapshot_component.level_title = "Veteran"
    snapshot_component.traits = [StringName("brave")]
    snapshot_component.body_pool_fixed = 2
    snapshot_component.body_pool_relative = 3
    snapshot_component.mind_pool_fixed = 4
    snapshot_component.mind_pool_relative = 5
    snapshot_component.strength = 6
    snapshot_component.agility = 5
    snapshot_component.speed = 4
    snapshot_component.intelligence = 7
    snapshot_component.wisdom = 8
    snapshot_component.charisma = 9
    snapshot_component.athletics = 2
    snapshot_component.combat_training = 3
    snapshot_component.thievery = 1
    snapshot_component.diplomacy = 4
    snapshot_component.lore = 6
    snapshot_component.technical = 5
    snapshot_component.advanced_training = {StringName("pilot"): 2}
    snapshot_component.skill_levels = {StringName("piloting"): 3}
    snapshot_component.skill_options = {StringName("piloting"): [StringName("loop_the_loop")]}
    snapshot_component.equipped_items = {StringName("weapon"): StringName("cutlass")}
    snapshot_component.inventory_items = [StringName("potion")]

    var snapshot := snapshot_component.to_dictionary()
    var expected_keys := [
        "job_id",
        "job_title",
        "job_pool_tags",
        "health",
        "max_health",
        "energy",
        "max_energy",
        "armor_rating",
        "action_points",
        "max_action_points",
        "short_term_statuses",
        "long_term_statuses",
        "resistances",
        "vulnerabilities",
        "experience_points",
        "level",
        "level_title",
        "traits",
        "body_pool_fixed",
        "body_pool_relative",
        "mind_pool_fixed",
        "mind_pool_relative",
        "strength",
        "agility",
        "speed",
        "intelligence",
        "wisdom",
        "charisma",
        "athletics",
        "combat_training",
        "thievery",
        "diplomacy",
        "lore",
        "technical",
        "advanced_training",
        "skill_levels",
        "skill_options",
        "equipped_items",
        "inventory_items",
    ]

    var snapshot_valid := snapshot.keys().size() == expected_keys.size()
    for key in expected_keys:
        if not snapshot.has(key):
            snapshot_valid = false
            break
        var component_value := snapshot_component.get(key)
        if snapshot[key] != component_value:
            snapshot_valid = false
            break

    if snapshot_valid:
        (snapshot["job_pool_tags"] as Array).append(StringName("extra_pool"))
        snapshot_valid = snapshot_valid and snapshot_component.job_pool_tags.size() == 1

        (snapshot["short_term_statuses"] as Array).append(StringName("frozen"))
        snapshot_valid = snapshot_valid and not snapshot_component.short_term_statuses.has(StringName("frozen"))

        var resistances_snapshot: Dictionary = snapshot["resistances"]
        resistances_snapshot[StringName("acid")] = 0.1
        snapshot_valid = snapshot_valid and not snapshot_component.resistances.has(StringName("acid"))

        var advanced_snapshot: Dictionary = snapshot["advanced_training"]
        advanced_snapshot[StringName("navigator")] = 1
        snapshot_valid = snapshot_valid and not snapshot_component.advanced_training.has(StringName("navigator"))

        var skill_levels_snapshot: Dictionary = snapshot["skill_levels"]
        skill_levels_snapshot[StringName("piloting")] = 4
        snapshot_valid = snapshot_valid and snapshot_component.skill_levels[StringName("piloting")] == 3

        var skill_options_snapshot: Dictionary = snapshot["skill_options"]
        (skill_options_snapshot[StringName("piloting")] as Array).append(StringName("immelmann_turn"))
        snapshot_valid = snapshot_valid and snapshot_component.skill_options[StringName("piloting")].size() == 1

        var inventory_snapshot: Array = snapshot["inventory_items"]
        inventory_snapshot.append(StringName("tonic"))
        snapshot_valid = snapshot_valid and snapshot_component.inventory_items.size() == 1

    if snapshot_valid:
        print("PASS: to_dictionary exposes a full, defensive snapshot of the StatsComponent state.")
        successes += 1
    else:
        push_error("FAIL: to_dictionary did not include all fields or returned live references.")
        passed = false

    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
