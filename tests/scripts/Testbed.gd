extends Control
## Component inspection harness that lets designers and engineers load any EntityData
## resource, introspect its exported properties, and edit those values live. The
## node hierarchy is defined by `Component_Testbed.tscn` and wires into this
## controller script to populate UI controls dynamically.

const PROPERTY_EXCLUSIONS := {
    "EntityData": ["components"],
}

var current_entity_data: EntityData

@onready var file_dialog: FileDialog = %EntityFileDialog
@onready var loaded_file_label: Label = %LoadedFileLabel
@onready var component_display: VBoxContainer = %ComponentDisplay
@onready var load_button: Button = %LoadButton
@onready var save_button: Button = %SaveButton

const ULTEnums := preload("res://src/globals/ULTEnums.gd")

func _ready() -> void:
    """Initialises default UI state and connects runtime signals."""
    load_button.pressed.connect(_on_load_button_pressed)
    save_button.pressed.connect(_on_save_button_pressed)
    file_dialog.file_selected.connect(_on_file_dialog_file_selected)
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    file_dialog.filters = PackedStringArray(["*.tres ; EntityData Resources"])
    load_button.tooltip_text = "Browse the filesystem for an EntityData resource."
    save_button.tooltip_text = "Persist the active EntityData resource to disk."
    loaded_file_label.text = "No EntityData loaded"
    save_button.disabled = true
    _render_components()

func _on_load_button_pressed() -> void:
    """Shows the file picker so the operator can choose an EntityData resource."""
    file_dialog.popup_centered_ratio(0.4)

func _on_file_dialog_file_selected(path: String) -> void:
    """Loads the chosen EntityData resource and rebuilds the inspector UI."""
    var resource := load(path)
    if resource == null or not (resource is EntityData):
        push_warning("Component Testbed expected an EntityData resource but received %s" % [path])
        return
    current_entity_data = resource
    loaded_file_label.text = path
    save_button.disabled = false
    _render_components()

func _render_components() -> void:
    """Clears the inspector panel and populates it with the latest resource data."""
    for child in component_display.get_children():
        child.queue_free()

    if current_entity_data == null:
        component_display.add_child(_build_help_label())
        return

    _add_section_header("Entity Manifest")
    _render_resource_properties(current_entity_data, "EntityData")

    _add_section_separator()

    _add_section_header("Components")
    var component_keys := current_entity_data.components.keys()
    component_keys.sort()
    for component_key in component_keys:
        var component_resource: Resource = current_entity_data.components.get(component_key)
        var header := Label.new()
        header.text = "Component: %s" % String(component_key).to_upper()
        header.add_theme_font_size_override("font_size", 18)
        component_display.add_child(header)

        var metadata := ULTEnums.get_component_metadata(component_key)
        if not metadata.is_empty():
            var description := Label.new()
            description.text = metadata.get("description", "")
            description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            description.add_theme_color_override("font_color", Color.DIM_GRAY)
            component_display.add_child(description)

        if component_resource == null:
            var missing := Label.new()
            missing.text = "No resource assigned."
            component_display.add_child(missing)
            continue

        if component_resource.get_script() == null:
            var type_warning := Label.new()
            type_warning.text = "Resource has no script; cannot introspect properties."
            component_display.add_child(type_warning)
            continue

        _render_resource_properties(component_resource, String(component_key), 1)

func _render_resource_properties(resource: Resource, resource_name: String, indent_level: int = 0) -> void:
    """Builds property rows for every exported member on the supplied resource."""
    var exclusions: Array = PROPERTY_EXCLUSIONS.get(resource_name, []) as Array
    for property_info in resource.get_script().get_script_property_list():
        var property_name: String = property_info.get("name", "")
        if property_name == "":
            continue
        if property_name in exclusions:
            continue
        if not property_info.get("usage", 0) & PROPERTY_USAGE_EDITOR:
            continue
        _add_property_row(resource, property_info, indent_level)

func _add_property_row(resource: Resource, property_info: Dictionary, indent_level: int) -> void:
    """Adds a labelled editor row to the inspector for a single property."""
    var property_name: String = property_info.get("name", "")
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    component_display.add_child(row)

    var label := Label.new()
    label.text = "%s%s" % ["    ".repeat(indent_level), property_name]
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var editor := _create_editor_for_property(resource, property_info)
    if editor == null:
        var fallback := Label.new()
        fallback.text = str(resource.get(property_name))
        row.add_child(fallback)
        return

    editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(editor)

