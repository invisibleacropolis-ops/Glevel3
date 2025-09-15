# src/tests/TestArchetype.gd
extends Node

const ArchetypeResource := preload("res://assets/archetypes/MerchantArchetype.tres")
const TraitComponentScript := preload("res://src/systems/TraitComponent.gd")
const Trait := preload("res://src/systems/Trait.gd")
const MerchantTrait := preload("res://assets/traits/MerchantTrait.tres")
const CowardlyTrait := preload("res://assets/traits/CowardlyTrait.tres")
const FireAttunedTrait := preload("res://assets/traits/FireAttunedTrait.tres")

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- Archetype Tests --")

    var archetype: Archetype = ArchetypeResource.duplicate(true)

    # Test 1: Required trait validates successfully.
    total += 1
    var base_component: TraitComponent = TraitComponentScript.new()
    base_component.add_trait(MerchantTrait.duplicate(true))
    if archetype.validate_component(base_component):
        print("PASS: Archetype validates components containing required traits.")
        successes += 1
    else:
        push_error("FAIL: Archetype should accept components with required traits.")
        passed = false

    # Test 2: Missing required trait is rejected.
    total += 1
    var missing_component: TraitComponent = TraitComponentScript.new()
    missing_component.add_trait(CowardlyTrait.duplicate(true))
    if archetype.validate_component(missing_component):
        push_error("FAIL: Archetype should reject components missing required traits.")
        passed = false
    else:
        print("PASS: Archetype rejects components without the required trait.")
        successes += 1

    # Test 3: Optional traits are allowed.
    total += 1
    var optional_component: TraitComponent = TraitComponentScript.new()
    optional_component.add_trait(MerchantTrait.duplicate(true))
    optional_component.add_trait(FireAttunedTrait.duplicate(true))
    if archetype.validate_component(optional_component):
        print("PASS: Archetype accepts optional traits from the pool.")
        successes += 1
    else:
        push_error("FAIL: Archetype should allow optional traits defined in the pool.")
        passed = false

    # Test 4: Unknown traits are rejected.
    total += 1
    var forbidden_component: TraitComponent = TraitComponentScript.new()
    forbidden_component.add_trait(MerchantTrait.duplicate(true))
    var forbidden_trait := Trait.new()
    forbidden_trait.trait_id = "shadow_broker"
    forbidden_component.add_trait(forbidden_trait)
    if archetype.validate_component(forbidden_component):
        push_error("FAIL: Archetype should reject traits outside the defined pool.")
        passed = false
    else:
        print("PASS: Archetype rejects traits outside the allowed pool.")
        successes += 1

    # Test 5: get_all_traits merges required and optional pools without duplicates.
    total += 1
    var all_traits := archetype.get_all_traits()
    if all_traits.size() != 3:
        push_error("FAIL: get_all_traits should combine required and optional traits.")
        passed = false
    else:
        var ids := PackedStringArray()
        for trait in all_traits:
            ids.append(trait.trait_id)
        ids.sort()
        if ids[0] == "cowardly" and ids[1] == "fire_attuned" and ids[2] == "merchant":
            print("PASS: get_all_traits returns the expected identifiers.")
            successes += 1
        else:
            push_error("FAIL: get_all_traits produced unexpected identifiers: %s" % [ids])
            passed = false

    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
