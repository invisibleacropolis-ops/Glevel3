extends Node
class_name Test_InventorySystem
"""Temporary inventory harness used to validate SystemTriggerPanel interactions."""

const UNKNOWN_TARGET_LABEL := "[unknown]"
const ENTITY_SCRIPT := preload("res://src/entities/Entity.gd")
const ENTITY_DATA_SCRIPT := preload("res://src/core/EntityData.gd")
const INVENTORY_COMPONENT_SCRIPT := preload("res://src/components/InventoryComponent.gd")
const BASE_ITEM_SCRIPT := preload("res://src/core/BaseItem.gd")
const ULTENUMS := preload("res://src/globals/ULTEnums.gd")

func add_item_to_entity(target: Node, item_id: String) -> void:
    """Adds an item to the selected entity's inventory while logging debug output."""
    var item_identifier := StringName(item_id)
    var descriptor := _describe_target(target)
    print("[Test_InventorySystem] add_item_to_entity -> target=%s, item_id=%s" % [descriptor, item_identifier])

    var inventory := _extract_inventory_component(target)
    if inventory == null:
        push_warning("Test_InventorySystem could not locate InventoryComponent for %s; skipping item grant." % descriptor)
        return

    var resolved_entity_id := _resolve_entity_identifier(target)
    if resolved_entity_id != StringName() and (String(inventory.owner_entity_id).is_empty() or inventory.owner_entity_id == StringName()):
        inventory.owner_entity_id = resolved_entity_id

    var item_resource := _resolve_or_build_item_resource(inventory, item_identifier)
    if item_resource == null:
        push_warning("Test_InventorySystem failed to construct an item resource for %s." % String(item_identifier))
        return

    inventory.add_item(item_resource, 1)

func _describe_target(target: Node) -> String:
    if not is_instance_valid(target):
        return "[null]"
    var path := "(unknown path)"
    if target.is_inside_tree():
        path = str(target.get_path())
    var entity_id := String(_resolve_entity_identifier(target))
    return "%s {entity_id=%s, path=%s}" % [target.name, entity_id, path]

func _resolve_entity_identifier(target: Node) -> StringName:
    if not is_instance_valid(target):
        return StringName(UNKNOWN_TARGET_LABEL)
    if target is ENTITY_SCRIPT:
        var entity := target as ENTITY_SCRIPT
        var via_property: StringName = entity.get_entity_id()
        if via_property != StringName():
            return via_property
    if target.has_method("get_entity_id"):
        var via_method: Variant = target.call("get_entity_id")
        if via_method is StringName:
            return via_method
        if via_method is String:
            return StringName(via_method)
    if target.has_meta("entity_id"):
        var via_meta: Variant = target.get_meta("entity_id")
        if via_meta is StringName:
            return via_meta
        if via_meta is String:
            return StringName(via_meta)
    var data := _extract_entity_data(target)
    if data != null and not data.entity_id.is_empty():
        return StringName(data.entity_id)
    return StringName(target.name)

func _extract_inventory_component(target: Node) -> INVENTORY_COMPONENT_SCRIPT:
    var data := _extract_entity_data(target)
    if data == null:
        return null
    var component := data.get_component(ULTENUMS.ComponentKeys.INVENTORY)
    if component is INVENTORY_COMPONENT_SCRIPT:
        return component as INVENTORY_COMPONENT_SCRIPT
    return null

func _extract_entity_data(target: Node) -> ENTITY_DATA_SCRIPT:
    if not is_instance_valid(target):
        return null
    if target is ENTITY_SCRIPT:
        var entity := target as ENTITY_SCRIPT
        if entity.entity_data is ENTITY_DATA_SCRIPT:
            return entity.entity_data
    var via_property: Variant = target.get("entity_data")
    if via_property is ENTITY_DATA_SCRIPT:
        return via_property
    if target.has_method("get_entity_data"):
        var via_method: Variant = target.call("get_entity_data")
        if via_method is ENTITY_DATA_SCRIPT:
            return via_method
    if target.has_meta("entity_data"):
        var via_meta: Variant = target.get_meta("entity_data")
        if via_meta is ENTITY_DATA_SCRIPT:
            return via_meta
    return null

func _resolve_or_build_item_resource(inventory: INVENTORY_COMPONENT_SCRIPT, item_id: StringName) -> BaseItem:
    if inventory == null:
        return null
    for entry in inventory.items:
        if entry is Dictionary and entry.has("item_resource"):
            var resource: BaseItem = entry.get("item_resource") as BaseItem
            if resource != null and resource.item_id == item_id:
                return resource
    var item := BASE_ITEM_SCRIPT.new()
    item.item_id = item_id
    var base_name := String(item_id)
    if base_name.is_empty():
        base_name = "Test Item"
    item.item_name = base_name.replace("_", " ").capitalize()
    item.description = "System testbed generated item for inventory validation."
    return item
