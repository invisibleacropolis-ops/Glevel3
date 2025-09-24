extends "res://src/systems/System.gd"
class_name StatusSystem

const ULTEnums := preload("res://src/globals/ULTEnums.gd")

## Manages lifecycle events for short- and long-term status effects using the
## canonical EntityData -> Component pipeline defined in the architectural guide.

func _ready() -> void:
    subscribe_event(&"turn_passed", Callable(self, "_on_turn_passed"))
    subscribe_event(&"day_passed", Callable(self, "_on_day_passed"))

func _on_turn_passed(_payload: Dictionary) -> void:
    _process_status_groups(true)

func _on_day_passed(_payload: Dictionary) -> void:
    _process_status_groups(false)

## Resolves timed status effects for every entity discovered through the
## canonical "entities" group, operating purely on EntityData components.
func _process_status_groups(is_short_term: bool) -> void:
    var entity_nodes := get_tree().get_nodes_in_group("entities")
    for entity_node in entity_nodes:
        var entity: Entity = entity_node as Entity
        if entity == null:
            continue

        var entity_data: EntityData = entity.entity_data
        if entity_data == null:
            continue

        if not entity_data.has_component(ULTEnums.ComponentKeys.STATUS):
            continue
        if not entity_data.has_component(ULTEnums.ComponentKeys.STATS):
            continue

        var status_component: StatusComponent = entity_data.get_component(ULTEnums.ComponentKeys.STATUS)
        var stats_component: StatsComponent = entity_data.get_component(ULTEnums.ComponentKeys.STATS)
        if status_component == null or stats_component == null:
            continue

        var entity_id := entity_data.ensure_runtime_entity_id(StringName(entity.name))
        _process_effects(entity_id, status_component, stats_component, is_short_term)

## Ticks down effect durations, removes expired entries, and emits lifecycle
## events for downstream systems.
func _process_effects(
    entity_id: StringName,
    status_component: StatusComponent,
    stats_component: StatsComponent,
    is_short_term: bool
) -> void:
    var effects: Array[StatusFX] = status_component.short_term_effects if is_short_term else status_component.long_term_effects
    if effects.is_empty():
        return

    var removal_indices: Array[int] = []
    for index in range(effects.size()):
        var effect: StatusFX = effects[index]
        if effect == null:
            removal_indices.append(index)
            continue

        if effect.duration_in_turns > 0:
            effect.duration_in_turns -= 1

        if effect.duration_in_turns <= 0:
            removal_indices.append(index)

    if removal_indices.is_empty():
        return

    for i in range(removal_indices.size() - 1, -1, -1):
        var effect_index := removal_indices[i]
        if effect_index < 0 or effect_index >= effects.size():
            continue

        var expired_effect: StatusFX = effects[effect_index]
        effects.remove_at(effect_index)

        if expired_effect == null:
            continue

        _synchronise_status_tags(stats_component, expired_effect)
        _revert_effect_modifiers(stats_component, expired_effect)
        _emit_effect_ended(entity_id, expired_effect)

    if is_short_term:
        status_component.short_term_effects = effects
    else:
        status_component.long_term_effects = effects

## Synchronises the StatsComponent's status tag arrays with the effect removal.
func _synchronise_status_tags(stats_component: StatsComponent, effect: StatusFX) -> void:
    if effect == null or effect.effect_name == StringName():
        return
    stats_component.remove_status(effect.effect_name)

## Builds and applies an inverse modifier payload so StatsComponent rolls back
## passive adjustments applied while the status effect was active.
func _revert_effect_modifiers(stats_component: StatsComponent, effect: StatusFX) -> void:
    var modifiers := effect.modifiers
    if modifiers == null or modifiers.is_empty():
        return
    stats_component.revert_modifiers(modifiers)

## Broadcasts the canonical status_effect_ended payload via the shared EventBus.
func _emit_effect_ended(entity_id: StringName, effect: StatusFX) -> void:
    var payload := {
        "entity_id": entity_id,
        "effect_name": effect.effect_name,
        "reason": &"expired",
        "modifiers": effect.modifiers,
    }
    emit_event(&"status_effect_ended", payload)
