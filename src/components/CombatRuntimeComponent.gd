extends "res://src/core/Component.gd"
class_name CombatRuntimeComponent

## Runtime combat state for a single entity. Tracks initiative roll bonuses and
## temporary modifiers applied by statuses or abilities so combat systems can
## reconstruct the current turn order without querying scene nodes.

## Baseline initiative bonus applied each time the entity enters combat.
@export var base_initiative_bonus: int = 0

## Initiative score for the current encounter after modifiers have been applied.
@export var current_initiative: int = 0

## Active initiative modifiers awaiting expiration. Each entry stores:
## { "amount": int, "remaining_turns": int, "source_id": StringName }
@export var initiative_modifiers: Array[Dictionary] = []

## Resets transient combat state when starting a new encounter. Clears all
## modifiers and restores the current initiative to the base bonus value.
func reset_for_new_encounter() -> void:
    initiative_modifiers.clear()
    current_initiative = base_initiative_bonus

## Applies a temporary modifier to the initiative score for a fixed duration.
## The modifier immediately affects the current initiative total.
func apply_initiative_modifier(amount: int, duration: int, source: StringName) -> void:
    var modifier := {
        "amount": amount,
        "remaining_turns": max(duration, 0),
        "source_id": source,
    }
    initiative_modifiers.append(modifier)
    current_initiative += amount

## Advances modifier timers by one turn. Any modifier whose remaining duration
## reaches zero is removed and its amount returned as part of the net bonus
## stripped from the entity. The current initiative is reduced by the total.
func tick_initiative_modifiers() -> int:
    var expired_total := 0
    var active_modifiers: Array[Dictionary] = []
    for modifier in initiative_modifiers:
        var remaining: int = int(modifier.get("remaining_turns", 0))
        remaining -= 1
        modifier["remaining_turns"] = remaining
        if remaining > 0:
            active_modifiers.append(modifier)
        else:
            expired_total += int(modifier.get("amount", 0))
    initiative_modifiers = active_modifiers
    if expired_total != 0:
        current_initiative -= expired_total
    return expired_total
