extends EditorPlugin

var dock: Control

func _enter_tree() -> void:
    dock = load("res://addons/test_runner_gui/TestRunnerDock.tscn").instantiate()
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
    if dock:
        remove_control_from_docks(dock)
        dock.free()
