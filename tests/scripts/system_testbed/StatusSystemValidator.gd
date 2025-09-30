extends Node
class_name StatusSystemValidator
"""Automated validation harness that exercises StatusSystem contracts inside the System Testbed.

The validator mirrors the documentation pattern described in the README for `TestSystemStyle` by
running targeted checks, capturing outcomes, and printing a concise PASS/FAIL summary so outside
engineers immediately understand the sandbox health. It verifies three critical behaviours:

1. Short-term status effects apply modifiers, synchronise StatusComponent/StatsComponent state,
   and emit the canonical `status_effect_applied` payload.
2. Expired status effects cleanly revert their modifiers, update component collections, and emit
   the `status_effect_ended` payload with the documented `reason` and modifier snapshot.
3. The EventBus singleton actively rejects malformed `status_effect_applied` payloads while
   accepting valid dictionaries, ensuring contract regressions surface immediately in tooling.

Results are printed to the output console with a `[StatusSystemValidator]` prefix so engineers can
scan logs quickly when running the System Testbed headlessly during CI or manual smoke tests.
"""

const STATUS_SYSTEM_SCRIPT := preload("res://src/systems/StatusSystem.gd")
const ENTITY_SCRIPT := preload("res://src/entities/Entity.gd")
const ENTITY_DATA_SCRIPT := preload("res://src/core/EntityData.gd")
const STATUS_COMPONENT_SCRIPT := preload("res://src/components/StatusComponent.gd")
const STATS_COMPONENT_SCRIPT := preload("res://src/components/StatsComponent.gd")
const STATUS_FX_SCRIPT := preload("res://src/core/StatusFX.gd")
const ULTENUMS := preload("res://src/globals/ULTEnums.gd")
const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")

const SHORT_TERM_EFFECT_NAME := StringName("validator_short_term")
const LONG_TERM_EFFECT_NAME := StringName("validator_long_term")
const VALIDATION_SOURCE_ID := StringName("status_system_validator")
const SHORT_TERM_DAMAGE := 3
const SHORT_TERM_DURATION := 2
const LONG_TERM_DURATION := 1
const BASELINE_HEALTH := 20

var _status_system: STATUS_SYSTEM_SCRIPT
var _test_environment: Node

func _ready() -> void:
	"""Defers execution until the scene finishes instancing so dependencies are ready."""
	if Engine.is_editor_hint():
		return
	call_deferred("_run_validations")

func _run_validations() -> void:
	"""Orchestrates the validation flow and prints a summary for engineers."""
	_status_system = _resolve_status_system()
	_test_environment = _resolve_test_environment()
	var event_bus := EVENT_BUS_SCRIPT.get_singleton()

	var lifecycle_results: Array[Dictionary] = []
	if not _dependencies_ready(event_bus):
		lifecycle_results.append(_build_result("StatusSystem lifecycle validation", [
			"StatusSystem node, TestEnvironment node, and EventBus autoload must be available before running validations.",
		]))
		lifecycle_results.append(_build_result("EventBus payload contract enforcement", [
			"EventBus autoload unavailable; register it under Project Settings → Autoload to enable contract validation.",
		]))
		_log_results(lifecycle_results)
		return

	var context := await _spawn_test_entity()
	if context.is_empty():
		lifecycle_results.append(_build_result("StatusSystem lifecycle validation", [
			"Failed to spawn validation entity; ensure StatusComponent and StatsComponent scripts are accessible.",
		]))
		lifecycle_results.append(_validate_event_bus_contracts(event_bus))
		_log_results(lifecycle_results)
		return

	var applied_events: Array[Dictionary] = []
	var ended_events: Array[Dictionary] = []
	var applied_callable := Callable(self, "_capture_applied_event").bind(applied_events)
	var ended_callable := Callable(self, "_capture_ended_event").bind(ended_events)

	var connect_errors: Array[String] = []
	if event_bus.connect("status_effect_applied", applied_callable) != OK:
		connect_errors.append("Unable to listen for status_effect_applied; EventBus returned a connection error.")
	if event_bus.connect("status_effect_ended", ended_callable) != OK:
		connect_errors.append("Unable to listen for status_effect_ended; EventBus returned a connection error.")

	if connect_errors.is_empty():
		lifecycle_results.append(
			_validate_short_term_lifecycle(context, applied_events, ended_events, event_bus)
		)
		lifecycle_results.append(
			_validate_long_term_lifecycle(context, applied_events, ended_events, event_bus)
		)
	else:
		lifecycle_results.append(_build_result("StatusSystem lifecycle validation", connect_errors))

	if event_bus.is_connected("status_effect_applied", applied_callable):
		event_bus.disconnect("status_effect_applied", applied_callable)
	if event_bus.is_connected("status_effect_ended", ended_callable):
		event_bus.disconnect("status_effect_ended", ended_callable)

	_teardown_entity(context.get("entity"))

	lifecycle_results.append(_validate_event_bus_contracts(event_bus))
	_log_results(lifecycle_results)

