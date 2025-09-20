extends Node
class_name Test_CombatSystem
"""Temporary combat harness used to validate SystemTriggerPanel interactions.

This utility lives only inside the testbed scene. It mirrors the API shape
expected from the real CombatSystem so UI engineers can bind buttons and confirm
payloads before the production gameplay logic exists.
"""

func _describe_target(target: Node) -> String:
    """Returns a human readable description of the supplied target."""
    if not is_instance_valid(target):
        return "[null]"
    var path := "(unknown path)"
    if target.is_inside_tree():
        path = str(target.get_path())
    return "%s {path=%s, id=%d}" % [target.name, path, target.get_instance_id()]

func apply_damage(target: Node, amount: int, damage_type: String) -> void:
    """Logs a debug message when damage is applied to confirm wiring works."""
    var target_label := _describe_target(target)
    print("[Test_CombatSystem] apply_damage -> target=%s, amount=%d, type=%s" % [target_label, amount, damage_type])

func kill_target(target: Node) -> void:
    """Logs a debug message when a kill trigger is invoked."""
    var target_label := _describe_target(target)
    print("[Test_CombatSystem] kill_target -> target=%s" % target_label)
