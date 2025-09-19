extends Node
class_name EventBusSingleton

## Holds a reference to the autoloaded singleton instance so code can resolve the
## EventBus without resorting to scene tree lookups. The value is assigned when
## the node enters the tree and cleared on exit so tests can instantiate their
## own isolated copies without side effects.
static var _singleton: EventBusSingleton = null

## Centralized, autoloaded event bus that brokers decoupled communication between
## gameplay systems. All signals defined here must accept exactly one argument –
## a Dictionary payload – so the event contracts can evolve without requiring
## refactors to every subscriber. This script is intended to be registered as an
## autoload singleton named "EventBus".
##
## Each signal's payload contract is documented both in its docstring and inside
## `SIGNAL_CONTRACTS` below. The validation logic inside `emit_signal()` enforces
## these contracts at runtime, preventing malformed events from propagating
## through the game and greatly simplifying cross-team debugging efforts.

## Comprehensive catalogue of every EventBus signal contract. Each entry stores a
## human-readable description plus dictionaries that map payload keys to the
## Variant types accepted for those keys.
const SIGNAL_CONTRACTS := {
    &"debug_stats_reported": {
        "description": "Telemetry broadcast emitted whenever DebugSystem captures "
            + "a snapshot of an entity's StatsComponent for diagnostics.",
        "required_keys": {
            "entity_id": [TYPE_STRING, TYPE_STRING_NAME],
            "stats": TYPE_DICTIONARY,
        },
        "optional_keys": {
            "timestamp": TYPE_FLOAT,
        },
    },
    &"entity_killed": {
        "description": "CombatSystem notification that an entity has been removed "
            + "from play. Downstream systems such as quests, loot, or meta "
            + "narrative modules react to this signal to update their state.",
        "required_keys": {
            "entity_id": [TYPE_STRING, TYPE_STRING_NAME],
        },
        "optional_keys": {
            "killer_id": [TYPE_STRING, TYPE_STRING_NAME],
            "archetype_id": [TYPE_STRING, TYPE_STRING_NAME],
            "entity_type": TYPE_STRING_NAME,
            "components": TYPE_DICTIONARY,
        },
    },
    &"item_acquired": {
        "description": "Inventory or loot system broadcast whenever an entity "
            + "adds an item stack to its inventory.",
        "required_keys": {
            "item_id": [TYPE_STRING, TYPE_STRING_NAME],
            "quantity": TYPE_INT,
        },
        "optional_keys": {
            "owner_id": [TYPE_STRING, TYPE_STRING_NAME],
            "source": TYPE_STRING_NAME,
            "metadata": TYPE_DICTIONARY,
        },
    },
    &"quest_state_changed": {
        "description": "QuestSystem update describing a quest's latest lifecycle "
            + "state transition.",
        "required_keys": {
            "quest_id": [TYPE_STRING, TYPE_STRING_NAME],
            "state": TYPE_STRING_NAME,
        },
        "optional_keys": {
            "progress": TYPE_FLOAT,
            "objectives": TYPE_ARRAY,
            "metadata": TYPE_DICTIONARY,
        },
    },
    &"turn_passed": {
        "description": "Emitted when a game turn passes, typically used for short-term status effect durations.",
        "required_keys": {},
        "optional_keys": {
            "turn_number": TYPE_INT,
        },
    },
    &"day_passed": {
        "description": "Emitted when a game day passes, typically used for long-term status effect durations.",
        "required_keys": {},
        "optional_keys": {
            "day_number": TYPE_INT,
        },
    },
    &"status_effect_ended": {
        "description": "Emitted when a status effect expires or is removed from an entity.",
        "required_keys": {
            "entity_id": [TYPE_STRING, TYPE_STRING_NAME],
            "effect_name": [TYPE_STRING, TYPE_STRING_NAME],
        },
        "optional_keys": {
            "reason": [TYPE_STRING, TYPE_STRING_NAME],
            "modifiers": TYPE_DICTIONARY,
        },
    },
}

## Emitted whenever DebugSystem reports an entity snapshot.
## Payload keys:
## - "entity_id" (String or StringName): Unique identifier for the reported entity.
## - "stats" (Dictionary): Snapshot of the StatsComponent values (health, action_points, etc.).
## - Optional "timestamp" (float): Monotonic timestamp indicating when the sample was captured.
@warning_ignore("unused_signal")
signal debug_stats_reported(data: Dictionary)

## Emitted when CombatSystem determines an entity has been removed from play.
## Required payload keys:
## - "entity_id" (String or StringName): Identifier of the defeated entity.
## Optional payload keys:
## - "killer_id" (String or StringName): Identifier of the killer, if known.
## - "archetype_id" (String or StringName): Source archetype for postmortem analytics.
## - "entity_type" (StringName): High-level taxonomy from ComponentKeys/ULTEnums.
## - "components" (Dictionary): Snapshot of relevant Components for downstream systems.
@warning_ignore("unused_signal")
signal entity_killed(data: Dictionary)

## Emitted whenever an item stack enters an inventory.
## Required payload keys:
## - "item_id" (String or StringName): Identifier of the acquired item resource.
## - "quantity" (int): Number of units added to the stack.
## Optional payload keys:
## - "owner_id" (String or StringName): Identifier of the receiving entity.
## - "source" (StringName): Origin of the acquisition (loot_drop, vendor_purchase, etc.).
## - "metadata": Arbitrary supplemental data for UI, analytics, or logging.
@warning_ignore("unused_signal")
signal item_acquired(data: Dictionary)

