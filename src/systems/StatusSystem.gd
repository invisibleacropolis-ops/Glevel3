extends "res://src/systems/System.gd"
class_name StatusSystem

## Manages the duration and application of status effects on entities.
## Subscribes to turn_passed and day_passed events to update effect timers.

func _ready() -> void:
    subscribe_event(&"turn_passed", Callable(self, "_on_turn_passed"))
    subscribe_event(&"day_passed", Callable(self, "_on_day_passed"))

func _on_turn_passed(payload: Dictionary) -> void:
    # TODO: Implement a way to get all entities in the game world.
    # For example, if you have a global EntityManager, you might call:
    # var entities = EntityManager.get_all_entities()
    var entities: Array = get_tree().get_nodes_in_group("entities") # Placeholder: Assuming entities are in a group named "entities"

    for entity in entities:
        if not entity.has_node("StatusComponent") or not entity.has_node("StatsComponent"):
            continue

        var status_component: StatusComponent = entity.get_node("StatusComponent")
        var stats_component: StatsComponent = entity.get_node("StatsComponent")

        _process_effects(entity, stats_component, status_component.short_term_effects, stats_component.short_term_statuses, true)

func _on_day_passed(payload: Dictionary) -> void:
    # TODO: Implement a way to get all entities in the game world.
    # For example, if you have a global EntityManager, you might call:
    # var entities = EntityManager.get_all_entities()
    var entities: Array = get_tree().get_nodes_in_group("entities") # Placeholder: Assuming entities are in a group named "entities"

    for entity in entities:
        if not entity.has_node("StatusComponent") or not entity.has_node("StatsComponent"):
            continue

        var status_component: StatusComponent = entity.get_node("StatusComponent")
        var stats_component: StatsComponent = entity.get_node("StatsComponent")

        _process_effects(entity, stats_component, status_component.long_term_effects, stats_component.long_term_statuses, false)

func _process_effects(entity: Node, stats_component: StatsComponent, effects_array: Array[StatusFX], status_names_array: Array[StringName], is_short_term: bool) -> void:
    var effects_to_remove: Array[StatusFX] = []

    for effect in effects_array:
        if effect.duration_in_turns > 0:
            effect.duration_in_turns -= 1
        
        if effect.duration_in_turns <= 0:
            effects_to_remove.append(effect)

    for effect in effects_to_remove:
        effects_array.erase(effect)
        # Also remove from StatsComponent's list of status names
        if effect.effect_name in status_names_array:
            status_names_array.erase(effect.effect_name)

        # Revert modifiers
        var inverted_modifiers: Dictionary = {}
        for key in effect.modifiers.keys():
            var value = effect.modifiers[key]
            if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
                inverted_modifiers[key] = -value
            # TODO: Handle other types of modifiers if they are not simple numeric changes
            # For example, if a modifier adds a trait, you'd need to remove it here.

        if not inverted_modifiers.is_empty():
            stats_component.apply_stat_mod(inverted_modifiers)

        # Emit an event that the status effect has ended
        emit_event(&"status_effect_ended", {
            "entity_id": entity.name, # Assuming entity.name is a unique identifier
            "effect_name": effect.effect_name,
            "reason": &"expired",
            "modifiers": effect.modifiers # Provide the original modifiers for context
        })


# TODO: Consider how new status effects are added.
# When a new status effect is added to an entity, ensure:
# 1. The StatusFX resource is duplicated before being added to StatusComponent.short_term_effects or long_term_effects.
# 2. The effect.effect_name is added to StatsComponent.short_term_statuses or long_term_statuses.
# This synchronization is crucial for the system to work correctly.
