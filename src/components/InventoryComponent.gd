extends "res://src/core/Component.gd"
class_name InventoryComponent

## Canonical inventory manifest describing every physical object currently associated with
## an entity. This resource acts as the shared data contract between the LootSystem,
## UISystem, and future crafting or trade interfaces. It intentionally remains lightweight
## until the dedicated ``Item`` resource ships, at which point the ``items`` array will
## contain strongly typed references instead of arbitrary data dictionaries.
##
## Designed for Godot 4.4.1.

@export_group("Inventory")
## Ordered list of item descriptors owned by the entity. Systems consuming this component
## should duplicate the array prior to mutation to avoid coupling editor state to runtime
## logic. Entries are currently untyped to maximise prototyping velocity; downstream
## systems should treat each element as either a lightweight identifier (StringName) or a
## Dictionary describing stack counts and metadata until the item framework stabilises.
@export var items: Array = []
