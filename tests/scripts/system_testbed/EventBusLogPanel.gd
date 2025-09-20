extends PanelContainer
class_name EventBusLogPanel
"""
Streams recent EventBus activity so operators can validate system interactions in real time.
The toolbar provides a quick reset button so each experiment starts with a clean transcript.
"""

const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")

@onready var _placeholder_label: Label = %EventBusLogPlaceholder
@onready var _log_output: RichTextLabel = %EventBusLogOutput
@onready var _clear_button: Button = %ClearLogButton

var _connected_signals: Array[StringName] = []
var _entry_count := 0

func _ready() -> void:
    """Connects to every EventBus signal and prepares the log display."""
    _initialise_log_output()
    _connect_event_bus_signals()
    _wire_actions()
    _update_placeholder_visibility()

func _initialise_log_output() -> void:
    """Clears any stale content from the log label before use."""
    if is_instance_valid(_log_output):
        _log_output.clear()
    _entry_count = 0

func _wire_actions() -> void:
    """Connects toolbar buttons that manage the log content."""
    if is_instance_valid(_clear_button):
        _clear_button.pressed.connect(_on_clear_button_pressed)

func _connect_event_bus_signals() -> void:
    """Iterates through the EventBus signal catalog and hooks the generic handler."""
    var event_bus := _resolve_event_bus()
    if event_bus == null:
        push_warning("EventBus singleton is unavailable; log will remain empty.")
        return

    for signal_data in event_bus.get_signal_list():
        var signal_name := StringName(signal_data.get("name", ""))
        if signal_name == StringName():
            continue
        var callable := Callable(self, "_on_event_bus_signal").bind(signal_name)
        if event_bus.is_connected(signal_name, callable):
            continue
        var error_code := event_bus.connect(signal_name, callable)
        if error_code != OK:
            push_warning("Failed to connect to EventBus signal %s (error %d)." % [signal_name, error_code])
            continue
        _connected_signals.append(signal_name)

func _resolve_event_bus() -> EVENT_BUS_SCRIPT:
    """Returns the active EventBus singleton when registered as an autoload."""
    if not EVENT_BUS_SCRIPT.is_singleton_ready():
        return null
    return EVENT_BUS_SCRIPT.get_singleton()

func _on_event_bus_signal(payload: Variant = null, signal_name: StringName = StringName()) -> void:
    """Generic handler that formats signal payloads into the log feed."""
    if signal_name == StringName():
        signal_name = StringName(str(payload))
        payload = null
    var name_string := String(signal_name)
    if name_string.begins_with("tree_") or name_string == "ready":
        return
    var payload_string := _format_payload(payload)
    var entry := "[b]%s[/b]: %s" % [signal_name, payload_string]
    if is_instance_valid(_log_output):
        _log_output.append_text(entry + "\n")
        _log_output.scroll_to_line(_log_output.get_line_count() - 1)
    _entry_count += 1
    _update_placeholder_visibility()

func _on_clear_button_pressed() -> void:
    """Clears the log output so new experiments start with a blank slate."""
    clear_log()

func clear_log() -> void:
    """Public helper that wipes the log and resets counters."""
    _entry_count = 0
    if is_instance_valid(_log_output):
        _log_output.clear()
    _update_placeholder_visibility()

func _format_payload(payload: Variant) -> String:
    """Produces a readable representation of the payload for the log."""
    if typeof(payload) == TYPE_DICTIONARY:
        var json := JSON.new()
        return json.stringify(payload, "  ")
    return str(payload)

func _update_placeholder_visibility() -> void:
    """Toggles the placeholder text based on whether any log entries exist."""
    var has_entries := _entry_count > 0
    if is_instance_valid(_log_output):
        _log_output.visible = has_entries
    if is_instance_valid(_placeholder_label):
        _placeholder_label.visible = not has_entries