## Emitted whenever a quest transitions between states.
## Required payload keys:
## - "quest_id" (String or StringName): Identifier of the quest resource or runtime instance.
## - "state" (StringName): New quest state (e.g., &"in_progress", &"completed").
## Optional payload keys:
## - "progress" (float): Normalized progress value between 0.0 and 1.0.
## - "objectives" (Array): Collection of objective payload dictionaries for UI updates.
## - "metadata": Arbitrary contextual data for analytics or notifications.
@warning_ignore("unused_signal")
signal quest_state_changed(data: Dictionary)

## Emitted when a game turn passes, typically used for short-term status effect durations.
## Optional payload keys:
## - "turn_number" (int): The current turn number.
@warning_ignore("unused_signal")
signal turn_passed(data: Dictionary)

## Emitted when a game day passes, typically used for long-term status effect durations.
## Optional payload keys:
## - "day_number" (int): The current day number.
@warning_ignore("unused_signal")
signal day_passed(data: Dictionary)

## Emitted when a status effect expires or is removed from an entity.
## Required payload keys:
## - "entity_id" (String or StringName): Identifier of the entity the effect was on.
## - "effect_name" (String or StringName): The name of the status effect that ended.
## Optional payload keys:
## - "reason" (StringName): Why the effect ended (e.g., &"expired", &"removed_manually").
## - "modifiers" (Dictionary): The modifiers of the effect that ended.
@warning_ignore("unused_signal")
signal status_effect_ended(data: Dictionary)

func _ready() -> void:
    # This node is intended to be added as an autoload singleton.
    pass

func _enter_tree() -> void:
    _singleton = self

func _exit_tree() -> void:
    if _singleton == self:
        _singleton = null

## Returns the active EventBus singleton when it has been registered as an
## autoload. This is intentionally static so callers can access the shared
## instance without depending on the autoload name or scene tree paths.
static func get_singleton() -> EventBusSingleton:
    return _singleton

## Convenience helper allowing call sites to guard EventBus usage until the
## autoload has been initialized.
static func is_singleton_ready() -> bool:
    return is_instance_valid(_singleton)

## Broadcasts a signal after validating the provided payload dictionary against the
## documented contract. Returns a Godot error code that callers can inspect when
## running in validation-heavy environments (e.g., automated tests).
@warning_ignore("native_method_override")
func emit_signal(signal_name: StringName, payload: Variant = null) -> int:
    var validation_result := _validate_payload(signal_name, payload)
    if validation_result != OK:
        return validation_result

    return super.emit_signal(signal_name, payload)

## Returns the documented contract for a signal so tools or debug panels can
## surface the schema to developers at runtime.
func describe_signal(signal_name: StringName) -> Dictionary:
    return SIGNAL_CONTRACTS.get(signal_name, {})

## Internal validation routine that ensures every broadcast complies with the
## contract declared in SIGNAL_CONTRACTS. Invalid payloads stop propagation and
## surface descriptive errors in the editor console.
func _validate_payload(signal_name: StringName, payload: Variant) -> int:
    if typeof(payload) != TYPE_DICTIONARY:
        push_error("EventBus.%s expects a Dictionary payload but received %s." % [
            signal_name,
            type_string(typeof(payload)),
        ])
        return ERR_INVALID_PARAMETER

    var contract: Dictionary = SIGNAL_CONTRACTS.get(signal_name, {})
    if contract.is_empty():
        # Even if we do not have a bespoke contract we still accept dictionary payloads.
        return OK

    var required: Dictionary = contract.get("required_keys", {})
    for key in required.keys():
        if not payload.has(key):
            push_error("EventBus.%s payload missing required key \"%s\"." % [signal_name, key])
            return ERR_INVALID_DATA
        if not _value_matches_type(payload[key], required[key]):
            push_error(
                "EventBus.%s payload key \"%s\" has invalid type %s (expected %s)." % [
                    signal_name,
                    key,
                    type_string(typeof(payload[key])),
                    _describe_expected_type(required[key]),
                ]
            )
            return ERR_INVALID_DATA

    var optional: Dictionary = contract.get("optional_keys", {})
    for key in optional.keys():
        if payload.has(key) and not _value_matches_type(payload[key], optional[key]):
            push_error(
                "EventBus.%s optional key \"%s\" has invalid type %s (expected %s)." % [
                    signal_name,
                    key,
                    type_string(typeof(payload[key])),
                    _describe_expected_type(optional[key]),
                ]
            )
            return ERR_INVALID_DATA

    return OK

## Helper that compares a Variant value against an expected type rule. The rule
## can be a single Variant.Type integer or an Array of acceptable Variant.Type values.
func _value_matches_type(value: Variant, expected_rule: Variant) -> bool:
    if typeof(expected_rule) == TYPE_ARRAY:
        for allowed_type in expected_rule:
            if _single_type_match(value, int(allowed_type)):
                return true
        return false

    return _single_type_match(value, int(expected_rule))

func _single_type_match(value: Variant, expected_type: int) -> bool:
    var actual_type := typeof(value)
    if actual_type == expected_type:
        return true

    # Permit StringName payloads where a String was declared (and vice versa)
    # because most identifiers can be authored as either.
    var is_string_like := (actual_type == TYPE_STRING and expected_type == TYPE_STRING_NAME)
    is_string_like = is_string_like or (actual_type == TYPE_STRING_NAME and expected_type == TYPE_STRING)
    return is_string_like

func _describe_expected_type(expected_rule: Variant) -> String:
    if typeof(expected_rule) == TYPE_ARRAY:
        var names := PackedStringArray()
        for allowed_type in expected_rule:
            names.append(type_string(int(allowed_type)))
        return ", ".join(names)

    return type_string(int(expected_rule))
