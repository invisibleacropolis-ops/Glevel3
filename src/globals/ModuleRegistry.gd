extends Node
class_name ModuleRegistry

## Simple registry for dynamically added modules.
## Designed for Godot 4.4.1.

var modules := {}

## Registers a module under the provided name.
func register_module(name: String, node: Node) -> void:
    modules[name] = node
