extends Node
class_name CombatTimerValidator
"""Automated validation harness exercising CombatTimer lifecycle guarantees.

The validator mirrors the StatusSystem harness by instantiating a CombatTimer,
StatusSystem, and EventBus in isolation so CI pipelines and engineers can
execute deterministic combat loops without launching the full game. Test entities
are generated from the reusable EntityData fixture under `tests/test_assets/`
and receive fresh Stats + CombatRuntime components every run. Key assurances:

1. Deterministic RNG seeding produces a stable initiative queue and round
   progression so initiative regressions are caught immediately.
2. StatsComponent.refresh_action_points_for_turn() fires whenever a combatant
   becomes active, restoring the action budget to max_action_points each turn.
3. CombatTimer emits the documented combat_turn_started, combat_turn_completed,
   turn_passed, and combat_encounter_ended payloads, including summary fields
   required by downstream systems.

The harness also exposes convenience helpers (start_demo_encounter,
advance_demo_turn, describe_encounter_state) so the dedicated
`CombatTimer_Testbed.tscn` scene can drive the same logic via UI buttons.
"""

const COMBAT_TIMER_SCRIPT := preload("res://src/systems/combat/CombatTimer.gd")
const STATUS_SYSTEM_SCRIPT := preload("res://src/systems/StatusSystem.gd")
const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")
const COMBAT_ENCOUNTER_STATE_SCRIPT := preload("res://src/core/CombatEncounterState.gd")
const ENTITY_SCRIPT := preload("res://src/entities/Entity.gd")
const ENTITY_DATA_FIXTURE := preload("res://tests/test_assets/TestDum2.tres")
const STATS_COMPONENT_SCRIPT := preload("res://src/components/StatsComponent.gd")
const COMBAT_RUNTIME_COMPONENT_SCRIPT := preload("res://src/components/CombatRuntimeComponent.gd")
const FACTION_COMPONENT_SCRIPT := preload("res://src/components/FactionComponent.gd")
const ULTENUMS := preload("res://src/globals/ULTEnums.gd")

const VALIDATION_RNG_SEED := 424242

const VALIDATOR_TAG := "[CombatTimerValidator]"

@export var auto_run_on_ready: bool = true

var _event_bus: EventBusSingleton
var _combat_timer: CombatTimer
var _status_system: StatusSystem
var _encounter_state: CombatEncounterState
var _environment_initialized := false

var _combatants: Array[Dictionary] = []
var _combatant_lookup: Dictionary[StringName, Dictionary] = {}

var _round_reset_connected := false
var _round_reset_callable := Callable()

var _demo_mode_active := false

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    if auto_run_on_ready:
        call_deferred("run_all_validations")

func run_all_validations() -> void:
    """Bootstraps the combat environment, executes validations, and logs a summary."""
    var results: Array[Dictionary] = []
    if not await _setup_environment():
        results.append(_build_result(
            "CombatTimer environment bootstraps",
            ["Failed to initialise EventBus/StatusSystem/CombatTimer dependencies."],
        ))
        _log_results(results)
        _teardown_environment()
        return

    await _despawn_combatants()
    await _spawn_default_combatants()

    var validation_result := await _validate_combat_loop()
    results.append(validation_result)

    _log_results(results)

    await _despawn_combatants()
    _teardown_environment()

func start_demo_encounter() -> Array[StringName]:
    """Initialises the deterministic demo encounter for the CombatTimer testbed UI."""
    _demo_mode_active = true
    await _setup_environment()
    await _despawn_combatants()
    await _spawn_default_combatants()
    _ensure_round_reset_hook()

    _combat_timer.rng_seed = VALIDATION_RNG_SEED
    _encounter_state.reset()

    var participants := _collect_participant_nodes()
    _combat_timer.initialize_encounter(participants)
    var identifiers: Array[StringName] = []
    for context in _combatants:
        identifiers.append(context.get("entity_id", StringName()))
    return identifiers

