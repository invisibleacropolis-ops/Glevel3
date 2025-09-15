extends Control

const EVENT_BUS_SCENE := preload("res://src/globals/EventBus.gd")
const EVENT_BUS_NODE_NAME := "EventBus"

## Diagnostic scene that allows engineers to emit EventBus signals with mock payloads.
## When combined with the sibling TestListener node, this scene provides a
## self-contained harness for validating the global event bus in isolation.

@onready var _log_label: RichTextLabel = %Log
@onready var _listener: Node = $TestListener
@onready var _event_bus: Node = _resolve_event_bus()

## Mapping of EventBus signal names to their emit buttons and field editors.
## Each LineEdit represents a payload key that will be serialized before
## emission. The nodes referenced here are marked as unique within the scene
## tree so they can be accessed through the %NodeName shorthand.
@onready var _signal_controls: Dictionary = {
    "entity_killed": {
        "button": %EntityKilledEmitButton,
        "fields": {
            "entity_id": %EntityKilledEntityId,
            "killer_id": %EntityKilledKillerId,
        },
    },
    "item_acquired": {
        "button": %ItemAcquiredEmitButton,
        "fields": {
            "item_id": %ItemAcquiredItemId,
            "quantity": %ItemAcquiredQuantity,
        },
    },
    "quest_state_changed": {
        "button": %QuestStateChangedEmitButton,
        "fields": {
            "quest_id": %QuestStateChangedQuestId,
            "state": %QuestStateChangedState,
        },
    },
}

func _ready() -> void:
    ## Wire the UI controls to the EventBus emitters once the scene tree is ready.
    _wire_signal_controls()
    _configure_listener()

func _emit_signal(signal_name: String) -> void:
    ## Construct a payload dictionary from the configured LineEdits and emit the
    ## signal on the shared EventBus singleton.
    if not _signal_controls.has(signal_name):
        push_warning("Unknown signal requested: %s" % signal_name)
        return

    if _event_bus == null:
        push_error("EventBus is unavailable; cannot emit \"%s\"." % signal_name)
        return

    var payload: Dictionary = _gather_payload(signal_name)
    _event_bus.emit_signal(signal_name, payload)

func _gather_payload(signal_name: String) -> Dictionary:
    ## Read every configured LineEdit for the provided signal and serialise their
    ## text contents to a usable Dictionary payload.
    var payload: Dictionary = {}
    var fields: Dictionary = _signal_controls[signal_name]["fields"]
    for field_name in fields.keys():
        var editor := fields[field_name] as LineEdit
        if editor == null:
            continue
        payload[field_name] = _coerce_field_value(editor.text)
    return payload

func _coerce_field_value(raw_text: String) -> Variant:
    ## Attempt to coerce free-form text into a richer Variant type. Supports JSON,
    ## integers, floats, booleans and defaults to string content.
    var value: String = raw_text.strip_edges()
    if value.is_empty():
        return ""

    var json := JSON.new()
    if json.parse(value) == OK:
        return json.data

    if value.is_valid_int():
        return value.to_int()
    if value.is_valid_float():
        return value.to_float()

    var lower: String = value.to_lower()
    if lower == "true":
        return true
    if lower == "false":
        return false

    return value

func append_log(signal_name: String, payload: Dictionary) -> void:
    ## Helper used by the TestListener to render an easily scannable log entry.
    var timestamp: String = Time.get_time_string_from_system()
    var payload_text: String = JSON.stringify(payload)
    _log_label.append_text("[%s] %s -> %s\n" % [timestamp, signal_name, payload_text])
    var last_line := max(_log_label.get_line_count() - 1, 0)
    _log_label.scroll_to_line(last_line)

func clear_log() -> void:
    ## Intentionally exposed for future automation or UI additions.
    _log_label.clear()

func _wire_signal_controls() -> void:
    ## Connect each emit button to its corresponding signal callback so the harness UI
    ## can trigger EventBus emissions without additional boilerplate.
    for signal_name in _signal_controls.keys():
        var button := _signal_controls[signal_name]["button"] as Button
        if button:
            button.pressed.connect(func() -> void:
                _emit_signal(signal_name)
            )

func _configure_listener() -> void:
    ## Lazily propagate the resolved EventBus reference to the sibling listener so
    ## it can subscribe using the same instance created or located by the harness.
    if _listener and _listener.has_method("set_event_bus"):
        _listener.call_deferred("set_event_bus", _event_bus)

func _resolve_event_bus() -> Node:
    ## Locate the shared EventBus singleton in the active SceneTree or spawn a
    ## private instance when running the harness in isolation. The private
    ## instance mirrors the autoload configuration used in production builds.
    var tree := get_tree()
    if tree == null:
        push_error("SceneTree is unavailable; cannot resolve EventBus.")
        return null

    var root := tree.get_root()
    if root == null:
        push_error("Tree root is unavailable; cannot resolve EventBus.")
        return null

    var existing := root.get_node_or_null(EVENT_BUS_NODE_NAME)
    if existing:
        return existing

    var event_bus := EVENT_BUS_SCENE.new()
    event_bus.name = EVENT_BUS_NODE_NAME
    root.add_child(event_bus)
    return event_bus
