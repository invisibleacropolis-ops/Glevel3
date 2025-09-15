extends Control

## Diagnostic scene that allows engineers to emit EventBus signals with mock payloads.
## When combined with the sibling TestListener node, this scene provides a
## self-contained harness for validating the global event bus in isolation.

@onready var _log_label: RichTextLabel = %Log

## Mapping of EventBus signal names to their emit buttons and field editors.
## Each LineEdit represents a payload key that will be serialized before
## emission. The nodes referenced here are marked as unique within the scene
## tree so they can be accessed through the %NodeName shorthand.
@onready var _signal_controls := {
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
    for signal_name in _signal_controls.keys():
        var button := _signal_controls[signal_name]["button"] as Button
        if button:
            button.pressed.connect(func() -> void:
                _emit_signal(signal_name)
            )

func _emit_signal(signal_name: String) -> void:
    ## Construct a payload dictionary from the configured LineEdits and emit the
    ## signal on the shared EventBus singleton.
    if not _signal_controls.has(signal_name):
        push_warning("Unknown signal requested: %s" % signal_name)
        return

    var payload := _gather_payload(signal_name)
    EventBus.emit_signal(signal_name, payload)

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
    var value := raw_text.strip_edges()
    if value.is_empty():
        return ""

    var json := JSON.new()
    if json.parse(value) == OK:
        return json.data

    if value.is_valid_int():
        return value.to_int()
    if value.is_valid_float():
        return value.to_float()

    var lower := value.to_lower()
    if lower == "true":
        return true
    if lower == "false":
        return false

    return value

func append_log(signal_name: String, payload: Dictionary) -> void:
    ## Helper used by the TestListener to render an easily scannable log entry.
    var timestamp := Time.get_time_string_from_system()
    var payload_text := JSON.stringify(payload)
    _log_label.append_text("[%s] %s -> %s\n" % [timestamp, signal_name, payload_text])
    var last_line := max(_log_label.get_line_count() - 1, 0)
    _log_label.scroll_to_line(last_line)

func clear_log() -> void:
    ## Intentionally exposed for future automation or UI additions.
    _log_label.clear()
