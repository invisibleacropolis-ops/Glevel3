# src/tests/TestArchetype.gd
extends Node

const TRAIT_CLASS_PATH := "res://src/systems/Trait.gd"
const ARCHETYPE_RESOURCE_PATH := "res://assets/archetypes/MerchantArchetype.tres"
const TRAIT_COMPONENT_SCRIPT_PATH := "res://src/systems/TraitComponent.gd"
const MERCHANT_TRAIT_PATH := "res://assets/traits/MerchantTrait.tres"
const COWARDLY_TRAIT_PATH := "res://assets/traits/CowardlyTrait.tres"
const FIRE_TRAIT_PATH := "res://assets/traits/FireAttunedTrait.tres"

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- Archetype Tests --")

    var trait_class := load(TRAIT_CLASS_PATH)
    var archetype_resource := load(ARCHETYPE_RESOURCE_PATH)
    var trait_component_script := load(TRAIT_COMPONENT_SCRIPT_PATH)
    var merchant_trait_resource := load(MERCHANT_TRAIT_PATH)
    var cowardly_trait_resource := load(COWARDLY_TRAIT_PATH)
    var fire_trait_resource := load(FIRE_TRAIT_PATH)

    if archetype_resource == null or trait_component_script == null:
        push_error("FAIL: Unable to load Archetype dependencies.")
        return {"passed": false, "successes": 0, "total": 0}

    var archetype = archetype_resource.duplicate(true)

    # Test 1: Required trait validates successfully.
    total += 1
    var base_component = trait_component_script.new()
    base_component.add_trait(merchant_trait_resource.duplicate(true))
    if archetype.validate_component(base_component):
        print("PASS: Archetype validates components containing required traits.")
        successes += 1
    else:
        push_error("FAIL: Archetype should accept components with required traits.")
        passed = false

    # Test 2: Missing required trait is rejected.
    total += 1
    var missing_component = trait_component_script.new()
    missing_component.add_trait(cowardly_trait_resource.duplicate(true))
    if archetype.validate_component(missing_component):
        push_error("FAIL: Archetype should reject components missing required traits.")
        passed = false
    else:
        print("PASS: Archetype rejects components without the required trait.")
        successes += 1

    # Test 3: Optional traits are allowed.
    total += 1
    var optional_component = trait_component_script.new()
    optional_component.add_trait(merchant_trait_resource.duplicate(true))
    optional_component.add_trait(fire_trait_resource.duplicate(true))
    if archetype.validate_component(optional_component):
        print("PASS: Archetype accepts optional traits from the pool.")
        successes += 1
    else:
        push_error("FAIL: Archetype should allow optional traits defined in the pool.")
        passed = false

    # Test 4: Unknown traits are rejected.
    total += 1
    var forbidden_component = trait_component_script.new()
    forbidden_component.add_trait(merchant_trait_resource.duplicate(true))
    var forbidden_trait = null
    if trait_class != null and trait_class.has_method("new"):
        forbidden_trait = trait_class.new()
        forbidden_trait.set("trait_id", "shadow_broker")
        forbidden_component.add_trait(forbidden_trait)
    if forbidden_trait == null or archetype.validate_component(forbidden_component):
        push_error("FAIL: Archetype should reject traits outside the defined pool.")
        passed = false
    else:
        print("PASS: Archetype rejects traits outside the allowed pool.")
        successes += 1

    # Test 5: get_all_traits merges required and optional pools without duplicates.
    total += 1
    var all_traits = archetype.get_all_traits()
    if all_traits.size() != 3:
        push_error("FAIL: get_all_traits should combine required and optional traits.")
        passed = false
    else:
        var ids := PackedStringArray()
        for entry_index in range(all_traits.size()):
            var trait_resource = all_traits[entry_index]
            ids.append(trait_resource.get("trait_id"))
        ids.sort()
        if ids[0] == "cowardly" and ids[1] == "fire_attuned" and ids[2] == "merchant":
            print("PASS: get_all_traits returns the expected identifiers.")
            successes += 1
        else:
            push_error("FAIL: get_all_traits produced unexpected identifiers: %s" % [ids])
            passed = false

    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
