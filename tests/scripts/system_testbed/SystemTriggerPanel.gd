extends PanelContainer
class_name SystemTriggerPanel
"""
Hosts manual triggers for gameplay systems so engineers can exercise signal flows on demand.
The status label mirrors the currently selected entity so it is obvious when triggers are armed.
"""

const SYSTEM_TESTBED_SCRIPT := preload("res://tests/scripts/system_testbed/SystemTestbed.gd")
const TEST_COMBAT_SYSTEM_SCRIPT := preload("res://tests/scripts/system_testbed/Test_CombatSystem.gd")
const TEST_INVENTORY_SYSTEM_SCRIPT := preload("res://tests/scripts/system_testbed/Test_InventorySystem.gd")
const ENTITY_SPAWNER_PANEL_SCRIPT := preload("res://tests/scripts/system_testbed/EntitySpawnerPanel.gd")
const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")

const HEALTH_POTION_ITEM_ID := "Health Potion"
const DEFAULT_ATTACK_DAMAGE := 10
const DEFAULT_ATTACK_DAMAGE_TYPE := "physical"
const DEFAULT_STATUS_EFFECT_NAME := "Burning"
const DEFAULT_STATUS_EFFECT_DURATION := 3

@onready var _placeholder_label: Label = %SystemTriggerPlaceholder
@onready var _actions_container: VBoxContainer = %SystemTriggerActions
@onready var _spawn_selected_button: Button = %SpawnSelectedArchetypeButton
@onready var _attack_button: Button = %AttackTargetButton
@onready var _attack_damage_field: SpinBox = %AttackDamageSpinner
@onready var _kill_target_button: Button = %KillTargetButton
@onready var _give_health_potion_button: Button = %GiveHealthPotionButton
@onready var _assign_status_effect_button: Button = %AssignStatusEffectButton
@onready var _status_effect_name_field: LineEdit = %StatusEffectNameField
@onready var _status_effect_duration_field: SpinBox = %StatusEffectDurationSpinner
@onready var _combat_system: TEST_COMBAT_SYSTEM_SCRIPT = %TestCombatSystem
@onready var _inventory_system: TEST_INVENTORY_SYSTEM_SCRIPT = %TestInventorySystem
@onready var _entity_spawner_panel: ENTITY_SPAWNER_PANEL_SCRIPT = %EntitySpawnerPanel
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
    _subscribe_to_spawner_updates()
    _update_button_states()
    _configure_event_bus_controls()
    _update_placeholder_visibility()
    _refresh_spawn_selected_button_label()
    _refresh_attack_button_label()
    _refresh_status_effect_button_label()
    _refresh_kill_button_label()

func _wire_buttons() -> void:
    """Safely connects UI button presses to their handlers."""
    if is_instance_valid(_spawn_selected_button):
        _spawn_selected_button.pressed.connect(_on_spawn_selected_pressed)
    else:
        push_warning("SystemTriggerPanel missing SpawnSelectedArchetypeButton; spawn trigger disabled.")

    if is_instance_valid(_attack_button):
        _attack_button.pressed.connect(_on_attack_target_pressed)
    else:
        push_warning("SystemTriggerPanel missing AttackTargetButton; attack trigger disabled.")

    if is_instance_valid(_attack_damage_field):
        _attack_damage_field.value_changed.connect(
            func(_value: float) -> void:
                _refresh_attack_button_label()
        )
    else:
        push_warning("SystemTriggerPanel missing AttackDamageSpinner; attack trigger will use default damage.")

    if is_instance_valid(_kill_target_button):
        _kill_target_button.pressed.connect(_on_kill_target_pressed)
    else:
        push_warning("SystemTriggerPanel missing KillTargetButton; kill trigger disabled.")

    if is_instance_valid(_give_health_potion_button):
        _give_health_potion_button.pressed.connect(_on_give_health_potion_pressed)
    else:
        push_warning("SystemTriggerPanel missing GiveHealthPotionButton; inventory trigger disabled.")

    if is_instance_valid(_assign_status_effect_button):
        _assign_status_effect_button.pressed.connect(_on_assign_status_effect_pressed)
    else:
        push_warning("SystemTriggerPanel missing AssignStatusEffectButton; status effect trigger disabled.")

    if is_instance_valid(_status_effect_name_field):
        _status_effect_name_field.text_changed.connect(
            func(_text: String) -> void:
                _refresh_status_effect_button_label()
        )
        if _status_effect_name_field.text.is_empty():
            _status_effect_name_field.text = DEFAULT_STATUS_EFFECT_NAME
    else:
        push_warning("SystemTriggerPanel missing StatusEffectNameField; status effect trigger requires manual effect name entry.")

    if is_instance_valid(_status_effect_duration_field):
        _status_effect_duration_field.value_changed.connect(
            func(_value: float) -> void:
                _refresh_status_effect_button_label()
        )
    else:
        push_warning("SystemTriggerPanel missing StatusEffectDurationSpinner; status effect trigger will use default duration.")

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

