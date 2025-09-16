# src/tests/TestAssetRegistry.gd
extends Node

## Tests for the AssetRegistry loader.
## Designed for Godot 4.4.1.

const TEST_DIRECTORY := "res://tests/test_assets/registry_samples/"
const EXPECTED_ASSET_KEYS := ["shield.tres", "sword.tres"]
const CORRUPTED_ASSET_KEY := "broken_asset.tres"

# Manually instantiate the registry to avoid relying on project autoloads.
var AssetRegistry = preload("res://src/globals/AssetRegistry.gd").new()

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- AssetRegistry Tests --")

    AssetRegistry.assets.clear()
    AssetRegistry.failed_assets.clear()
    AssetRegistry._scan_and_load_assets(TEST_DIRECTORY)

    # Test 1: Expected number of assets load successfully.
    total += 1
    var loaded_count := AssetRegistry.assets.size()
    var expected_count := EXPECTED_ASSET_KEYS.size()
    var count_matches := loaded_count == expected_count
    assert(count_matches, "AssetRegistry loaded %d assets; expected %d." % [loaded_count, expected_count])
    if count_matches:
        print("PASS: AssetRegistry loaded %d assets from %s." % [loaded_count, TEST_DIRECTORY])
        successes += 1
    else:
        push_error("FAIL: AssetRegistry loaded %d assets; expected %d." % [loaded_count, expected_count])
        passed = false

    # Test 2: Each asset is retrievable by key.
    total += 1
    var retrieval_success := true
    for asset_key in EXPECTED_ASSET_KEYS:
        var resource := AssetRegistry.get_asset(asset_key)
        var asset_present := resource != null and AssetRegistry.has_asset(asset_key)
        assert(asset_present, "Asset '%s' should be available after scanning %s." % [asset_key, TEST_DIRECTORY])
        if not asset_present:
            push_error("FAIL: AssetRegistry failed to expose '%s'." % asset_key)
            passed = false
            retrieval_success = false

    if retrieval_success:
        print("PASS: AssetRegistry returned expected assets by key.")
        successes += 1

    # Test 3: Corrupted assets are logged without being cached.
    total += 1
    var failed_assets := AssetRegistry.get_failed_assets()
    var failure_recorded := not AssetRegistry.has_asset(CORRUPTED_ASSET_KEY) and failed_assets.has(CORRUPTED_ASSET_KEY)
    assert(failure_recorded, "Corrupted asset '%s' should be tracked as a failure." % CORRUPTED_ASSET_KEY)
    if failure_recorded:
        print("PASS: AssetRegistry recorded corrupted asset failure without caching it.")
        successes += 1
    else:
        push_error("FAIL: Corrupted asset '%s' not tracked correctly." % CORRUPTED_ASSET_KEY)
        passed = false

    # Summary
    print("Summary: %d/%d tests passed." % [successes, total])
    AssetRegistry.assets.clear()
    AssetRegistry.failed_assets.clear()
    AssetRegistry.free()
    return {"passed": passed, "successes": successes, "total": total}
