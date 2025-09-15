extends Control

const EVENT_BUS_SCENE := preload("res://src/globals/EventBus.gd")
const EVENT_BUS_NODE_NAME := "EventBus"
const _REQUIRED_FIELD_BORDER_COLOR := Color(0.86, 0.27, 0.27)
const _REQUIRED_FIELD_TOOLTIP_TEMPLATE := "Enter a value for \"%s\" before emitting the signal."
const _REQUIRED_FIELD_BORDER_WIDTH := 2

## Diagnostic scene that allows engineers to emit EventBus signals with mock payloads.
## When combined with the sibling TestListener node, this scene provides a
## self-contained harness for validating the global event bus in isolation.

@onready var _log_label: RichTextLabel = %Log
@onready var _clear_log_button: Button = %ClearLogButton
@onready var _save_log_button: Button = %SaveLogButton
@onready var _replay_log_button: Button = %ReplayLogButton
@onready var _save_dialog: FileDialog = %SaveLogDialog
@onready var _replay_dialog: FileDialog = %ReplayLogDialog
@onready var _listener: Node = $TestListener
@onready var _event_bus: EventBusSingleton = _resolve_event_bus()
@onready var _signals_container: VBoxContainer = %SignalsContainer

## Mapping of EventBus signal names to their emit buttons and field editors.
## Entries are populated at runtime so the harness automatically tracks newly
## documented contracts without requiring additional scene editing.
var _signal_controls: Dictionary = {}
var _has_validation_errors: bool = false

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
    _populate_field_rows(fields_grid, contract.get("required_keys", {}), field_configs, false, signal_name)
    _populate_field_rows(fields_grid, contract.get("optional_keys", {}), field_configs, true, signal_name)

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
    is_optional: bool,
    signal_name: StringName
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
            "default_tooltip": editor.tooltip_text,
        }
        _apply_type_metadata(config, type_hint)
        _apply_empty_value_metadata(config, type_hint, is_optional)
        field_configs[field_name] = config

        var captured_field_name := field_name
        var captured_signal := signal_name
        editor.text_changed.connect(func(_new_text: String) -> void:
            _on_field_text_changed(captured_signal, captured_field_name)
        )

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
    if _has_validation_errors:
        return
    _event_bus.emit_signal(signal_name, payload)

func _gather_payload(signal_name: StringName) -> Dictionary:
    ## Read every configured LineEdit for the provided signal and serialise their
    ## text contents to a usable Dictionary payload.
    var payload: Dictionary = {}
    var fields: Dictionary = _signal_controls[signal_name]["fields"]
    var has_errors := false
    for field_name in fields.keys():
        var field_config: Dictionary = fields[field_name]
        var editor := field_config.get("node") as LineEdit
        if editor == null:
            continue
        var text := editor.text.strip_edges()
        var is_optional: bool = field_config.get("optional", false)
        if text.is_empty():
            if is_optional:
                _clear_field_validation(field_config)
                continue
            _mark_field_invalid(field_name, field_config)
            has_errors = true
            continue
        _clear_field_validation(field_config)
        payload[field_name] = _coerce_field_value(editor.text, field_config)
    _has_validation_errors = has_errors
    return payload

func _mark_field_invalid(field_name: String, field_config: Dictionary) -> void:
    var editor := field_config.get("node") as LineEdit
    if editor == null:
        return

    var message := _REQUIRED_FIELD_TOOLTIP_TEMPLATE % field_name
    editor.tooltip_text = message
    _apply_field_error_styles(editor, field_config)
    field_config["is_invalid"] = true

func _clear_field_validation(field_config: Dictionary) -> void:
    var editor := field_config.get("node") as LineEdit
    if editor == null:
        return

    editor.remove_theme_stylebox_override("normal")
    editor.remove_theme_stylebox_override("focus")
    editor.tooltip_text = field_config.get("default_tooltip", "")
    field_config["is_invalid"] = false

func _apply_field_error_styles(editor: LineEdit, field_config: Dictionary) -> void:
    var styles: Dictionary = _ensure_error_styles(editor, field_config)
    var normal_style := styles.get("normal", null) as StyleBox
    if normal_style:
        editor.add_theme_stylebox_override("normal", normal_style)
    var focus_style := styles.get("focus", null) as StyleBox
    if focus_style:
        editor.add_theme_stylebox_override("focus", focus_style)

func _ensure_error_styles(editor: LineEdit, field_config: Dictionary) -> Dictionary:
    if field_config.has("_error_styles"):
        return field_config["_error_styles"]

    var styles := {}
    styles["normal"] = _create_error_style(editor, editor.get_theme_stylebox("normal", "LineEdit"))
    styles["focus"] = _create_error_style(editor, editor.get_theme_stylebox("focus", "LineEdit"))
    field_config["_error_styles"] = styles
    return styles