func _subscribe_to_spawner_updates() -> void:
    """Listens for archetype selection changes to keep spawn shortcuts in sync."""
    var spawner := _resolve_entity_spawner_panel()
    if spawner == null:
        return
    if spawner.has_signal("archetype_selection_changed") and not spawner.archetype_selection_changed.is_connected(_on_archetype_selection_changed):
        spawner.archetype_selection_changed.connect(_on_archetype_selection_changed)
        _refresh_spawn_selected_button_label()
        _update_button_states()

func _resolve_testbed_root() -> SYSTEM_TESTBED_SCRIPT:
    """Caches the SystemTestbed instance that tracks the active entity selection."""
    if is_instance_valid(_testbed_root):
        return _testbed_root
    var current_scene := get_tree().get_current_scene()
    _testbed_root = current_scene as SYSTEM_TESTBED_SCRIPT
    return _testbed_root

func _resolve_entity_spawner_panel() -> ENTITY_SPAWNER_PANEL_SCRIPT:
    """Safely resolves the EntitySpawnerPanel used by spawn triggers."""
    if is_instance_valid(_entity_spawner_panel):
        return _entity_spawner_panel
    var current_scene := get_tree().get_current_scene()
    if current_scene == null:
        return null
    var candidate := current_scene.find_child("EntitySpawnerPanel", true, false)
    if candidate is ENTITY_SPAWNER_PANEL_SCRIPT:
        _entity_spawner_panel = candidate
        return _entity_spawner_panel
    return null

func _resolve_inventory_system() -> TEST_INVENTORY_SYSTEM_SCRIPT:
    """Safely resolves the temporary inventory harness for item triggers."""
    if is_instance_valid(_inventory_system):
        return _inventory_system
    var current_scene := get_tree().get_current_scene()
    if current_scene == null:
        return null
    var candidate := current_scene.find_child("TestInventorySystem", true, false)
    if candidate is TEST_INVENTORY_SYSTEM_SCRIPT:
        _inventory_system = candidate
        return _inventory_system
    return null

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

func _on_archetype_selection_changed(_archetype_id: String) -> void:
    _update_button_states()

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

func _on_attack_target_pressed() -> void:
    """Invokes the temporary combat system to simulate an attack event."""
    var target := _get_active_target()
    if target == null:
        push_warning("Select an entity in the Scene Inspector before attacking.")
        return
    if not is_instance_valid(_combat_system):
        push_warning("Test_CombatSystem node is unavailable; cannot attack target.")
        return
    if not _combat_system.has_method("attack_target"):
        push_warning("Test_CombatSystem is missing attack_target(); trigger skipped.")
        return

    var amount := _get_attack_damage_amount()
    if amount < 0:
        push_warning("Attack damage must be zero or greater.")
        return

    _combat_system.attack_target(target, amount, DEFAULT_ATTACK_DAMAGE_TYPE)

func _get_attack_damage_amount() -> int:
    if is_instance_valid(_attack_damage_field):
        return int(round(_attack_damage_field.value))
    return DEFAULT_ATTACK_DAMAGE

func _refresh_attack_button_label() -> void:
    if not is_instance_valid(_attack_button):
        return
    var amount := _get_attack_damage_amount()
    var target := _get_active_target()
    var target_label := "Target"
    if is_instance_valid(target):
        target_label = target.name
    _attack_button.text = "Attack %s for %d Damage" % [target_label, amount]

func _on_assign_status_effect_pressed() -> void:
    """Invokes the temporary combat system to assign a status effect."""
    var target := _get_active_target()
    if target == null:
        push_warning("Select an entity in the Scene Inspector before assigning status effects.")
        return
    if not is_instance_valid(_combat_system):
        push_warning("Test_CombatSystem node is unavailable; cannot assign status effects.")
        return
    if not _combat_system.has_method("assign_status_effect"):
        push_warning("Test_CombatSystem is missing assign_status_effect(); trigger skipped.")
        return

    var effect_name := _get_status_effect_name()
    if effect_name.is_empty():
        push_warning("Enter a status effect name before assigning it to the target.")
        return

    var duration := _get_status_effect_duration()
    if duration < 1:
        push_warning("Status effect duration must be at least 1 turn.")
        return

    _combat_system.assign_status_effect(target, effect_name, duration)

func _get_status_effect_name() -> String:
    if is_instance_valid(_status_effect_name_field):
        return _status_effect_name_field.text.strip_edges()
    return DEFAULT_STATUS_EFFECT_NAME

