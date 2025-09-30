extends "res://src/systems/System.gd"
class_name CombatTimer

const ULTEnums := preload("res://src/globals/ULTEnums.gd")
const CombatEncounterState := preload("res://src/core/CombatEncounterState.gd")
const Entity := preload("res://src/entities/Entity.gd")
const EntityData := preload("res://src/core/EntityData.gd")
const StatsComponent := preload("res://src/components/StatsComponent.gd")
const CombatRuntimeComponent := preload("res://src/components/CombatRuntimeComponent.gd")
const FactionComponent := preload("res://src/components/FactionComponent.gd")

@export var encounter_state: CombatEncounterState

var _rng_seed_internal: int = 0
@export var rng_seed: int:
    get:
        return _rng_seed_internal
    set(value):
        _rng_seed_internal = value
        _configure_rng_seed()

## Optional EventBus injection so deterministic tests can supply a stub.
var event_bus: Node = null

var _is_waiting_for_action := false
var _rng := RandomNumberGenerator.new()
var _action_signal_connected := false

func _ready() -> void:
    _configure_rng_seed()
    _ensure_action_signal_subscription()

func _exit_tree() -> void:
    _disconnect_action_signal()

## Allows tests or tooling layers to inject a deterministic EventBus reference.
func set_event_bus(bus: Node) -> void:
    if event_bus == bus:
        return
    _disconnect_action_signal()
    event_bus = bus
    _ensure_action_signal_subscription()

## Initializes the encounter roster and seeds the combat queue.
func initialize_encounter(participants: Array[Entity]) -> void:
    if encounter_state == null:
        push_warning("CombatTimer.initialize_encounter requires a CombatEncounterState resource.")
        return

    encounter_state.reset()
    _is_waiting_for_action = false
    _configure_rng_seed()
    _ensure_action_signal_subscription()

    if participants == null or participants.is_empty():
        push_warning("CombatTimer.initialize_encounter called without participants.")
        return

    var participant_ids: Array[StringName] = []
    for participant in participants:
        var entity: Entity = participant
        if entity == null:
            continue

        var prepared := _prepare_participant_runtime(entity, true)
        if prepared.is_empty():
            continue

        var entity_id: StringName = prepared["entity_id"]
        if participant_ids.has(entity_id):
            continue

        participant_ids.append(entity_id)
        encounter_state.register_participant_runtime(entity_id, prepared["runtime"])

    encounter_state.set_participants(participant_ids)
    encounter_state.turn_queue.clear()

    emit_event(&"combat_encounter_started", {"participants": participant_ids})

    if participant_ids.is_empty():
        return

    _rebuild_turn_queue()
    _advance_to_next_turn()

## Forces an immediate rebuild of the initiative queue. Optionally advances the
## timeline when ``auto_advance`` is true so UI layers can resynchronise the
## active combatant after manual edits.
func force_rebuild_queue(auto_advance: bool = false) -> void:
    if encounter_state == null:
        push_warning("CombatTimer.force_rebuild_queue requires a CombatEncounterState resource.")
        return

    encounter_state.turn_queue.clear()
    _rebuild_turn_queue()

    if auto_advance and not _is_waiting_for_action:
        _advance_to_next_turn()

## Applies an initiative modifier to the specified combatant and emits the
## canonical ``combat_initiative_modified`` event so HUD overlays stay in sync.
func apply_initiative_modifier(entity_id: StringName, amount: int, duration: int, source: StringName) -> void:
    if encounter_state == null:
        push_warning("CombatTimer.apply_initiative_modifier requires a CombatEncounterState resource.")
        return

    if entity_id == StringName():
        push_warning("CombatTimer.apply_initiative_modifier requires a valid entity_id.")
        return

    var runtime_info := encounter_state.get_participant_runtime(entity_id)
    if runtime_info.is_empty():
        push_warning("CombatTimer.apply_initiative_modifier missing runtime metadata for %s." % entity_id)
        return

    var combat_runtime: CombatRuntimeComponent = runtime_info.get("combat_runtime")
    if combat_runtime == null:
        push_warning("CombatTimer.apply_initiative_modifier missing CombatRuntimeComponent for %s." % entity_id)
        return

    combat_runtime.apply_initiative_modifier(amount, duration, source)

    var payload := {
        "entity_id": entity_id,
        "delta": amount,
        "source": source,
    }
    if duration > 0:
        payload["remaining_turns"] = duration
    emit_event(&"combat_initiative_modified", payload)