func _create_editor_for_property(resource: Resource, property_info: Dictionary) -> Control:
    """Instantiates a context-appropriate editor control for the property."""
    var property_name: String = property_info.get("name", "")
    var property_type: int = property_info.get("type", TYPE_NIL)
    var hint: int = property_info.get("hint", PROPERTY_HINT_NONE)
    var hint_string: String = property_info.get("hint_string", "")
    var value: Variant = resource.get(property_name)

    match property_type:
        TYPE_BOOL:
            return _build_bool_editor(resource, property_name, value)
        TYPE_INT, TYPE_FLOAT:
            if hint == PROPERTY_HINT_ENUM:
                return _build_enum_editor(resource, property_name, value, hint_string)
            return _build_numeric_editor(resource, property_name, value, property_type)
        TYPE_STRING, TYPE_STRING_NAME:
            return _build_string_editor(resource, property_name, value, property_type)
        TYPE_ARRAY, TYPE_DICTIONARY:
            return _build_variant_editor(resource, property_name, value)
        _:
            if value is Resource:
                var display := Button.new()
                display.text = _format_resource_label(value)
                display.disabled = true
                return display
    return null

func _build_bool_editor(resource: Resource, property_name: String, value: Variant) -> Control:
    """Creates a toggle for boolean properties."""
    var check_box := CheckBox.new()
    check_box.button_pressed = bool(value)
    check_box.toggled.connect(
        _on_bool_editor_toggled.bind(resource, property_name)
    )
    return check_box

func _build_enum_editor(resource: Resource, property_name: String, value: Variant, hint_string: String) -> Control:
    """Creates an option selector for enum-style integer exports."""
    var options := OptionButton.new()
    var entries := hint_string.split(",", false)
    var selected_index := 0
    for index in entries.size():
        var entry: String = entries[index].strip_edges()
        if entry.is_empty():
            continue
        var parts := entry.split(":", false, 1)
        var label := parts[0].strip_edges()
        var id := index
        if parts.size() > 1:
            id = parts[1].strip_edges().to_int()
        options.add_item(label, id)
        if int(value) == id:
            selected_index = options.item_count - 1
    options.select(selected_index)
    options.item_selected.connect(
        _on_enum_item_selected.bind(options, resource, property_name)
    )
    return options

func _build_numeric_editor(resource: Resource, property_name: String, value: Variant, property_type: int) -> Control:
    """Creates a SpinBox for integer and float exports."""
    var spin_box := SpinBox.new()
    spin_box.allow_lesser = true
    spin_box.allow_greater = true
    if property_type == TYPE_INT:
        spin_box.step = 1
        spin_box.rounded = true
        spin_box.value = int(value)
    else:
        spin_box.step = 0.1
        spin_box.value = float(value)
    spin_box.value_changed.connect(
        _on_numeric_value_changed.bind(spin_box, property_type, resource, property_name)
    )
    return spin_box

func _build_string_editor(resource: Resource, property_name: String, value: Variant, property_type: int) -> Control:
    """Creates a LineEdit for string-based properties."""
    var line_edit := LineEdit.new()
    line_edit.text = str(value)
    line_edit.placeholder_text = "Enter %s" % property_name
    line_edit.text_submitted.connect(
        _on_line_edit_submitted.bind(line_edit, resource, property_name, property_type)
    )
    line_edit.focus_exited.connect(
        _on_line_edit_focus_exited.bind(line_edit, resource, property_name, property_type)
    )
    return line_edit

func _build_variant_editor(resource: Resource, property_name: String, value: Variant) -> Control:
    """Creates a text editor that serialises complex Variant data."""
    var text_edit := TextEdit.new()
    text_edit.custom_minimum_size = Vector2(0, 120)
    text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    text_edit.text = var_to_str(value)
    text_edit.focus_exited.connect(
        _on_variant_editor_focus_exited.bind(text_edit, resource, property_name)
    )
    return text_edit

func _on_bool_editor_toggled(pressed: bool, resource: Resource, property_name: String) -> void:
    """Routes boolean editor changes to the resource."""
    _on_property_changed(pressed, resource, property_name)

