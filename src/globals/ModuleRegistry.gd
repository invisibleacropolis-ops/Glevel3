extends Node
class_name ModuleRegistrySingleton

## Simple registry for dynamically added modules.
## Designed for Godot 4.4.1.

var modules := {}

## Registers a module under the provided name.
func register_module(name: String, node: Node) -> void:
    modules[name] = node

## Retrieves a previously registered module.
## Returns `null` when no module exists for the provided name.
func get_module(name: String) -> Node:
    return modules.get(name, null)

## Checks if a module has been registered under the provided name.
func has_module(name: String) -> bool:
    return modules.has(name)
