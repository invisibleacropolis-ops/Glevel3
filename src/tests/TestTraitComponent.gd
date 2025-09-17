# src/tests/TestTraitComponent.gd
extends Node

const TRAIT_COMPONENT_RESOURCE_PATH := "res://src/systems/TraitComponent.tres"
const TRAIT_COMPONENT_SCRIPT_PATH := "res://src/systems/TraitComponent.gd"
const MERCHANT_TRAIT_PATH := "res://assets/traits/MerchantTrait.tres"
const FIRE_TRAIT_PATH := "res://assets/traits/FireAttunedTrait.tres"

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- TraitComponent Tests --")

    var trait_component_resource := load(TRAIT_COMPONENT_RESOURCE_PATH)
    var trait_component_script := load(TRAIT_COMPONENT_SCRIPT_PATH)
    var merchant_trait_resource := load(MERCHANT_TRAIT_PATH)
    var fire_trait_resource := load(FIRE_TRAIT_PATH)

    if trait_component_resource == null or trait_component_script == null:
        push_error("FAIL: Unable to load TraitComponent resources.")
        return {"passed": false, "successes": 0, "total": 0}

    # Test 1: Resource loads proper trait references
    total += 1
    var component = trait_component_resource.duplicate(true)
    if component == null:
        push_error("FAIL: TraitComponent.tres failed to load.")
        passed = false
    elif component.get("traits").size() != 3:
        push_error("FAIL: TraitComponent should preload three sample traits.")
        passed = false
    else:
        var valid_traits := true
        for entry_index in range(component.get("traits").size()):
            var trait_resource = component.get("traits")[entry_index]
            if trait_resource == null:
                valid_traits = false
                break
            if not trait_resource.has_method("get") or trait_resource.get("trait_id") == null:
                valid_traits = false
                break
        if not valid_traits:
            push_error("FAIL: TraitComponent contains an entry that is not a Trait resource.")
            passed = false
        elif not (component.has_trait_id("merchant") and component.has_trait_id("cowardly") and component.has_trait_id("fire_attuned")):
            push_error("FAIL: TraitComponent missing expected trait identifiers.")
            passed = false
        else:
            print("PASS: TraitComponent.tres exposes the expected trait resources.")
            successes += 1

    # Test 2: Adding a trait prevents duplicates
    total += 1
    var runtime_component = trait_component_script.new()
    var merchant_trait := merchant_trait_resource.duplicate(true)
    runtime_component.add_trait(merchant_trait)
    runtime_component.add_trait(merchant_trait)
    if runtime_component.get("traits").size() != 1:
        push_error("FAIL: Duplicate trait should not be added twice.")
        passed = false
    elif not runtime_component.has_trait_id("merchant"):
        push_error("FAIL: Added trait identifier should be discoverable.")
        passed = false
    else:
        print("PASS: add_trait enforces unique trait identifiers.")
        successes += 1

    # Test 3: Removing a trait cleans up identifiers
    total += 1
    runtime_component.remove_trait("merchant")
    if runtime_component.get("traits").size() != 0:
        push_error("FAIL: remove_trait should remove the specified entry.")
        passed = false
    elif runtime_component.has_trait_id("merchant"):
        push_error("FAIL: Removed trait identifier should no longer be reported.")
        passed = false
    else:
        print("PASS: remove_trait clears the matching trait identifier.")
        successes += 1

    # Test 4: get_trait_ids exposes immutable copies
    total += 1
    runtime_component.add_trait(merchant_trait_resource.duplicate(true))
    runtime_component.add_trait(fire_trait_resource.duplicate(true))
    var ids = runtime_component.get_trait_ids()
    ids.sort()
    if ids.size() != 2:
        push_error("FAIL: get_trait_ids should mirror the number of traits assigned.")
        passed = false
    elif ids[0] != "fire_attuned" or ids[1] != "merchant":
        push_error("FAIL: get_trait_ids returned unexpected identifiers.")
        passed = false
    else:
        print("PASS: get_trait_ids returns the expected identifiers.")
        successes += 1

    print("Summary: %d/%d tests passed." % [successes, total])
    return {"passed": passed, "successes": successes, "total": total}
