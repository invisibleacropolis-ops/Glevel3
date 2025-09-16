extends "res://src/systems/System.gd"
class_name DebugSystem

const EVENT_BUS_SCRIPT := preload("res://src/globals/EventBus.gd")
const DEBUG_LOG_REDIRECTOR_SCRIPT := preload("res://src/globals/DebugLogRedirector.gd")

const DEFAULT_LOG_DIRECTORY := "user://logs"
const MASTER_ERROR_LOG_DIRECTORY := "res://"
const MASTER_ERROR_LOG_EXTENSION := ".txt"
const ERROR_SEVERITY_THRESHOLD := 3
const LOG_LEVEL_FALLBACK_LABELS := {
    0: "DEBUG",
    1: "INFO",
    2: "WARNING",
    3: "ERROR",
    4: "FATAL",
}

const EntityData = preload("res://src/core/EntityData.gd")
const StatsComponent = preload("res://src/components/StatsComponent.gd")
const ULTEnums = preload("res://src/globals/ULTEnums.gd")

## Optional EventBus reference to allow dependency injection in tests.
var event_bus: EventBusSingleton = null

## Optional DebugLogRedirector reference so tests can inject a stub.
var log_redirector: Node = null

## Directory where scene-specific log transcripts are written.
var log_directory_path: String = DEFAULT_LOG_DIRECTORY

## Resolved file path for the most recent log capture.
var log_file_path: String = ""

## Absolute path for the most recent master error log capture.
var master_error_log_path: String = ""

var _logging_active := false
var _log_file: FileAccess = null
var _master_error_log_file: FileAccess = null
var _captured_log_entries: Array = []
var _log_scene_name := ""
var _log_session_id := ""
var _log_redirector_registered := false
var _log_level_labels: Dictionary = {}
var _master_error_log_run_index := 0

## Simple system that prints entity statistics to the console each physics frame
## and captures Godot logger output for diagnostic review. Designed for Godot
## 4.4.1.

func _enter_tree() -> void:
    _initialize_log_capture()

func _ready() -> void:
    _ensure_event_bus_subscription()

func _exit_tree() -> void:
    _finalize_log_capture()

func _physics_process(delta: float) -> void:
    for entity in get_tree().get_nodes_in_group("entities"):
        var data: EntityData = entity.get("entity_data")
        if data and data.has_component(ULTEnums.ComponentKeys.STATS):
            var stats: StatsComponent = data.get_component(ULTEnums.ComponentKeys.STATS)
            print("%s HP: %d" % [entity.name, stats.health])
            var bus := _get_event_bus()
            if bus:
                bus.emit_signal(
                    "debug_stats_reported",
                    {
                        "entity_id": _resolve_entity_id(entity, data),
                        "stats": _snapshot_stats(stats),
                    }
                )

## Opens the scene-specific log file, registers the DebugSystem with the
## DebugLogRedirector, and prepares in-memory storage for captured log entries.
## The helper degrades gracefully when filesystem access or the redirector
## singleton is unavailable so automated tests can still exercise DebugSystem's
## other behaviours.
func _initialize_log_capture() -> void:
    if _logging_active:
        return

    _captured_log_entries.clear()
    _initialize_log_level_labels()

    _log_scene_name = _resolve_scene_name()
    var datetime_components := Time.get_datetime_dict_from_system()
    _log_session_id = _generate_timestamp_id(datetime_components)

    var master_date_stamp := _generate_master_error_log_date_stamp(datetime_components)
    _initialize_master_error_log(master_date_stamp)

    var directory := _prepare_log_directory()
    if directory != "":
        var sanitized_scene := _sanitize_scene_name(_log_scene_name)
        var file_name := "%s_%s.txt" % [sanitized_scene, _log_session_id]
        log_file_path = _join_paths(directory, file_name)

        _log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
        if _log_file == null:
            var open_error := FileAccess.get_open_error()
            push_error(
                "DebugSystem failed to open log file at %s (error %d)." % [log_file_path, open_error]
            )
            log_file_path = ""
        else:
            _log_file.store_line("=== Log started for scene: %s ===" % _log_scene_name)
            _log_file.flush()
    else:
        log_file_path = ""
        _log_file = null

    _logging_active = _log_file != null or _master_error_log_file != null
    if _logging_active:
        _register_with_log_redirector()

