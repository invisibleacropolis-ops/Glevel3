# AssetRegistry

The `AssetRegistry` is a lightweight loader responsible for discovering `.tres` resources at startup and exposing them through a uniform lookup API. It is designed for Godot 4.4.1 and lives at `res://src/globals/AssetRegistry.gd`.

## Initialization Sequence
1. **Autoload setup (recommended):** Add `AssetRegistry.gd` as an Autoload singleton (Project Settings → Autoload) so it enters the scene tree during engine boot. Because the script extends `Node`, the `_ready()` callback executes automatically and primes the registry.
2. **Default preload path:** During `_ready()` the registry iterates over the exported `directories_to_scan` array (which defaults to `res://assets/`) and recursively ingests every `.tres` file it finds. Each successfully loaded `Resource` is cached in the internal dictionary so systems can fetch handcrafted data without performing additional disk I/O.
3. **Manual instancing (for tests or tools):** You can instantiate the registry manually when running in isolation (for example, unit tests) and call `_scan_and_load_assets()` for any directory tree you need. The helper preserves the recursive scan behaviour used at runtime, making it ideal for verifying new asset packs before promoting them into the main project.

## Registration Methods
- **Directory scans:** `_scan_and_load_assets(path: String)` opens the provided directory, iterates over its contents, and loads any file ending in `.tres`. The method walks subdirectories automatically, so providing a root such as `res://assets/` discovers the entire handcrafted catalogue. Successfully loaded resources are stored in the `assets` dictionary keyed by file name (e.g., `"flame_sword.tres"`). Loading failures trigger `push_error` messages so issues surface in the editor or console while continuing the scan.
- **Custom additions:** For ad-hoc registrations (such as procedurally generated resources), you can assign directly into `assets[name] = resource` after ensuring the value is a valid `Resource`. Maintain unique keys to avoid overwriting previously loaded assets.

## Retrieval Patterns
- `get_asset(name: String) -> Resource` returns the resource associated with the requested file name, or `null` when nothing was registered under that key. Callers should null-check the return value before use.
- `has_asset(name: String) -> bool` offers a cheap existence check when you need to branch logic without paying the cost of retrieving the underlying resource.
- When querying from gameplay code, prefer using constants or enumerations for the keys to reduce typographical errors.

## Diagnostics & Failure Handling
- The registry maintains a `failed_assets` dictionary mirroring the keys stored in `assets`. When a `.tres` file fails to load—because of malformed syntax, missing dependencies, or permission issues—the singleton records the resource path in this dictionary and surfaces a `push_error` message so the problem is visible in-editor and in headless test logs.
- Call `get_failed_assets() -> Dictionary` to obtain a duplicate of the current failure map. Automated tests (see `res://src/tests/TestAssetRegistry.gd`) leverage this to ensure corrupted files do not crash the loader and that the registry advertises which resources require attention before shipping.

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
- Keep asset directories organised by theme or feature; the recursive scan handles nested directories automatically.
- Clear or rebuild the registry (`assets.clear()`) when hot-reloading resource packs to avoid stale references.
