extends Node
class_name ModuleRegistrySingleton

## Central index for procedural generation modules.
## Designed for Godot 4.4.1.
##
## The registry decouples director-style systems from their generator counterparts by
## providing fast lookup access through stable identifiers. Modules typically call
## `register_module` in their `_ready()` callback and pair it with `unregister_module`
## inside `_exit_tree()` to clean up manual registrations.
##
## Example usage:
##
##     ModuleRegistry.register_module("world_map", self)
##     if ModuleRegistry.has_module("world_map"):
##         ModuleRegistry.get_module("world_map").generate(seed)

## Tracks registered module nodes by a stable identifier so systems can query collaborators dynamically.
var modules: Dictionary[StringName, Node] = {}

## Registers a module under the provided name.
##
## @param module_name Identifier used for lookups (prefer a `StringName` constant shared across systems).
## @param node Concrete module instance to expose through the registry.
func register_module(module_name: StringName, node: Node) -> void:
    var key := _normalize_key(module_name)

    if String(key).is_empty():
        push_warning("ModuleRegistry: Refusing to register module with an empty name.")
        return

    if node == null or not is_instance_valid(node):
        push_warning("ModuleRegistry: Attempted to register an invalid module node for '%s'." % key)
        return

    if modules.has(key) and modules[key] != node:
        push_warning("ModuleRegistry: Replacing existing module registration for '%s'." % key)

    modules[key] = node
    _register_cleanup_hook(key, node)

## Removes a module from the registry.
## Systems can call this when a generator exits the scene tree or is about to free itself.
func unregister_module(module_name: StringName) -> void:
    var key := _normalize_key(module_name)
    if not modules.has(key):
        return

    var module := modules[key]
    modules.erase(key)

    if module != null and is_instance_valid(module):
        _disconnect_cleanup_hook(key, module)

## Retrieves a previously registered module.
## Returns `null` when no module exists for the provided name.
## The return type is intentionally `Node` to remain agnostic about the module's concrete implementation.
func get_module(module_name: StringName) -> Node:
    return modules.get(_normalize_key(module_name), null)

## Checks if a module has been registered under the provided name.
func has_module(module_name: StringName) -> bool:
    return modules.has(_normalize_key(module_name))

## Normalizes identifiers supplied by callers so spaces or differing String/Name
## types cannot cause lookup mismatches.
func _normalize_key(module_name: StringName) -> StringName:
    if module_name == null:
        return StringName()

    return StringName(String(module_name).strip_edges())

## Connects to a module's `tree_exiting` signal to keep the registry synchronized
## when systems are torn down.
func _register_cleanup_hook(module_name: StringName, module: Node) -> void:
    if module == null or not is_instance_valid(module):
        return

    var callable := _make_cleanup_callable(module_name, module)
    if module.tree_exiting.is_connected(callable):
        return

    module.tree_exiting.connect(callable, Object.CONNECT_ONE_SHOT)

## Disconnects a previously installed cleanup hook when modules are manually unregistered.
func _disconnect_cleanup_hook(module_name: StringName, module: Node) -> void:
    if module == null or not is_instance_valid(module):
        return

    var callable := _make_cleanup_callable(module_name, module)
    if module.tree_exiting.is_connected(callable):
        module.tree_exiting.disconnect(callable)

## Generates the callable used to attach cleanup hooks so signal management stays consistent.
func _make_cleanup_callable(module_name: StringName, module: Node) -> Callable:
    return Callable(self, "_on_module_tree_exiting").bind(module_name, module)

## Removes a module reference when its node leaves the scene tree, ensuring consumers never
## receive dangling references.
func _on_module_tree_exiting(module_name: StringName, module: Node) -> void:
    var key := _normalize_key(module_name)
    if modules.get(key) == module:
        modules.erase(key)
