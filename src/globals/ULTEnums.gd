extends Object
class_name ULTEnums

## Ultimate enumeration registry that merges the streamlined constants from the
## lightweight Enums helper with the diagnostic tooling of OldEnums.
##
## The registry underpins the data-first architecture documented in the design
## docs by exposing canonical identifiers for entity taxonomies and component
## dictionaries. Systems such as the InteractionManager rely on
## `EntityType` to branch their encounter state machines—e.g. a
## PROCESS_ACTION phase can prioritise PLAYER entities while queueing MONSTER
## counter-attacks—without spelunking through component payloads first.
## Component key helpers keep EntityData manifests typo-safe so procedurally
## assembled archetypes interoperate with debugging tools and validation suites.

## High-level entity classifications consumed by filtering utilities and
## encounter state machines.
enum EntityType {
    PLAYER,
    NPC,
    MONSTER,
    WILDLIFE,
    OBJECT,
}

## Maps entity type IDs back to symbolic labels for telemetry, debugging, and UI.
const _ENTITY_TYPE_NAMES := {
    EntityType.PLAYER: &"PLAYER",
    EntityType.NPC: &"NPC",
    EntityType.MONSTER: &"MONSTER",
    EntityType.WILDLIFE: &"WILDLIFE",
    EntityType.OBJECT: &"OBJECT",
}

## Namespace of canonical dictionary keys used throughout EntityData manifests.
## Keys are stored as `StringName` to keep lookups fast while remaining human
## readable inside `.tres` files. Both array (`values`) and PackedStringArray
## (`all`) helpers are retained for compatibility with existing tooling.
class ComponentKeys:
    const STATS := StringName("stats")
    const TRAITS := StringName("traits")
    const STATUS := StringName("status")
    const SKILLS := StringName("skills")
    const INVENTORY := StringName("inventory")
    const AI_BEHAVIOR := StringName("ai_behavior")
    const FACTION := StringName("faction")
    const QUEST_STATE := StringName("quest_state")

    ## Returns the registered component keys as StringName values so systems can
    ## iterate without incurring temporary allocations.
    static func values() -> Array[StringName]:
        return [
            STATS,
            TRAITS,
            STATUS,
            SKILLS,
            INVENTORY,
            AI_BEHAVIOR,
            FACTION,
            QUEST_STATE,
        ]

    ## Returns the component keys as strings for editor drop-downs and UI lists.
    static func all() -> PackedStringArray:
        var keys := PackedStringArray()
        for key in values():
            keys.append(String(key))
        return keys

## Descriptive metadata for each component key so debug tooling can surface the
## expected resource types and high-level intent to engineers.
const COMPONENT_KEY_METADATA := {
    ComponentKeys.STATS: {
        "description": "Primary combat and utility statistics supplied by StatsComponent resources.",
        "resource": &"StatsComponent",
    },
    ComponentKeys.TRAITS: {
        "description": "Collection of TraitComponent resources defining passive modifiers and narrative hooks.",
        "resource": &"TraitComponent",
    },
    ComponentKeys.STATUS: {
        "description": "StatusComponent payload tracking timed effects such as poison, burns, or scars.",
        "resource": &"StatusComponent",
    },
    ComponentKeys.SKILLS: {
        "description": "SkillComponent manifest listing usable abilities and their metadata.",
        "resource": &"SkillComponent",
    },
    ComponentKeys.INVENTORY: {
        "description": "InventoryComponent reference detailing carried items and loot tables.",
        "resource": &"InventoryComponent",
    },
    ComponentKeys.AI_BEHAVIOR: {
        "description": "AIBehaviorComponent attachment specifying brain scripts or behaviour trees.",
        "resource": &"AIBehaviorComponent",
    },
    ComponentKeys.FACTION: {
        "description": "FactionComponent declaring allegiance identifiers and reputation dictionaries.",
        "resource": &"FactionComponent",
    },
    ComponentKeys.QUEST_STATE: {
        "description": "QuestStateComponent tracking quest lifecycle data for an entity.",
        "resource": &"QuestStateComponent",
    },
}

## Returns the symbolic label associated with an EntityType ID. Unknown IDs fall
## back to `UNKNOWN_ENTITY_TYPE` so debug logs remain informative even when data
## is malformed.
static func get_entity_type_name(entity_type: int) -> StringName:
    return _ENTITY_TYPE_NAMES.get(entity_type, &"UNKNOWN_ENTITY_TYPE")

