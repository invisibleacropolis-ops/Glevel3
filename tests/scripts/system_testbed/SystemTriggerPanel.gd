extends PanelContainer
class_name SystemTriggerPanel
"""
Hosts manual triggers for gameplay systems so engineers can exercise signal flows on demand.
Future milestones will expose buttons, dropdowns, and parameter editors to drive systems.
"""

const SYSTEM_TESTBED_SCRIPT := preload("res://tests/scripts/system_testbed/SystemTestbed.gd")
const TEST_COMBAT_SYSTEM_SCRIPT := preload("res://tests/scripts/system_testbed/Test_CombatSystem.gd")
const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")

@onready var _placeholder_label: Label = %SystemTriggerPlaceholder
@onready var _actions_container: VBoxContainer = %SystemTriggerActions
@onready var _apply_damage_button: Button = %ApplyFireDamageButton
@onready var _kill_target_button: Button = %KillTargetButton
@onready var _emit_entity_killed_button: Button = %EmitEntityKilledButton
@onready var _combat_system: TEST_COMBAT_SYSTEM_SCRIPT = %TestCombatSystem

var _testbed_root: SYSTEM_TESTBED_SCRIPT

func _ready() -> void:
    """Wires trigger buttons so operators can exercise combat and bus interactions."""
    _testbed_root = _resolve_testbed_root()
    _wire_buttons()
    _subscribe_to_target_updates()
    _update_button_states()
    _update_placeholder_visibility()

func _wire_buttons() -> void:
    """Safely connects UI button presses to their handlers."""
    if is_instance_valid(_apply_damage_button):
        _apply_damage_button.pressed.connect(_on_apply_damage_pressed)
    else:
        push_warning("SystemTriggerPanel missing ApplyFireDamageButton; damage trigger disabled.")

    if is_instance_valid(_kill_target_button):
        _kill_target_button.pressed.connect(_on_kill_target_pressed)
    else:
        push_warning("SystemTriggerPanel missing KillTargetButton; kill trigger disabled.")

    if is_instance_valid(_emit_entity_killed_button):
        _emit_entity_killed_button.pressed.connect(_on_emit_entity_killed_pressed)
    else:
        push_warning("SystemTriggerPanel missing EmitEntityKilledButton; manual signal trigger disabled.")

func _subscribe_to_target_updates() -> void:
    """Listens for active target changes so button state mirrors selection availability."""
    var testbed := _resolve_testbed_root()
    if testbed == null:
        push_warning("SystemTriggerPanel could not resolve SystemTestbed root; target-aware triggers disabled.")
        return
    if not testbed.active_target_entity_changed.is_connected(_on_active_target_entity_changed):
        testbed.active_target_entity_changed.connect(_on_active_target_entity_changed)

func _resolve_testbed_root() -> SYSTEM_TESTBED_SCRIPT:
    """Caches the SystemTestbed instance that tracks the active entity selection."""
    if is_instance_valid(_testbed_root):
        return _testbed_root
    var current_scene := get_tree().get_current_scene()
    _testbed_root = current_scene as SYSTEM_TESTBED_SCRIPT
    return _testbed_root

func _get_active_target() -> Node:
    """Retrieves the currently selected entity from the SystemTestbed."""
    var testbed := _resolve_testbed_root()
    if testbed == null:
        return null
    return testbed.active_target_entity

func _on_apply_damage_pressed() -> void:
    """Invokes the temporary combat system to simulate a fire damage event."""
    var target := _get_active_target()
    if target == null:
        push_warning("Select an entity in the Scene Inspector before applying damage.")
        return
    if not is_instance_valid(_combat_system):
        push_warning("Test_CombatSystem node is unavailable; cannot apply damage.")
        return
    if not _combat_system.has_method("apply_damage"):
        push_warning("Test_CombatSystem is missing apply_damage(); trigger skipped.")
        return
    _combat_system.apply_damage(target, 10, "fire")

func _on_kill_target_pressed() -> void:
    """Invokes the temporary combat system to simulate a kill."""
    var target := _get_active_target()
    if target == null:
        push_warning("Select an entity in the Scene Inspector before triggering a kill.")
        return
    if not is_instance_valid(_combat_system):
        push_warning("Test_CombatSystem node is unavailable; cannot kill target.")
        return
    if not _combat_system.has_method("kill_target"):
        push_warning("Test_CombatSystem is missing kill_target(); trigger skipped.")
        return
    _combat_system.kill_target(target)

func _on_emit_entity_killed_pressed() -> void:
    """Manually emits the entity_killed signal on the EventBus for logging validation."""
    var event_bus := _resolve_event_bus()
    if event_bus == null:
        push_warning("EventBus singleton not available; cannot emit entity_killed signal.")
        return
    var payload := {
        "entity_id": "debug_entity_id",
        "killer_id": "system_trigger_panel",
        "archetype_id": "DebugGoblin_EntityData.tres",
    }
    var error_code := event_bus.emit_signal(&"entity_killed", payload)
    if error_code != OK:
        push_warning("Failed to emit entity_killed signal; error code %d." % error_code)

func _resolve_event_bus() -> EVENT_BUS_SCRIPT:
    """Returns the active EventBus singleton when registered as an autoload."""
    if not EVENT_BUS_SCRIPT.is_singleton_ready():
        return null
    return EVENT_BUS_SCRIPT.get_singleton()

func _on_active_target_entity_changed(_target: Node) -> void:
    """Recomputes button enabled state whenever the selection updates."""
    _update_button_states()

func _update_button_states() -> void:
    """Enables target-dependent triggers only when a selection exists."""
    var has_target := is_instance_valid(_get_active_target())
    if is_instance_valid(_apply_damage_button):
        _apply_damage_button.disabled = not has_target
    if is_instance_valid(_kill_target_button):
        _kill_target_button.disabled = not has_target

func _update_placeholder_visibility() -> void:
    """Hides the placeholder label whenever actionable controls are present."""
    var has_actions := is_instance_valid(_actions_container) and _actions_container.get_child_count() > 0
    if is_instance_valid(_actions_container):
        _actions_container.visible = has_actions
    if is_instance_valid(_placeholder_label):
        _placeholder_label.visible = not has_actions
