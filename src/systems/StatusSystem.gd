extends "res://src/systems/System.gd"
class_name StatusSystem

const ULTEnums := preload("res://src/globals/ULTEnums.gd")

## Manages lifecycle events for short- and long-term status effects using the
## canonical EntityData -> Component pipeline defined in the architectural guide.

func _ready() -> void:
    subscribe_event(&"turn_passed", Callable(self, "_on_turn_passed"))
    subscribe_event(&"day_passed", Callable(self, "_on_day_passed"))

## Public entry point used by combat, narrative, or item systems to apply a
## status effect to an entity's component manifest. The caller provides the
## owning ``EntityData`` resource, the status definition to apply, and an
## optional dictionary of context values:
##
## ``{ "is_long_term": bool, "duration": int, "source_id": StringName,
##     "metadata": Dictionary }``
##
## The system duplicates the supplied ``StatusFX`` so every entity tracks its
## own timer, updates the StatsComponent tags, applies passive modifiers, and
## emits the canonical ``status_effect_applied`` EventBus payload.
func apply_status_effect(
    entity_data: EntityData,
    effect: StatusFX,
    options: Dictionary = {}
) -> void:
    if entity_data == null:
        push_warning("StatusSystem.apply_status_effect requires EntityData.")
        return
    if effect == null:
        push_warning("StatusSystem.apply_status_effect requires a StatusFX resource.")
        return

    var normalized_name := effect.effect_name
    if normalized_name == StringName():
        push_warning("StatusSystem.apply_status_effect requires effect_name to be set on the StatusFX resource.")
        return

    if not entity_data.has_component(ULTEnums.ComponentKeys.STATUS):
        push_warning("StatusSystem.apply_status_effect called on entity missing StatusComponent.")
        return
    if not entity_data.has_component(ULTEnums.ComponentKeys.STATS):
        push_warning("StatusSystem.apply_status_effect called on entity missing StatsComponent.")
        return

    var status_component: StatusComponent = entity_data.get_component(ULTEnums.ComponentKeys.STATUS)
    var stats_component: StatsComponent = entity_data.get_component(ULTEnums.ComponentKeys.STATS)
    if status_component == null or stats_component == null:
        push_warning("StatusSystem.apply_status_effect could not resolve required components.")
        return

    var entity_id := entity_data.ensure_runtime_entity_id(StringName(entity_data.entity_id))
    var is_long_term := bool(options.get("is_long_term", false))

    var stored_effect := status_component.add_effect(effect, is_long_term)
    if stored_effect == null:
        return

    var duration_variant: Variant = options.get("duration")
    if duration_variant != null and (typeof(duration_variant) == TYPE_INT or typeof(duration_variant) == TYPE_FLOAT):
        stored_effect.duration_in_turns = int(duration_variant)

    stats_component.add_status(stored_effect.effect_name, is_long_term)

    var modifiers: Dictionary = stored_effect.modifiers
    if stored_effect.is_passive and modifiers != null and not modifiers.is_empty():
        stats_component.apply_modifiers(modifiers)

    var source_id_variant: Variant = options.get("source_id")
    var source_id := StringName()
    if typeof(source_id_variant) == TYPE_STRING or typeof(source_id_variant) == TYPE_STRING_NAME:
        source_id = StringName(source_id_variant)

    var metadata_variant: Variant = options.get("metadata")
    var metadata: Dictionary = {}
    if metadata_variant is Dictionary:
        metadata = (metadata_variant as Dictionary).duplicate(true)

    metadata["is_long_term"] = is_long_term
    metadata["is_passive"] = stored_effect.is_passive
    metadata["duration_scope"] = &"days" if is_long_term else &"turns"
    if modifiers != null and not modifiers.is_empty():
        metadata["modifiers"] = modifiers.duplicate(true)

    _emit_effect_applied(entity_id, stored_effect, source_id, metadata)

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
        _emit_effect_ended(entity_id, expired_effect, not is_short_term)

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
    if effect == null or not effect.is_passive:
        return
    var modifiers := effect.modifiers
    if modifiers == null or modifiers.is_empty():
        return
    stats_component.revert_modifiers(modifiers)

## Broadcasts the canonical status_effect_ended payload via the shared EventBus.
func _emit_effect_applied(
    entity_id: StringName,
    effect: StatusFX,
    source_id: StringName,
    metadata: Dictionary
) -> void:
    var payload := {
        "entity_id": entity_id,
        "effect_name": effect.effect_name,
    }
    if effect.duration_in_turns > 0:
        payload["duration"] = effect.duration_in_turns
    if source_id != StringName():
        payload["source_id"] = source_id
    if not metadata.is_empty():
        payload["metadata"] = metadata
    emit_event(&"status_effect_applied", payload)


func _emit_effect_ended(entity_id: StringName, effect: StatusFX, is_long_term: bool) -> void:
    var reason := &"expired_turn"
    if is_long_term:
        reason = &"expired_day"
    var payload := {
        "entity_id": entity_id,
        "effect_name": effect.effect_name,
        "reason": reason,
    }
    if effect.modifiers is Dictionary and not (effect.modifiers as Dictionary).is_empty():
        payload["modifiers"] = (effect.modifiers as Dictionary).duplicate(true)
    emit_event(&"status_effect_ended", payload)
