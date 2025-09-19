extends "res://src/core/Component.gd"
class_name StatusComponent

## Holds and manages the short-term and long-term status effects applied to an entity.

@export var short_term_effects: Array[StatusFX] = []
@export var long_term_effects: Array[StatusFX] = []

## Adds a status effect to the appropriate list if it is not already present.
func add_effect(effect: StatusFX, is_long_term: bool = false) -> void:
    if effect == null:
        push_warning("Attempted to add a null status effect.")
        return

    var target_array = long_term_effects if is_long_term else short_term_effects

    if effect in target_array:
        # TODO: Add logic to refresh duration if effects can be re-applied
        return

    target_array.append(effect.duplicate())

## Removes a status effect from both short and long term lists.
func remove_effect(effect_to_remove: StatusFX) -> void:
    if effect_to_remove == null:
        return

    if effect_to_remove in short_term_effects:
        short_term_effects.erase(effect_to_remove)

    if effect_to_remove in long_term_effects:
        long_term_effects.erase(effect_to_remove)

## A helper to remove an effect by its name.
func remove_effect_by_name(effect_name: StringName) -> void:
    if effect_name == &"":
        return

    for i in range(short_term_effects.size() - 1, -1, -1):
        if short_term_effects[i].effect_name == effect_name:
            short_term_effects.remove_at(i)

    for i in range(long_term_effects.size() - 1, -1, -1):
        if long_term_effects[i].effect_name == effect_name:
            long_term_effects.remove_at(i)
