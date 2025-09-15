extends Node
class_name System

const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")

## Abstract base class for gameplay systems that operate on entities.
## Systems are expected to iterate over entities each frame and perform logic.
## Systems must stay decoupled from each other – use emit_event()/subscribe_event()
## instead of storing direct references to peer nodes.
## Designed for Godot 4.4.1.

## Called by subclasses to process a specific entity.
func _process_entity(entity_node: Node, delta: float) -> void:
    pass

## Emit a payload on the global EventBus singleton.
## Subclasses should prefer this helper over referencing the autoload directly so
## all event traffic flows through a consistent abstraction.
func emit_event(signal_name: StringName, payload: Dictionary = {}) -> void:
    var event_bus := _get_event_bus()
    if event_bus == null:
        push_warning("EventBus singleton is unavailable; cannot emit \"%s\"." % signal_name)
        return

    if not event_bus.has_signal(signal_name):
        push_warning("EventBus is missing expected signal: %s" % signal_name)
        return

    event_bus.emit_signal(signal_name, payload)

## Subscribe to an EventBus signal using the provided callback.
## Returns the Godot error code from the underlying connect call so callers can
## react to failures without coupling to the EventBus implementation details.
func subscribe_event(signal_name: StringName, callback: Callable, flags: int = Object.CONNECT_REFERENCE_COUNTED) -> int:
    var event_bus := _get_event_bus()
    if event_bus == null:
        push_warning("EventBus singleton is unavailable; cannot subscribe to \"%s\"." % signal_name)
        return ERR_DOES_NOT_EXIST

    if not event_bus.has_signal(signal_name):
        push_warning("EventBus is missing expected signal: %s" % signal_name)
        return ERR_INVALID_PARAMETER

    return event_bus.connect(signal_name, callback, flags)

## Internal helper that fetches the EventBus autoload or returns null when the
## system is running outside of a full game tree (e.g. during isolated tests).
func _get_event_bus() -> Node:
    if EVENT_BUS_SCRIPT.is_singleton_ready():
        return EVENT_BUS_SCRIPT.get_singleton()

    if typeof(EventBus) == TYPE_OBJECT and EventBus is Node:
        return EventBus

    var scene_tree := get_tree()
    if scene_tree == null:
        return null

    var root := scene_tree.get_root()
    if root == null:
        return null

    return root.get_node_or_null("EventBus")
