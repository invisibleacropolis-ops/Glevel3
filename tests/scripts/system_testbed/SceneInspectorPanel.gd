extends PanelContainer
class_name SceneInspectorPanel
"""Displays and manages live entities spawned into the System Testbed."""

const ENTITY_SCRIPT := preload("res://src/entities/Entity.gd")
const SYSTEM_TESTBED_SCRIPT := preload("res://tests/scripts/system_testbed/SystemTestbed.gd")

@onready var _tree: Tree = %SceneInspectorTree
@onready var _placeholder_label: Label = %SceneInspectorPlaceholder
@onready var _delete_button: Button = %DeleteSelectedButton

var _test_environment: Node
var _testbed_root: SYSTEM_TESTBED_SCRIPT
var _tree_root: TreeItem
var _entity_items: Dictionary = {}
var _entity_watchers: Dictionary = {}
var _current_selection: ENTITY_SCRIPT

func _ready() -> void:
    """Wires selection hooks and seeds the inspector with current entities."""
    _tree.item_selected.connect(_on_tree_item_selected)
    if _tree.has_signal("nothing_selected"):
        _tree.nothing_selected.connect(_on_tree_nothing_selected)

    if is_instance_valid(_delete_button):
        _delete_button.pressed.connect(_on_delete_button_pressed)
    _update_delete_button_state()

    _test_environment = _resolve_test_environment()
    if _test_environment != null:
        _test_environment.child_entered_tree.connect(_on_environment_child_entered)
        _test_environment.child_exiting_tree.connect(_on_environment_child_exiting)
    else:
        push_warning("SceneInspectorPanel could not locate the TestEnvironment node.")

    _rebuild_tree()

func _resolve_test_environment() -> Node:
    """Caches the TestEnvironment node for child monitoring."""
    if is_instance_valid(_test_environment):
        return _test_environment
    var current_scene := get_tree().get_current_scene()
    if current_scene == null:
        return null
    _testbed_root = current_scene as SYSTEM_TESTBED_SCRIPT
    _test_environment = current_scene.get_node_or_null("TestEnvironment")
    return _test_environment

func _rebuild_tree() -> void:
    """Clears and repopulates the tree to mirror the current environment."""
    _tree.clear()
    _tree_root = null
    _entity_items.clear()
    _clear_entity_watchers()

    if _test_environment == null:
        _placeholder_label.text = "TestEnvironment node is missing from the scene."
        _update_placeholder_visibility()
        _update_delete_button_state()
        return

    _tree_root = _tree.create_item()
    for child in _test_environment.get_children():
        _track_entity(child)

    if is_instance_valid(_current_selection) and _entity_items.has(_current_selection.get_instance_id()):
        _tree.set_selected(_entity_items[_current_selection.get_instance_id()], 0)
    else:
        _current_selection = null
    _update_delete_button_state()
    _update_placeholder_visibility()

func _track_entity(node: Node) -> void:
    """Adds entities to the inspector tree when they appear in the environment."""
    if not _is_entity(node):
        return

    var entity := node as ENTITY_SCRIPT
    var key := entity.get_instance_id()
    if _entity_items.has(key):
        return
    var root := _ensure_tree_root()
    var item := _tree.create_item(root)
    item.set_text(0, _format_entity_label(entity))
    item.set_metadata(0, entity)
    item.set_tooltip_text(0, entity.get_path())
    _entity_items[key] = item
    _watch_entity_data(entity)
    _update_placeholder_visibility()

func _untrack_entity(node: Node) -> void:
    """Removes tree entries when entities exit the TestEnvironment."""
    if not _is_entity(node):
        return

    var entity := node as ENTITY_SCRIPT
    var key := entity.get_instance_id()
    if _entity_items.has(key):
        var item: TreeItem = _entity_items[key]
        if item != null:
            item.free()
        _entity_items.erase(key)
    _unwatch_entity_data(key)

    if _current_selection == entity:
        _current_selection = null
        _tree.deselect_all()
        _set_active_target(null)

    _update_placeholder_visibility()
    _update_delete_button_state()

func _on_environment_child_entered(node: Node) -> void:
    """Responds when new nodes join the TestEnvironment branch."""
    _track_entity(node)

func _on_environment_child_exiting(node: Node) -> void:
    """Purges inspector items as entities leave the environment."""
    _untrack_entity(node)

func _on_tree_item_selected() -> void:
    """Updates the global active target when the operator selects an item."""
    var item := _tree.get_selected()
    if item == null:
        return
    var entity := item.get_metadata(0) as ENTITY_SCRIPT
    if not is_instance_valid(entity):
        _tree.deselect_all()
        _set_active_target(null)
        return
    _current_selection = entity
    _set_active_target(entity)
    _update_delete_button_state()

func _on_tree_nothing_selected() -> void:
    """Clears the active target when the tree loses selection."""
    _current_selection = null
    _set_active_target(null)
    _update_delete_button_state()

