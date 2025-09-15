# src/tests/TestTraitComponent.gd
extends Node

const TraitComponentResource := preload("res://src/systems/TraitComponent.tres")
const TraitComponentScript := preload("res://src/systems/TraitComponent.gd")
const Trait := preload("res://src/systems/Trait.gd")
const MerchantTrait := preload("res://assets/traits/MerchantTrait.tres")
const FireAttunedTrait := preload("res://assets/traits/FireAttunedTrait.tres")

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- TraitComponent Tests --")

    # Test 1: Resource loads proper trait references
    total += 1
    var component: TraitComponent = TraitComponentResource.duplicate(true)
    if component == null:
        push_error("FAIL: TraitComponent.tres failed to load.")
        passed = false
    elif component.traits.size() != 3:
        push_error("FAIL: TraitComponent should preload three sample traits.")
        passed = false
    else:
        var valid_traits := true
        for trait in component.traits:
            if not (trait is Trait):
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
    var runtime_component: TraitComponent = TraitComponentScript.new()
    var merchant_trait: Trait = MerchantTrait.duplicate(true)
    runtime_component.add_trait(merchant_trait)
    runtime_component.add_trait(merchant_trait)
    if runtime_component.traits.size() != 1:
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
    if runtime_component.traits.size() != 0:
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
    runtime_component.add_trait(MerchantTrait.duplicate(true))
    runtime_component.add_trait(FireAttunedTrait.duplicate(true))
    var ids := runtime_component.get_trait_ids()
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
