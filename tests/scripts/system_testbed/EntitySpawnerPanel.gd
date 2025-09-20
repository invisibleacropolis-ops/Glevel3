extends PanelContainer
class_name EntitySpawnerPanel
"""UI controller responsible for spawning archetype-driven entities into the testbed."""

const ENTITY_DIRECTORY := "res://assets/entity_archetypes/"
const ENTITY_SCENE_PATH := "res://src/entities/Entity.tscn"

const EntityData := preload("res://src/core/EntityData.gd")
const Entity := preload("res://src/entities/Entity.gd")

@onready var _archetype_selector: OptionButton = %ArchetypeSelector
@onready var _spawn_button: Button = %SpawnButton
@onready var _status_label: Label = %SpawnStatusLabel

var _test_environment: Node

func _ready() -> void:
    """Initialises the archetype list and wires UI interactions."""
    _wire_ui_signals()
    _populate_archetype_selector()

func _wire_ui_signals() -> void:
    """Connects UI signals when the expected child controls exist."""
    if not is_instance_valid(_spawn_button):
        push_warning("Spawn button was not found; spawning is disabled until the scene is fully instantiated.")
    else:
        _spawn_button.pressed.connect(_on_spawn_button_pressed)

    if not is_instance_valid(_archetype_selector):
        push_warning("Archetype selector was not found; spawning is disabled until the scene is fully instantiated.")
    else:
        _archetype_selector.item_selected.connect(_on_archetype_selected)

func _populate_archetype_selector() -> void:
    """Builds the dropdown options from the AssetRegistry catalog."""
    if not is_instance_valid(_archetype_selector):
        push_warning("Cannot populate archetype selector because the control is missing.")
        return
    _archetype_selector.clear()
    var registry := AssetRegistry
    if registry == null:
        _update_status("AssetRegistry autoload not available.")
        _set_spawn_button_enabled(false)
        return

    var entries := _collect_archetype_keys(registry.get_asset_catalog())
    if entries.is_empty():
        registry._scan_and_load_assets(ENTITY_DIRECTORY)
        entries = _collect_archetype_keys(registry.get_asset_catalog())

    entries.sort()

    for entry in entries:
        _archetype_selector.add_item(entry)
        var index := _archetype_selector.item_count - 1
        _archetype_selector.set_item_metadata(index, entry)

    if _archetype_selector.item_count == 0:
        _update_status("No EntityData resources found in entity_archetypes.")
        _set_spawn_button_enabled(false)
        return

    _archetype_selector.select(0)
    _set_spawn_button_enabled(true)
    _update_status("Select an archetype and press Spawn to instantiate an entity.")

func _on_archetype_selected(_item_index: int) -> void:
    """Enables spawning once a valid archetype selection exists."""
    var has_selection := _get_selected_archetype_id() != ""
    _set_spawn_button_enabled(has_selection)

func _on_spawn_button_pressed() -> void:
    """Instantiates the selected archetype into the TestEnvironment node."""
    var archetype_id := _get_selected_archetype_id()
    if archetype_id == "":
        _update_status("Select an archetype before spawning.")
        return

    var registry := AssetRegistry
    if registry == null:
        _update_status("AssetRegistry is unavailable.")
        return

    var base_resource := registry.get_asset(archetype_id)
    if base_resource == null:
        _update_status("Unable to locate resource for %s." % archetype_id)
        return
    if not (base_resource is EntityData):
        _update_status("%s is not an EntityData resource." % archetype_id)
        return

    var entity_data: EntityData = base_resource.duplicate(true)
    var entity_scene: PackedScene = load(ENTITY_SCENE_PATH)
    if entity_scene == null:
        _update_status("Base Entity.tscn could not be loaded.")
        return

    var entity_instance := entity_scene.instantiate()
    if not (entity_instance is Entity):
        if entity_instance != null:
            entity_instance.queue_free()
        _update_status("Base entity scene does not provide the Entity script.")
        return

    entity_instance.entity_data = entity_data
    if entity_data.display_name != "":
        entity_instance.name = entity_data.display_name
    else:
        entity_instance.name = archetype_id.get_basename()

    var environment := _resolve_test_environment()
    if environment == null:
        entity_instance.queue_free()
        _update_status("TestEnvironment node is missing from the scene.")
        return

    environment.add_child(entity_instance)
    _update_status("Spawned %s into TestEnvironment." % entity_instance.name)

func _get_selected_archetype_id() -> String:
    """Returns the asset key for the currently highlighted archetype."""
    var selected_index := _archetype_selector.get_selected()
    if selected_index < 0:
        return ""
    var metadata: Variant = _archetype_selector.get_item_metadata(selected_index)
    if metadata is String:
        return metadata as String
    return ""

func _resolve_test_environment() -> Node:
    """Caches a reference to the TestEnvironment node for spawned entities."""
    if is_instance_valid(_test_environment):
        return _test_environment
    var current_scene := get_tree().get_current_scene()
    if current_scene == null:
        return null
    _test_environment = current_scene.get_node_or_null("TestEnvironment")
    return _test_environment

func _collect_archetype_keys(catalog: Dictionary) -> Array[String]:
    """Filters the registry catalog for EntityData resources in the archetype directory."""
    var entries: Array[String] = []
    for asset_key in catalog.keys():
        var resource: Resource = catalog.get(asset_key)
        if resource == null:
            continue
        if not (resource is EntityData):
            continue
        if not resource.resource_path.begins_with(ENTITY_DIRECTORY):
            continue
        entries.append(asset_key)
    return entries

func _set_spawn_button_enabled(is_enabled: bool) -> void:
    """Safely toggles the Spawn button when it exists in the scene tree."""
    if is_instance_valid(_spawn_button):
        _spawn_button.disabled = not is_enabled

func _update_status(message: String) -> void:
    """Safely writes a status message to the UI label when available."""
    if is_instance_valid(_status_label):
        _status_label.text = message