func _set_active_target(target: ENTITY_SCRIPT) -> void:
    """Pushes the selection to the testbed root for other panels to consume."""
    if _testbed_root == null or not is_instance_valid(_testbed_root):
        var current_scene := get_tree().get_current_scene()
        _testbed_root = current_scene as SYSTEM_TESTBED_SCRIPT
    if _testbed_root != null:
        _testbed_root.active_target_entity = target

func _update_placeholder_visibility() -> void:
    """Toggles the placeholder message based on inspector population."""
    var has_entities := not _entity_items.is_empty()
    _tree.visible = has_entities
    _placeholder_label.visible = not has_entities
    if _test_environment != null and not has_entities:
        _placeholder_label.text = "No entities have been spawned yet."
    if not has_entities:
        _tree.deselect_all()

func _ensure_tree_root() -> TreeItem:
    """Creates or returns the root TreeItem required for child entries."""
    if _tree_root == null:
        _tree_root = _tree.get_root()
        if _tree_root == null:
            _tree_root = _tree.create_item()
    return _tree_root

func _is_entity(node: Node) -> bool:
    """Validates that a node is an Entity instance with display metadata."""
    return node is ENTITY_SCRIPT

func _format_entity_label(entity: ENTITY_SCRIPT) -> String:
    """Builds the label text presented in the inspector tree."""
    if entity == null:
        return "Unknown Entity"
    var entity_id := _resolve_entity_id(entity)
    var archetype_label := _resolve_archetype_label(entity)
    if archetype_label.is_empty():
        archetype_label = entity.name
    if entity_id.is_empty():
        return archetype_label
    return "%s [%s]" % [archetype_label, entity_id]

func _resolve_entity_id(entity: ENTITY_SCRIPT) -> String:
    if entity == null:
        return ""
    var via_method: StringName = entity.get_entity_id()
    if via_method != StringName():
        return String(via_method)
    if entity.entity_data != null and not entity.entity_data.entity_id.is_empty():
        return entity.entity_data.entity_id
    if entity.has_meta("entity_id"):
        var via_meta: Variant = entity.get_meta("entity_id")
        if via_meta is StringName:
            return String(via_meta)
        if via_meta is String:
            return via_meta
    return ""

func _resolve_archetype_label(entity: ENTITY_SCRIPT) -> String:
    if entity == null:
        return ""
    var data := entity.entity_data
    if data != null:
        if not data.archetype_id.is_empty():
            return data.archetype_id
        if not data.display_name.is_empty():
            return data.display_name
    return entity.name

func _watch_entity_data(entity: ENTITY_SCRIPT) -> void:
    if entity == null:
        return
    var key := entity.get_instance_id()
    var data: Resource = entity.entity_data
    if data == null:
        return
    if _entity_watchers.has(key):
        var existing: Dictionary = _entity_watchers[key]
        var previous_data: Resource = existing.get("data")
        var previous_callable: Callable = existing.get("callable")
        if previous_data == data:
            return
        if is_instance_valid(previous_data) and previous_data.changed.is_connected(previous_callable):
            previous_data.changed.disconnect(previous_callable)
    var callback := Callable(self, "_on_entity_data_changed").bind(key)
    data.changed.connect(callback, Object.CONNECT_REFERENCE_COUNTED)
    _entity_watchers[key] = {"data": data, "callable": callback}

func _unwatch_entity_data(key: int) -> void:
    if not _entity_watchers.has(key):
        return
    var entry: Dictionary = _entity_watchers[key]
    var data: Resource = entry.get("data")
    var callback: Callable = entry.get("callable")
    if is_instance_valid(data) and data.changed.is_connected(callback):
        data.changed.disconnect(callback)
    _entity_watchers.erase(key)

func _clear_entity_watchers() -> void:
    for key in _entity_watchers.keys():
        _unwatch_entity_data(key)

func _on_entity_data_changed(instance_id: int) -> void:
    if not _entity_items.has(instance_id):
        return
    var item: TreeItem = _entity_items[instance_id]
    if item == null:
        return
    var entity := item.get_metadata(0) as ENTITY_SCRIPT
    if not is_instance_valid(entity):
        return
    item.set_text(0, _format_entity_label(entity))

func _update_delete_button_state() -> void:
    """Enables the deletion button only when a valid entity is selected."""
    if not is_instance_valid(_delete_button):
        return
    var can_delete := is_instance_valid(_current_selection)
    _delete_button.disabled = not can_delete

func _on_delete_button_pressed() -> void:
    """Queues the selected entity for deletion and clears the inspector state."""
    if not is_instance_valid(_current_selection):
        _update_delete_button_state()
        return
    var entity := _current_selection
    _set_active_target(null)
    _current_selection = null
    _tree.deselect_all()
    _update_delete_button_state()
    if is_instance_valid(entity):
        entity.queue_free()
