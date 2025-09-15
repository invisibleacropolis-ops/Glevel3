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

## Returns all traits that the archetype explicitly allows.
func get_all_traits() -> Array[Trait]:
    var combined: Array[Trait] = []
    combined.append_array(required_traits)
    for trait in trait_pool:
        if trait not in combined:
            combined.append(trait)
    return combined

## Determines if a specific trait resource is compatible with the archetype.
func is_trait_allowed(trait: Trait) -> bool:
    if trait == null:
        return false
    return trait in get_all_traits()

## Validates that a trait component satisfies the archetype rules.
func validate_component(component: TraitComponent) -> bool:
    if component == null:
        return false
    for trait in required_traits:
        if not component.has_trait_id(trait.trait_id):
            return false
    for trait in component.traits:
        if not is_trait_allowed(trait):
            return false
    return true
