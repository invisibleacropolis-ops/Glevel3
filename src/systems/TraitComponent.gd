extends "res://src/core/Component.gd"
class_name TraitComponent

## Component holding a list of traits or tags for an entity.
## Designed for Godot 4.4.1.

@export var traits: Array[String] = []

## Adds a trait if not already present.
func add_trait(trait: String) -> void:
    if trait not in traits:
        traits.append(trait)
