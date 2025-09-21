extends PanelContainer
class_name ComponentViewerPanel
"""Dynamic component inspector for entities selected in the System Testbed."""

const ENTITY_SCRIPT := preload("res://src/entities/Entity.gd")
const SYSTEM_TESTBED_SCRIPT := preload("res://tests/scripts/system_testbed/SystemTestbed.gd")

const _IGNORED_PROPERTY_NAMES := {
    "resource_local_to_scene": true,
    "resource_name": true,
    "resource_path": true,
    "script": true,
}

@export var auto_connect_to_system_testbed := true
@export var read_only := false

@onready var _component_body: VBoxContainer = %ComponentViewerBody
@onready var _placeholder_label: Label = %ComponentViewerPlaceholder

var _testbed_root: SYSTEM_TESTBED_SCRIPT
var _current_target: ENTITY_SCRIPT
var _active_manifest: Dictionary = {}
#: Maps component keys to duplicated resources for the current inspection target.
var _property_bindings: Array[Dictionary] = []

func _ready() -> void:
    """Connects to the System Testbed and prepares the initial placeholder state."""
    _show_placeholder("Select an entity to inspect component data.")
    if auto_connect_to_system_testbed:
        call_deferred("_initialise_connections")

func _initialise_connections() -> void:
    """Resolves the SystemTestbed singleton and listens for selection changes."""
    _testbed_root = _resolve_testbed_root()
    if _testbed_root == null:
        push_warning("ComponentViewerPanel could not locate the SystemTestbed root node.")
        return
    if not _testbed_root.active_target_entity_changed.is_connected(_on_active_target_entity_changed):
        _testbed_root.active_target_entity_changed.connect(_on_active_target_entity_changed)
    _on_active_target_entity_changed(_testbed_root.active_target_entity)

func _resolve_testbed_root() -> SYSTEM_TESTBED_SCRIPT:
    """Locates the SystemTestbed node driving inter-panel coordination."""
    var current_scene := get_tree().get_current_scene()
    if current_scene == null:
        return null
    return current_scene as SYSTEM_TESTBED_SCRIPT

func _on_active_target_entity_changed(target: Node) -> void:
    """Rebuilds the component UI whenever the inspector selects a new entity."""
    if target is ENTITY_SCRIPT and is_instance_valid(target):
        _current_target = target
        _rebuild_for_entity(_current_target)
    else:
        _current_target = null
        _clear_component_views()
        _show_placeholder("Select an entity to inspect component data.")

func inspect_entity(target: Node) -> void:
    """Public helper allowing external callers to drive entity inspection manually."""
    _on_active_target_entity_changed(target)

func clear_inspection(message: String = "Select an entity to inspect component data.") -> void:
    """Clears the current entity selection and displays the supplied placeholder."""
    _current_target = null
    _clear_component_views()
    _show_placeholder(message)

func _rebuild_for_entity(entity: ENTITY_SCRIPT) -> void:
    """Generates editor widgets for each component attached to the entity."""
    _clear_component_views()
    if entity == null or not is_instance_valid(entity):
        _show_placeholder("Select an entity to inspect component data.")
        return
    var data: EntityData = entity.entity_data
    if data == null:
        _show_placeholder("The selected entity does not expose EntityData.")
        return
    var manifest: Dictionary = data.list_components()
    if manifest.is_empty():
        _show_placeholder("The selected entity has no registered components.")
        return

    _placeholder_label.visible = false
    _active_manifest.clear()
    _property_bindings.clear()
    var keys: Array[String] = []
    for key in manifest.keys():
        keys.append(String(key))
    keys.sort()
    for component_key_string in keys:
        var component_key := StringName(component_key_string)
        var component: Resource = manifest.get(component_key)
        if component == null:
            continue
        _active_manifest[component_key] = component
        var section := _build_component_section(component_key, component)
        if section != null:
            _component_body.add_child(section)

