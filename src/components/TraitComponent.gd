extends "res://src/core/Component.gd"
class_name TraitComponent

## Component holding a list of Trait resources assigned to an entity.
## Traits act as passive modifiers, behavioural flags, or narrative tags.
## The default ``TraitComponent.tres`` asset demonstrates wiring to ``Trait.tres``
## resources that power AI and narrative logic.
## Designed for Godot 4.4.1.

@export var traits: Array = []

## Adds a trait resource if it is not already registered by identifier.
func add_trait(trait_resource) -> void:
    if trait_resource == null:
        push_warning("Attempted to add a null trait resource.")
        return
    if not has_trait_id(_get_trait_id(trait_resource)):
        traits.append(trait_resource)

## Removes the first trait that matches the requested identifier.
func remove_trait(trait_id: String) -> void:
    for index in range(traits.size()):
        var entry = traits[index]
        if _get_trait_id(entry) == trait_id:
            traits.remove_at(index)
            return

## Returns ``true`` when the component currently exposes the id.
func has_trait_id(trait_id: String) -> bool:
    for entry in traits:
        if _get_trait_id(entry) == trait_id:
            return true
    return false

## Helper returning a stable copy of all registered trait identifiers.
func get_trait_ids() -> PackedStringArray:
    var ids: PackedStringArray = []
    for entry in traits:
        var id := _get_trait_id(entry)
        if id != "":
            ids.append(id)
    return ids

func _get_trait_id(trait_resource) -> String:
    if trait_resource == null:
        return ""
    var raw_id = trait_resource.get("trait_id") if trait_resource.has_method("get") else null
    if raw_id == null:
        return ""
    var id_string := String(raw_id)
    return id_string if not id_string.is_empty() else ""
