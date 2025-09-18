extends Resource
class_name Trait

## Data resource describing a passive gameplay trait.
## Traits allow designers to tag and modify entities without adding logic.
## Designed for Godot 4.4.1.

@export var trait_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var tags: Array[String] = []
@export var flags: Array[String] = []
@export var stat_modifiers: Dictionary = {}

## Returns ``true`` when the trait advertises the requested flag.
func has_flag(flag: String) -> bool:
    return flag in flags

## Convenience helper that exposes stat modifiers as a shallow copy.
func get_stat_modifiers() -> Dictionary:
    return stat_modifiers.duplicate()
