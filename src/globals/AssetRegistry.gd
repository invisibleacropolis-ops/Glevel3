extends Node
class_name AssetRegistry

## Registry responsible for loading and providing game assets.
## Designed for Godot 4.4.1.

var assets := {}

func _ready() -> void:
    # Preload default item assets on startup.
    _scan_and_load_assets("res://assets/items/")

## Scans a directory for .tres resources and loads them into the registry.
func _scan_and_load_assets(path: String) -> void:
    var dir := DirAccess.open(path)
    if dir:
        dir.list_dir_begin()
        var file_name := dir.get_next()
        while file_name != "":
            if file_name.ends_with(".tres"):
                var res := load(path + file_name)
                if res:
                    assets[file_name] = res
                else:
                    push_error("Failed to load: " + file_name)
            file_name = dir.get_next()
        dir.list_dir_end()
    else:
        push_error("Failed to open directory: %s" % path)

## Retrieves a previously loaded asset by file name.
func get_asset(name: String) -> Resource:
    return assets.get(name, null)