func _build_component_section(component_key: StringName, component: Resource) -> VBoxContainer:
    """Creates a titled block with editors for every exported property on the component."""
    var section := VBoxContainer.new()
    section.name = "Component_%s" % String(component_key)
    section.add_theme_constant_override("separation", 8)

    var header := Label.new()
    header.text = _format_component_title(component_key)
    header.add_theme_font_size_override("font_size", 16)
    section.add_child(header)

    for property_info in _collect_editable_properties(component):
        var property_row := HBoxContainer.new()
        property_row.add_theme_constant_override("separation", 12)

        var label := Label.new()
        label.text = _format_property_label(property_info.get("name", ""))
        label.tooltip_text = String(property_info.get("name", ""))
        label.custom_minimum_size = Vector2(160, 0)
        property_row.add_child(label)

        var editor := _create_property_editor(component, property_info)
        if editor != null:
            editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            property_row.add_child(editor)
            _register_property_binding(component_key, String(property_info.get("name", "")), property_info.get("type", TYPE_NIL), editor)
        else:
            var value_label := Label.new()
            value_label.text = str(component.get(property_info.get("name")))
            value_label.autowrap_mode = TextServer.AUTOWRAP_WORD
            value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            property_row.add_child(value_label)
            _register_property_binding(component_key, String(property_info.get("name", "")), property_info.get("type", TYPE_NIL), value_label)

        section.add_child(property_row)

    return section

func _collect_editable_properties(component: Resource) -> Array[Dictionary]:
    """Filters the component's property list for exported, user-facing fields."""
    var filtered: Array[Dictionary] = []
    for property_info in component.get_property_list():
        if not (property_info is Dictionary):
            continue
        var usage: int = property_info.get("usage", 0)
        if (usage & PROPERTY_USAGE_GROUP) != 0:
            continue
        if (usage & PROPERTY_USAGE_CATEGORY) != 0:
            continue
        if (usage & PROPERTY_USAGE_EDITOR) == 0:
            continue
        var property_name: String = String(property_info.get("name", ""))
        if property_name == "" or _IGNORED_PROPERTY_NAMES.has(property_name):
            continue
        filtered.append(property_info)
    return filtered

func _create_property_editor(component: Resource, property_info: Dictionary) -> Control:
    """Instantiates a UI control capable of mutating the supplied property."""
    var property_name := String(property_info.get("name", ""))
    if property_name == "":
        return null
    var property_type: int = property_info.get("type", TYPE_NIL)
    var value: Variant = component.get(property_name)
    match property_type:
        TYPE_BOOL:
            var checkbox := CheckBox.new()
            checkbox.button_pressed = bool(value)
            checkbox.toggled.connect(_on_boolean_editor_toggled.bind(component, property_name))
            if read_only:
                checkbox.disabled = true
                checkbox.focus_mode = Control.FOCUS_NONE
            return checkbox
        TYPE_INT:
            var int_editor := SpinBox.new()
            int_editor.step = 1
            int_editor.rounded = true
            int_editor.allow_greater = true
            int_editor.allow_lesser = true
            int_editor.value = int(value)
            _apply_numeric_hints(int_editor, property_info)
            int_editor.value_changed.connect(_on_numeric_editor_value_changed.bind(component, property_name, true))
            if read_only:
                int_editor.editable = false
                int_editor.focus_mode = Control.FOCUS_NONE
            return int_editor
        TYPE_FLOAT:
            var float_editor := SpinBox.new()
            float_editor.step = 0.1
            float_editor.allow_greater = true
            float_editor.allow_lesser = true
            float_editor.value = float(value)
            _apply_numeric_hints(float_editor, property_info)
            float_editor.value_changed.connect(_on_numeric_editor_value_changed.bind(component, property_name, false))
            if read_only:
                float_editor.editable = false
                float_editor.focus_mode = Control.FOCUS_NONE
            return float_editor
        TYPE_STRING, TYPE_STRING_NAME:
            var line_edit := LineEdit.new()
            line_edit.text = str(value)
            line_edit.placeholder_text = "Enter %s" % property_name
            line_edit.text_submitted.connect(_on_text_editor_submitted.bind(component, property_name, property_type))
            line_edit.focus_exited.connect(_on_text_editor_focus_exited.bind(line_edit))
            if read_only:
                line_edit.editable = false
                line_edit.focus_mode = Control.FOCUS_NONE
            return line_edit
    return null