## Injects additional combatants mid-encounter, refreshing their runtime state
## before rebuilding the queue so they can act on subsequent rounds.
func inject_participants(participants: Array[Entity], rebuild_queue: bool = true) -> void:
    if encounter_state == null:
        push_warning("CombatTimer.inject_participants requires a CombatEncounterState resource.")
        return

    if participants == null or participants.is_empty():
        return

    var participant_ids := encounter_state.participants.duplicate()
    for participant in participants:
        var entity: Entity = participant
        if entity == null:
            continue

        var prepared := _prepare_participant_runtime(entity, true)
        if prepared.is_empty():
            continue

        var entity_id: StringName = prepared["entity_id"]
        if participant_ids.has(entity_id):
            continue

        participant_ids.append(entity_id)
        encounter_state.register_participant_runtime(entity_id, prepared["runtime"])

    encounter_state.set_participants(participant_ids)

    if rebuild_queue:
        force_rebuild_queue(false)

func _rebuild_turn_queue() -> void:
    if encounter_state == null:
        return
    if not encounter_state.is_queue_empty():
        return
    if encounter_state.participants.is_empty():
        push_warning("CombatTimer._rebuild_turn_queue called without participants registered.")
        return

    encounter_state.round_counter += 1
    var round_index := encounter_state.round_counter
    emit_event(&"combat_round_started", {"round": round_index})

    encounter_state.turn_queue.clear()

    for entity_id in encounter_state.participants:
        var runtime_info := encounter_state.get_participant_runtime(entity_id)
        if runtime_info.is_empty():
            push_warning("CombatTimer._rebuild_turn_queue missing runtime metadata for %s." % entity_id)
            continue

        var stats: StatsComponent = runtime_info.get("stats")
        var combat_runtime: CombatRuntimeComponent = runtime_info.get("combat_runtime")
        if stats == null or combat_runtime == null:
            push_warning("CombatTimer._rebuild_turn_queue missing stats or combat runtime for %s." % entity_id)
            continue

        var initiative_seed := stats.calculate_initiative_seed()
        var base_initiative := combat_runtime.current_initiative
        var modifier_delta := combat_runtime.tick_initiative_modifiers()
        var roll := _rng.randi_range(1, 100)
        var total_initiative := roll + initiative_seed + base_initiative + modifier_delta
        combat_runtime.current_initiative = total_initiative

        var entry_metadata := {
            "roll": roll,
            "seed": initiative_seed,
            "modifier_delta": modifier_delta,
            "base_initiative": base_initiative,
        }
        encounter_state.record_turn_entry(entity_id, total_initiative, entry_metadata)

    if encounter_state.turn_queue.is_empty():
        push_warning("CombatTimer._rebuild_turn_queue failed; no eligible combatants produced entries.")
        return

    encounter_state.turn_queue.sort_custom(Callable(self, "_sort_turn_entries"))

    var snapshot: Array[Dictionary] = []
    for entry in encounter_state.turn_queue:
        snapshot.append(entry.duplicate(true))

    emit_event(&"combat_queue_rebuilt", {
        "round": round_index,
        "queue_snapshot": snapshot,
    })

func _advance_to_next_turn() -> void:
    if encounter_state == null:
        return
    if _is_waiting_for_action:
        return

    if encounter_state.is_queue_empty():
        _rebuild_turn_queue()
        if encounter_state.is_queue_empty():
            return

    var next_entry := encounter_state.pop_next_turn()
    if next_entry.is_empty():
        return

    var entity_id_variant := next_entry.get("entity_id", StringName())
    var entity_id := _normalize_entity_id(entity_id_variant)
    if entity_id == StringName():
        push_warning("CombatTimer._advance_to_next_turn encountered an entry without entity_id.")
        return

    var runtime_info := encounter_state.get_participant_runtime(entity_id)
    var stats: StatsComponent = runtime_info.get("stats") if not runtime_info.is_empty() else null
    if stats != null:
        stats.refresh_action_points_for_turn()

    var initiative_value := int(next_entry.get("initiative", 0))

    var queue_snapshot: Array[Dictionary] = []
    for entry in encounter_state.turn_queue:
        queue_snapshot.append(entry.duplicate(true))

    emit_event(&"turn_passed", {"turn_number": encounter_state.turn_number})

    var payload := {
        "entity_id": entity_id,
        "round": encounter_state.round_counter,
        "initiative": initiative_value,
    }
    if not queue_snapshot.is_empty():
        payload["queue_snapshot"] = queue_snapshot

    emit_event(&"combat_turn_started", payload.duplicate(true))
    emit_event(&"combat_turn_ready_for_action", payload)

    _is_waiting_for_action = true