func _dependencies_ready(event_bus: EventBusSingleton) -> bool:
	"""Ensures the StatusSystem node, TestEnvironment spawn root, and EventBus singleton exist."""
	if _status_system == null or _test_environment == null:
		return false
	return event_bus != null

func _resolve_status_system() -> STATUS_SYSTEM_SCRIPT:
	"""Finds the StatusSystem instance mounted in the System Testbed."""
	if is_instance_valid(_status_system):
		return _status_system
	var root := get_tree().get_current_scene()
	if root == null:
		return null
	var candidate := root.get_node_or_null("%StatusSystem")
	if candidate is STATUS_SYSTEM_SCRIPT:
		_status_system = candidate
	return _status_system

func _resolve_test_environment() -> Node:
	"""Resolves the TestEnvironment node that owns spawned entities."""
	if is_instance_valid(_test_environment):
		return _test_environment
	var root := get_tree().get_current_scene()
	if root == null:
		return null
	var candidate := root.get_node_or_null("%TestEnvironment")
	if candidate != null:
		_test_environment = candidate
	return _test_environment

func _spawn_test_entity() -> Dictionary:
	"""Creates an Entity node with Stats/Status components so the StatusSystem can operate."""
	if _test_environment == null:
		return {}

	var entity := ENTITY_SCRIPT.new()
	entity.name = "StatusSystemValidatorEntity"

	var entity_data := ENTITY_DATA_SCRIPT.new()
	entity_data.entity_id = "status_system_validator_entity"
	entity_data.display_name = "Status System Validator"
	entity_data.archetype_id = "StatusSystemValidator"

	var stats := STATS_COMPONENT_SCRIPT.new()
	stats.health = BASELINE_HEALTH
	stats.max_health = BASELINE_HEALTH

	var status_component := STATUS_COMPONENT_SCRIPT.new()

	entity_data.add_component(ULTENUMS.ComponentKeys.STATS, stats)
	entity_data.add_component(ULTENUMS.ComponentKeys.STATUS, status_component)

	entity.assign_entity_data(entity_data)
	_test_environment.add_child(entity)
	await entity.ready

	return {
		"entity": entity,
		"entity_data": entity_data,
		"stats": stats,
		"status_component": status_component,
	}

