extends Node
class_name ModuleRegistrySingleton

## Simple registry for dynamically added modules.
## Designed for Godot 4.4.1.

## Tracks registered module nodes by a stable identifier so systems can query collaborators dynamically.
var modules: Dictionary[StringName, Node] = {}

## Registers a module under the provided name.
##
## @param module_name Identifier used for lookups (prefer a `StringName` constant shared across systems).
## @param node Concrete module instance to expose through the registry.
func register_module(module_name: StringName, node: Node) -> void:
    modules[module_name] = node

## Retrieves a previously registered module.
## Returns `null` when no module exists for the provided name.
## The return type is intentionally `Node` to remain agnostic about the module's concrete implementation.
func get_module(module_name: StringName) -> Node:
    return modules.get(module_name, null)

## Checks if a module has been registered under the provided name.
func has_module(module_name: StringName) -> bool:
    return modules.has(module_name)
