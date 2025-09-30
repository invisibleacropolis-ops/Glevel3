extends Resource
class_name CombatEncounterState

## Resource describing the state of a tactical combat encounter. Systems can
## persist turn order, participants, and bookkeeping counters without relying on
## scene tree nodes. Designed for save/load serialisation and deterministic tests.

## Current round index starting at zero for pre-roll bookkeeping.
@export var round_counter: int = 0

## Total number of turn activations processed so far.
@export var turn_number: int = 0

## Identifier for the entity currently taking its turn. Empty when idle.
@export var active_entity_id: StringName = StringName()

## Ordered roster of combatants participating in the encounter.
@export var participants: Array[StringName] = []

## Pending turn entries sorted by initiative or other scheduling logic.
## Each dictionary is expected to contain at least `entity_id` and `initiative`
## keys, with optional metadata for system callbacks.
@export var turn_queue: Array[Dictionary] = []

## Runtime metadata for encounter participants keyed by entity identifier.
## Stores references to the relevant EntityData and Component resources so the
## CombatTimer system can operate purely on detached resources without storing
## heavy state on the scene tree.
@export var participant_runtime: Dictionary[StringName, Dictionary] = {}

## Clears the encounter state so the resource can be reused for a fresh battle.
func reset() -> void:
    round_counter = 0
    turn_number = 0
    active_entity_id = StringName()
    participants.clear()
    turn_queue.clear()
    participant_runtime.clear()

## Registers the combatants participating in the encounter.
func set_participants(ids: Array[StringName]) -> void:
    participants = ids.duplicate()

## Records a new entry in the turn queue for processing by the initiative system.
func record_turn_entry(entity_id: StringName, initiative: int, metadata: Dictionary = {}) -> void:
    var entry: Dictionary = {
        "entity_id": entity_id,
        "initiative": initiative,
    }
    if not metadata.is_empty():
        entry["metadata"] = metadata.duplicate(true)
    turn_queue.append(entry)

## Stores runtime metadata for a specific participant, overwriting any previous
## entry registered for the same entity identifier. Passing an empty dictionary
## removes the participant entry to keep the cache clean for persistence.
func register_participant_runtime(entity_id: StringName, runtime_data: Dictionary) -> void:
    if entity_id == StringName():
        return
    if runtime_data.is_empty():
        participant_runtime.erase(entity_id)
        return
    participant_runtime[entity_id] = runtime_data

## Retrieves the runtime metadata dictionary for the supplied entity identifier.
## Returns an empty dictionary when the entity has not been registered.
func get_participant_runtime(entity_id: StringName) -> Dictionary:
    if participant_runtime.has(entity_id):
        return participant_runtime[entity_id]
    return {}

## Removes a participant's runtime metadata from the encounter state.
func remove_participant_runtime(entity_id: StringName) -> void:
    if entity_id == StringName():
        return
    participant_runtime.erase(entity_id)

## Removes and returns the next turn entry from the queue. Updates bookkeeping to
## reflect the active entity. Returns an empty dictionary when the queue is empty.
func pop_next_turn() -> Dictionary:
    if turn_queue.is_empty():
        active_entity_id = StringName()
        return {}
    var next_entry: Dictionary = turn_queue.pop_front()
    active_entity_id = next_entry.get("entity_id", StringName())
    turn_number += 1
    return next_entry

## Returns the next queued entry without removing it. Returns an empty dictionary
## when the queue has no entries.
func peek_next_turn() -> Dictionary:
    if turn_queue.is_empty():
        return {}
    return turn_queue[0]

## Indicates whether there are any turns waiting to be processed.
func is_queue_empty() -> bool:
    return turn_queue.is_empty()
