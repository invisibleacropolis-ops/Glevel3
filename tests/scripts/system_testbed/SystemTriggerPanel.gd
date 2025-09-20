extends PanelContainer
class_name SystemTriggerPanel
"""
Hosts manual triggers for gameplay systems so engineers can exercise signal flows on demand.
The status label mirrors the currently selected entity so it is obvious when triggers are armed.
"""

const SYSTEM_TESTBED_SCRIPT := preload("res://tests/scripts/system_testbed/SystemTestbed.gd")
const TEST_COMBAT_SYSTEM_SCRIPT := preload("res://tests/scripts/system_testbed/Test_CombatSystem.gd")
const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")

@onready var _placeholder_label: Label = %SystemTriggerPlaceholder
@onready var _actions_container: VBoxContainer = %SystemTriggerActions
@onready var _apply_damage_button: Button = %ApplyFireDamageButton
@onready var _kill_target_button: Button = %KillTargetButton
@onready var _combat_system: TEST_COMBAT_SYSTEM_SCRIPT = %TestCombatSystem
@onready var _target_status_label: Label = %TargetStatusLabel
@onready var _event_selector: OptionButton = %EventSelector
@onready var _event_description_label: Label = %EventDescriptionLabel
@onready var _payload_editor: VBoxContainer = %PayloadEditor
@onready var _emit_event_button: Button = %EmitEventButton

const OPTIONAL_FIELD_DISABLED_MODULATE := Color(0.7, 0.7, 0.7, 0.6)

var _testbed_root: SYSTEM_TESTBED_SCRIPT
var _payload_field_registry: Dictionary = {}

func _ready() -> void:
    """Initializes connections and builds the EventBus trigger controls."""
    _testbed_root = _resolve_testbed_root()
    _wire_buttons()
    _subscribe_to_target_updates()
    _update_button_states()
    _configure_event_bus_controls()
    _update_placeholder_visibility()

func _wire_buttons() -> void:
    """Safely connects UI button presses to their handlers."""
    if is_instance_valid(_apply_damage_button):
        _apply_damage_button.pressed.connect(_on_apply_damage_pressed)
    else:
        push_warning("SystemTriggerPanel missing ApplyFireDamageButton; damage trigger disabled.")

    if is_instance_valid(_kill_target_button):
        _kill_target_button.pressed.connect(_on_kill_target_pressed)
    else:
        push_warning("SystemTriggerPanel missing KillTargetButton; kill trigger disabled.")

    if is_instance_valid(_emit_event_button):
        _emit_event_button.pressed.connect(_on_emit_event_pressed)
    else:
        push_warning("SystemTriggerPanel missing EmitEventButton; EventBus triggers disabled.")

func _subscribe_to_target_updates() -> void:
    """Listens for active target changes so button state mirrors selection availability."""
    var testbed := _resolve_testbed_root()
    if testbed == null:
        push_warning("SystemTriggerPanel could not resolve SystemTestbed root; target-aware triggers disabled.")
        return
    if not testbed.active_target_entity_changed.is_connected(_on_active_target_entity_changed):
        testbed.active_target_entity_changed.connect(_on_active_target_entity_changed)

func _resolve_testbed_root() -> SYSTEM_TESTBED_SCRIPT:
    """Caches the SystemTestbed instance that tracks the active entity selection."""
    if is_instance_valid(_testbed_root):
        return _testbed_root
    var current_scene := get_tree().get_current_scene()
    _testbed_root = current_scene as SYSTEM_TESTBED_SCRIPT
    return _testbed_root

func _get_active_target() -> Node:
    """Retrieves the currently selected entity from the SystemTestbed."""
    var testbed := _resolve_testbed_root()
    if testbed == null:
        return null
    return testbed.active_target_entity