## Closes the active log file and unregisters from the DebugLogRedirector so the
## logger callback stops targeting this system once the scene exits.
func _finalize_log_capture() -> void:
    _unregister_from_log_redirector()

    if _log_file:
        _log_file.store_line("=== Scene ended ===")
        _log_file.flush()
        _log_file.close()
        _log_file = null

    _close_master_error_log()

    _logging_active = false

## Ensures the configured log directory exists and falls back to the default
## location when directory creation fails. Returns an empty string when the
## filesystem is unavailable.
func _prepare_log_directory() -> String:
    var desired_path := _normalize_directory_path(log_directory_path)

    var result := DirAccess.make_dir_recursive_absolute(desired_path)
    if result != OK and result != ERR_ALREADY_EXISTS:
        if desired_path != DEFAULT_LOG_DIRECTORY:
            var fallback_result := DirAccess.make_dir_recursive_absolute(DEFAULT_LOG_DIRECTORY)
            if fallback_result == OK or fallback_result == ERR_ALREADY_EXISTS:
                push_warning(
                    "DebugSystem fell back to default log directory at %s (error %d creating %s)."
                    % [DEFAULT_LOG_DIRECTORY, result, desired_path]
                )
                log_directory_path = DEFAULT_LOG_DIRECTORY
                return DEFAULT_LOG_DIRECTORY

        push_error(
            "DebugSystem failed to prepare log directory %s (error %d)." % [desired_path, result]
        )
        return ""

    log_directory_path = desired_path
    return desired_path

## Normalises the provided directory path by trimming trailing separators while
## preserving Godot's resource scheme syntax (e.g., `user://`).
func _normalize_directory_path(path: String) -> String:
    var result := path.strip_edges()
    if result == "":
        result = DEFAULT_LOG_DIRECTORY

    while result.ends_with("\\"):
        result = result.substr(0, result.length() - 1)

    while result.ends_with("/") and not result.ends_with("://"):
        result = result.substr(0, result.length() - 1)

    if result == "":
        result = DEFAULT_LOG_DIRECTORY

    return result

## Lightweight path join helper that respects Godot's virtual filesystem
## prefixes.
func _join_paths(base: String, file_name: String) -> String:
    if base == "":
        return file_name

    if base.ends_with("://"):
        return "%s%s" % [base, file_name]

    return "%s/%s" % [base, file_name]

## Returns the best available scene name for use in log headers and filenames.
func _resolve_scene_name() -> String:
    var tree := get_tree()
    if tree and tree.current_scene:
        return tree.current_scene.name

    if owner:
        return owner.name

    return name

## Sanitises the scene name so it can be embedded in filenames across
## platforms.
func _sanitize_scene_name(scene_name: String) -> String:
    var trimmed := scene_name.strip_edges()
    if trimmed == "":
        trimmed = "Scene"

    var builder := ""
    for character in trimmed:
        if character.is_ascii_alphanumeric():
            builder += character
        elif character == "_" or character == "-":
            builder += character
        elif character == " ":
            builder += "_"
        else:
            builder += "_"

    return builder

## Generates a timestamp identifier suitable for filenames and log headers.
func _generate_timestamp_id(components: Dictionary = {}) -> String:
    var resolved := components
    if resolved.is_empty():
        resolved = Time.get_datetime_dict_from_system()

    if resolved.has("year"):
        var year := int(resolved.get("year", 0))
        var month := int(resolved.get("month", 0))
        var day := int(resolved.get("day", 0))
        var hour := int(resolved.get("hour", 0))
        var minute := int(resolved.get("minute", 0))
        var second := int(resolved.get("second", 0))
        return "%04d%02d%02d_%02d%02d%02d" % [year, month, day, hour, minute, second]

    return str(Time.get_unix_time_from_system())