func advance_demo_turn(results: Dictionary = {}) -> Dictionary:
    """Resolves the active turn inside the demo environment and returns a summary."""
    if not _environment_initialized or _combat_timer == null:
        return {
            "status": "error",
            "message": "CombatTimer environment not initialised.",
        }

    var active_id := _encounter_state.active_entity_id if _encounter_state != null else StringName()
    if active_id == StringName():
        return {
            "status": "idle",
            "message": "No active combatant; start an encounter first.",
        }

    if results.is_empty():
        results = {
            "source": &"combat_timer_testbed",
            "timestamp": Time.get_ticks_msec(),
        }

    _prime_next_combatant_action_points()
    _event_bus.emit_signal(&"combat_action_resolved", {
        "entity_id": active_id,
        "results": results.duplicate(true),
    })
    await get_tree().process_frame()

    return {
        "status": "ok",
        "resolved_id": active_id,
        "round": _encounter_state.round_counter if _encounter_state != null else 0,
        "turn_number": _encounter_state.turn_number if _encounter_state != null else 0,
    }

func describe_encounter_state() -> String:
    """Returns a human readable snapshot of the CombatTimer encounter state."""
    if _encounter_state == null:
        return "Encounter state unavailable; initialise the validator first."

    var lines: Array[String] = []
    lines.append("Round: %d" % _encounter_state.round_counter)
    lines.append("Turn Count: %d" % _encounter_state.turn_number)
    lines.append("Active Entity: %s" % String(_encounter_state.active_entity_id))

    if not _encounter_state.turn_queue.is_empty():
        lines.append("Queued Turns:")
        for entry in _encounter_state.turn_queue:
            var entity_id: StringName = entry.get("entity_id", StringName())
            var initiative := int(entry.get("initiative", 0))
            lines.append("  • %s (initiative=%d)" % [String(entity_id), initiative])
    else:
        lines.append("Queued Turns: [empty]")

    return "\n".join(lines)

func shutdown_environment() -> void:
    """Allows UI callers to tear down the demo environment explicitly."""
    _demo_mode_active = false
    await _despawn_combatants()
    _teardown_environment()

func _setup_environment() -> bool:
    if _environment_initialized:
        return true

    var tree := get_tree()
    if tree == null:
        push_warning("%s SceneTree unavailable; cannot initialise combat validator." % VALIDATOR_TAG)
        return false

    _event_bus = EVENT_BUS_SCRIPT.new()
    _event_bus.name = "EventBus"
    add_child(_event_bus)

    _status_system = STATUS_SYSTEM_SCRIPT.new()
    _status_system.name = "StatusSystem"
    add_child(_status_system)

    _combat_timer = COMBAT_TIMER_SCRIPT.new()
    _combat_timer.name = "CombatTimer"
    _encounter_state = COMBAT_ENCOUNTER_STATE_SCRIPT.new()
    _combat_timer.encounter_state = _encounter_state
    add_child(_combat_timer)

    await get_tree().process_frame()

    if _event_bus == null or _combat_timer == null or _status_system == null:
        return false

    _combat_timer.set_event_bus(_event_bus)
    _environment_initialized = true
    return true

func _teardown_environment() -> void:
    if _demo_mode_active:
        return

    _disconnect_round_reset_hook()

    if is_instance_valid(_combat_timer):
        _combat_timer.queue_free()
    if is_instance_valid(_status_system):
        _status_system.queue_free()
    if is_instance_valid(_event_bus):
        _event_bus.queue_free()

    _combat_timer = null
    _status_system = null
    _event_bus = null
    _encounter_state = null
    _environment_initialized = false

