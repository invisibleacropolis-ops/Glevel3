extends "res://src/core/Component.gd"
class_name StatsComponent

## Modular data block storing combat and utility statistics for an entity.
## Exported values are editable by designers and consumed by all runtime systems.

## Current health pool for the entity. Clamped in gameplay systems between 0 and max_health.
@export var health: int = 0

## Maximum health capacity used for healing, leveling, and archetype templates.
@export var max_health: int = 0

## Current action points available to spend on tactical abilities during a turn.
@export var action_points: int = 0

## Maximum action points regenerated at the start of a turn or rest cycle.
@export var max_action_points: int = 0

## Primary physical power used for melee damage calculations and carry capacity checks.
@export var strength: int = 0

## Agility and precision score influencing accuracy, evasion, and ranged weapons.
@export var dexterity: int = 0

## Physical resilience governing fortitude saves, poison resistance, and stamina pools.
@export var constitution: int = 0

## Arcane aptitude affecting spell potency, mana checks, and knowledge gates.
@export var intelligence: int = 0

## Mental resolve dictating morale, resistance to control effects, and focus recovery.
@export var willpower: int = 0

## Base movement or initiative score determining turn order or grid traversal speed.
@export var speed: float = 0.0

## Mapping of damage-type identifiers (e.g., "fire") to fractional mitigation values.
@export var resistances: Dictionary[StringName, float] = {}

## Mapping of damage-type identifiers to vulnerability multipliers applied by combat systems.
@export var vulnerabilities: Dictionary[StringName, float] = {}