func _configure_event_bus_controls() -> void:
    """Populates the EventBus trigger dropdown and renders its payload form."""
    if not is_instance_valid(_event_selector):
        push_warning("SystemTriggerPanel missing EventSelector; cannot build EventBus trigger UI.")
        return

    if not _event_selector.item_selected.is_connected(_on_event_selector_item_selected):
        _event_selector.item_selected.connect(_on_event_selector_item_selected)

    var signal_names: Array = EVENT_BUS_SCRIPT.SIGNAL_CONTRACTS.keys()
    signal_names.sort()

    _event_selector.clear()
    for signal_name in signal_names:
        _event_selector.add_item(String(signal_name))

    if _event_selector.item_count == 0:
        _update_event_description("")
        _clear_payload_editor()
        return

    _event_selector.select(0)
    _on_event_selector_item_selected(0)

func _on_event_selector_item_selected(index: int) -> void:
    """Rebuilds the payload editor whenever a different EventBus signal is selected."""
    if not is_instance_valid(_event_selector):
        return
    var signal_name: String = _event_selector.get_item_text(index)
    _render_payload_fields(signal_name)

func _render_payload_fields(signal_name: String) -> void:
    _clear_payload_editor()
    _payload_field_registry.clear()

    var contract: Dictionary = EVENT_BUS_SCRIPT.SIGNAL_CONTRACTS.get(StringName(signal_name), {})
    _update_event_description(contract.get("description", ""))

    if contract.is_empty():
        _payload_editor.add_child(_build_contract_missing_label(signal_name))
        return

    var required: Dictionary = contract.get("required_keys", {})
    if not required.is_empty():
        _payload_editor.add_child(_build_section_label("Required Payload"))
        for key in required.keys():
            _add_payload_field(signal_name, key, required[key], false)

    var optional: Dictionary = contract.get("optional_keys", {})
    if not optional.is_empty():
        _payload_editor.add_child(_build_section_label("Optional Payload"))
        for key in optional.keys():
            _add_payload_field(signal_name, key, optional[key], true)

func _build_section_label(text: String) -> Control:
    var label := Label.new()
    label.text = text
    label.add_theme_color_override("font_color", Color(0.76, 0.79, 0.9))
    label.add_theme_font_size_override("font_size", 14)
    return label

func _build_contract_missing_label(signal_name: String) -> Control:
    var label := Label.new()
    label.text = "Signal %s does not declare a payload contract. Payload editor not generated." % signal_name
    label.autowrap_mode = TextServer.AUTOWRAP_WORD
    return label

func _add_payload_field(signal_name: String, key: StringName, expected_rule: Variant, is_optional: bool) -> void:
    var container := VBoxContainer.new()
    container.add_theme_constant_override("separation", 4)

    var header := HBoxContainer.new()
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var label := Label.new()
    label.text = "%s (%s)" % [key, _describe_expected_rule(expected_rule)]
    label.autowrap_mode = TextServer.AUTOWRAP_WORD
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(label)

    var include_toggle: CheckBox = null
    if is_optional:
        include_toggle = CheckBox.new()
        include_toggle.text = "Include"
        include_toggle.button_pressed = false
        include_toggle.tooltip_text = "Enable to include this optional payload key when emitting the signal."
        header.add_child(include_toggle)

    container.add_child(header)

    var editor := _create_editor_control(key, expected_rule)
    container.add_child(editor)

    if include_toggle != null:
        _set_control_enabled(editor, false)
        include_toggle.toggled.connect(func(pressed: bool) -> void:
            _set_control_enabled(editor, pressed)
        )

    _payload_editor.add_child(container)
    _payload_field_registry[key] = {
        "control": editor,
        "expected_rule": expected_rule,
        "optional": is_optional,
        "toggle": include_toggle,
        "signal": signal_name,
    }

func _create_editor_control(key: StringName, expected_rule: Variant) -> Control:
    var primary_type := _resolve_primary_type(expected_rule)
    match primary_type:
        TYPE_INT:
            var spin := SpinBox.new()
            spin.step = 1
            spin.allow_lesser = true
            spin.allow_greater = true
            spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            return spin
        TYPE_FLOAT:
            var float_spin := SpinBox.new()
            float_spin.step = 0.1
            float_spin.allow_lesser = true
            float_spin.allow_greater = true
            float_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            return float_spin
        TYPE_ARRAY, TYPE_DICTIONARY:
            var text_edit := TextEdit.new()
            text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
            text_edit.custom_minimum_size = Vector2(0, 80)
            if primary_type == TYPE_ARRAY:
                text_edit.text = "[]"
            else:
                text_edit.text = "{}"
            text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
            return text_edit
        _:
            var line_edit := LineEdit.new()
            line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            line_edit.text = _default_string_for_key(key)
            return line_edit