func _spawn_default_combatants() -> void:
    var configs := [
        {
            "name": "ValidatorPlayerAlpha",
            "entity_id": "validator_player_alpha",
            "display_name": "Validator Player Alpha",
            "faction": "player",
            "team": &"PLAYER",
            "max_action_points": 3,
            "max_health": 40,
            "speed": 5,
            "agility": 3,
            "initiative_bonus": 2,
            "base_initiative": 0,
        },
        {
            "name": "ValidatorShadow",
            "entity_id": "validator_shadow",
            "display_name": "Validator Shadow",
            "faction": "shadow_syndicate",
            "team": &"SHADOW_SYNDICATE",
            "max_action_points": 4,
            "max_health": 32,
            "speed": 4,
            "agility": 4,
            "initiative_bonus": 1,
            "base_initiative": 0,
        },
        {
            "name": "ValidatorPlayerBravo",
            "entity_id": "validator_player_bravo",
            "display_name": "Validator Player Bravo",
            "faction": "player",
            "team": &"PLAYER",
            "max_action_points": 2,
            "max_health": 36,
            "speed": 6,
            "agility": 2,
            "initiative_bonus": 0,
            "base_initiative": 1,
        },
    ]

    await _spawn_combatants_from_config(configs)

func _spawn_combatants_from_config(configs: Array) -> void:
    await _despawn_combatants()

    _combatants.clear()
    _combatant_lookup.clear()

    for config in configs:
        var context := await _create_combatant_context(config)
        if context.is_empty():
            continue
        _combatants.append(context)
        var entity_id: StringName = context.get("entity_id", StringName())
        if entity_id != StringName():
            _combatant_lookup[entity_id] = context

func _create_combatant_context(config: Dictionary) -> Dictionary:
    var fixture: EntityData = ENTITY_DATA_FIXTURE.duplicate(true)
    if fixture == null:
        return {}

    var entity := ENTITY_SCRIPT.new()
    entity.name = String(config.get("name", "Combatant"))

    var entity_data := fixture as EntityData
    entity_data.entity_id = String(config.get("entity_id", entity.name))
    entity_data.display_name = String(config.get("display_name", entity.name))
    entity_data.archetype_id = "CombatTimerValidator"

    var stats := STATS_COMPONENT_SCRIPT.new()
    entity_data.add_component(ULTENUMS.ComponentKeys.STATS, stats)

    stats.max_health = int(config.get("max_health", 30))
    stats.health = stats.max_health
    stats.max_action_points = int(config.get("max_action_points", 3))
    stats.action_points = 0
    stats.speed = int(config.get("speed", 4))
    stats.agility = int(config.get("agility", 2))
    stats.initiative_static_bonus = int(config.get("initiative_bonus", 0))

    var combat_runtime := COMBAT_RUNTIME_COMPONENT_SCRIPT.new()
    entity_data.add_component(ULTENUMS.ComponentKeys.COMBAT_RUNTIME, combat_runtime)
    combat_runtime.base_initiative_bonus = int(config.get("base_initiative", 0))
    combat_runtime.current_initiative = combat_runtime.base_initiative_bonus
    combat_runtime.initiative_modifiers.clear()

    var faction_component := FACTION_COMPONENT_SCRIPT.new()
    faction_component.faction_id = String(config.get("faction", "neutral"))
    entity_data.add_component(ULTENUMS.ComponentKeys.FACTION, faction_component)

    entity.assign_entity_data(entity_data)
    add_child(entity)
    await entity.ready

    var entity_id := entity_data.ensure_runtime_entity_id(StringName(entity.name))

    return {
        "entity": entity,
        "entity_data": entity_data,
        "stats": stats,
        "combat_runtime": combat_runtime,
        "faction": faction_component,
        "entity_id": entity_id,
        "team": config.get("team", &"NEUTRAL"),
        "config": config,
    }

func _despawn_combatants() -> void:
    for context in _combatants:
        var entity: Node = context.get("entity")
        if is_instance_valid(entity):
            entity.queue_free()
    _combatants.clear()
    _combatant_lookup.clear()
    await get_tree().process_frame()