func _complete_turn(results: Dictionary) -> void:
    if encounter_state == null:
        return
    if encounter_state.active_entity_id == StringName():
        return

    var payload := {
        "entity_id": encounter_state.active_entity_id,
        "round": encounter_state.round_counter,
    }
    if results != null and not results.is_empty():
        payload["results"] = results.duplicate(true)

    emit_event(&"combat_turn_completed", payload)

    _is_waiting_for_action = false

    if _evaluate_encounter_outcome(results):
        return

    _advance_to_next_turn()

func _on_combat_action_resolved(payload: Dictionary) -> void:
    if not _is_waiting_for_action:
        return

    var results: Dictionary = {}
    if payload != null and payload.has("results") and payload["results"] is Dictionary:
        results = payload["results"]

    if encounter_state != null and payload != null and payload.has("entity_id"):
        var resolved_id := _normalize_entity_id(payload["entity_id"])
        if resolved_id != StringName() and encounter_state.active_entity_id != resolved_id:
            return

    _complete_turn(results)

func _evaluate_encounter_outcome(results: Dictionary) -> bool:
    if encounter_state == null or encounter_state.participants.is_empty():
        return false

    var players_alive := false
    var opponents_alive := false
    var opponent_faction := StringName()

    for entity_id in encounter_state.participants:
        var runtime_info := encounter_state.get_participant_runtime(entity_id)
        if runtime_info.is_empty():
            continue

        var stats: StatsComponent = runtime_info.get("stats")
        if stats == null:
            continue

        var faction_component: FactionComponent = runtime_info.get("faction")
        var faction_id := _normalize_faction_id(faction_component)
        var is_player := faction_id == &"PLAYER"

        if stats.health > 0:
            if is_player:
                players_alive = true
            else:
                opponents_alive = true
                if opponent_faction == StringName() and faction_id != StringName():
                    opponent_faction = faction_id

    if not players_alive:
        _emit_encounter_ended(&"defeat", results, opponent_faction)
        return true

    if not opponents_alive:
        _emit_encounter_ended(&"victory", results, &"PLAYER")
        return true

    return false

func _emit_encounter_ended(outcome: StringName, results: Dictionary, winning_team: StringName) -> void:
    if encounter_state == null:
        return

    var summary := {
        "round": encounter_state.round_counter,
        "turns": encounter_state.turn_number,
        "participants": encounter_state.participants.duplicate(),
    }

    if results != null and not results.is_empty():
        summary["last_action"] = results.duplicate(true)

    if not encounter_state.turn_queue.is_empty():
        var remaining: Array[Dictionary] = []
        for entry in encounter_state.turn_queue:
            remaining.append(entry.duplicate(true))
        summary["remaining_queue"] = remaining

    var payload := {
        "outcome": outcome,
        "summary": summary,
    }
    if winning_team != StringName():
        payload["winning_team"] = winning_team

    emit_event(&"combat_encounter_ended", payload)
    encounter_state.active_entity_id = StringName()
    encounter_state.turn_queue.clear()

func _prepare_participant_runtime(participant: Entity, reset_runtime: bool) -> Dictionary:
    if participant == null:
        return {}

    var entity_data := _resolve_entity_data(participant)
    if entity_data == null:
        push_warning("CombatTimer could not resolve EntityData for participant node %s." % participant.name)
        return {}

    var stats := _resolve_stats_component(entity_data)
    if stats == null:
        push_warning("CombatTimer participant %s missing StatsComponent." % _resolve_participant_label(participant, entity_data))
        return {}

    var combat_runtime := _resolve_combat_runtime_component(entity_data)
    if combat_runtime == null:
        push_warning("CombatTimer participant %s missing CombatRuntimeComponent." % _resolve_participant_label(participant, entity_data))
        return {}

    var faction := _resolve_faction_component(entity_data)
    var entity_id := _resolve_participant_identifier(participant, entity_data)

    if reset_runtime:
        combat_runtime.reset_for_new_encounter()
        stats.refresh_action_points_for_turn()

    var runtime := {
        "entity_data": entity_data,
        "stats": stats,
        "combat_runtime": combat_runtime,
    }
    if faction != null:
        runtime["faction"] = faction

    return {
        "entity_id": entity_id,
        "runtime": runtime,
    }

