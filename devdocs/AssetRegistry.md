# AssetRegistry

The `AssetRegistry` is a lightweight loader responsible for discovering `.tres` resources at startup and exposing them through a uniform lookup API. It is designed for Godot 4.4.1 and lives at `res://src/globals/AssetRegistry.gd`.

## Initialization Sequence
1. **Autoload setup (recommended):** Add `AssetRegistry.gd` as an Autoload singleton (Project Settings → Autoload) so it enters the scene tree during engine boot. Because the script extends `Node`, the `_ready()` callback executes automatically and primes the registry.
2. **Default preload path:** During `_ready()` the registry calls `_scan_and_load_assets("res://assets/items/")`, traversing the directory for `.tres` files and storing each successfully loaded `Resource` in its internal dictionary. This ensures common gameplay assets are immediately available.
3. **Manual instancing (for tests or tools):** You can instantiate the registry manually when running in isolation (for example, unit tests) and call `_scan_and_load_assets()` for the directories you need. The test suite demonstrates this approach to avoid relying on project autoloads.

## Registration Methods
- **Directory scans:** `_scan_and_load_assets(path: String)` opens the provided directory, iterates over its contents, and loads any file ending in `.tres`. Successfully loaded resources are stored in the `assets` dictionary keyed by file name (e.g., `"flame_sword.tres"`). Loading failures trigger `push_error` messages so issues surface in the editor or console.
- **Custom additions:** For ad-hoc registrations (such as procedurally generated resources), you can assign directly into `assets[name] = resource` after ensuring the value is a valid `Resource`. Maintain unique keys to avoid overwriting previously loaded assets.

## Retrieval Patterns
- `get_asset(name: String) -> Resource` returns the resource associated with the requested file name, or `null` when nothing was registered under that key. Callers should null-check the return value before use.
- When querying from gameplay code, prefer using constants or enumerations for the keys to reduce typographical errors.

## Common Use Cases
```gdscript
# Example: retrieving a preloaded asset from the singleton registry.
var sword_data := AssetRegistry.get_asset("heroic_sword.tres")
if sword_data:
    inventory.add_item(sword_data)
else:
    push_warning("Missing asset: heroic_sword.tres")
```

```gdscript
# Example: manually extending the registry during a tool pipeline.
var local_registry := AssetRegistry.new()
local_registry._scan_and_load_assets("res://addons/custom_items/")
var prototype := local_registry.get_asset("prototype_item.tres")
```

## Maintenance Tips
- Keep asset directories flat or ensure `_scan_and_load_assets` is invoked recursively if subdirectories become necessary.
- Clear or rebuild the registry (`assets.clear()`) when hot-reloading resource packs to avoid stale references.
