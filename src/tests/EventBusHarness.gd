extends Control

const EVENT_BUS_SCENE := preload("res://src/globals/EventBus.gd")
const EVENT_BUS_NODE_NAME := "EventBus"

## Diagnostic scene that allows engineers to emit EventBus signals with mock payloads.
## When combined with the sibling TestListener node, this scene provides a
## self-contained harness for validating the global event bus in isolation.

@onready var _log_label: RichTextLabel = %Log
@onready var _listener: Node = $TestListener
@onready var _event_bus: EventBusSingleton = _resolve_event_bus()
@onready var _signals_container: VBoxContainer = %SignalsContainer

## Mapping of EventBus signal names to their emit buttons and field editors.
## Entries are populated at runtime so the harness automatically tracks newly
## documented contracts without requiring additional scene editing.
var _signal_controls: Dictionary = {}

func _ready() -> void:
    ## Wire the UI controls to the EventBus emitters once the scene tree is ready.
    _build_signal_controls()
    _wire_signal_controls()
    _configure_listener()

func _build_signal_controls() -> void:
    ## Iterate over EventBus signal contracts and generate the harness UI on the fly
    ## so future signals become testable without hand-authoring extra nodes.
    if _signals_container == null:
        push_warning("EventBusHarness is missing its SignalsContainer; UI cannot be generated.")
        _signal_controls.clear()
        return

    for child in _signals_container.get_children():
        child.queue_free()

    _signal_controls.clear()

    var contracts: Dictionary = EventBusSingleton.SIGNAL_CONTRACTS
    var signal_names: Array[String] = []
    for contract_name in contracts.keys():
        signal_names.append(String(contract_name))
    signal_names.sort()

    var is_first_section := true
    for signal_name_text in signal_names:
        if not is_first_section:
            _signals_container.add_child(HSeparator.new())
        is_first_section = false

        var signal_name: StringName = StringName(signal_name_text)
        var contract: Dictionary = contracts.get(signal_name, null)
        if contract == null:
            contract = contracts.get(signal_name_text, {})
        if contract == null:
            contract = {}
        var control_metadata: Dictionary = _create_signal_section(signal_name, contract)
        _signal_controls[signal_name] = control_metadata

func _create_signal_section(signal_name: StringName, contract: Dictionary) -> Dictionary:
    ## Build a VBox container with labels, editors, and an emit button describing a
    ## single EventBus signal contract. Returns metadata for the harness runtime.
    var section := VBoxContainer.new()
    section.name = "%sSection" % String(signal_name)
    section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _signals_container.add_child(section)

    var title := Label.new()
    title.text = String(signal_name)
    section.add_child(title)

    var description: String = contract.get("description", "")
    if not description.is_empty():
        var blurb := Label.new()
        blurb.text = description
        blurb.autowrap_mode = Label.AUTOWRAP_WORD_SMART
        blurb.theme_type_variation = "DescriptionLabel"
        section.add_child(blurb)

    var fields_grid := GridContainer.new()
    fields_grid.columns = 2
    section.add_child(fields_grid)

    var field_configs: Dictionary = {}
    _populate_field_rows(fields_grid, contract.get("required_keys", {}), field_configs, false)
    _populate_field_rows(fields_grid, contract.get("optional_keys", {}), field_configs, true)

    var button := Button.new()
    button.text = "Emit %s" % String(signal_name)
    section.add_child(button)

    return {
        "button": button,
        "fields": field_configs,
    }

func _populate_field_rows(
    grid: GridContainer,
    definitions: Dictionary,
    field_configs: Dictionary,
    is_optional: bool
) -> void:
    ## Instantiate the label/editor pairs for a set of payload keys and capture the
    ## metadata the harness uses when serialising button presses into dictionaries.
    if definitions.is_empty():
        return

    var normalized: Dictionary = {}
    for raw_key in definitions.keys():
        normalized[String(raw_key)] = definitions[raw_key]

    var field_names: Array[String] = normalized.keys()
    field_names.sort()

    for field_name in field_names:
        var type_hint: Variant = normalized[field_name]

        var label := Label.new()
        label.text = _format_field_label(field_name, is_optional)
        label.tooltip_text = _describe_type_hint(type_hint)
        grid.add_child(label)

        var editor := LineEdit.new()
        editor.placeholder_text = _build_field_placeholder(field_name, type_hint, is_optional)
        editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        grid.add_child(editor)

        var config: Dictionary = {
            "node": editor,
            "optional": is_optional,
        }
        _apply_type_metadata(config, type_hint)
        _apply_empty_value_metadata(config, type_hint, is_optional)
        field_configs[field_name] = config

func _format_field_label(field_name: String, is_optional: bool) -> String:
    if is_optional:
        return "%s (optional)" % field_name
    return field_name