func _resolve_entity_data(participant: Entity) -> EntityData:
    if participant == null:
        return null

    if participant.entity_data != null:
        return participant.entity_data

    if participant.has_method("get_entity_data"):
        var via_method := participant.call("get_entity_data")
        if via_method is EntityData:
            return via_method

    if participant.has_meta("entity_data"):
        var via_meta := participant.get_meta("entity_data")
        if via_meta is EntityData:
            return via_meta

    return null

func _resolve_stats_component(entity_data: EntityData) -> StatsComponent:
    if entity_data == null:
        return null
    if not entity_data.has_component(ULTEnums.ComponentKeys.STATS):
        return null
    var component := entity_data.get_component(ULTEnums.ComponentKeys.STATS)
    return component if component is StatsComponent else null

func _resolve_combat_runtime_component(entity_data: EntityData) -> CombatRuntimeComponent:
    if entity_data == null:
        return null
    if not entity_data.has_component(ULTEnums.ComponentKeys.COMBAT_RUNTIME):
        return null
    var component := entity_data.get_component(ULTEnums.ComponentKeys.COMBAT_RUNTIME)
    return component if component is CombatRuntimeComponent else null

func _resolve_faction_component(entity_data: EntityData) -> FactionComponent:
    if entity_data == null:
        return null
    if not entity_data.has_component(ULTEnums.ComponentKeys.FACTION):
        return null
    var component := entity_data.get_component(ULTEnums.ComponentKeys.FACTION)
    return component if component is FactionComponent else null

func _resolve_participant_label(participant: Entity, entity_data: EntityData) -> String:
    if entity_data != null and entity_data.entity_id != "":
        return entity_data.entity_id
    if participant != null:
        return participant.name
    return "unknown_participant"

func _resolve_participant_identifier(participant: Entity, entity_data: EntityData) -> StringName:
    if entity_data != null:
        return entity_data.ensure_runtime_entity_id(StringName(participant.name))
    if participant != null:
        if participant.has_method("get_entity_id"):
            var via_method := participant.call("get_entity_id")
            return _normalize_entity_id(via_method)
        return StringName(participant.name)
    return StringName()

func _normalize_entity_id(value: Variant) -> StringName:
    if value is StringName:
        return value
    if value is String:
        return StringName(value)
    return StringName()

func _normalize_faction_id(component: FactionComponent) -> StringName:
    if component == null:
        return StringName()
    var identifier := component.faction_id.strip_edges()
    if identifier == "":
        return StringName()
    return StringName(identifier.to_upper())

func _configure_rng_seed() -> void:
    if _rng == null:
        _rng = RandomNumberGenerator.new()
    if _rng_seed_internal != 0:
        _rng.seed = _rng_seed_internal
    else:
        _rng.randomize()

func _get_event_bus() -> Node:
    if event_bus != null and is_instance_valid(event_bus):
        return event_bus
    var resolved := super._get_event_bus()
    if resolved != null:
        event_bus = resolved
    return event_bus

func _ensure_action_signal_subscription() -> void:
    var bus := _get_event_bus()
    if bus == null:
        return
    if _action_signal_connected:
        return
    if not bus.has_signal("combat_action_resolved"):
        push_warning("CombatTimer could not subscribe; EventBus missing combat_action_resolved signal.")
        return
    var error := bus.connect("combat_action_resolved", Callable(self, "_on_combat_action_resolved"), Object.CONNECT_REFERENCE_COUNTED)
    if error == OK or error == ERR_ALREADY_IN_USE:
        _action_signal_connected = true
    else:
        push_warning("CombatTimer failed to subscribe to combat_action_resolved (error %d)." % error)

func _disconnect_action_signal() -> void:
    if not _action_signal_connected:
        return
    if event_bus == null or not is_instance_valid(event_bus):
        _action_signal_connected = false
        event_bus = null
        return
    if event_bus.is_connected("combat_action_resolved", Callable(self, "_on_combat_action_resolved")):
        event_bus.disconnect("combat_action_resolved", Callable(self, "_on_combat_action_resolved"))
    _action_signal_connected = false

func _sort_turn_entries(a: Dictionary, b: Dictionary) -> bool:
    return int(a.get("initiative", 0)) > int(b.get("initiative", 0))