func _create_error_style(editor: LineEdit, base_style: StyleBox) -> StyleBox:
    if base_style is StyleBoxFlat:
        var flat := (base_style as StyleBoxFlat).duplicate()
        flat.border_color = _REQUIRED_FIELD_BORDER_COLOR
        flat.border_width_left = max(flat.border_width_left, _REQUIRED_FIELD_BORDER_WIDTH)
        flat.border_width_right = max(flat.border_width_right, _REQUIRED_FIELD_BORDER_WIDTH)
        flat.border_width_top = max(flat.border_width_top, _REQUIRED_FIELD_BORDER_WIDTH)
        flat.border_width_bottom = max(flat.border_width_bottom, _REQUIRED_FIELD_BORDER_WIDTH)
        return flat

    var fallback := StyleBoxFlat.new()
    if editor.has_theme_color("background_color", "LineEdit"):
        fallback.bg_color = editor.get_theme_color("background_color", "LineEdit")
    fallback.draw_center = true
    fallback.border_color = _REQUIRED_FIELD_BORDER_COLOR
    fallback.border_width_left = _REQUIRED_FIELD_BORDER_WIDTH
    fallback.border_width_right = _REQUIRED_FIELD_BORDER_WIDTH
    fallback.border_width_top = _REQUIRED_FIELD_BORDER_WIDTH
    fallback.border_width_bottom = _REQUIRED_FIELD_BORDER_WIDTH
    fallback.corner_radius_top_left = 4
    fallback.corner_radius_top_right = 4
    fallback.corner_radius_bottom_left = 4
    fallback.corner_radius_bottom_right = 4
    return fallback

func _on_field_text_changed(signal_name: StringName, field_name: String) -> void:
    if not _signal_controls.has(signal_name):
        return
    var fields: Dictionary = _signal_controls[signal_name].get("fields", {})
    if not fields.has(field_name):
        return

    var field_config: Dictionary = fields[field_name]
    var editor := field_config.get("node") as LineEdit
    if editor == null:
        return

    var trimmed_text := editor.text.strip_edges()
    if trimmed_text.is_empty():
        if field_config.get("optional", false):
            _clear_field_validation(field_config)
        else:
            _mark_field_invalid(field_name, field_config)
    else:
        _clear_field_validation(field_config)

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
    ## Clear every rendered entry from the signal log and reset the scroll
    ## position so subsequent appends start at the top of the viewport.
    _log_label.clear()
    _log_label.scroll_to_line(0)

func replay_signals_from_json(records_json: Variant) -> void:
    ## Replays a collection of event bus payloads from serialized JSON data. Accepts
    ## either a raw JSON string or a parsed Array of dictionaries containing
    ## `signal_name` and `payload` keys. Emits each entry through the EventBus and
    ## records whether the replay succeeded so engineers can audit rehydrated test
    ## runs directly from the harness UI.
    if _event_bus == null:
        _log_replay_message("EventBus is unavailable; cannot replay signals.")
        push_error("EventBusHarness cannot replay signals without an EventBus instance.")
        return

    var entries: Array = []
    match typeof(records_json):
        TYPE_ARRAY:
            entries = records_json
        TYPE_STRING:
            var json := JSON.new()
            var parse_error: int = json.parse(records_json)
            if parse_error != OK:
                var error_context := "line %d" % json.get_error_line()
                var parse_message := json.get_error_message()
                if parse_message.is_empty():
                    parse_message = error_string(parse_error)
                _log_replay_message(
                    "Failed to parse replay JSON (%s): %s." % [
                        error_context,
                        parse_message,
                    ]
                )
                push_error("Replay JSON parsing failed: %s" % parse_message)
                return
            if typeof(json.data) != TYPE_ARRAY:
                _log_replay_message(
                    "Replay JSON root must be an array but received %s." % type_string(typeof(json.data))
                )
                push_error("Replay data must be a JSON array of dictionaries.")
                return
            entries = json.data
        _:
            _log_replay_message(
                "Replay data must be a JSON string or array but received %s." % type_string(typeof(records_json))
            )
            push_error("Unsupported replay data type supplied to replay_signals_from_json().")
            return

    if entries.is_empty():
        _log_replay_message("Replay JSON did not contain any entries.")
        return

    for index in range(entries.size()):
        var entry := entries[index]
        if typeof(entry) != TYPE_DICTIONARY:
            _log_replay_message("Replay entry %d is not a dictionary; skipping." % (index + 1))
            continue

        var raw_signal_name: Variant = entry.get("signal_name", "")
        var signal_name: StringName = StringName()
        match typeof(raw_signal_name):
            TYPE_STRING_NAME:
                signal_name = raw_signal_name
            TYPE_STRING:
                signal_name = StringName(raw_signal_name)
            _:
                _log_replay_message(
                    "Replay entry %d is missing a valid signal_name; skipping." % (index + 1)
                )
                continue

        var payload: Variant = entry.get("payload", {})
        if typeof(payload) != TYPE_DICTIONARY:
            _log_replay_message(
                "Replay entry %d for %s is missing a dictionary payload; skipping." % [
                    index + 1,
                    String(signal_name),
                ]
            )
            continue

        var error_code: int = _event_bus.emit_signal(signal_name, payload)
        var payload_text: String = JSON.stringify(payload)
        if error_code == OK:
            _log_replay_message(
                "Replayed %s with payload %s (OK)." % [String(signal_name), payload_text]
            )
        else:
            _log_replay_message(
                "Failed to replay %s with payload %s (error %s: %s)." % [
                    String(signal_name),
                    payload_text,
                    error_code,
                    error_string(error_code),
                ]
            )