func _build_field_placeholder(field_name: String, type_hint: Variant, is_optional: bool) -> String:
    var example: String = _suggest_example_value(type_hint)
    var prefix: String = field_name
    if is_optional:
        prefix += " (optional)"
    if example.is_empty():
        return prefix
    return "%s – e.g. %s" % [prefix, example]

func _describe_type_hint(type_hint: Variant) -> String:
    var type_ids: Array[int] = _extract_type_ids(type_hint)
    if type_ids.is_empty():
        return ""
    var descriptions: Array[String] = []
    for type_id in type_ids:
        descriptions.append(type_string(type_id))
    descriptions.sort()
    return ", ".join(descriptions)

func _apply_type_metadata(config: Dictionary, type_hint: Variant) -> void:
    var type_ids: Array[int] = _extract_type_ids(type_hint)
    if type_ids.size() == 1 and type_ids[0] == TYPE_STRING_NAME:
        config["type"] = TYPE_STRING_NAME

func _apply_empty_value_metadata(config: Dictionary, type_hint: Variant, is_optional: bool) -> void:
    if is_optional:
        return
    var type_ids: Array[int] = _extract_type_ids(type_hint)
    if TYPE_DICTIONARY in type_ids:
        config["empty_value"] = {}
    elif TYPE_ARRAY in type_ids:
        config["empty_value"] = []

func _suggest_example_value(type_hint: Variant) -> String:
    for type_id in _extract_type_ids(type_hint):
        match type_id:
            TYPE_BOOL:
                return "true"
            TYPE_INT:
                return "1"
            TYPE_FLOAT:
                return "0.5"
            TYPE_DICTIONARY:
                return "{\"key\": \"value\"}"
            TYPE_ARRAY:
                return "[1, 2, 3]"
            TYPE_STRING_NAME, TYPE_STRING:
                return "value"
    return ""

func _extract_type_ids(type_hint: Variant) -> Array[int]:
    var ids: Array[int] = []
    match typeof(type_hint):
        TYPE_INT:
            ids.append(type_hint)
        TYPE_ARRAY:
            for element in type_hint:
                if typeof(element) == TYPE_INT and not ids.has(element):
                    ids.append(element)
    return ids

func _emit_signal(signal_name: StringName) -> void:
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

func _gather_payload(signal_name: StringName) -> Dictionary:
    ## Read every configured LineEdit for the provided signal and serialise their
    ## text contents to a usable Dictionary payload.
    var payload: Dictionary = {}
    var fields: Dictionary = _signal_controls[signal_name]["fields"]
    for field_name in fields.keys():
        var field_config: Dictionary = fields[field_name]
        var editor := field_config.get("node") as LineEdit
        if editor == null:
            continue
        var text := editor.text.strip_edges()
        var is_optional: bool = field_config.get("optional", false)
        if text.is_empty():
            if is_optional:
                continue
            if field_config.has("empty_value"):
                payload[field_name] = field_config["empty_value"]
                continue
        payload[field_name] = _coerce_field_value(editor.text, field_config)
    return payload

func _coerce_field_value(raw_text: String, field_config: Dictionary = {}) -> Variant:
    ## Attempt to coerce free-form text into a richer Variant type. Supports JSON,
    ## integers, floats, booleans and configurable fallbacks via the supplied
    ## field configuration metadata.
    var value: String = raw_text.strip_edges()
    if value.is_empty():
        return field_config.get("empty_value", "")

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

    if field_config.get("type") == TYPE_STRING_NAME:
        return StringName(value)

    return value

func append_log(signal_name: String, payload: Dictionary) -> void:
    ## Helper used by the TestListener to render an easily scannable log entry.
    var timestamp: String = Time.get_time_string_from_system()
    var payload_text: String = JSON.stringify(payload)
    _log_label.append_text("[%s] %s -> %s\n" % [timestamp, signal_name, payload_text])
    var last_line: int = _log_label.get_line_count() - 1
    if last_line < 0:
        last_line = 0
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
            var signal_to_emit: StringName = signal_name
            button.pressed.connect(func() -> void:
                _emit_signal(signal_to_emit)
            )

func _configure_listener() -> void:
    ## Lazily propagate the resolved EventBus reference to the sibling listener so
    ## it can subscribe using the same instance created or located by the harness.
    if _listener and _listener.has_method("set_event_bus"):
        _listener.call_deferred("set_event_bus", _event_bus)

func _resolve_event_bus() -> EventBusSingleton:
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
        return existing as EventBusSingleton

    var event_bus := EVENT_BUS_SCENE.new() as EventBusSingleton
    event_bus.name = EVENT_BUS_NODE_NAME
    if root.is_node_ready():
        root.add_child(event_bus)
    else:
        # When scenes are still being instanced the SceneTree forbids immediate
        # structural mutations. Defer the add_child() call so the harness can
        # spawn an isolated EventBus without tripping the engine safeguard
        # mentioned in the runtime warning.
        root.call_deferred("add_child", event_bus)
    return event_bus
