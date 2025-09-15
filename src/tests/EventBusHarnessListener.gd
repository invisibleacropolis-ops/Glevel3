extends Node

const EVENT_BUS_NODE_NAME := "EventBus"

## Connects to every EventBus signal and forwards payloads to the harness log.
## This node mirrors an omniscient subscriber that verifies the bus remains
## functional, regardless of the state of other gameplay systems.

const SIGNAL_NAMES := [
    "entity_killed",
    "item_acquired",
    "quest_state_changed",
]

var _connected: Array[StringName] = []
var _event_bus: Node = null

func _ready() -> void:
    if _event_bus == null:
        _event_bus = _find_event_bus()
    _connect_to_bus()

func _exit_tree() -> void:
    _disconnect_from_bus()

func set_event_bus(event_bus: Node) -> void:
    ## Allows the harness scene to inject a specific EventBus instance, ensuring the
    ## listener remains synchronized with whichever singleton is under test.
    if event_bus == _event_bus:
        return
    _disconnect_from_bus()
    _event_bus = event_bus
    if is_inside_tree():
        _connect_to_bus()

func _connect_to_bus() -> void:
    ## Subscribe to each known EventBus signal while tracking active connections so
    ## they can be safely removed when the node exits the scene tree or is rebound.
    if _event_bus == null:
        push_warning("EventBusHarnessListener cannot connect without an EventBus instance.")
        return

    for signal_name in SIGNAL_NAMES:
        var signal_id := StringName(signal_name)
        if _connected.has(signal_id):
            continue
        if not _event_bus.has_signal(signal_id):
            push_warning("EventBus is missing expected signal: %s" % signal_name)
            continue
        var callable := Callable(self, "_on_signal_received").bind(signal_name)
        var error := _event_bus.connect(signal_id, callable, Object.CONNECT_REFERENCE_COUNTED)
        if error != OK:
            push_error("Failed to connect to EventBus.%s (error %s)" % [signal_name, error])
            continue
        _connected.push_back(signal_id)

func _disconnect_from_bus() -> void:
    ## Remove every active connection established by _connect_to_bus, gracefully
    ## handling cases where the EventBus instance became unavailable mid-session.
    if _event_bus == null:
        _connected.clear()
        return

    for signal_id in _connected:
        if _event_bus.has_signal(signal_id):
            var signal_name := String(signal_id)
            var callable := Callable(self, "_on_signal_received").bind(signal_name)
            if _event_bus.is_connected(signal_id, callable):
                _event_bus.disconnect(signal_id, callable)
    _connected.clear()

func _on_signal_received(payload: Dictionary, signal_name: String) -> void:
    var harness := get_parent()
    if harness and harness.has_method("append_log"):
        harness.append_log(signal_name, payload)

func _find_event_bus() -> Node:
    ## Attempt to locate the EventBus singleton within the active SceneTree without
    ## instantiating a new node. Harness.gd will fall back to creating its own copy
    ## if this lookup fails.
    var tree := get_tree()
    if tree == null:
        return null

    var root := tree.get_root()
    if root == null:
        return null

    return root.get_node_or_null(EVENT_BUS_NODE_NAME)