func _ensure_round_reset_hook() -> void:
    if _round_reset_connected:
        return
    if _event_bus == null:
        return
    _round_reset_callable = Callable(self, "_handle_round_started")
    var error := _event_bus.connect(&"combat_round_started", _round_reset_callable, Object.CONNECT_REFERENCE_COUNTED)
    if error == OK or error == ERR_ALREADY_IN_USE:
        _round_reset_connected = true

func _disconnect_round_reset_hook() -> void:
    if not _round_reset_connected:
        return
    if _event_bus != null and _event_bus.is_connected(&"combat_round_started", _round_reset_callable):
        _event_bus.disconnect(&"combat_round_started", _round_reset_callable)
    _round_reset_connected = false

func _handle_round_started(_payload: Dictionary) -> void:
    for context in _combatants:
        var stats: STATS_COMPONENT_SCRIPT = context.get("stats")
        if stats != null:
            stats.action_points = 0

func _collect_participant_nodes() -> Array[Entity]:
    var nodes: Array[Entity] = []
    for context in _combatants:
        var entity: Entity = context.get("entity")
        if entity != null:
            nodes.append(entity)
    return nodes

func _validate_combat_loop() -> Dictionary:
    var errors: Array[String] = []

    _combat_timer.rng_seed = VALIDATION_RNG_SEED
    _encounter_state.reset()

    _ensure_round_reset_hook()

    var queue_events: Array[Dictionary] = []
    var round_events: Array[Dictionary] = []
    var turn_started_events: Array[Dictionary] = []
    var turn_completed_events: Array[Dictionary] = []
    var turn_passed_events: Array[Dictionary] = []
    var encounter_ended_events: Array[Dictionary] = []

    var connections := _connect_validation_signals({
        &"combat_queue_rebuilt": queue_events,
        &"combat_round_started": round_events,
        &"combat_turn_started": turn_started_events,
        &"combat_turn_completed": turn_completed_events,
        &"turn_passed": turn_passed_events,
        &"combat_encounter_ended": encounter_ended_events,
    })

    var participants := _collect_participant_nodes()
    _combat_timer.initialize_encounter(participants)

    await get_tree().process_frame()

    var predicted_rounds := _predict_round_snapshots(2)

    if queue_events.is_empty():
        errors.append("CombatTimer did not emit combat_queue_rebuilt after initialisation.")
    else:
        var first_queue := queue_events[0]
        _expect(int(first_queue.get("round", 0)) == 1, "Initial queue snapshot reported incorrect round index.", errors)
        var snapshot: Array = first_queue.get("queue_snapshot", [])
        if snapshot.size() != predicted_rounds[0].size():
            errors.append("Initial queue snapshot size mismatch (expected %d, received %d)." % [
                predicted_rounds[0].size(), snapshot.size(),
            ])
        else:
            for i in range(snapshot.size()):
                var entry: Dictionary = snapshot[i]
                var expected_entry: Dictionary = predicted_rounds[0][i]
                var entity_id := _normalize_entity_id(entry.get("entity_id"))
                _expect(
                    entity_id == expected_entry.get("entity_id"),
                    "Queue order mismatch at index %d (expected %s, received %s)." % [
                        i,
                        String(expected_entry.get("entity_id")),
                        String(entity_id),
                    ],
                    errors,
                )
                _expect(
                    int(entry.get("initiative", -1)) == int(expected_entry.get("initiative", -1)),
                    "Initiative total mismatch for %s (expected %d, received %d)." % [
                        String(entity_id),
                        int(expected_entry.get("initiative", -1)),
                        int(entry.get("initiative", -1)),
                    ],
                    errors,
                )

    var turn_cursor := 0
    var completed_cursor := 0
    var turn_passed_cursor := 0

    var first_round_entries := predicted_rounds[0]
    for index in range(first_round_entries.size()):
        var expected_entry: Dictionary = first_round_entries[index]
        var entity_id: StringName = expected_entry.get("entity_id", StringName())
        if turn_cursor >= turn_started_events.size():
            errors.append("Missing combat_turn_started event for round 1 turn %d (entity %s)." % [
                index + 1,
                String(entity_id),
            ])
            break

        var turn_event := turn_started_events[turn_cursor]
        _expect(_normalize_entity_id(turn_event.get("entity_id")) == entity_id,
            "combat_turn_started dispatched incorrect entity (expected %s, received %s)." % [
                String(entity_id),
                String(turn_event.get("entity_id")),
            ],
            errors)
        _expect(int(turn_event.get("round", 0)) == 1,
            "combat_turn_started reported wrong round for %s (expected 1)." % String(entity_id),
            errors)
        _expect(int(turn_event.get("initiative", -1)) == int(expected_entry.get("initiative", -1)),
            "combat_turn_started initiative mismatch for %s." % String(entity_id),
            errors)

        var stats: STATS_COMPONENT_SCRIPT = _combatant_lookup.get(entity_id, {}).get("stats")
        if stats != null:
            _expect(stats.action_points == stats.max_action_points,
                "StatsComponent.action_points not refreshed for %s (expected %d, found %d)." % [
                    String(entity_id),
                    stats.max_action_points,
                    stats.action_points,
                ],
                errors)
        turn_cursor += 1

        if turn_passed_cursor >= turn_passed_events.size():
            errors.append("turn_passed missing entry for global turn %d." % (turn_passed_cursor + 1))
        else:
            var turn_passed_payload := turn_passed_events[turn_passed_cursor]
            _expect(int(turn_passed_payload.get("turn_number", 0)) == turn_passed_cursor + 1,
                "turn_passed turn_number mismatch at index %d." % turn_passed_cursor,
                errors)
        turn_passed_cursor += 1

        _prime_next_combatant_action_points()

        var results_payload := {
            "round": 1,
            "turn_index": index,
            "source": &"validator",
        }
        _event_bus.emit_signal(&"combat_action_resolved", {
            "entity_id": entity_id,
            "results": results_payload,
        })
        await get_tree().process_frame()

        if completed_cursor >= turn_completed_events.size():
            errors.append("Missing combat_turn_completed event for %s." % String(entity_id))
            break
        var completed_event := turn_completed_events[completed_cursor]
        _expect(_normalize_entity_id(completed_event.get("entity_id")) == entity_id,
            "combat_turn_completed entity mismatch (expected %s)." % String(entity_id),
            errors)
        _expect(int(completed_event.get("round", 0)) == 1,
            "combat_turn_completed round mismatch for %s." % String(entity_id),
            errors)
        _expect(completed_event.has("results"),
            "combat_turn_completed missing results payload for %s." % String(entity_id),
            errors)
        completed_cursor += 1
    
    await get_tree().process_frame()

    if round_events.size() < 2:
        errors.append("CombatTimer failed to start a second round after cycling the queue.")
    else:
        var second_round_event := round_events[1]
        _expect(int(second_round_event.get("round", 0)) == 2,
            "combat_round_started reported wrong index for the second round.",
            errors)

    if queue_events.size() >= 2:
        var second_queue := queue_events[1]
        var second_snapshot: Array = second_queue.get("queue_snapshot", [])
        var predicted_second := predicted_rounds[1]
        if second_snapshot.size() == predicted_second.size():
            for j in range(second_snapshot.size()):
                var snapshot_entry: Dictionary = second_snapshot[j]
                var expected_snapshot: Dictionary = predicted_second[j]
                _expect(_normalize_entity_id(snapshot_entry.get("entity_id")) == expected_snapshot.get("entity_id"),
                    "Second round queue order mismatch at index %d." % j,
                    errors)
        else:
            errors.append("Second round queue snapshot size mismatch (expected %d, received %d)." % [
                predicted_second.size(), second_snapshot.size(),
            ])
    else:
        errors.append("CombatTimer did not emit combat_queue_rebuilt for round two.")

    var second_round_entries := predicted_rounds[1]
    if not second_round_entries.is_empty():
        if turn_cursor >= turn_started_events.size():
            errors.append("Missing combat_turn_started event for round 2 initial combatant.")
        else:
            var second_turn_event := turn_started_events[turn_cursor]
            var expected_round_two_id: StringName = second_round_entries[0].get("entity_id", StringName())
            _expect(_normalize_entity_id(second_turn_event.get("entity_id")) == expected_round_two_id,
                "Round 2 opener mismatch (expected %s, received %s)." % [
                    String(expected_round_two_id),
                    String(second_turn_event.get("entity_id")),
                ],
                errors)
            _expect(int(second_turn_event.get("round", 0)) == 2,
                "combat_turn_started reported wrong round for second cycle opener.",
                errors)

            var stats_round_two: STATS_COMPONENT_SCRIPT = _combatant_lookup.get(expected_round_two_id, {}).get("stats")
            if stats_round_two != null:
                _expect(stats_round_two.action_points == stats_round_two.max_action_points,
                    "Round 2 opener did not restore action points for %s." % String(expected_round_two_id),
                    errors)
            turn_cursor += 1

            if turn_passed_cursor >= turn_passed_events.size():
                errors.append("turn_passed did not increment for round 2 opener.")
            else:
                var turn_passed_round_two := turn_passed_events[turn_passed_cursor]
                _expect(int(turn_passed_round_two.get("turn_number", 0)) == turn_passed_cursor + 1,
                    "turn_passed turn_number mismatch for round 2 opener.",
                    errors)
            turn_passed_cursor += 1

            var opponent_context := _resolve_opponent_context()
            if not opponent_context.is_empty():
                var opponent_stats: STATS_COMPONENT_SCRIPT = opponent_context.get("stats")
                if opponent_stats != null:
                    opponent_stats.health = 0

            var results_second := {
                "round": 2,
                "turn_index": 0,
                "source": &"validator",
            }
            _event_bus.emit_signal(&"combat_action_resolved", {
                "entity_id": expected_round_two_id,
                "results": results_second,
            })
            await get_tree().process_frame()

            if completed_cursor >= turn_completed_events.size():
                errors.append("Missing combat_turn_completed for round 2 opener.")
            else:
                var completed_round_two := turn_completed_events[completed_cursor]
                _expect(int(completed_round_two.get("round", 0)) == 2,
                    "combat_turn_completed reported wrong round for cycle opener.",
                    errors)
                completed_cursor += 1

    if encounter_ended_events.is_empty():
        errors.append("CombatTimer did not emit combat_encounter_ended after the opponent was defeated.")
    else:
        var ended_payload := encounter_ended_events[0]
        _expect(ended_payload.get("outcome") == &"victory",
            "combat_encounter_ended outcome should be &\"victory\" when all opponents fall.",
            errors)
        _expect(ended_payload.has("summary"),
            "combat_encounter_ended summary payload missing.",
            errors)
        var summary: Dictionary = ended_payload.get("summary", {})
        if not summary.is_empty():
            _expect(int(summary.get("round", 0)) >= 2,
                "Encounter summary round counter expected >= 2 after second cycle.",
                errors)
            _expect(int(summary.get("turns", 0)) >= 4,
                "Encounter summary should report at least four turns processed.",
                errors)
            var participants: Array = summary.get("participants", [])
            _expect(participants.size() == _combatants.size(),
                "Encounter summary participant roster mismatch.",
                errors)
        _expect(ended_payload.get("winning_team") == &"PLAYER",
            "combat_encounter_ended winning_team should resolve to &\"PLAYER\" when players survive.",
            errors)

    _disconnect_validation_signals(connections)

    return _build_result("CombatTimer deterministic combat loop", errors)

