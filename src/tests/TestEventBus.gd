# src/tests/TestEventBus.gd
extends Node

## Automated tests for the EventBus singleton.
## Designed for Godot 4.4.1.

# Instantiate EventBus explicitly for isolated testing.
var EventBus = preload("res://src/globals/EventBus.gd").new()

# Tracks payload delivery for each monitored EventBus signal.
var _entity_received := false
var _entity_payload: Dictionary = {}
var _item_received := false
var _item_payload: Dictionary = {}
var _item_payload_valid := false
var _quest_received := false
var _quest_payload: Dictionary = {}
var _quest_payload_valid := false

func _on_entity_killed(data: Dictionary) -> void:
    _entity_received = true
    _entity_payload = data

func _on_item_acquired(data: Dictionary) -> void:
    _item_received = true
    _item_payload = data
    _item_payload_valid = _validate_item_payload(data)

func _on_quest_state_changed(data: Dictionary) -> void:
    _quest_received = true
    _quest_payload = data
    _quest_payload_valid = _validate_quest_payload(data)

func _reset_entity_state() -> void:
    _entity_received = false
    _entity_payload = {}

func _reset_item_state() -> void:
    _item_received = false
    _item_payload = {}
    _item_payload_valid = false

func _reset_quest_state() -> void:
    _quest_received = false
    _quest_payload = {}
    _quest_payload_valid = false

func _validate_item_payload(data: Dictionary) -> bool:
    ## Required structure: {"item_id": String, "quantity": int}
    if not data.has("item_id"):
        return false
    if not data.has("quantity"):
        return false

    var item_id_type := typeof(data["item_id"])
    if item_id_type != TYPE_STRING and item_id_type != TYPE_STRING_NAME:
        return false
    if typeof(data["quantity"]) != TYPE_INT:
        return false
    return true

func _validate_quest_payload(data: Dictionary) -> bool:
    ## Required structure: {"quest_id": String, "state": StringName}
    if not data.has("quest_id"):
        return false
    if not data.has("state"):
        return false

    var quest_id_type := typeof(data["quest_id"])
    if quest_id_type != TYPE_STRING and quest_id_type != TYPE_STRING_NAME:
        return false
    return typeof(data["state"]) == TYPE_STRING_NAME

func run_test() -> Dictionary:
    var passed := true
    var total := 0
    var successes := 0
    print("-- EventBus Tests --")

    _reset_entity_state()
    _reset_item_state()
    _reset_quest_state()
    EventBus.entity_killed.connect(_on_entity_killed)
    EventBus.item_acquired.connect(_on_item_acquired)
    EventBus.quest_state_changed.connect(_on_quest_state_changed)

    # Test 1: Emit and receive signal
    total += 1
    var payload := {"entity_id": "test_entity", "killer_id": "tester"}
    EventBus.emit_signal("entity_killed", payload)

    await get_tree().process_frame

    if not _entity_received or _entity_payload != payload:
        push_error("FAIL: EventBus did not deliver entity_killed correctly.")
        passed = false
    else:
        print("PASS: EventBus emitted and received entity_killed successfully.")
        successes += 1

    # Test 2: item_acquired delivers valid payload
    total += 1
    _reset_item_state()
    var item_payload := {"item_id": "healing_potion", "quantity": 3}
    EventBus.emit_signal("item_acquired", item_payload)

    await get_tree().process_frame

    if not _item_received or not _item_payload_valid or _item_payload != item_payload:
        push_error("FAIL: EventBus did not deliver item_acquired payload correctly.")
        passed = false
    else:
        print("PASS: item_acquired delivered a well-formed payload to listeners.")
        successes += 1

    # Test 3: item_acquired rejects payloads missing required keys
    total += 1
    _reset_item_state()
    var incomplete_item_payload := {"item_id": "healing_potion"}
    EventBus.emit_signal("item_acquired", incomplete_item_payload)

    await get_tree().process_frame

    if _item_payload_valid:
        push_error("FAIL: EventBus accepted item_acquired payload missing required keys.")
        passed = false
    else:
        print("PASS: item_acquired detected missing required keys.")
        successes += 1

    # Test 4: item_acquired rejects non-dictionary payloads
    total += 1
    var item_error := EventBus.emit_signal("item_acquired", "invalid")
    if item_error == OK:
        push_error("FAIL: EventBus accepted non-dictionary payload for item_acquired.")
        passed = false
    else:
        print("PASS: item_acquired rejected a non-dictionary payload (error code %d)." % item_error)
        successes += 1

    # Test 5: quest_state_changed delivers valid payload
    total += 1
    _reset_quest_state()
    var quest_payload := {"quest_id": "rescue_mission", "state": &"in_progress"}
    EventBus.emit_signal("quest_state_changed", quest_payload)

    await get_tree().process_frame

    if not _quest_received or not _quest_payload_valid or _quest_payload != quest_payload:
        push_error("FAIL: EventBus did not deliver quest_state_changed payload correctly.")
        passed = false
    else:
        print("PASS: quest_state_changed delivered a well-formed payload to listeners.")
        successes += 1

    # Test 6: quest_state_changed rejects payloads missing required keys
    total += 1
    _reset_quest_state()
    var incomplete_quest_payload := {"quest_id": "rescue_mission"}
    EventBus.emit_signal("quest_state_changed", incomplete_quest_payload)

    await get_tree().process_frame

    if _quest_payload_valid:
        push_error("FAIL: EventBus accepted quest_state_changed payload missing required keys.")
        passed = false
    else:
        print("PASS: quest_state_changed detected missing required keys.")
        successes += 1

    # Test 7: quest_state_changed rejects non-dictionary payloads
    total += 1
    var quest_error := EventBus.emit_signal("quest_state_changed", 42)
    if quest_error == OK:
        push_error("FAIL: EventBus accepted non-dictionary payload for quest_state_changed.")
        passed = false
    else:
        print("PASS: quest_state_changed rejected a non-dictionary payload (error code %d)." % quest_error)
        successes += 1

    # Summary
    print("Summary: %d/%d tests passed." % [successes, total])
    EventBus.free()
    return {"passed": passed, "successes": successes, "total": total}
