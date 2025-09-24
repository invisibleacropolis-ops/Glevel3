extends "res://src/core/Component.gd"
class_name StatusComponent

## Holds and manages the short-term and long-term status effects applied to an entity.

@export var short_term_effects: Array[StatusFX] = []
@export var long_term_effects: Array[StatusFX] = []

## Adds a status effect to the appropriate list if it is not already present.
##
## Returns the stored ``StatusFX`` instance so callers can mutate the runtime
## copy (e.g., overriding duration) without touching the source asset. The
## component duplicates the resource before insertion so each entity tracks its
## own timers and modifier bundles independently.
func add_effect(effect: StatusFX, is_long_term: bool = false) -> StatusFX:
    if effect == null:
        push_warning("Attempted to add a null status effect.")
        return null

    var target_array: Array[StatusFX] = long_term_effects if is_long_term else short_term_effects
    var effect_name := effect.effect_name

    var existing_index := _find_effect_index(effect_name, target_array)
    if existing_index != -1:
        return target_array[existing_index]

    var stored_effect: StatusFX = effect.duplicate(true)
    target_array.append(stored_effect)

    if is_long_term:
        long_term_effects = target_array
    else:
        short_term_effects = target_array

    return stored_effect

## Removes a status effect from both short and long term lists.
func remove_effect(effect_to_remove: StatusFX) -> void:
    if effect_to_remove == null:
        return

    var short_term := short_term_effects
    var long_term := long_term_effects

    _erase_effect_instance(effect_to_remove, short_term)
    _erase_effect_instance(effect_to_remove, long_term)

    short_term_effects = short_term
    long_term_effects = long_term

## A helper to remove an effect by its name.
func remove_effect_by_name(effect_name: StringName) -> void:
    if effect_name == &"":
        return

    var short_term := short_term_effects
    var long_term := long_term_effects

    _erase_effect_by_name(effect_name, short_term)
    _erase_effect_by_name(effect_name, long_term)

    short_term_effects = short_term
    long_term_effects = long_term


func _find_effect_index(effect_name: StringName, pool: Array[StatusFX]) -> int:
    if effect_name == StringName():
        return -1
    for index in range(pool.size()):
        var candidate: StatusFX = pool[index]
        if candidate != null and candidate.effect_name == effect_name:
            return index
    return -1


func _erase_effect_instance(effect: StatusFX, pool: Array[StatusFX]) -> void:
    if effect == null:
        return
    var index := pool.find(effect)
    if index != -1:
        pool.remove_at(index)
        return
    _erase_effect_by_name(effect.effect_name, pool)


func _erase_effect_by_name(effect_name: StringName, pool: Array[StatusFX]) -> void:
    if effect_name == StringName():
        return
    for i in range(pool.size() - 1, -1, -1):
        var candidate: StatusFX = pool[i]
        if candidate != null and candidate.effect_name == effect_name:
            pool.remove_at(i)
