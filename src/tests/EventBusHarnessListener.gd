extends Node

const EVENT_BUS_NODE_NAME := "EventBus"
const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")

## Connects to every EventBus signal and forwards payloads to the harness log.
## This node mirrors an omniscient subscriber that verifies the bus remains
## functional, regardless of the state of other gameplay systems.

var _connected: Array[StringName] = []
var _event_bus: EventBus = null
var _signal_names: Array[StringName] = []

func _ready() -> void:
    if _event_bus == null:
        _event_bus = _find_event_bus()
    _signal_names = _gather_signal_names()
    _connect_to_bus()

func _exit_tree() -> void:
    _disconnect_from_bus()

func set_event_bus(event_bus: EventBus) -> void:
    ## Allows the harness scene to inject a specific EventBus instance, ensuring the
    ## listener remains synchronized with whichever singleton is under test.
    if event_bus == _event_bus:
        return
    _disconnect_from_bus()
    _event_bus = event_bus
    _signal_names = _gather_signal_names()
    if is_inside_tree():
        _connect_to_bus()

func _connect_to_bus() -> void:
    ## Subscribe to each known EventBus signal while tracking active connections so
    ## they can be safely removed when the node exits the scene tree or is rebound.
    if _event_bus == null:
        push_warning("EventBusHarnessListener cannot connect without an EventBus instance.")
        return

    for signal_name: StringName in _signal_names:
        if _connected.has(signal_name):
            continue
        if not _event_bus.has_signal(signal_name):
            push_warning("EventBus is missing expected signal: %s" % signal_name)
            continue
        var callable: Callable = Callable(self, "_on_signal_received").bind(String(signal_name))
        var error: int = _event_bus.connect(signal_name, callable, Object.CONNECT_REFERENCE_COUNTED)
        if error != OK:
            push_error("Failed to connect to EventBus.%s (error %s)" % [signal_name, error])
            continue
        _connected.push_back(signal_name)

func _disconnect_from_bus() -> void:
    ## Remove every active connection established by _connect_to_bus, gracefully
    ## handling cases where the EventBus instance became unavailable mid-session.
    if _event_bus == null:
        _connected.clear()
        return

    for signal_name: StringName in _connected:
        if _event_bus.has_signal(signal_name):
            var callable: Callable = Callable(self, "_on_signal_received").bind(String(signal_name))
            if _event_bus.is_connected(signal_name, callable):
                _event_bus.disconnect(signal_name, callable)
    _connected.clear()

func _on_signal_received(payload: Dictionary, signal_name: String) -> void:
    var harness: Node = get_parent()
    if harness and harness.has_method("append_log"):
        harness.append_log(signal_name, payload)

func _find_event_bus() -> EventBus:
    ## Attempt to locate the EventBus singleton within the active SceneTree without
    ## instantiating a new node. Harness.gd will fall back to creating its own copy
    ## if this lookup fails.
    var tree: SceneTree = get_tree()
    if tree == null:
        return null

    var root: Node = tree.get_root()
    if root == null:
        return null

    return root.get_node_or_null(EVENT_BUS_NODE_NAME) as EventBus

func _gather_signal_names() -> Array[StringName]:
    ## Resolve the complete set of script-defined EventBus signals so the harness can
    ## automatically track future additions without hand-maintained lists.
    var names: Array[StringName] = []
    if _event_bus:
        for signal_info: Dictionary in _event_bus.get_signal_list():
            var name_text: String = String(signal_info.get("name", ""))
            if name_text.is_empty():
                continue
            var name: StringName = StringName(name_text)
            if not _event_bus.has_user_signal(name):
                continue
            if not names.has(name):
                names.append(name)

    if names.is_empty():
        for contract_name in EVENT_BUS_SCRIPT.SIGNAL_CONTRACTS.keys():
            var signal_name: StringName = contract_name
            if not names.has(signal_name):
                names.append(signal_name)

    return names
