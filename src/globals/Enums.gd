extends Object
class_name Enums

## Central repository for engine-wide enumerations and key constants.
## Maintains canonical identifiers for component dictionaries and entity taxonomies.

## High-level entity classifications used to segment systems.
enum EntityType {
    PLAYER,
    NPC,
    MONSTER,
    WILDLIFE,
    OBJECT,
}

## Namespace describing the canonical dictionary keys for component manifests.
class ComponentKeys:
    const STATS := StringName("stats")
    const STATUS := StringName("status")
    const SKILLS := StringName("skills")
    const TRAITS := StringName("traits")
    const INVENTORY := StringName("inventory")
    const AI_BEHAVIOR := StringName("ai_behavior")
    const FACTION := StringName("faction")
    const QUEST_STATE := StringName("quest_state")

    ## Enumerates every supported component key as StringNames for quick validation.
    static func values() -> Array[StringName]:
        return [
            STATS,
            STATUS,
            SKILLS,
            TRAITS,
            INVENTORY,
            AI_BEHAVIOR,
            FACTION,
            QUEST_STATE,
        ]

## Convenience helper to test if a StringName matches a registered component key.
static func is_valid_component_key(key: StringName) -> bool:
    return ComponentKeys.values().has(key)