func _connect_validation_signals(registry: Dictionary) -> Array[Dictionary]:
    var connections: Array[Dictionary] = []
    if _event_bus == null:
        return connections
    for signal_name in registry.keys():
        var sink: Array = registry[signal_name]
        var callable := Callable(self, "_capture_event").bind(sink)
        var error := _event_bus.connect(signal_name, callable, Object.CONNECT_REFERENCE_COUNTED)
        if error == OK or error == ERR_ALREADY_IN_USE:
            connections.append({
                "signal": signal_name,
                "callable": callable,
            })
    return connections

func _disconnect_validation_signals(connections: Array[Dictionary]) -> void:
    if _event_bus == null:
        return
    for connection in connections:
        var signal_name: StringName = connection.get("signal")
        var callable: Callable = connection.get("callable")
        if _event_bus.is_connected(signal_name, callable):
            _event_bus.disconnect(signal_name, callable)

func _capture_event(payload: Dictionary, sink: Array[Dictionary]) -> void:
    sink.append(payload.duplicate(true))

func _predict_round_snapshots(round_count: int) -> Array[Array[Dictionary]]:
    var predictions: Array[Array[Dictionary]] = []
    if _combatants.is_empty():
        return predictions

    var rng := RandomNumberGenerator.new()
    rng.seed = VALIDATION_RNG_SEED

    var initiative_totals: Dictionary[StringName, int] = {}
    for context in _combatants:
        var entity_id: StringName = context.get("entity_id", StringName())
        var runtime: COMBAT_RUNTIME_COMPONENT_SCRIPT = context.get("combat_runtime")
        initiative_totals[entity_id] = runtime.base_initiative_bonus if runtime != null else 0

    for _round_index in range(round_count):
        var entries: Array[Dictionary] = []
        for context in _combatants:
            var entity_id: StringName = context.get("entity_id", StringName())
            var stats: STATS_COMPONENT_SCRIPT = context.get("stats")
            var previous_total := initiative_totals.get(entity_id, 0)
            var roll := rng.randi_range(1, 100)
            var seed := stats.calculate_initiative_seed() if stats != null else 0
            var total := roll + seed + previous_total
            initiative_totals[entity_id] = total
            entries.append({
                "entity_id": entity_id,
                "initiative": total,
            })
        entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            return int(a.get("initiative", 0)) > int(b.get("initiative", 0))
        )
        predictions.append(entries)
    return predictions