## Formats the system clock into the DATE-X-X-XX segment required by the master
## error log filename contract. Falls back to "00-00-00" when calendar fields are
## unavailable on the current platform.
func _generate_master_error_log_date_stamp(components: Dictionary) -> String:
    var month := int(components.get("month", 0))
    var day := int(components.get("day", 0))
    var year := int(components.get("year", 0))

    if month == 0 or day == 0 or year == 0:
        var fallback := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system())
        month = int(fallback.get("month", 0))
        day = int(fallback.get("day", 0))
        year = int(fallback.get("year", 0))

    if month == 0 or day == 0 or year == 0:
        return "00-00-00"

    var short_year := year % 100
    return "%02d-%02d-%02d" % [month, day, short_year]

## Initialises a lookup table translating Godot logger level integers into
## human-readable severity labels.
func _initialize_log_level_labels() -> void:
    if not _log_level_labels.is_empty():
        return

    _log_level_labels = LOG_LEVEL_FALLBACK_LABELS.duplicate()

    var has_constant := Callable(ClassDB, "class_has_integer_constant")
    var get_constant := Callable(ClassDB, "class_get_integer_constant")

    if not has_constant.is_valid() or not get_constant.is_valid():
        return

    var remap := {
        "LEVEL_DEBUG": "DEBUG",
        "LEVEL_INFO": "INFO",
        "LEVEL_WARNING": "WARNING",
        "LEVEL_ERROR": "ERROR",
        "LEVEL_FATAL": "FATAL",
        "LEVEL_EDITOR": "EDITOR",
    }

    for constant_name in remap.keys():
        if has_constant.call("Logger", constant_name):
            var value := get_constant.call("Logger", constant_name)
            if typeof(value) == TYPE_INT:
                _log_level_labels[value] = remap[constant_name]

## Resolves the display label for a logger severity integer.
func _resolve_log_level_name(level: int) -> String:
    if _log_level_labels.has(level):
        return _log_level_labels[level]

    return "LEVEL_%d" % level

## Registers this DebugSystem with the DebugLogRedirector so intercepted log
## messages are forwarded to `capture_log_message()`.
func _register_with_log_redirector() -> void:
    if _log_redirector_registered:
        return

    var redirector := _resolve_log_redirector()
    if redirector == null:
        push_warning("DebugSystem could not locate DebugLogRedirector; log capture will remain local only.")
        return

    if redirector.has_method("register_debug_system"):
        redirector.register_debug_system(self)
        _log_redirector_registered = true
    else:
        push_warning("DebugLogRedirector is missing register_debug_system(); log forwarding disabled.")

## Resolves the DebugLogRedirector singleton, tolerating dependency injection in
## tests and falling back to the autoloaded instance when present.
func _resolve_log_redirector() -> Node:
    if is_instance_valid(log_redirector):
        return log_redirector

    if DEBUG_LOG_REDIRECTOR_SCRIPT.is_singleton_ready():
        log_redirector = DEBUG_LOG_REDIRECTOR_SCRIPT.get_singleton()
    elif typeof(DebugLogRedirector) == TYPE_OBJECT and DebugLogRedirector is Node:
        log_redirector = DebugLogRedirector

    return log_redirector

## Unregisters from the DebugLogRedirector when the DebugSystem is shutting down
## so future scenes can take ownership of the logger.
func _unregister_from_log_redirector() -> void:
    if not _log_redirector_registered:
        return

    var redirector := _resolve_log_redirector()
    if redirector and redirector.has_method("unregister_debug_system"):
        redirector.unregister_debug_system(self)

    _log_redirector_registered = false

## Called by DebugLogRedirector whenever Godot emits a log message while this
## DebugSystem is active. Records the entry and persists it to the active log
## file.
func capture_log_message(message: String, level: int, category: String, timestamp: String) -> void:
    if not _logging_active:
        return

    var entry := _build_log_entry(message, level, category, timestamp)
    _captured_log_entries.append(entry)
    _write_log_entry(entry)
    _write_master_error_entry(entry)

## Constructs a structured representation of a log entry for storage and export.
func _build_log_entry(message: String, level: int, category: String, timestamp: String) -> Dictionary:
    var severity := _resolve_log_level_name(level)
    return {
        "message": message,
        "level": level,
        "severity": severity,
        "category": category,
        "timestamp": timestamp,
        "scene": _log_scene_name,
        "session_id": _log_session_id,
        "formatted": "[%s] [L%d %s] (%s) %s" % [timestamp, level, severity, category, message],
    }

