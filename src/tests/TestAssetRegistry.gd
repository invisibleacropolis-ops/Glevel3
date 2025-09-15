# src/tests/TestAssetRegistry.gd
extends Node

## Tests for the AssetRegistry loader.
## Designed for Godot 4.4.1.

# Manually instantiate the registry to avoid relying on project autoloads.
var AssetRegistry = preload("res://src/globals/AssetRegistry.gd").new()

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- AssetRegistry Tests --")

    AssetRegistry._scan_and_load_assets("res://tests/test_assets/")

    # Test 1: Good asset loads
    total += 1
    var good = AssetRegistry.get_asset("good_item.tres")
    if good == null:
        push_error("FAIL: Good asset did not load!")
        passed = false
    else:
        print("PASS: Good asset loaded successfully.")
        successes += 1

    # Test 2: Broken asset handled safely
    total += 1
    var bad = AssetRegistry.get_asset("bad_item.tres")
    if bad != null:
        push_error("FAIL: Broken asset should not load!")
        passed = false
    else:
        print("PASS: Broken asset correctly ignored.")
        successes += 1

    # Summary
    print("Summary: %d/%d tests passed." % [successes, total])
    AssetRegistry.assets.clear()
    return {"passed": passed, "successes": successes, "total": total}
