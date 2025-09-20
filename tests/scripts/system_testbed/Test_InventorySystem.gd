extends Node
class_name Test_InventorySystem
"""Temporary inventory harness used to validate SystemTriggerPanel interactions."""

func add_item_to_entity(target: Node, item_id: String) -> void:
    """Logs a debug message confirming item triggers reached the harness."""
    var target_name := "[null]"
    if is_instance_valid(target):
        target_name = "%s (%s)" % [target.name, target.get_path()]
    print("[Test_InventorySystem] add_item_to_entity -> target=%s, item_id=%s" % [target_name, item_id])
