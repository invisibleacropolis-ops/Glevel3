extends Node
class_name Test_CombatSystem
"""Temporary combat harness used to validate SystemTriggerPanel interactions."""

func apply_damage(target: Node, amount: int, damage_type: String) -> void:
    """Logs a debug message when damage is applied to confirm wiring works."""
    var target_name := "[null]"
    if is_instance_valid(target):
        target_name = "%s (%s)" % [target.name, target.get_path()]
    print("[Test_CombatSystem] apply_damage -> target=%s, amount=%d, type=%s" % [target_name, amount, damage_type])

func kill_target(target: Node) -> void:
    """Logs a debug message when a kill trigger is invoked."""
    var target_name := "[null]"
    if is_instance_valid(target):
        target_name = "%s (%s)" % [target.name, target.get_path()]
    print("[Test_CombatSystem] kill_target -> target=%s" % target_name)