## Enumerates every declared EntityType value for dropdown construction or tests.
static func list_entity_types() -> Array[int]:
    var ids: Array[int] = []
    for id in _ENTITY_TYPE_NAMES.keys():
        ids.append(int(id))
    return ids

## Returns true when the provided integer maps to a declared EntityType.
static func is_valid_entity_type(entity_type: int) -> bool:
    return _ENTITY_TYPE_NAMES.has(entity_type)

## Emits an editor error if the supplied value is not a recognised entity type.
## Returns `true` when valid so the helper can be used inside `assert` chains.
static func assert_valid_entity_type(entity_type: int) -> bool:
    if not is_valid_entity_type(entity_type):
        push_error(
            "ULTEnums: Unknown EntityType id %s. Expected one of: %s." % [
                entity_type,
                ", ".join(_ENTITY_TYPE_NAMES.values().map(func(name: StringName) -> String: return String(name))),
            ]
        )
        return false
    return true

## Returns the metadata dictionary for a component key. Unknown keys produce an
## empty dictionary so callers can detect missing definitions without risking
## runtime errors.
static func get_component_metadata(key: Variant) -> Dictionary:
    var normalized := _normalize_component_key(key)
    if normalized == StringName():
        return {}
    return COMPONENT_KEY_METADATA.get(normalized, {})

## Returns a deep copy of the component metadata table for editor integrations
## that need to present descriptions without risking accidental mutation.
static func describe_all_components() -> Dictionary:
    return COMPONENT_KEY_METADATA.duplicate(true)

## Enumerates all registered component keys as `StringName` values.
static func list_component_keys() -> Array[StringName]:
    var keys: Array[StringName] = []
    for key in ComponentKeys.values():
        keys.append(key)
    return keys

## Returns true when the provided key is recognised and non-empty.
static func is_valid_component_key(key: Variant) -> bool:
    var normalized := _normalize_component_key(key)
    return normalized != StringName() and COMPONENT_KEY_METADATA.has(normalized)

## Emits descriptive errors for component keys that fall outside the curated
## registry. Returns `true` when the key is accepted so the helper can be used
## as a guard clause.
static func assert_valid_component_key(key: Variant) -> bool:
    var normalized := _normalize_component_key(key)
    if not COMPONENT_KEY_METADATA.has(normalized):
        push_error(
            "ULTEnums: Unknown component key '%s'. Registered keys: %s." % [
                key,
                ", ".join(ComponentKeys.all()),
            ]
        )
        return false
    return true

## Produces a structured diagnostic report for a components dictionary. Each
## entry records whether the key is recognised, the value type, and any issues
## detected so debug overlays can surface actionable feedback to engineers.
static func inspect_component_dictionary(components: Dictionary) -> Dictionary:
    var report := {}
    for raw_key in components.keys():
        var normalized := _normalize_component_key(raw_key)
        var metadata := COMPONENT_KEY_METADATA.get(normalized, {})
        var value := components[raw_key]
        var entry := {
            "normalized_key": String(normalized),
            "recognized": not metadata.is_empty(),
            "value_type": type_string(typeof(value)),
            "resource_hint": metadata.get("resource", &""),
            "description": metadata.get("description", ""),
            "is_null": value == null,
        }
        if metadata.is_empty():
            entry["issue"] = "Unregistered component key"
        elif value == null:
            entry["issue"] = "Component reference is null"
        report[String(normalized)] = entry
    return report

## Runs validation across a components dictionary and returns any problems as a
## list of human-readable messages. Upstream systems can log or assert on the
## returned array to stop invalid payloads from propagating deeper into the game
## loop.
static func validate_component_dictionary(components: Dictionary) -> Array[String]:
    var issues: Array[String] = []
    for raw_key in components.keys():
        var normalized := _normalize_component_key(raw_key)
        if not COMPONENT_KEY_METADATA.has(normalized):
            issues.append("Unknown component key '%s'." % raw_key)
            continue
        if components[raw_key] == null:
            issues.append("Component '%s' is assigned a null resource." % normalized)
    return issues

static func _normalize_component_key(key: Variant) -> StringName:
    if key is StringName:
        return key
    if key is String:
        return StringName(key)
    if key == null:
        return StringName()
    return StringName(str(key))
