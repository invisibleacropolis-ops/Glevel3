extends "res://src/core/Component.gd"
class_name InventoryComponent

const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")
const BASE_ITEM_SCRIPT := preload("res://src/core/BaseItem.gd")

## Canonical inventory manifest describing every physical object currently associated with
## an entity. This resource acts as the shared data contract between the LootSystem,
## UISystem, and future crafting or trade interfaces.
##
## Designed for Godot 4.4.1.

@export_group("Inventory")
## Ordered list of item entries owned by the entity. Each entry is a Dictionary with:
##   - "item_resource": BaseItem (the actual item resource)
##   - "quantity": int (number of items in this stack)
@export var items: Array[Dictionary] = []
@export var owner_entity_id: StringName = &""

## Adds an item to the inventory, handling stacking if the item already exists.
func add_item(item_resource: BaseItem, quantity: int = 1) -> void:
    if not item_resource:
        push_warning("Attempted to add a null item resource.")
        return
    if quantity <= 0:
        push_warning("Attempted to add non-positive quantity of item: %s" % item_resource.item_id)
        return

    var found_item_entry = null
    for entry in items:
        if entry.has("item_resource") and entry["item_resource"] == item_resource:
            found_item_entry = entry
            break

    if found_item_entry:
        # Item already exists, increment quantity
        found_item_entry["quantity"] += quantity
    else:
        # Item does not exist, add new entry
        var new_item_entry = {
            "item_resource": item_resource,
            "quantity": quantity,
        }
        items.append(new_item_entry)

    # Emit item_acquired event
    var event_payload = {
        "item_id": item_resource.item_id,
        "quantity": quantity,
        "owner_id": owner_entity_id,
        "source": &"inventory_component_add", # Or a more specific source if known
        # "metadata": item_resource.metadata # If BaseItem had metadata
    }
    emit_event(&"item_acquired", event_payload)

## Removes an item from the inventory by its item_id.
## Returns true if items were successfully removed, false otherwise.
func remove_item(item_id: StringName, quantity: int = 1) -> bool:
    if quantity <= 0:
        push_warning("Attempted to remove non-positive quantity of item: %s" % item_id)
        return false

    var found_item_index = -1
    for i in range(items.size()):
        if items[i].has("item_resource") and items[i]["item_resource"].item_id == item_id:
            found_item_index = i
            break

    if found_item_index == -1:
        return false # Item not found

    var current_quantity = items[found_item_index]["quantity"]
    if current_quantity < quantity:
        return false # Not enough items to remove

    items[found_item_index]["quantity"] -= quantity

    if items[found_item_index]["quantity"] <= 0:
        items.remove_at(found_item_index)

    # TODO: Emit an item_removed event if needed
    # You would need to define a new signal in EventBus.gd for this.

    return true

## Checks if the inventory contains at least one of the specified item by its item_id.
func has_item(item_id: StringName) -> bool:
    for item_entry in items:
        if item_entry.has("item_resource") and item_entry["item_resource"].item_id == item_id:
            return true
    return false

## Returns the total quantity of a specific item in the inventory by its item_id.
func get_item_count(item_id: StringName) -> int:
    for item_entry in items:
        if item_entry.has("item_resource") and item_entry["item_resource"].item_id == item_id:
            return item_entry.get("quantity", 0)
    return 0

## Returns the BaseItem resource for a given item_id, or null if not found.
func get_item_resource(item_id: StringName) -> BaseItem:
    for item_entry in items:
        if item_entry.has("item_resource") and item_entry["item_resource"].item_id == item_id:
            return item_entry["item_resource"]
    return null

## Internal helper that fetches the EventBus autoload or returns null when the
## system is running outside of a full game tree (e.g. during isolated tests).
func _get_event_bus() -> Node:
    if EVENT_BUS_SCRIPT.is_singleton_ready():
        var singleton := EVENT_BUS_SCRIPT.get_singleton()
        if singleton is Node:
            return singleton

    var main_loop := Engine.get_main_loop()
    var scene_tree := main_loop as SceneTree
    if scene_tree == null:
        return null

    var root := scene_tree.get_root()
    if root == null:
        return null

    return root.get_node_or_null("EventBus")

## Emit a payload on the global EventBus singleton.
## Subclasses should prefer this helper over referencing the autoload directly so
## all event traffic flows through a consistent abstraction.
func emit_event(signal_name: StringName, payload: Dictionary = {}) -> void:
    var event_bus := _get_event_bus()
    if event_bus == null:
        push_warning("EventBus singleton is unavailable; cannot emit \"%s\"." % signal_name)
        return

    if not event_bus.has_signal(signal_name):
        push_warning("EventBus is missing expected signal: %s" % signal_name)
        return

    event_bus.emit_signal(signal_name, payload)