## Writes the formatted log entry to disk, flushing after each message so logs
## persist even if the runtime exits unexpectedly.
func _write_log_entry(entry: Dictionary) -> void:
    if _log_file == null:
        return

    _log_file.store_line(entry.get("formatted", ""))
    _log_file.flush()

## Returns a deep copy of the captured log entries so external tools can analyse
## the session without mutating the DebugSystem's internal state.
func get_captured_log_entries() -> Array:
    return _captured_log_entries.duplicate(true)

## Exposes the resolved log file path for the current capture session. Returns an
## empty string when log capture failed to initialise.
func get_log_file_path() -> String:
    return log_file_path

## Exposes the resolved path to the master error log written to the project root.
## Returns an empty string when the file could not be created.
func get_master_error_log_path() -> String:
    return master_error_log_path

## Returns the timestamp-derived identifier associated with the current logging
## session. Useful for correlating file exports with in-memory summaries during
## automated tests.
func get_log_session_id() -> String:
    return _log_session_id

func _ensure_event_bus_subscription() -> void:
    if event_bus and _connect_event_bus(event_bus):
        return

    if typeof(EventBus) == TYPE_OBJECT and EventBus is Node:
        event_bus = EventBus
        var error := EventBus.connect(
            "entity_killed",
            Callable(self, "_on_entity_killed"),
            Object.CONNECT_REFERENCE_COUNTED,
        )
        if error != OK and error != ERR_ALREADY_IN_USE:
            push_warning("DebugSystem failed to connect to EventBus.entity_killed (error %d)." % error)
        return

    if EVENT_BUS_SCRIPT.is_singleton_ready():
        event_bus = EVENT_BUS_SCRIPT.get_singleton()
        if _connect_event_bus(event_bus):
            return

    var resolved_bus := _get_event_bus()
    if resolved_bus:
        event_bus = resolved_bus
        _connect_event_bus(event_bus)

func _connect_event_bus(bus: Node) -> bool:
    if not is_instance_valid(bus):
        return false

    if not bus.has_signal("entity_killed"):
        push_warning("EventBus reference missing entity_killed signal; cannot subscribe.")
        return false

    var error := bus.connect(
        "entity_killed",
        Callable(self, "_on_entity_killed"),
        Object.CONNECT_REFERENCE_COUNTED,
    )
    if error != OK and error != ERR_ALREADY_IN_USE:
        push_warning("DebugSystem failed to connect to entity_killed (error %d)." % error)
        return false

    return true

## Attempts to locate the global EventBus if it was not injected manually.
func _get_event_bus() -> EventBusSingleton:
    if event_bus:
        return event_bus

    if EVENT_BUS_SCRIPT.is_singleton_ready():
        event_bus = EVENT_BUS_SCRIPT.get_singleton()
        return event_bus

    if typeof(EventBus) == TYPE_OBJECT and EventBus is Node:
        event_bus = EventBus
        return event_bus

    var tree := get_tree()
    if tree:
        var root := tree.get_root()
        if root:
            event_bus = root.get_node_or_null("EventBus") as EventBusSingleton
    return event_bus

## Ensures we always emit a usable entity identifier for debug payloads.
func _resolve_entity_id(entity: Node, data: EntityData) -> String:
    if data.entity_id != "":
        return data.entity_id
    return entity.name

## Produces a serializable snapshot of the stats component for signal payloads.
func _snapshot_stats(stats: StatsComponent) -> Dictionary:
    return stats.to_dictionary()

## Receives notifications when other systems broadcast entity_killed.
## The payload is retained for future diagnostics or extended instrumentation.
func _on_entity_killed(payload: Dictionary) -> void:
    if not payload.has("entity_id"):
        return

    # Coerce the identifier to a String so downstream tooling receives a stable type.
    var entity_id: String = str(payload["entity_id"])
    print("DebugSystem observed entity_killed for %s" % str(entity_id))

