extends "res://src/core/Component.gd"
class_name AIBehaviorComponent

## Declarative data surface that gives the future AISystem everything it needs to drive an
## entity's behaviour. Although the concrete behaviour tree implementation and runtime
## scheduler have not shipped yet, this component defines the contract those systems will
## rely on. Designers can author assets against this interface today with confidence that
## the fields below will remain stable as the AI stack comes online.
##
## Designed for Godot 4.4.1.

@export_group("Behaviour Authoring")
## Reference to the behaviour tree resource that should be executed to control this entity.
## Once the AI runtime is available, the AISystem will load this resource, build an
## execution graph, and tick it each frame (or turn) while injecting sensory context.
## The project will eventually ship a dedicated ``BehaviorTree`` Resource subclass; until
## then we keep the type broad so prototypes can wire up placeholder assets without
## engine errors.
@export var behavior_tree: Resource = null

@export_group("Fallback Configuration")
## Baseline disposition that describes how the entity should act when no behaviour tree is
## provided or when the primary tree aborts. The AISystem can map these string tokens to
## curated fallback routines (e.g., "Passive" idles in place, "Defensive" guards allies,
## "Aggressive" seeks targets). Narrative systems may also inspect this flag to align
## generated dialogue or quest beats with the character's temperament.
@export var default_disposition: String = "Passive"