func _validate_short_term_lifecycle(
	context: Dictionary,
	applied_events: Array[Dictionary],
	ended_events: Array[Dictionary],
	event_bus: EventBusSingleton
) -> Dictionary:
	"""Confirms short-term status effects mutate components and emit lifecycle payloads."""
	applied_events.clear()
	ended_events.clear()

	var stats: STATS_COMPONENT_SCRIPT = context.get("stats")
	var status_component: STATUS_COMPONENT_SCRIPT = context.get("status_component")
	var entity_data: ENTITY_DATA_SCRIPT = context.get("entity_data")
	var entity_ref: ENTITY_SCRIPT = context.get("entity")

	var effect := STATUS_FX_SCRIPT.new()
	effect.effect_name = SHORT_TERM_EFFECT_NAME
	effect.is_passive = true
	effect.duration_in_turns = SHORT_TERM_DURATION
	effect.modifiers = {"damage": SHORT_TERM_DAMAGE}

	var initial_health := stats.health
	var options := {
		"duration": SHORT_TERM_DURATION,
		"source_id": VALIDATION_SOURCE_ID,
		"metadata": {"test_case": "short_term"},
	}

	_status_system.apply_status_effect(entity_data, effect, options)

	var errors: Array[String] = []
	if stats.health != initial_health - SHORT_TERM_DAMAGE:
		errors.append("StatsComponent health did not reflect passive damage application (expected %d, found %d)."
			% [initial_health - SHORT_TERM_DAMAGE, stats.health])
	if not stats.short_term_statuses.has(SHORT_TERM_EFFECT_NAME):
		errors.append("StatsComponent.short_term_statuses missing validator effect tag.")
	if status_component.short_term_effects.size() != 1:
		errors.append("StatusComponent.short_term_effects should contain exactly one stored effect.")
	else:
		var stored_effect: StatusFX = status_component.short_term_effects[0]
		if stored_effect == effect:
			errors.append("StatusSystem should duplicate incoming StatusFX resources instead of storing originals.")
		if stored_effect.duration_in_turns != SHORT_TERM_DURATION:
			errors.append("Stored StatusFX duration expected %d but found %d." % [SHORT_TERM_DURATION, stored_effect.duration_in_turns])

	if applied_events.size() != 1:
		errors.append("Expected one status_effect_applied payload but captured %d." % applied_events.size())
	else:
		var payload := applied_events[0]
		if payload.get("entity_id") != entity_ref.get_entity_id():
			errors.append("status_effect_applied entity_id mismatch; expected %s." % String(entity_ref.get_entity_id()))
		if payload.get("effect_name") != SHORT_TERM_EFFECT_NAME:
			errors.append("status_effect_applied effect_name mismatch; expected %s." % String(SHORT_TERM_EFFECT_NAME))
		if payload.get("duration") != SHORT_TERM_DURATION:
			errors.append("status_effect_applied duration expected %d but found %s." % [SHORT_TERM_DURATION, str(payload.get("duration"))])
		if payload.get("source_id") != VALIDATION_SOURCE_ID:
			errors.append("status_effect_applied source_id expected %s but received %s." % [String(VALIDATION_SOURCE_ID), str(payload.get("source_id"))])
		var metadata: Dictionary = payload.get("metadata", {})
		if metadata.get("is_long_term") != false:
			errors.append("status_effect_applied metadata should mark short-term effects with is_long_term=false.")
		if metadata.get("is_passive") != true:
			errors.append("status_effect_applied metadata should flag passive effects.")
		if metadata.get("duration_scope") != StringName("turns"):
			errors.append("status_effect_applied metadata expected duration_scope=turns but found %s." % str(metadata.get("duration_scope")))
		if not metadata.has("modifiers"):
			errors.append("status_effect_applied metadata must include modifiers for passive effects.")
		elif metadata.get("modifiers") != effect.modifiers:
			errors.append("status_effect_applied metadata modifiers payload mismatched the originating effect definition.")

	var first_tick := event_bus.emit_signal(&"turn_passed", {})
	var second_tick := event_bus.emit_signal(&"turn_passed", {})
	if first_tick != OK or second_tick != OK:
		errors.append("EventBus rejected turn_passed payload during validation; ensure signal contract still accepts {}.")

	if ended_events.size() != 1:
		errors.append("Expected one status_effect_ended payload after expiration but captured %d." % ended_events.size())
	else:
		var ended_payload := ended_events[0]
		if ended_payload.get("entity_id") != entity_ref.get_entity_id():
			errors.append("status_effect_ended entity_id mismatch; expected %s." % String(entity_ref.get_entity_id()))
		if ended_payload.get("effect_name") != SHORT_TERM_EFFECT_NAME:
			errors.append("status_effect_ended effect_name mismatch; expected %s." % String(SHORT_TERM_EFFECT_NAME))
		if ended_payload.get("reason") != StringName("expired_turn"):
			errors.append("status_effect_ended reason expected expired_turn but found %s." % str(ended_payload.get("reason")))
		if not ended_payload.has("modifiers"):
			errors.append("status_effect_ended payload should echo the modifiers so StatsComponent can revert them.")
		elif ended_payload.get("modifiers") != effect.modifiers:
			errors.append("status_effect_ended modifiers payload mismatched the originating effect definition.")

	if status_component.short_term_effects.size() != 0:
		errors.append("StatusComponent.short_term_effects should be empty after the validator effect expires.")
	if stats.short_term_statuses.has(SHORT_TERM_EFFECT_NAME):
		errors.append("StatsComponent.short_term_statuses retained the validator effect tag after expiration.")
	if stats.health != initial_health:
		errors.append("StatsComponent health did not revert after effect expiration (expected %d, found %d)."
			% [initial_health, stats.health])

	return _build_result("StatusSystem short-term lifecycle", errors)

