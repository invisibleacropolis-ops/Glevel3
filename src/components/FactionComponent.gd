extends "res://src/core/Component.gd"
class_name FactionComponent

## Foundational social alignment record for entities participating in the simulation. The
## AI targeting logic, quest planners, and narrative systems inspect this data to
## determine alliances, hostilities, and situational loyalties. Designers can assign
## faction identifiers directly in the Inspector while tooling scripts synchronise
## reputation values against a master faction matrix.
##
## Designed for Godot 4.4.1.

@export_group("Faction Identity")
## String identifier representing the entity's primary faction membership. Standard practice
## is to use lowercase snake_case tokens that align with campaign documentation (e.g.,
## "free_merchants", "shadow_syndicate"). Systems must treat an empty string as "unaligned".
@export var faction_id: String = ""

@export_group("Reputation Matrix")
## Dictionary storing reputation deltas toward other factions. Keys must be faction string
## identifiers while values represent integer reputation scores. Positive numbers indicate
## friendly standing, zero represents neutrality, and negative numbers denote hostility. The
## QuestPlanner and AI targeting filters will treat missing keys as neutral relationships.
@export var reputation: Dictionary[String, int] = {}
