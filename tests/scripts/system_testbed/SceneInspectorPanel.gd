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
    if entity.entity_data != null and not entity.entity_data.display_name.is_empty():
        return entity.entity_data.display_name
    return entity.name

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