func _get_status_effect_duration() -> int:
    if is_instance_valid(_status_effect_duration_field):
        return int(round(max(_status_effect_duration_field.value, 1)))
    return DEFAULT_STATUS_EFFECT_DURATION

func _refresh_status_effect_button_label() -> void:
    if not is_instance_valid(_assign_status_effect_button):
        return
    var effect_name := _get_status_effect_name()
    if effect_name.is_empty():
        effect_name = DEFAULT_STATUS_EFFECT_NAME
    var duration := _get_status_effect_duration()
    var target := _get_active_target()
    var target_label := "Target"
    if is_instance_valid(target):
        target_label = target.name
    _assign_status_effect_button.text = "Assign %s (%d turns) to %s" % [effect_name, duration, target_label]

func _refresh_kill_button_label() -> void:
    if not is_instance_valid(_kill_target_button):
        return
    var target := _get_active_target()
    if is_instance_valid(target):
        _kill_target_button.text = "Kill %s" % target.name
    else:
        _kill_target_button.text = "Kill Target"

func _on_spawn_selected_pressed() -> void:
    """Spawns the currently highlighted archetype into the test environment."""
    var spawner := _resolve_entity_spawner_panel()
    if spawner == null:
        push_warning("SystemTriggerPanel could not locate EntitySpawnerPanel; spawn trigger disabled.")
        return
    if not spawner.has_method("get_selected_archetype_id"):
        push_warning("EntitySpawnerPanel is missing get_selected_archetype_id(); spawn trigger disabled.")
        return
    var archetype_id := spawner.get_selected_archetype_id()
    if archetype_id.strip_edges().is_empty():
        push_warning("Select an archetype in the Entity Spawner before using the shortcut.")
        return
    var entity := spawner.spawn_entity_by_id(archetype_id)
    if entity == null:
        push_warning("Failed to spawn %s via EntitySpawnerPanel." % archetype_id)

func _on_give_health_potion_pressed() -> void:
    """Invokes the temporary inventory system to hand the target a health potion."""
    var target := _get_active_target()
    if target == null:
        push_warning("Select an entity in the Scene Inspector before granting inventory items.")
        return
    var inventory := _resolve_inventory_system()
    if inventory == null:
        push_warning("Test_InventorySystem node is unavailable; cannot grant items.")
        return
    if not inventory.has_method("add_item_to_entity"):
        push_warning("Test_InventorySystem is missing add_item_to_entity(); trigger skipped.")
        return
    inventory.add_item_to_entity(target, HEALTH_POTION_ITEM_ID)

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
    if is_instance_valid(_spawn_selected_button):
        var spawner := _resolve_entity_spawner_panel()
        var can_spawn := false
        if spawner != null and spawner.has_method("get_selected_archetype_id"):
            can_spawn = not spawner.get_selected_archetype_id().strip_edges().is_empty()
        _spawn_selected_button.disabled = not can_spawn
    if is_instance_valid(_attack_button):
        _attack_button.disabled = not has_target
    if is_instance_valid(_attack_damage_field):
        _set_control_enabled(_attack_damage_field, has_target)
    if is_instance_valid(_kill_target_button):
        _kill_target_button.disabled = not has_target
    if is_instance_valid(_give_health_potion_button):
        _give_health_potion_button.disabled = not has_target or _resolve_inventory_system() == null
    if is_instance_valid(_assign_status_effect_button):
        _assign_status_effect_button.disabled = not has_target
    if is_instance_valid(_status_effect_name_field):
        _set_control_enabled(_status_effect_name_field, has_target)
    if is_instance_valid(_status_effect_duration_field):
        _set_control_enabled(_status_effect_duration_field, has_target)
    if is_instance_valid(_emit_event_button):
        _emit_event_button.disabled = not EVENT_BUS_SCRIPT.is_singleton_ready() or _event_selector.item_count == 0
    _update_target_status_label()
    _refresh_spawn_selected_button_label()
    _refresh_attack_button_label()
    _refresh_status_effect_button_label()
    _refresh_kill_button_label()

func _refresh_spawn_selected_button_label() -> void:
    if not is_instance_valid(_spawn_selected_button):
        return
    var spawner := _resolve_entity_spawner_panel()
    if spawner == null:
        _spawn_selected_button.text = "Spawn Selected Archetype"
        return
    var label := ""
    if spawner.has_method("get_selected_archetype_display_label"):
        label = spawner.get_selected_archetype_display_label()
    if label.strip_edges().is_empty() and spawner.has_method("get_selected_archetype_id"):
        label = spawner.get_selected_archetype_id()
    if label.strip_edges().is_empty():
        _spawn_selected_button.text = "Spawn Selected Archetype"
    else:
        _spawn_selected_button.text = "Spawn %s" % label

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
