# ModuleRegistry

`ModuleRegistry` provides a centralized place to register and retrieve gameplay modules at runtime. Modules are stored by name, enabling systems to look up collaborators without hard-wiring scene tree paths. The script lives at `res://src/globals/ModuleRegistry.gd` and targets Godot 4.4.1.

## Initialization Sequence
1. **Autoload setup (recommended):** Add `ModuleRegistry.gd` as an Autoload singleton so it is available globally. Because it extends `Node`, no additional configuration is required beyond the autoload entry.
2. **Manual instancing for isolated contexts:** Tests or editor tools can instantiate the registry directly by calling `ModuleRegistry.new()`. The existing test suite follows this pattern so that each scenario starts with a clean registry state.
3. **Lifecycle management:** When the registry is about to be discarded (for example, in tests), clear any stored modules and free the instance to avoid leaking references.

## Registration Methods
- `register_module(name: StringName, node: Node)` stores the supplied node under the provided identifier. Re-registering an existing name overwrites the previous value, which is helpful for replacing modules during hot-reload workflows.
- `unregister_module(name: StringName)` removes an entry explicitly. Call this when a module is being freed manually or replaced by a different implementation mid-session.
- You can register any node type, including systems, services, or UI managers. Keep module names consistent by defining them as constants (for example, in an `Enums.gd` file) to avoid typos.

### Example: registering from a module's `_ready`
```gdscript
func _ready() -> void:
    ModuleRegistry.register_module("loot_generator", self)
```

## Retrieval Patterns
- `get_module(name: String) -> Node` returns the stored module node or `null` if the name has not been registered. Always guard against a `null` return to fail gracefully.
- `has_module(name: String) -> bool` reports whether a module exists under the key. Use this before calling `get_module` when you need to branch logic.

### Example: consuming a registered module
```gdscript
var loot_gen := ModuleRegistry.get_module("loot_generator")
if loot_gen:
    var drop := loot_gen.roll_loot_for(enemy_data)
else:
    push_warning("Loot generator module not registered; falling back to defaults.")
```

## Common Workflows
- **Hot swapping modules:** Call `register_module` again with a replacement node. The latest registration always wins, as validated by the test coverage (`res://src/tests/TestModuleRegistry.gd`).
- **Automatic cleanup:** The singleton listens for each module's `tree_exiting` signal and removes the entry automatically, ensuring the registry never exposes freed nodes to other systems.
- **Optional dependencies:** Use `has_module` to detect whether optional subsystems (such as analytics or debugging tools) are active before invoking them.
- **Tear-down:** Explicitly call `unregister_module` when unloading a game mode to avoid stale references in subsequent runs; the helper pairs nicely with `_exit_tree()` implementations.
