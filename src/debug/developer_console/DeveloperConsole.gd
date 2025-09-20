extends CanvasLayer
class_name DeveloperConsoleSingleton
"""Autoloaded dropdown console that executes GDScript expressions at runtime."""

const ENTITY_SCRIPT := preload("res://src/entities/Entity.gd")
const ENTITY_DATA_SCRIPT := preload("res://src/core/EntityData.gd")
const ENTITY_SCENE_PATH := "res://src/entities/Entity.tscn"

const DEFAULT_TOGGLE_ACTION := "debug_toggle_console"
const DEFAULT_HISTORY_LIMIT := 64

@export var toggle_action := DEFAULT_TOGGLE_ACTION
@export var history_limit := DEFAULT_HISTORY_LIMIT

@onready var _output: RichTextLabel = %ConsoleOutput
@onready var _input: LineEdit = %ConsoleInput

var _is_active := false
var _history: Array[String] = []
var _history_index := -1
var _command_docs: Dictionary[String, String] = {}

func _ready() -> void:
    """Initialises the console UI and registers the default command bindings."""
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    _ensure_input_action(toggle_action, KEY_QUOTELEFT)
    if is_instance_valid(_input):
        _input.text_submitted.connect(_on_command_submitted)
        _input.gui_input.connect(_on_input_gui_event)
    _register_default_commands()
    _print_banner()

func _unhandled_input(event: InputEvent) -> void:
    """Listens for the toggle shortcut so the console can appear above gameplay."""
    if event.is_action_pressed(toggle_action):
        _toggle_console()
        get_viewport().set_input_as_handled()

func _toggle_console() -> void:
    """Toggles console visibility and focus state."""
    _is_active = not _is_active
    visible = _is_active
    if not is_instance_valid(_input):
        return
    if _is_active:
        _input.grab_focus()
        _input.caret_column = _input.text.length()
    else:
        _input.release_focus()
        _history_index = _history.size()

func _on_command_submitted(raw_text: String) -> void:
    """Parses and executes the supplied command string."""
    var command := raw_text.strip_edges()
    if command.is_empty():
        _input.text = ""
        return
    _print_prompt(command)
    _append_history(command)
    _input.text = ""
    _execute_command(command)

func _on_input_gui_event(event: InputEvent) -> void:
    """Handles history navigation keys from the LineEdit control."""
    if not (event is InputEventKey) or not event.pressed:
        return
    var key_event := event as InputEventKey
    match key_event.keycode:
        KEY_UP:
            _step_history(-1)
            key_event.accept()
        KEY_DOWN:
            _step_history(1)
            key_event.accept()

func _execute_command(command: String) -> void:
    """Evaluates the console command using Godot's Expression API."""
    var expression := Expression.new()
    var parse_error := expression.parse(command)
    if parse_error != OK:
        _print_error("Parse", expression.get_error_text())
        return
    var result: Variant = expression.execute([], self, true)
    if expression.has_execute_failed():
        _print_error("Runtime", expression.get_error_text())
        return
    if result != null:
        _print_line(str(result))

func _append_history(command: String) -> void:
    """Records executed commands so users can navigate with arrow keys."""
    if command == "":
        return
    if not _history.is_empty() and _history.back() == command:
        _history_index = _history.size()
        return
    _history.append(command)
    if history_limit > 0 and _history.size() > history_limit:
        var start: int = max(_history.size() - history_limit, 0)
        _history = _history.slice(start, _history.size())
    _history_index = _history.size()

func _step_history(direction: int) -> void:
    """Moves the history cursor and populates the input line."""
    if _history.is_empty():
        return
    if _history_index < 0 or _history_index > _history.size():
        _history_index = _history.size()
    _history_index = clamp(_history_index + direction, 0, _history.size())
    if _history_index >= _history.size():
        _input.text = ""
        _input.caret_column = 0
        return
    var entry: String = _history[_history_index]
    _input.text = entry
    _input.caret_column = entry.length()

func _print_prompt(command: String) -> void:
    """Echoes the command back into the transcript with a prompt indicator."""
    _print_line(":> %s" % command)

func _print_line(text: String) -> void:
    """Appends a line to the RichTextLabel and scrolls to the latest entry."""
    if not is_instance_valid(_output):
        return
    _output.append_text(text + "\n")
    _output.scroll_to_line(_output.get_line_count())

