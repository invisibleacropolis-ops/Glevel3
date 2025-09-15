extends Node

## Connects to every EventBus signal and forwards payloads to the harness log.
## This node mirrors an omniscient subscriber that verifies the bus remains
## functional, regardless of the state of other gameplay systems.

const SIGNAL_NAMES := [
    "entity_killed",
    "item_acquired",
    "quest_state_changed",
]

var _connected: Array[StringName] = []

func _ready() -> void:
    _connect_to_bus()

func _exit_tree() -> void:
    _disconnect_from_bus()

func _connect_to_bus() -> void:
    for signal_name in SIGNAL_NAMES:
        var signal_id := StringName(signal_name)
        if _connected.has(signal_id):
            continue
        if not EventBus.has_signal(signal_id):
            push_warning("EventBus is missing expected signal: %s" % signal_name)
            continue
        var callable := Callable(self, "_on_signal_received").bind(signal_name)
        var error := EventBus.connect(signal_id, callable, Object.CONNECT_REFERENCE_COUNTED)
        if error != OK:
            push_error("Failed to connect to EventBus.%s (error %s)" % [signal_name, error])
            continue
        _connected.push_back(signal_id)

func _disconnect_from_bus() -> void:
    for signal_id in _connected:
        if EventBus.has_signal(signal_id):
            var signal_name := String(signal_id)
            var callable := Callable(self, "_on_signal_received").bind(signal_name)
            if EventBus.is_connected(signal_id, callable):
                EventBus.disconnect(signal_id, callable)
    _connected.clear()

func _on_signal_received(payload: Dictionary, signal_name: String) -> void:
    var harness := get_parent()
    if harness and harness.has_method("append_log"):
        harness.append_log(signal_name, payload)