func _set_control_enabled(control: Control, enabled: bool) -> void:
    if control is LineEdit:
        (control as LineEdit).editable = enabled
    elif control is TextEdit:
        (control as TextEdit).editable = enabled
    elif control is SpinBox:
        (control as SpinBox).editable = enabled
    if enabled:
        control.modulate = Color.WHITE
    else:
        control.modulate = OPTIONAL_FIELD_DISABLED_MODULATE

func _clear_payload_editor() -> void:
    if not is_instance_valid(_payload_editor):
        return
    for child in _payload_editor.get_children():
        child.queue_free()

func _update_event_description(text: String) -> void:
    if not is_instance_valid(_event_description_label):
        return
    if text.is_empty():
        _event_description_label.text = "Select an EventBus signal to configure its payload."
        return
    _event_description_label.text = text

func _describe_expected_rule(expected_rule: Variant) -> String:
    if typeof(expected_rule) == TYPE_ARRAY:
        var names := PackedStringArray()
        for value in expected_rule:
            names.append(type_string(int(value)))
        return ", ".join(names)
    return type_string(int(expected_rule))

func _default_string_for_key(key: StringName) -> String:
    var sanitized := String(key).replace(" ", "_")
    return "debug_%s" % sanitized

func _resolve_primary_type(expected_rule: Variant) -> int:
    if typeof(expected_rule) == TYPE_ARRAY and expected_rule.size() > 0:
        return int(expected_rule[0])
    return int(expected_rule)

func _on_apply_damage_pressed() -> void:
    """Invokes the temporary combat system to simulate a fire damage event."""
    var target := _get_active_target()
    if target == null:
        push_warning("Select an entity in the Scene Inspector before applying damage.")
        return
    if not is_instance_valid(_combat_system):
        push_warning("Test_CombatSystem node is unavailable; cannot apply damage.")
        return
    if not _combat_system.has_method("apply_damage"):
        push_warning("Test_CombatSystem is missing apply_damage(); trigger skipped.")
        return
    _combat_system.apply_damage(target, 10, "fire")

func _on_kill_target_pressed() -> void:
    """Invokes the temporary combat system to simulate a kill."""
    var target := _get_active_target()
    if target == null:
        push_warning("Select an entity in the Scene Inspector before triggering a kill.")
        return
    if not is_instance_valid(_combat_system):
        push_warning("Test_CombatSystem node is unavailable; cannot kill target.")
        return
    if not _combat_system.has_method("kill_target"):
        push_warning("Test_CombatSystem is missing kill_target(); trigger skipped.")
        return
    _combat_system.kill_target(target)

func _on_emit_event_pressed() -> void:
    """Broadcasts the selected EventBus signal using values from the payload editor."""
    var event_bus: EVENT_BUS_SCRIPT = _resolve_event_bus()
    if event_bus == null:
        push_warning("EventBus singleton not available; cannot emit signals.")
        return
    var signal_name: String = _get_selected_signal_name()
    if signal_name.is_empty():
        push_warning("Select an EventBus signal before emitting.")
        return

    var payload: Variant = _build_payload_dictionary(signal_name)
    if payload == null:
        return

    var error_code := event_bus.emit_signal(StringName(signal_name), payload)
    if error_code != OK:
        push_warning("Failed to emit %s; error code %d." % [signal_name, error_code])

func _get_selected_signal_name() -> String:
    if not is_instance_valid(_event_selector):
        return ""
    if _event_selector.item_count == 0:
        return ""
    return _event_selector.get_item_text(_event_selector.selected)

