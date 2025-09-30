extends Control
"""UI harness that drives CombatTimerValidator from the dedicated testbed scene."""

@onready var validator: CombatTimerValidator = %CombatTimerValidator
@onready var status_label: RichTextLabel = %StatusLog

func _ready() -> void:
    if validator != null:
        validator.auto_run_on_ready = false
    _append_status("Combat Timer testbed ready. Use the controls to drive encounters.")

func _on_start_button_pressed() -> void:
    if validator == null:
        _append_status("Validator node missing; cannot start encounter.")
        return
    var participants: Array[StringName] = await validator.start_demo_encounter()
    var names: Array[String] = []
    for id in participants:
        names.append(String(id))
    _append_status("Encounter started with participants: %s" % ", ".join(names))

func _on_resolve_button_pressed() -> void:
    if validator == null:
        _append_status("Validator node missing; cannot resolve turns.")
        return
    var result := await validator.advance_demo_turn()
    match result.get("status"):
        "error":
            _append_status("Resolve failed: %s" % result.get("message", "Unknown error"))
        "idle":
            _append_status(result.get("message", "No active turn to resolve."))
        _:
            _append_status("Resolved %s (round %d, turn %d)." % [
                String(result.get("resolved_id", "unknown")),
                int(result.get("round", 0)),
                int(result.get("turn_number", 0)),
            ])

func _on_inspect_button_pressed() -> void:
    if validator == null:
        _append_status("Validator node missing; cannot inspect state.")
        return
    _append_status(validator.describe_encounter_state())

func _append_status(message: String) -> void:
    if status_label == null:
        return
    status_label.append_text("%s\n" % message)
    var scroll_bar := status_label.get_v_scroll_bar()
    if scroll_bar != null:
        status_label.scroll_vertical = scroll_bar.max_value
