extends "res://src/core/Component.gd"
class_name SkillComponent

## Canonical skill manifest describing every combat or utility action exposed by an entity.
## The InteractionManager (scheduled for implementation in future sprints) will consume this
## data contract to construct contextual action menus, evaluate upgrade availability, and
## resolve equipment gating. The component follows the project mandate that Resources act as
## typed containers wrapping other resources so designers can mix and match data blocks in the
## editor without touching script logic.
##
## Skills are organised hierarchically by combat Type (Melee, Ranged, Defense, Utility), then
## by Rarity (Basic, Common, Unique, Legendary), followed by Upgrade Level and Trait tags. Each
## combination yields one or more concrete actions that the InteractionManager may present to
## the player. Arrays store the terminal action identifiers so systems can duplicate and mutate
## selections safely at runtime.
## Designed for Godot 4.4.1.

## Enumerates the canonical high-level categories so helper methods can normalise lookups and
## editor tooling may populate drop-downs without hard-coded strings scattered around the
## project.
const SKILL_TYPES: PackedStringArray = [
    &"melee",
    &"ranged",
    &"defense",
    &"utility",
]

## Enumerates supported rarity bands for diagnostic messaging and authoring hints. Designers
## can still add custom rarity identifiers in exported dictionaries when prototyping new
## progressions; this constant simply documents the primary expectations used across docs.
const SKILL_RARITIES: PackedStringArray = [
    &"basic",
    &"common",
    &"unique",
    &"legendary",
]

@export_group("Skill Catalog")
@export_subgroup("Hierarchical Organisation")
## Hierarchical catalog describing every skill action available to the entity.
## Keys follow the structure:
##   skill_catalog[type][rarity][upgrade_level][trait] -> Array[StringName] of action IDs
## * type: high-level combat categories such as "melee", "ranged", "defense", or "utility".
## * rarity: acquisition band such as "basic", "common", "unique", or "legendary".
## * upgrade_level: identifiers such as &"base", &"branch_a_rank_1", etc.
## * trait: modifiers describing the mechanical twist applied at the current upgrade tier.
## Each terminal Array should contain StringName identifiers for concrete actions or
## SkillAction resources registered in the asset database.
@export var skill_catalog: Dictionary[StringName, Dictionary] = {}

@export_subgroup("Resource Buckets")
## Typed containers mapping each combat type to a list of Skill resources owned by the entity.
## The arrays typically hold custom Resource instances (e.g., SkillDefinition or SkillAction),
## but the component does not enforce a specific class so designers may iterate quickly using
## placeholder data. Systems should duplicate returned arrays before mutation.
@export var skill_resources: Dictionary[StringName, Array] = {}

@export_group("Loadout State")
## Mapping of combat type to the identifiers of currently equipped skill actions. Each Array
## entry should reference a StringName stored somewhere within ``skill_catalog``. Interaction
## systems will clamp the size of each Array based on runtime rules (equipment, buffs, etc.).
@export var equipped_actions: Dictionary[StringName, Array[StringName]] = {}

## Mapping of combat type to reserve or sideboard actions owned by the entity but not currently
## equipped. Designers can seed this with the full library unlocked by Jobs, while runtime
## systems migrate actions between ``equipped_actions`` and ``reserve_actions`` as the player
## reconfigures their deck.
@export var reserve_actions: Dictionary[StringName, Array[StringName]] = {}

## Tracks the latest upgrade tier chosen for each skill identifier. Keys should match entries
## in ``equipped_actions`` or ``reserve_actions`` while values store tokens such as
## &"base", &"rank_1_a", &"rank_2_b", etc. Godot 4.4.1 lacks nested typed dictionaries, so we
## rely on the ``duplicate(true)`` defensive copy helper when serialising state.
@export var upgrade_progress: Dictionary[StringName, StringName] = {}

@export_group("Constraints")
## Declares how many actions of each combat type may be simultaneously equipped. Designers can
## override defaults per entity by exporting dictionary entries such as ``{"melee": 4}``. When
## absent, Interaction systems should fall back to their internal defaults.
@export var max_active_actions: Dictionary[StringName, int] = {}


func register_skill_action(
    skill_type: StringName,
    rarity: StringName,
    upgrade_level: StringName,
    trait_id: StringName,
    action_id: StringName
) -> void:
    """Registers an action identifier inside the hierarchical catalog.

    The helper guarantees that every intermediate dictionary exists and that the final array
    contains unique identifiers. It intentionally stores StringName tokens instead of resource
    references so save games and remote procedure calls can serialise the manifest without
    touching disk-backed assets.
    """
    if String(action_id).is_empty():
        push_warning("SkillComponent.register_skill_action received an empty action identifier.")
        return

    var type_key := _normalise_string_name(skill_type)
    var rarity_key := _normalise_string_name(rarity)
    var level_key := _normalise_string_name(upgrade_level)
    var trait_key := _normalise_string_name(trait_id)

    var rarity_map: Dictionary = skill_catalog.get(type_key, {})
    var level_map: Dictionary = rarity_map.get(rarity_key, {})
    var trait_map: Dictionary = level_map.get(level_key, {})
    var actions: Array = trait_map.get(trait_key, [])

    var normalized_action := _normalise_string_name(action_id)
    if normalized_action in actions:
        return

    actions.append(normalized_action)
    trait_map[trait_key] = actions
    level_map[level_key] = trait_map
    rarity_map[rarity_key] = level_map
    skill_catalog[type_key] = rarity_map