func _prime_next_combatant_action_points() -> void:
    if _combat_timer == null or _encounter_state == null:
        return
    var next_entry := _encounter_state.peek_next_turn()
    if next_entry.is_empty():
        return
    var next_id := _normalize_entity_id(next_entry.get("entity_id"))
    if next_id == StringName():
        return
    var context := _combatant_lookup.get(next_id, {})
    if context.is_empty():
        return
    var stats: STATS_COMPONENT_SCRIPT = context.get("stats")
    if stats != null:
        stats.action_points = 0

func _resolve_opponent_context() -> Dictionary:
    for context in _combatants:
        if context.get("team") != &"PLAYER":
            return context
    return {}

func _normalize_entity_id(value: Variant) -> StringName:
    if value is StringName:
        return value
    if value is String:
        return StringName(value)
    return StringName()

func _expect(condition: bool, message: String, errors: Array[String]) -> void:
    if not condition:
        errors.append(message)

func _build_result(name: String, errors: Array[String]) -> Dictionary:
    return {
        "name": name,
        "passed": errors.is_empty(),
        "errors": errors,
    }

func _log_results(results: Array[Dictionary]) -> void:
    for result in results:
        var label := result.get("name", "Unnamed Validation")
        if result.get("passed", false):
            print("%s %s - PASS" % [VALIDATOR_TAG, label])
        else:
            print("%s %s - FAIL" % [VALIDATOR_TAG, label])
            for error in result.get("errors", []):
                push_warning("%s %s: %s" % [VALIDATOR_TAG, label, error])