func export_log(path: String) -> Error:
    ## Persist the current log contents to disk. Returns OK on success so
    ## callers can provide user feedback or retry on failure.
    var destination: String = path.strip_edges()
    if destination.is_empty():
        push_warning("Cannot export signal log: destination path is empty.")
        return ERR_INVALID_PARAMETER

    var directory: String = destination.get_base_dir()
    if not directory.is_empty():
        var resolved_directory: String = ProjectSettings.globalize_path(directory)
        if not DirAccess.dir_exists_absolute(resolved_directory):
            var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(resolved_directory)
            if mkdir_error != OK:
                push_error("Failed to prepare export directory %s (error %s)." % [directory, mkdir_error])
                return mkdir_error

    var file := FileAccess.open(destination, FileAccess.WRITE)
    if file == null:
        var open_error: Error = FileAccess.get_open_error()
        push_error("Failed to export signal log to %s (error %s)." % [destination, open_error])
        return open_error

    file.store_string(_log_label.get_parsed_text())
    file.close()
    print("Signal log exported to %s" % destination)
    return OK

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

    if _clear_log_button:
        _clear_log_button.pressed.connect(clear_log)

    if _save_log_button:
        _save_log_button.pressed.connect(_on_save_log_button_pressed)

    if _replay_log_button:
        _replay_log_button.pressed.connect(_on_replay_log_button_pressed)

    if _save_dialog:
        _save_dialog.file_selected.connect(func(selected_path: String) -> void:
            export_log(selected_path)
        )

    if _replay_dialog:
        _replay_dialog.file_selected.connect(_on_replay_file_selected)

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

func _on_save_log_button_pressed() -> void:
    ## Present a save dialog populated with a timestamped filename so engineers can
    ## export harness runs without leaving the editor.
    if _save_dialog:
        _save_dialog.current_file = _build_default_log_filename()
        if _save_dialog.get_current_dir().is_empty():
            _save_dialog.current_dir = _default_log_directory()
        _save_dialog.popup_centered_ratio()
        return

    var fallback_path: String = _default_log_directory().path_join(_build_default_log_filename())
    export_log(fallback_path)

func _build_default_log_filename() -> String:
    var now: Dictionary = Time.get_datetime_dict_from_system()
    return "event_bus_log_%04d-%02d-%02d_%02d-%02d-%02d.log" % [
        int(now.get("year", 0)),
        int(now.get("month", 0)),
        int(now.get("day", 0)),
        int(now.get("hour", 0)),
        int(now.get("minute", 0)),
        int(now.get("second", 0)),
    ]

func _default_log_directory() -> String:
    return OS.get_user_data_dir()

func _on_replay_log_button_pressed() -> void:
    ## Prompt the engineer to select a previously captured replay JSON file and feed
    ## the chosen path back into the harness once confirmed.
    if _replay_dialog:
        if _replay_dialog.get_current_dir().is_empty():
            _replay_dialog.current_dir = _default_log_directory()
        _replay_dialog.popup_centered_ratio()
        return

    _log_replay_message("Replay dialog unavailable; cannot select a log file.")

func _on_replay_file_selected(selected_path: String) -> void:
    var trimmed_path: String = selected_path.strip_edges()
    if trimmed_path.is_empty():
        _log_replay_message("Replay cancelled: no file selected.")
        return

    var file := FileAccess.open(trimmed_path, FileAccess.READ)
    if file == null:
        var open_error: int = FileAccess.get_open_error()
        _log_replay_message(
            "Failed to open replay file %s (error %s: %s)." % [
                trimmed_path,
                open_error,
                error_string(open_error),
            ]
        )
        push_error("Unable to open replay file %s" % trimmed_path)
        return

    var contents := file.get_as_text()
    file.close()
    replay_signals_from_json(contents)

func _log_replay_message(message: String) -> void:
    if _log_label == null:
        push_warning(message)
        return

    var timestamp: String = Time.get_time_string_from_system()
    _log_label.append_text("[%s] %s\n" % [timestamp, message])
    var last_line: int = _log_label.get_line_count() - 1
    if last_line < 0:
        last_line = 0
    _log_label.scroll_to_line(last_line)