func register_skill_resource(skill_type: StringName, skill_resource) -> void:
    """Adds a Skill resource reference to the ``skill_resources`` bucket for the type.

    The container stores plain arrays to stay compatible with both bespoke Skill resource
    classes and temporary prototypes authored with generic Resources. Null entries are rejected
    and duplicates ignored so Interaction systems can rely on stable ordering.
    """
    if skill_resource == null:
        push_warning("SkillComponent.register_skill_resource attempted to register a null resource.")
        return

    var type_key := _normalise_string_name(skill_type)
    var resources: Array = skill_resources.get(type_key, [])
    if skill_resource in resources:
        return
    resources.append(skill_resource)
    skill_resources[type_key] = resources


func get_skill_actions(
    skill_type: StringName,
    rarity: StringName,
    upgrade_level: StringName,
    trait_id: StringName
) -> Array[StringName]:
    """Returns a defensive copy of the action identifiers for the requested slot."""
    var type_key := _normalise_string_name(skill_type)
    if not skill_catalog.has(type_key):
        return []
    var rarity_key := _normalise_string_name(rarity)
    var rarity_map: Dictionary = skill_catalog[type_key]
    if not rarity_map.has(rarity_key):
        return []
    var level_key := _normalise_string_name(upgrade_level)
    var level_map: Dictionary = rarity_map[rarity_key]
    if not level_map.has(level_key):
        return []
    var trait_key := _normalise_string_name(trait_id)
    var trait_map: Dictionary = level_map[level_key]
    if not trait_map.has(trait_key):
        return []
    var actions: Array = trait_map[trait_key]
    return actions.duplicate()


func get_equipped_actions(skill_type: StringName) -> Array[StringName]:
    """Returns the currently equipped actions for the requested combat type."""
    var type_key := _normalise_string_name(skill_type)
    if not equipped_actions.has(type_key):
        return []
    var actions: Array = equipped_actions[type_key]
    return actions.duplicate()


func get_reserve_actions(skill_type: StringName) -> Array[StringName]:
    """Returns the reserve actions for the requested combat type."""
    var type_key := _normalise_string_name(skill_type)
    if not reserve_actions.has(type_key):
        return []
    var actions: Array = reserve_actions[type_key]
    return actions.duplicate()


func list_known_skill_types() -> PackedStringArray:
    """Returns every skill type currently represented in the catalog or loadouts."""
    var types := PackedStringArray()
    for entry in skill_catalog.keys():
        types.append(String(entry))
    for entry in equipped_actions.keys():
        var name := String(entry)
        if not types.has(name):
            types.append(name)
    for entry in reserve_actions.keys():
        var name := String(entry)
        if not types.has(name):
            types.append(name)
    return types


func to_dictionary() -> Dictionary:
    """Returns a deep copy of the component payload for serialization or debugging."""
    var catalog_copy: Dictionary[StringName, Dictionary] = {}
    for type_key in skill_catalog.keys():
        var rarity_map: Dictionary = skill_catalog[type_key]
        var rarity_copy: Dictionary[StringName, Dictionary] = {}
        for rarity_key in rarity_map.keys():
            var level_map: Dictionary = rarity_map[rarity_key]
            var level_copy: Dictionary[StringName, Dictionary] = {}
            for level_key in level_map.keys():
                var trait_map: Dictionary = level_map[level_key]
                var trait_copy: Dictionary[StringName, Array] = {}
                for trait_key in trait_map.keys():
                    var actions: Array = trait_map[trait_key]
                    trait_copy[trait_key] = actions.duplicate()
                level_copy[level_key] = trait_copy
            rarity_copy[rarity_key] = level_copy
        catalog_copy[type_key] = rarity_copy

    var resource_copy: Dictionary[StringName, Array] = {}
    for type_key in skill_resources.keys():
        var resources: Array = skill_resources[type_key]
        resource_copy[type_key] = resources.duplicate()

    var equipped_copy: Dictionary[StringName, Array] = {}
    for type_key in equipped_actions.keys():
        var actions: Array = equipped_actions[type_key]
        equipped_copy[type_key] = actions.duplicate()

    var reserve_copy: Dictionary[StringName, Array] = {}
    for type_key in reserve_actions.keys():
        var actions: Array = reserve_actions[type_key]
        reserve_copy[type_key] = actions.duplicate()

    return {
        "skill_catalog": catalog_copy,
        "skill_resources": resource_copy,
        "equipped_actions": equipped_copy,
        "reserve_actions": reserve_copy,
        "upgrade_progress": upgrade_progress.duplicate(true),
        "max_active_actions": max_active_actions.duplicate(true),
    }


func _normalise_string_name(value: StringName) -> StringName:
    """Converts incoming identifiers to trimmed ``StringName`` tokens."""
    var as_string := String(value).strip_edges()
    return StringName(as_string) if not as_string.is_empty() else StringName("")