func _build_payload_dictionary(signal_name: String) -> Variant:
    var payload: Dictionary = {}
    for key in _payload_field_registry.keys():
        var entry: Dictionary = _payload_field_registry[key]
        var toggle: CheckBox = entry.get("toggle")
        if entry.get("optional", false) and is_instance_valid(toggle) and not toggle.button_pressed:
            continue

        var value: Variant = _coerce_field_value(signal_name, key, entry)
        if value == null:
            return null
        payload[key] = value
    return payload

func _coerce_field_value(signal_name: String, key: StringName, entry: Dictionary) -> Variant:
    var expected_rule: Variant = entry.get("expected_rule")
    var control: Control = entry.get("control")
    var primary_type: int = _resolve_primary_type(expected_rule)

    if control is SpinBox:
        var spin := control as SpinBox
        if primary_type == TYPE_INT:
            return int(spin.value)
        return float(spin.value)

    var text_value := ""
    if control is LineEdit:
        text_value = (control as LineEdit).text
    elif control is TextEdit:
        text_value = (control as TextEdit).text

    match primary_type:
        TYPE_INT:
            if text_value.strip_edges().is_empty():
                return 0
            if not text_value.is_valid_int():
                push_warning("%s payload key '%s' expects an int." % [signal_name, key])
                return null
            return int(text_value)
        TYPE_FLOAT:
            if text_value.strip_edges().is_empty():
                return 0.0
            return text_value.to_float()
        TYPE_DICTIONARY:
            if text_value.strip_edges().is_empty():
                return {}
            var dict_value: Variant = JSON.parse_string(text_value)
            if typeof(dict_value) != TYPE_DICTIONARY:
                push_warning("%s payload key '%s' expects a Dictionary." % [signal_name, key])
                return null
            return dict_value
        TYPE_ARRAY:
            if text_value.strip_edges().is_empty():
                return []
            var array_value: Variant = JSON.parse_string(text_value)
            if typeof(array_value) != TYPE_ARRAY:
                push_warning("%s payload key '%s' expects an Array." % [signal_name, key])
                return null
            return array_value
        TYPE_STRING_NAME:
            return StringName(text_value)
        TYPE_STRING:
            return text_value
        _:
            return text_value

func _resolve_event_bus() -> EVENT_BUS_SCRIPT:
    """Returns the active EventBus singleton when registered as an autoload."""
    if not EVENT_BUS_SCRIPT.is_singleton_ready():
        return null
    return EVENT_BUS_SCRIPT.get_singleton()

func _on_active_target_entity_changed(_target: Node) -> void:
    """Recomputes button enabled state whenever the selection updates."""
    _update_button_states()

func _update_button_states() -> void:
    """Enables target-dependent triggers only when a selection exists."""
    var has_target := is_instance_valid(_get_active_target())
    if is_instance_valid(_apply_damage_button):
        _apply_damage_button.disabled = not has_target
    if is_instance_valid(_kill_target_button):
        _kill_target_button.disabled = not has_target
    if is_instance_valid(_emit_event_button):
        _emit_event_button.disabled = not EVENT_BUS_SCRIPT.is_singleton_ready() or _event_selector.item_count == 0
    _update_target_status_label()

func _update_target_status_label() -> void:
    """Reflects the currently selected entity in the status label."""
    if not is_instance_valid(_target_status_label):
        return
    var target := _get_active_target()
    if is_instance_valid(target):
        _target_status_label.text = "Active target: %s" % target.name
        _target_status_label.add_theme_color_override("font_color", Color(0.7, 0.88, 0.76))
    else:
        _target_status_label.text = "No active entity selected."
        _target_status_label.add_theme_color_override("font_color", Color(0.84, 0.67, 0.49))

func _update_placeholder_visibility() -> void:
    """Hides the placeholder label whenever actionable controls are present."""
    var has_actions := is_instance_valid(_actions_container) and _actions_container.get_child_count() > 0
    if is_instance_valid(_actions_container):
        _actions_container.visible = has_actions
    if is_instance_valid(_placeholder_label):
        _placeholder_label.visible = not has_actions
