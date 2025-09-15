extends "res://src/core/Component.gd"
class_name TraitComponent

## Component holding a list of Trait resources assigned to an entity.
## Traits act as passive modifiers, behavioural flags, or narrative tags.
## The default ``TraitComponent.tres`` asset demonstrates wiring to ``Trait.tres``
## resources that power AI and narrative logic.
## Designed for Godot 4.4.1.

@export var traits: Array[Trait] = []

## Adds a trait resource if it is not already registered by identifier.
func add_trait(trait: Trait) -> void:
    if trait == null:
        push_warning("Attempted to add a null trait resource.")
        return
    if not has_trait_id(trait.trait_id):
        traits.append(trait)

## Removes the first trait that matches the requested identifier.
func remove_trait(trait_id: String) -> void:
    for index in range(traits.size()):
        if traits[index].trait_id == trait_id:
            traits.remove_at(index)
            return

## Returns ``true`` when the component currently exposes the id.
func has_trait_id(trait_id: String) -> bool:
    for trait in traits:
        if trait.trait_id == trait_id:
            return true
    return false

## Helper returning a stable copy of all registered trait identifiers.
func get_trait_ids() -> PackedStringArray:
    var ids: PackedStringArray = []
    for trait in traits:
        if trait.trait_id != "":
            ids.append(trait.trait_id)
    return ids