func _print_banner() -> void:
    """Prints the initial console header to orient users."""
    _print_line("Developer Console ready. Type help() for available commands.")

func _print_error(prefix: String, message: String) -> void:
    """Formats error messages with emphasis for quick scanning."""
    _print_line("[color=#ff6b6b]%s error:[/color] %s" % [prefix, message])

func _register_default_commands() -> void:
    """Registers documentation strings for built-in console helpers."""
    _command_docs.clear()
    _command_docs["help"] = "Lists all available console commands."
    _command_docs["spawn"] = "Spawns the provided EntityData archetype at the player's location."

func help() -> void:
    """Prints the available console commands and their descriptions."""
    if _command_docs.is_empty():
        _print_line("No commands have been registered.")
        return
    _print_line("Available commands:")
    var keys := _command_docs.keys()
    keys.sort()
    for command in keys:
        var description: String = str(_command_docs.get(command, ""))
        if description == "":
            _print_line("  %s" % command)
        else:
            _print_line("  %s — %s" % [command, description])

func spawn(archetype_id: String) -> Node:
    """Instantiates an Entity archetype near the player's position."""
    var trimmed := archetype_id.strip_edges()
    if trimmed == "":
        _print_error("Runtime", "Provide an EntityData resource id, e.g. \"GoblinArcher_EntityData.tres\".")
        return null
    var registry := AssetRegistry
    if registry == null:
        _print_error("Runtime", "AssetRegistry autoload is unavailable.")
        return null
    var base_resource := registry.get_asset(trimmed)
    if base_resource == null:
        _print_error("Runtime", "Unable to locate asset '%s'." % trimmed)
        return null
    if not (base_resource is ENTITY_DATA_SCRIPT):
        _print_error("Runtime", "Asset '%s' is not an EntityData resource." % trimmed)
        return null
    var entity_data: EntityData = base_resource.duplicate(true)
    var entity_scene: PackedScene = load(ENTITY_SCENE_PATH)
    if entity_scene == null:
        _print_error("Runtime", "Base entity scene could not be loaded from %s." % ENTITY_SCENE_PATH)
        return null
    var entity_instance := entity_scene.instantiate()
    if not (entity_instance is ENTITY_SCRIPT):
        if entity_instance != null:
            entity_instance.queue_free()
        _print_error("Runtime", "Base entity scene does not implement the Entity script.")
        return null
    entity_instance.entity_data = entity_data
    if entity_data.display_name != "":
        entity_instance.name = entity_data.display_name
    else:
        entity_instance.name = trimmed.get_basename()
    var player := _find_player_node()
    if player == null:
        entity_instance.queue_free()
        _print_error("Runtime", "Unable to resolve a Player node to use as a spawn origin.")
        return null
    var parent := player.get_parent()
    if parent == null:
        parent = get_tree().get_current_scene()
    if parent == null:
        entity_instance.queue_free()
        _print_error("Runtime", "No valid parent found for the spawned entity.")
        return null
    parent.add_child(entity_instance)
    _position_entity_at_player(entity_instance, player)
    _print_line("Spawned %s at %s's location." % [entity_instance.name, player.name])
    return entity_instance

func _position_entity_at_player(entity: Node, player: Node) -> void:
    """Aligns the spawned entity with the player's transform when possible."""
    if entity == null or player == null:
        return
    if entity is Node3D and player is Node3D:
        entity.global_transform = player.global_transform
        entity.global_position += Vector3(0, 0, -2.0)
    elif "global_position" in entity and "global_position" in player:
        entity.global_position = player.global_position

func _find_player_node() -> Node:
    """Locates a node representing the player character."""
    var tree := get_tree()
    if tree == null:
        return null
    var group_matches := tree.get_nodes_in_group("player")
    if not group_matches.is_empty():
        return group_matches[0]
    var scene := tree.get_current_scene()
    if scene == null:
        return null
    var named := scene.get_node_or_null("Player")
    if named != null:
        return named
    return scene

func _ensure_input_action(action_name: String, default_key: Key) -> void:
    """Defines the toggle input action when it does not already exist."""
    if InputMap.has_action(action_name):
        return
    InputMap.add_action(action_name)
    var event := InputEventKey.new()
    event.physical_keycode = default_key
    InputMap.action_add_event(action_name, event)
