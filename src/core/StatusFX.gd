extends Resource
class_name StatusFX

## Data resource for a single status effect (e.g., Poisoned, Hasted).

@export_group("Identity")
@export var effect_name: StringName = &""
@export var description: String = ""

@export_group("Mechanics")
## A passive modifier is applied once and its effects persist for the duration.
## An active trigger can cause an action or emit a signal on certain events.
@export var is_passive: bool = true
@export var is_active_trigger: bool = false

## For passive effects, this dictionary defines the stat changes.
## Example: {"speed": -2, "damage_over_time": 5}
@export var modifiers: Dictionary = {}

## For active triggers, this is the EventBus signal it might fire.
@export var trigger_event_to_emit: StringName = &""

@export_group("Timing")
@export var duration_in_turns: int = 3
