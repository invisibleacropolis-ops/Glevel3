extends Node
class_name AssetRegistrySingleton

## Registry responsible for discovering handcrafted `.tres` assets and providing
## fast, in-memory lookup access for the rest of the project.
## Designed for Godot 4.4.1.

## Default directories scanned during `_ready()`. The list mirrors the paths
## referenced throughout the design bible and can be customized through the
## exported `directories_to_scan` property.
const DEFAULT_SCAN_DIRECTORIES: Array[String] = [
    "res://assets/",
]

## File extension the registry indexes. Keeping this in a constant makes future
## expansion (e.g., `.res`, `.tres` hybrids) trivial.
const RESOURCE_EXTENSION := ".tres"

## Maps asset identifiers (file names) to the loaded `Resource` objects.
## Using a typed dictionary makes intent explicit for engineers integrating new loaders.
var assets: Dictionary[String, Resource] = {}

## Directories recursively scanned for resources when the singleton becomes ready.
@export var directories_to_scan: Array[String] = DEFAULT_SCAN_DIRECTORIES.duplicate()

func _ready() -> void:
    ## Reset the cache in case the singleton is reloaded during hot-swap testing.
    assets.clear()

    for directory_path in directories_to_scan:
        _scan_and_load_assets(directory_path)

## Scans a directory tree for `.tres` resources and loads them into the registry.
## This helper is intentionally public so tests can target arbitrary mock directories
## without mutating the autoload's startup configuration.
func _scan_and_load_assets(path: String) -> void:
    var normalized_path := _ensure_directory_suffix(path)
    var dir := DirAccess.open(normalized_path)
    if dir == null:
        push_warning("AssetRegistry: Unable to open directory '%s'." % normalized_path)
        return

    dir.list_dir_begin(true, true)
    var file_name := dir.get_next()
    while file_name != "":
        var entry_path := normalized_path + file_name
        if dir.current_is_dir():
            _scan_and_load_assets(entry_path)
        elif file_name.ends_with(RESOURCE_EXTENSION):
            _ingest_resource(entry_path, file_name)

        file_name = dir.get_next()
    dir.list_dir_end()

## Normalizes a directory path so concatenation keeps a single trailing slash.
func _ensure_directory_suffix(path: String) -> String:
    if path == "":
        return path
    if not path.ends_with("/"):
        return path + "/"
    return path

## Loads a resource and records it under the provided key if successful.
func _ingest_resource(resource_path: String, asset_key: String) -> void:
    var resource := ResourceLoader.load(resource_path)
    if resource == null:
        push_error("AssetRegistry: Failed to load resource at '%s'." % resource_path)
        return

    if assets.has(asset_key):
        push_warning("AssetRegistry: Duplicate asset key '%s' encountered. Replacing existing entry." % asset_key)

    assets[asset_key] = resource

## Retrieves a previously loaded asset by file name.
##
## @param asset_name Human-readable key, typically the `.tres` file name.
## @return The registered resource, or `null` when the asset has not been scanned yet.
func get_asset(asset_name: String) -> Resource:
    return assets.get(asset_name, null)

## Checks whether an asset key exists inside the registry cache.
func has_asset(asset_name: String) -> bool:
    return assets.has(asset_name)