func _apply_numeric_hints(spin_box: SpinBox, property_info: Dictionary) -> void:
    """Attempts to honour range hints supplied by the exported property."""
    var hint_string := String(property_info.get("hint_string", ""))
    if hint_string == "":
        return
    var tokens := hint_string.split(",", false)
    if tokens.size() >= 1:
        var min_value := tokens[0].to_float()
        spin_box.min_value = min_value
    if tokens.size() >= 2:
        var max_value := tokens[1].to_float()
        spin_box.max_value = max_value
    if tokens.size() >= 3:
        var step := tokens[2].to_float()
        if step > 0.0:
            spin_box.step = step

func _on_numeric_editor_value_changed(value: float, component: Resource, property_name: String, is_integer: bool) -> void:
    """Writes numeric input values directly to the component resource."""
    if not is_instance_valid(component):
        return
    if is_integer:
        component.set(property_name, int(round(value)))
    else:
        component.set(property_name, value)

func _on_boolean_editor_toggled(pressed: bool, component: Resource, property_name: String) -> void:
    """Synchronises toggle controls with the backing resource."""
    if not is_instance_valid(component):
        return
    component.set(property_name, pressed)

func _on_text_editor_submitted(text: String, component: Resource, property_name: String, property_type: int) -> void:
    """Applies submitted text to string-backed properties."""
    if not is_instance_valid(component):
        return
    var value: Variant = text
    if property_type == TYPE_STRING_NAME:
        value = StringName(text)
    component.set(property_name, value)

func _on_text_editor_focus_exited(editor: LineEdit) -> void:
    """Ensures focus changes also commit text edits."""
    if editor == null or not editor.is_inside_tree():
        return
    editor.emit_signal("text_submitted", editor.text)

func _clear_component_views() -> void:
    """Removes any previously generated component UI blocks."""
    if not is_instance_valid(_component_body):
        return
    for child in _component_body.get_children():
        if child == _placeholder_label:
            continue
        child.queue_free()
    _placeholder_label.visible = true
    _property_bindings.clear()
    _active_manifest.clear()

func _show_placeholder(message: String) -> void:
    """Displays guidance text when no component data is available."""
    if not is_instance_valid(_placeholder_label):
        return
    _placeholder_label.visible = true
    _placeholder_label.text = message

func _format_component_title(component_key: StringName) -> String:
    """Produces a human-friendly heading for the component block."""
    var raw := String(component_key)
    if raw.is_empty():
        return "Component"
    return raw.capitalize().replace("_", " ")

func _format_property_label(property_name: String) -> String:
    """Transforms property identifiers into readable labels."""
    if property_name.is_empty():
        return "Property"
    var words := property_name.split("_", false)
    for i in range(words.size()):
        words[i] = words[i].capitalize()
    return " ".join(words)

func _register_property_binding(component_key: StringName, property_name: String, property_type: int, control: Control) -> void:
    """Records a UI control so read-only overlays can poll live component values."""
    if control == null:
        return
    var normalized_name := property_name.strip_edges()
    if normalized_name == "":
        return
    var binding := {
        "component_key": component_key,
        "property_name": StringName(normalized_name),
        "type": property_type,
        "control": control,
    }
    _property_bindings.append(binding)

func sync_controls_from_components() -> void:
    """Updates registered controls from the active entity's component resources."""
    if not read_only:
        return
    if _active_manifest.is_empty():
        return
    for binding in _property_bindings:
        var control: Control = binding.get("control")
        if control == null or not is_instance_valid(control):
            continue
        var component_key: StringName = binding.get("component_key")
        var component: Resource = _active_manifest.get(component_key)
        if component == null:
            continue
        var property_name: StringName = binding.get("property_name")
        var value: Variant = component.get(property_name)
        var property_type: int = int(binding.get("type", TYPE_NIL))
        control.set_block_signals(true)
        match property_type:
            TYPE_BOOL:
                if control is CheckBox:
                    control.button_pressed = bool(value)
            TYPE_INT:
                if control is SpinBox:
                    control.value = int(value)
                elif control is Label:
                    control.text = str(value)
            TYPE_FLOAT:
                if control is SpinBox:
                    control.value = float(value)
                elif control is Label:
                    control.text = str(value)
            TYPE_STRING, TYPE_STRING_NAME:
                if control is LineEdit:
                    control.text = str(value)
                elif control is Label:
                    control.text = str(value)
            _:
                if control is Label:
                    control.text = str(value)
        control.set_block_signals(false)
