extends System
class_name Test_CombatSystem
"""Temporary combat harness used to validate SystemTriggerPanel interactions.

This utility lives only inside the testbed scene. It mirrors the API shape
expected from the real CombatSystem so UI engineers can bind buttons and confirm
payloads before the production gameplay logic exists.
"""

const UNKNOWN_TARGET_LABEL := "[unknown]"
const UNKNOWN_EFFECT_LABEL := "UnknownEffect"
const ENTITY_SCRIPT := preload("res://src/entities/Entity.gd")
const ENTITY_DATA_SCRIPT := preload("res://src/core/EntityData.gd")
const STATS_COMPONENT_SCRIPT := preload("res://src/components/StatsComponent.gd")
const ULTENUMS := preload("res://src/globals/ULTEnums.gd")

func _describe_target(target: Node) -> String:
    """Returns a human readable description of the supplied target."""
    if not is_instance_valid(target):
        return "[null]"
    var path := "(unknown path)"
    if target.is_inside_tree():
        path = str(target.get_path())
    var entity_id := String(_resolve_entity_identifier(target))
    return "%s {entity_id=%s, path=%s, instance=%d}" % [
        target.name,
        entity_id,
        path,
        target.get_instance_id(),
    ]

func attack_target(target: Node, amount: int, damage_type: String) -> void:
    """Logs and emits an attack event so the EventBus log captures the interaction."""
    var clamped_amount: int = int(max(amount, 0))
    var target_label := _describe_target(target)
    print("[Test_CombatSystem] attack_target -> target=%s, amount=%d, type=%s" % [target_label, clamped_amount, damage_type])

    _apply_damage_to_target(target, clamped_amount)

    emit_event(&"entity_damaged", {
        "entity_id": _resolve_entity_identifier(target),
        "amount": clamped_amount,
        "damage_type": StringName(damage_type),
        "source_id": StringName(name),
    })

func apply_damage(target: Node, amount: int, damage_type: String) -> void:
    """Legacy shim that proxies to attack_target for backwards compatibility."""
    attack_target(target, amount, damage_type)

func assign_status_effect(target: Node, effect_name: String, duration: int) -> void:
    """Logs and emits a status effect assignment event through the EventBus."""
    var sanitized_name: String = effect_name.strip_edges()
    if sanitized_name.is_empty():
        sanitized_name = UNKNOWN_EFFECT_LABEL
    var clamped_duration: int = int(max(duration, 1))
    var target_label := _describe_target(target)
    print("[Test_CombatSystem] assign_status_effect -> target=%s, effect=%s, duration=%d" % [
        target_label,
        sanitized_name,
        clamped_duration,
    ])

    _apply_status_effect(target, sanitized_name, clamped_duration)

    emit_event(&"status_effect_applied", {
        "entity_id": _resolve_entity_identifier(target),
        "effect_name": StringName(sanitized_name),
        "duration": clamped_duration,
        "source_id": StringName(name),
    })

func kill_target(target: Node) -> void:
    """Logs and emits a kill event so downstream systems can respond."""
    var target_label := _describe_target(target)
    print("[Test_CombatSystem] kill_target -> target=%s" % target_label)

    _apply_kill_effect(target)

    emit_event(&"entity_killed", {
        "entity_id": _resolve_entity_identifier(target),
        "killer_id": StringName(name),
    })

func _resolve_entity_identifier(target: Node) -> StringName:
    if not is_instance_valid(target):
        return StringName(UNKNOWN_TARGET_LABEL)

    if target.has_method("get_entity_id"):
        var via_method: Variant = target.call("get_entity_id")
        if typeof(via_method) == TYPE_STRING or typeof(via_method) == TYPE_STRING_NAME:
            return StringName(via_method)

    if target.has_meta("entity_id"):
        var via_meta: Variant = target.get_meta("entity_id")
        if typeof(via_meta) == TYPE_STRING or typeof(via_meta) == TYPE_STRING_NAME:
            return StringName(via_meta)

    var via_property: Variant = target.get("entity_id")
    if typeof(via_property) == TYPE_STRING or typeof(via_property) == TYPE_STRING_NAME:
        return StringName(via_property)

    return StringName(target.name)

func _apply_damage_to_target(target: Node, amount: int) -> void:
    if amount <= 0:
        return
    var stats := _extract_stats_component(target)
    if stats == null:
        push_warning("Test_CombatSystem could not locate StatsComponent when damaging %s." % _describe_target(target))
        return
    stats.apply_damage(amount)

func _apply_status_effect(target: Node, effect_name: String, _duration: int) -> void:
    var stats := _extract_stats_component(target)
    if stats == null:
        push_warning("Test_CombatSystem could not locate StatsComponent when assigning %s to %s." % [effect_name, _describe_target(target)])
        return
    stats.add_status(StringName(effect_name))

func _apply_kill_effect(target: Node) -> void:
    var stats := _extract_stats_component(target)
    if stats == null:
        push_warning("Test_CombatSystem could not locate StatsComponent when killing %s." % _describe_target(target))
        return
    if stats.health > 0:
        stats.apply_damage(stats.health)

func _extract_stats_component(target: Node) -> STATS_COMPONENT_SCRIPT:
    var data := _extract_entity_data(target)
    if data == null:
        return null
    var component := data.get_component(ULTENUMS.ComponentKeys.STATS)
    if component is STATS_COMPONENT_SCRIPT:
        return component as STATS_COMPONENT_SCRIPT
    return null

func _extract_entity_data(target: Node) -> ENTITY_DATA_SCRIPT:
    if not is_instance_valid(target):
        return null
    if target is ENTITY_SCRIPT:
        var entity := target as ENTITY_SCRIPT
        if entity.entity_data is ENTITY_DATA_SCRIPT:
            return entity.entity_data
    var via_property: Variant = target.get("entity_data")
    if via_property is ENTITY_DATA_SCRIPT:
        return via_property
    if target.has_method("get_entity_data"):
        var via_method: Variant = target.call("get_entity_data")
        if via_method is ENTITY_DATA_SCRIPT:
            return via_method
    if target.has_meta("entity_data"):
        var via_meta: Variant = target.get_meta("entity_data")
        if via_meta is ENTITY_DATA_SCRIPT:
            return via_meta
    return null
