extends CanvasLayer
class_name EntityInspectorOverlaySingleton
"""Autoloaded CanvasLayer that exposes a runtime entity inspection overlay."""

const ENTITY_SCRIPT := preload("res://src/entities/Entity.gd")

const DEFAULT_TOGGLE_ACTION := "debug_toggle_inspector"
const DEFAULT_RAY_LENGTH := 2000.0

@export var toggle_action := DEFAULT_TOGGLE_ACTION
@export var selection_button := MOUSE_BUTTON_LEFT
@export var ray_length := DEFAULT_RAY_LENGTH

@onready var _title_label: Label = %InspectorTitle
@onready var _subtitle_label: Label = %InspectorSubtitle
@onready var _component_panel = %ComponentViewerPanel

var _is_active := false
var _current_entity: ENTITY_SCRIPT = null

func _ready() -> void:
    """Initialises the overlay and ensures the toggle input binding exists."""
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    _ensure_input_action(toggle_action, KEY_F1)
    if is_instance_valid(_component_panel):
        _component_panel.auto_connect_to_system_testbed = false
        _component_panel.read_only = true
        _component_panel.clear_inspection("Click an entity to inspect component data.")
    _update_title(null)
    _update_subtitle()

func _unhandled_input(event: InputEvent) -> void:
    """Listens for the toggle action and selection clicks when active."""
    if event.is_action_pressed(toggle_action):
        _toggle_overlay()
        get_viewport().set_input_as_handled()
        return
    if not _is_active:
        return
    if event is InputEventMouseButton and event.button_index == selection_button and event.pressed:
        _select_entity_under_cursor()
        get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
    """Refreshes live data while the overlay is visible."""
    if not _is_active:
        return
    if _current_entity != null and not is_instance_valid(_current_entity):
        _set_current_entity(null)
        return
    if is_instance_valid(_component_panel):
        _component_panel.sync_controls_from_components()
    _update_subtitle()

func _toggle_overlay() -> void:
    """Toggles the overlay visibility and resets state when hiding."""
    _is_active = not _is_active
    visible = _is_active
    if _is_active:
        if is_instance_valid(_component_panel):
            _component_panel.clear_inspection("Click an entity to inspect component data.")
    else:
        _set_current_entity(null)

func _select_entity_under_cursor() -> void:
    """Performs a raycast from the mouse position to resolve entities under the cursor."""
    var viewport := get_viewport()
    if viewport == null:
        return
    var mouse_position := viewport.get_mouse_position()
    var entity: ENTITY_SCRIPT = _raycast_for_entity_3d(mouse_position)
    if entity == null:
        entity = _raycast_for_entity_2d(mouse_position)
    _set_current_entity(entity)

func _raycast_for_entity_3d(screen_position: Vector2) -> ENTITY_SCRIPT:
    """Attempts to resolve an entity using a 3D physics ray."""
    var viewport := get_viewport()
    if viewport == null:
        return null
    var camera: Camera3D = viewport.get_camera_3d()
    if camera == null:
        return null
    var space_state: World3D = camera.get_world_3d()
    if space_state == null:
        return null
    var from := camera.project_ray_origin(screen_position)
    var direction := camera.project_ray_normal(screen_position)
    var params := PhysicsRayQueryParameters3D.new()
    params.from = from
    params.to = from + direction * ray_length
    params.collide_with_areas = true
    params.collide_with_bodies = true
    var result: Dictionary = space_state.direct_space_state.intersect_ray(params)
    if result.is_empty():
        return null
    var collider: Object = result.get("collider")
    return _resolve_entity_from_node(collider)

func _raycast_for_entity_2d(screen_position: Vector2) -> ENTITY_SCRIPT:
    """Fallback query that supports 2D scenes when no 3D camera is present."""
    var viewport := get_viewport()
    if viewport == null:
        return null
    var world: World2D = viewport.get_world_2d()
    if world == null:
        return null
    var camera: Camera2D = viewport.get_camera_2d()
    if camera == null:
        return null
    var world_point: Vector2 = camera.get_screen_to_world(screen_position)
    var params := PhysicsPointQueryParameters2D.new()
    params.position = world_point
    params.collide_with_areas = true
    params.collide_with_bodies = true
    var results: Array = world.direct_space_state.intersect_point(params, 32)
    if results.is_empty():
        return null
    var collider: Object = results[0].get("collider")
    return _resolve_entity_from_node(collider)

func _resolve_entity_from_node(node: Object) -> ENTITY_SCRIPT:
    """Walks up the scene tree to locate the nearest Entity ancestor."""
    if node == null:
        return null
    if node is ENTITY_SCRIPT:
        return node
    if node is Node:
        var current: Node = node
        while current != null:
            if current is ENTITY_SCRIPT:
                return current
            current = current.get_parent()
    return null

func _set_current_entity(entity: ENTITY_SCRIPT) -> void:
    """Updates the active entity selection and refreshes the UI."""
    if entity != null and not is_instance_valid(entity):
        entity = null
    if _current_entity == entity:
        return
    _current_entity = entity
    if entity == null:
        if is_instance_valid(_component_panel):
            _component_panel.clear_inspection("Click an entity to inspect component data.")
        _update_title(null)
    else:
        if is_instance_valid(_component_panel):
            _component_panel.inspect_entity(entity)
        _update_title(entity)
    _update_subtitle()

func _update_title(entity: ENTITY_SCRIPT) -> void:
    """Writes the overlay title based on the current entity selection."""
    if not is_instance_valid(_title_label):
        return
    if entity == null:
        _title_label.text = "Entity Inspector"
        return
    var label := entity.name
    var data = entity.entity_data
    if data != null:
        if data.display_name != "":
            label = data.display_name
        elif data.entity_id != "":
            label = data.entity_id.capitalize()
    _title_label.text = "Inspecting: %s" % label

func _update_subtitle() -> void:
    """Displays contextual details such as the entity's world position."""
    if not is_instance_valid(_subtitle_label):
        return
    if _current_entity == null or not is_instance_valid(_current_entity):
        _subtitle_label.text = "Click an entity to inspect component data."
        return
    var position: Vector3 = _current_entity.global_position
    var data = _current_entity.entity_data
    var entity_id: String = ""
    if data != null and data.entity_id != "":
        entity_id = String(data.entity_id)
    var descriptor: String = entity_id if entity_id != "" else _current_entity.name
    _subtitle_label.text = "%s — Position %s" % [descriptor, _format_vector3(position)]

func _format_vector3(value: Vector3) -> String:
    """Formats a Vector3 for compact display in the overlay."""
    return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]

func _ensure_input_action(action_name: String, default_key: int) -> void:
    """Creates the toggle input action if it was not defined in the project."""
    if InputMap.has_action(action_name):
        return
    InputMap.add_action(action_name)
    var event := InputEventKey.new()
    event.physical_keycode = default_key
    InputMap.action_add_event(action_name, event)