## Creates the master error log file in the repository root and writes the session
## header. The helper tolerates missing filesystem permissions so tests can still
## exercise DebugSystem behaviour without touching disk.
func _initialize_master_error_log(date_stamp: String) -> void:
    _close_master_error_log()

    _master_error_log_run_index = _resolve_next_master_error_run_index(date_stamp)

    var file_name := _build_master_error_log_filename(date_stamp, _master_error_log_run_index)
    master_error_log_path = _join_paths(MASTER_ERROR_LOG_DIRECTORY, file_name)

    _master_error_log_file = FileAccess.open(master_error_log_path, FileAccess.WRITE)
    if _master_error_log_file == null:
        var open_error := FileAccess.get_open_error()
        push_error(
            "DebugSystem failed to open master error log at %s (error %d)." % [
                master_error_log_path,
                open_error,
            ]
        )
        master_error_log_path = ""
        _master_error_log_run_index = 0
        return

    var header := _build_master_error_log_header(date_stamp, _master_error_log_run_index)
    _master_error_log_file.store_line(header)
    _master_error_log_file.flush()

## Flushes and closes the master error log file so follow-up scenes can start a
## fresh capture.
func _close_master_error_log() -> void:
    if _master_error_log_file:
        _master_error_log_file.store_line("=== Master Error Log Closed ===")
        _master_error_log_file.flush()
        _master_error_log_file.close()
        _master_error_log_file = null

## Serialises error-class log entries into the master log file.
func _write_master_error_entry(entry: Dictionary) -> void:
    if _master_error_log_file == null:
        return

    var level := int(entry.get("level", 0))
    if not _is_error_level(level):
        return

    var formatted := entry.get("formatted", "")
    if formatted == "":
        formatted = "[%s] [L%d %s] (%s) %s" % [
            entry.get("timestamp", ""),
            level,
            entry.get("severity", "ERROR"),
            entry.get("category", ""),
            entry.get("message", ""),
        ]

    _master_error_log_file.store_line(formatted)
    _master_error_log_file.flush()

## Determines whether the provided logger level should be treated as an error for
## the purposes of the master error log export.
func _is_error_level(level: int) -> bool:
    return level >= ERROR_SEVERITY_THRESHOLD

## Resolves the next RUN-X index for the master error log by scanning the
## repository root. The implementation preserves gaps instead of compacting
## previous runs so historical captures remain untouched.
func _resolve_next_master_error_run_index(date_stamp: String) -> int:
    var directory := DirAccess.open(MASTER_ERROR_LOG_DIRECTORY)
    if directory == null:
        return 1

    var prefix := "Master-Error-Log-DATE-%s-RUN-" % date_stamp
    var max_run := 0

    var begin_error := directory.list_dir_begin()
    if begin_error != OK:
        return 1

    while true:
        var file_name := directory.get_next()
        if file_name == "":
            break

        if file_name == "." or file_name == "..":
            continue

        if directory.current_is_dir():
            continue

        if not file_name.ends_with(MASTER_ERROR_LOG_EXTENSION):
            continue

        if not file_name.begins_with(prefix):
            continue

        var suffix := file_name.substr(prefix.length())
        if suffix.ends_with(MASTER_ERROR_LOG_EXTENSION):
            suffix = suffix.substr(0, suffix.length() - MASTER_ERROR_LOG_EXTENSION.length())

        if suffix.is_valid_int():
            var parsed := int(suffix)
            if parsed > max_run:
                max_run = parsed

    directory.list_dir_end()
    return max_run + 1

## Builds the canonical filename for the master error log contract.
func _build_master_error_log_filename(date_stamp: String, run_index: int) -> String:
    return "Master-Error-Log-DATE-%s-RUN-%d%s" % [date_stamp, run_index, MASTER_ERROR_LOG_EXTENSION]

## Generates a descriptive header for the master error log so engineers can
## correlate the export with in-memory captures.
func _build_master_error_log_header(date_stamp: String, run_index: int) -> String:
    return "=== Master Error Log | Date: %s | Run: %d | Scene: %s | Session: %s ===" % [
        date_stamp,
        run_index,
        _log_scene_name,
        _log_session_id,
    ]
