extends "res://src/core/Component.gd"
class_name StatsComponent

## Component storing basic combat statistics for an entity.
## Designed for Godot 4.4.1.

@export var health: int = 0
@export var action_points: int = 0

## Applies damage and clamps health at zero.
func apply_damage(amount: int) -> void:
    health = max(health - amount, 0)
