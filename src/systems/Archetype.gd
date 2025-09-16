extends Resource
class_name Archetype

## Resource describing an entity archetype used by procedural generation.
## Archetypes define base stats and the trait pool compatible with the entity.
## Instances are saved as ``Archetype.tres`` files and consumed during the
## "Archetype Selection" phase to seed generators with safe trait combinations.
## Designed for Godot 4.4.1.

@export var archetype_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var base_stats: Dictionary = {}
@export var required_traits: Array[Trait] = []
@export var trait_pool: Array[Trait] = []

## Returns all traits that the archetype explicitly allows. Required traits are
## always positioned ahead of optional entries while duplicates (matched by
## ``trait_id``) are removed to keep the payload stable for downstream systems.
func get_all_traits() -> Array[Trait]:
    var combined: Array[Trait] = []
    var seen_ids: Dictionary = {}
    _append_unique_traits(combined, required_traits, seen_ids)
    _append_unique_traits(combined, trait_pool, seen_ids)
    return combined

## Determines if a specific trait resource is compatible with the archetype.
## Invalid inputs (``null`` or missing identifiers) are rejected before
## searching the combined list to avoid nil dereferences in consuming systems.
func is_trait_allowed(trait: Trait) -> bool:
    if not _is_trait_resource_valid(trait):
        return false
    var allowed_traits: Array[Trait] = get_all_traits()
    var index := 0
    while index < allowed_traits.size():
        if allowed_traits[index].trait_id == trait.trait_id:
            return true
        index += 1
    return false

## Validates that a trait component satisfies the archetype rules. The
## component must expose all required trait identifiers and may not advertise
## traits outside of the archetype's combined pool. Any null or malformed
## entries are rejected to maintain the integrity of entity data resources.
func validate_component(component: TraitComponent) -> bool:
    if component == null:
        return false

    var allowed_traits: Array[Trait] = get_all_traits()
    var allowed_trait_ids: Dictionary = _collect_trait_id_lookup(allowed_traits)

    var index := 0
    while index < required_traits.size():
        var required_trait: Trait = required_traits[index]
        if _is_trait_resource_valid(required_trait):
            if not component.has_trait_id(required_trait.trait_id):
                return false
        else:
            return false
        index += 1

    index = 0
    while index < component.traits.size():
        var trait: Trait = component.traits[index]
        if not _is_trait_resource_valid(trait):
            return false
        if not allowed_trait_ids.has(trait.trait_id):
            return false
        index += 1

    return true

## Helper that copies valid, non-duplicate traits from ``source`` into
## ``target`` while preserving order. ``seen_ids`` tracks identifiers already
## appended to the target array so optional traits do not overwrite required
## selections.
func _append_unique_traits(target: Array[Trait], source: Array[Trait], seen_ids: Dictionary) -> void:
    var index := 0
    while index < source.size():
        var trait: Trait = source[index]
        if _is_trait_resource_valid(trait):
            var trait_id := trait.trait_id
            if not seen_ids.has(trait_id):
                target.append(trait)
                seen_ids[trait_id] = true
        index += 1

## Builds a dictionary keyed by ``trait_id`` for fast membership checks against
## the archetype's combined trait list.
func _collect_trait_id_lookup(traits: Array[Trait]) -> Dictionary:
    var lookup: Dictionary = {}
    var index := 0
    while index < traits.size():
        lookup[traits[index].trait_id] = true
        index += 1
    return lookup

## Returns ``true`` when the provided resource is a valid trait definition.
func _is_trait_resource_valid(trait: Trait) -> bool:
    return trait != null and trait.trait_id != ""