func _commit_string_value(
    line_edit: LineEdit,
    new_text: String,
    resource: Resource,
    property_name: String,
    property_type: int
) -> void:
    """Normalises string input before saving it back to the resource."""
    var final_value: Variant = new_text
    if property_type == TYPE_STRING_NAME:
        final_value = StringName(new_text)
    _on_property_changed(final_value, resource, property_name)
    line_edit.text = str(resource.get(property_name))

func _on_line_edit_submitted(
    new_text: String,
    line_edit: LineEdit,
    resource: Resource,
    property_name: String,
    property_type: int
) -> void:
    """Commits line edit input when Enter is pressed."""
    _commit_string_value(line_edit, new_text, resource, property_name, property_type)

func _on_line_edit_focus_exited(
    line_edit: LineEdit,
    resource: Resource,
    property_name: String,
    property_type: int
) -> void:
    """Persists line edit changes when focus leaves the control."""
    _commit_string_value(line_edit, line_edit.text, resource, property_name, property_type)

func _on_variant_editor_focus_exited(
    text_edit: TextEdit,
    resource: Resource,
    property_name: String
) -> void:
    """Parses multi-line Variant editors when focus changes."""
    var trimmed := text_edit.text.strip_edges()
    if trimmed.is_empty():
        push_warning("Value for %s cannot be empty." % property_name)
        text_edit.text = var_to_str(resource.get(property_name))
        return
    var parsed_value: Variant = str_to_var(trimmed)
    if parsed_value == null and trimmed.to_lower() != "null":
        push_warning("Failed to parse value for %s. Use Godot variant syntax (e.g. [] or {\"key\": value})." % property_name)
        text_edit.text = var_to_str(resource.get(property_name))
        return
    _on_property_changed(parsed_value, resource, property_name)
    text_edit.text = var_to_str(resource.get(property_name))

func _format_resource_label(resource: Resource) -> String:
    """Builds a human-readable caption for nested resource references."""
    if resource.resource_path != "":
        return resource.resource_path
    if resource.resource_name != "":
        return resource.resource_name
    return resource.get_class()

func _build_help_label() -> Label:
    """Returns instructions shown before an EntityData resource is loaded."""
    var label := Label.new()
    label.text = "Select an EntityData .tres file to inspect its manifest and components."
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return label

func _add_section_header(title: String) -> void:
    """Adds a bold section heading to the inspector panel."""
    var header := Label.new()
    header.text = title
    header.add_theme_font_size_override("font_size", 20)
    component_display.add_child(header)

func _add_section_separator() -> void:
    """Inserts visual spacing between major sections."""
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 12)
    component_display.add_child(spacer)

func _on_numeric_value_changed(
    new_value: float,
    spin_box: SpinBox,
    property_type: int,
    resource: Resource,
    property_name: String
) -> void:
    """Normalises numeric editor input and propagates the change."""
    var coerced := new_value
    if property_type == TYPE_INT:
        coerced = int(round(new_value))
        spin_box.value = coerced
    _on_property_changed(coerced, resource, property_name)

func _on_property_changed(new_value: Variant, resource: Resource, property_name: String) -> void:
    """Updates the given resource and logs the change for traceability."""
    if resource == null:
        return
    resource.set(property_name, new_value)
    print("Updated %s on %s to %s" % [
        property_name,
        resource.resource_path,
        str(new_value),
    ])

func _on_enum_item_selected(
    item_index: int,
    options: OptionButton,
    resource: Resource,
    property_name: String
) -> void:
    """Handles OptionButton changes for enum exports."""
    var selected_id := options.get_item_id(item_index)
    _on_property_changed(int(selected_id), resource, property_name)

func _on_save_button_pressed() -> void:
    """Persists the active EntityData resource to disk."""
    if current_entity_data == null:
        return
    if current_entity_data.resource_path.is_empty():
        push_warning("Loaded EntityData has no resource path; cannot save.")
        return
    var error := ResourceSaver.save(current_entity_data, current_entity_data.resource_path)
    if error != OK:
        push_error("Failed to save EntityData: %s" % error)
    else:
        print("Saved entity to: %s" % current_entity_data.resource_path)
