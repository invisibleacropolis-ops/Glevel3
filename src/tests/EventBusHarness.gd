extends Node

## Simple harness scene script to manually trigger EventBus signals.
## Designed for Godot 4.4.1.

@onready var entity_line: LineEdit = $VBox/EntityKilledLine
@onready var killer_line: LineEdit = $VBox/KillerIdLine
@onready var log: RichTextLabel = $VBox/Log

func _ready() -> void:
    EventBus.connect("entity_killed", Callable(self, "_on_entity_killed"))
    $VBox/EmitButton.pressed.connect(_emit_entity_killed)

func _emit_entity_killed() -> void:
    var payload := {
        "entity_id": entity_line.text,
        "killer_id": killer_line.text
    }
    EventBus.emit_signal("entity_killed", payload)

func _on_entity_killed(data: Dictionary) -> void:
    log.append_text("Received entity_killed: %s\n" % str(data))
