extends "res://src/core/Component.gd"
class_name QuestStateComponent

## Per-entity quest journal that the forthcoming QuestSystem and narrative planner will
## synchronize against. Each entry records how this entity is currently participating in a
## quest so the generator can assign roles, branch dialogue, and unlock follow-up steps.
## Keeping the schema stable now allows content designers to begin cataloguing quest IDs
## and expected state machines without waiting for the full quest runtime to materialise.
##
## Designed for Godot 4.4.1.

@export_group("Quest Participation")
## Mapping from quest identifiers to that quest's current status relative to this entity.
## Keys should be globally unique quest IDs (StringName). Values represent high-level
## statuses such as "Available", "InProgress", "Completed", or project-specific tokens
## like "NeedsBriefing". The QuestSystem will update this dictionary as it assigns roles,
## and UI layers can render it directly to show what the character knows or offers.
@export var quest_status: Dictionary[StringName, StringName] = {}