func _validate_long_term_lifecycle(
	context: Dictionary,
	applied_events: Array[Dictionary],
	ended_events: Array[Dictionary],
	event_bus: EventBusSingleton
) -> Dictionary:
	"""Validates long-term status metadata and expiration behaviour."""
	applied_events.clear()
	ended_events.clear()

	var stats: STATS_COMPONENT_SCRIPT = context.get("stats")
	var status_component: STATUS_COMPONENT_SCRIPT = context.get("status_component")
	var entity_data: ENTITY_DATA_SCRIPT = context.get("entity_data")
	var effect := STATUS_FX_SCRIPT.new()
	effect.effect_name = LONG_TERM_EFFECT_NAME
	effect.is_passive = false
	effect.duration_in_turns = LONG_TERM_DURATION
	effect.modifiers = {}

	var options := {
		"is_long_term": true,
		"duration": LONG_TERM_DURATION,
		"source_id": VALIDATION_SOURCE_ID,
		"metadata": {"test_case": "long_term"},
	}

	_status_system.apply_status_effect(entity_data, effect, options)

	var errors: Array[String] = []
	if not stats.long_term_statuses.has(LONG_TERM_EFFECT_NAME):
		errors.append("StatsComponent.long_term_statuses missing validator effect tag.")
	if status_component.long_term_effects.size() != 1:
		errors.append("StatusComponent.long_term_effects should contain exactly one stored effect.")

	if applied_events.size() != 1:
		errors.append("Expected one status_effect_applied payload for long-term effect but captured %d." % applied_events.size())
	else:
		var payload := applied_events[0]
		var metadata: Dictionary = payload.get("metadata", {})
		if metadata.get("is_long_term") != true:
			errors.append("status_effect_applied metadata should mark long-term effects with is_long_term=true.")
		if metadata.get("duration_scope") != StringName("days"):
			errors.append("status_effect_applied metadata expected duration_scope=days for long-term effects.")
		if metadata.get("is_passive") != false:
			errors.append("status_effect_applied metadata should reflect the validator effect's active nature.")
		if metadata.has("modifiers"):
			errors.append("status_effect_applied metadata should omit modifiers for non-passive effects with empty payloads.")

	var day_tick := event_bus.emit_signal(&"day_passed", {})
	if day_tick != OK:
		errors.append("EventBus rejected day_passed payload during validation; ensure signal contract still accepts {}.")

	if ended_events.size() != 1:
		errors.append("Expected one status_effect_ended payload for long-term effect but captured %d." % ended_events.size())
	else:
		var ended_payload := ended_events[0]
		if ended_payload.get("reason") != StringName("expired_day"):
			errors.append("status_effect_ended reason expected expired_day for long-term effects but found %s." % str(ended_payload.get("reason")))
		if ended_payload.has("modifiers"):
			errors.append("status_effect_ended payload should omit modifiers when the originating effect had none.")

	if stats.long_term_statuses.has(LONG_TERM_EFFECT_NAME):
		errors.append("StatsComponent.long_term_statuses retained the validator effect tag after expiration.")
	if status_component.long_term_effects.size() != 0:
		errors.append("StatusComponent.long_term_effects should be empty after the validator effect expires.")

	return _build_result("StatusSystem long-term lifecycle", errors)

func _validate_event_bus_contracts(event_bus: EventBusSingleton) -> Dictionary:
	"""Exercises EventBus payload validation for the status_effect_applied contract."""
	if event_bus == null:
		return _build_result("EventBus payload contract enforcement", [
			"EventBus autoload unavailable; register it before running contract validation.",
		])

	var errors: Array[String] = []

	var missing_key_result := event_bus.emit_signal(&"status_effect_applied", {"effect_name": SHORT_TERM_EFFECT_NAME})
	if missing_key_result == OK:
		errors.append("EventBus should reject status_effect_applied payloads missing entity_id with ERR_INVALID_DATA.")

	var invalid_type_result := event_bus.emit_signal(&"status_effect_applied", {
		"entity_id": &"validator",
		"effect_name": 42,
	})
	if invalid_type_result == OK:
		errors.append("EventBus should reject status_effect_applied payloads with invalid effect_name types.")

	var valid_payload := {
		"entity_id": &"validator",
		"effect_name": SHORT_TERM_EFFECT_NAME,
		"duration": 5,
		"metadata": {"note": "contract smoke test"},
	}
	var valid_result := event_bus.emit_signal(&"status_effect_applied", valid_payload)
	if valid_result != OK:
		errors.append("EventBus should accept well-formed status_effect_applied payloads; received error code %d." % valid_result)

	return _build_result("EventBus payload contract enforcement", errors)

func _capture_applied_event(payload: Dictionary, store: Array[Dictionary]) -> void:
	"""Duplicates payload dictionaries so assertions are not affected by downstream mutations."""
	store.append(payload.duplicate(true))

func _capture_ended_event(payload: Dictionary, store: Array[Dictionary]) -> void:
	"""Duplicates payload dictionaries so assertions are not affected by downstream mutations."""
	store.append(payload.duplicate(true))

func _teardown_entity(entity: Node) -> void:
	"""Safely queues the validation entity for deletion after tests complete."""
	if is_instance_valid(entity):
		entity.queue_free()

func _build_result(test_name: String, errors: Array[String]) -> Dictionary:
	"""Packages the outcome so _log_results can present a consistent summary."""
	return {
		"name": test_name,
		"passed": errors.is_empty(),
		"errors": errors,
	}

func _log_results(results: Array[Dictionary]) -> void:
	"""Prints PASS/FAIL summaries that mirror the README's TestSystemStyle format."""
	for result in results:
		if result.is_empty():
			continue
		var result_name: String = result.get("name", "Unnamed validation")
		var passed: bool = result.get("passed", false)
		var status_label := "PASS" if passed else "FAIL"
		print("[StatusSystemValidator] %s - %s" % [status_label, result_name])
		if not passed:
			var errors: Array = result.get("errors", [])
			for error in errors:
				push_warning("[StatusSystemValidator] %s: %s" % [result_name, error])
