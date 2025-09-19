extends SceneTree

const HARNESS_SCENE := preload("res://tests/EventBus_TestHarness.tscn")
const EXIT_SUCCESS := 0
const EXIT_FAILURE := 1

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := _parse_arguments(OS.get_cmdline_args())
    if args["help"]:
        _print_usage()
        quit(EXIT_SUCCESS)
        return

    if not args["errors"].is_empty():
        for error_message in args["errors"]:
            push_error(error_message)
            _emit_json({
                "type": "eventbus_replay_error",
                "message": error_message,
            })
        quit(EXIT_FAILURE)
        return

    var replay_path: String = args["replay_path"]
    if replay_path.is_empty():
        var missing_path := "Replay transcript path is required."
        push_error(missing_path)
        _emit_json({
            "type": "eventbus_replay_error",
            "message": missing_path,
        })
        _print_usage()
        quit(EXIT_FAILURE)
        return

    var normalized_replay_path := _normalize_path(replay_path)
    var load_result := _load_replay_entries(normalized_replay_path)
    if load_result.has("error"):
        var load_error: String = load_result["error"]
        push_error(load_error)
        _emit_json({
            "type": "eventbus_replay_error",
            "message": load_error,
        })
        quit(EXIT_FAILURE)
        return

    var entries: Array = load_result["entries"]

    var harness_root: Node = HARNESS_SCENE.instantiate()
    get_root().add_child(harness_root)
    await harness_root.ready

    var log_label := _resolve_log_label(harness_root)
    if log_label == null:
        var log_error := "EventBusHarness log label could not be resolved."
        push_error(log_error)
        _emit_json({
            "type": "eventbus_replay_error",
            "message": log_error,
        })
        quit(EXIT_FAILURE)
        return

    var previous_log_lines := _split_lines(log_label.get_parsed_text())

    harness_root.call("replay_signals_from_json", entries)
    await process_frame
    await process_frame

    var current_log_lines := _split_lines(log_label.get_parsed_text())
    var new_lines: Array = []
    if current_log_lines.size() > previous_log_lines.size():
        new_lines = current_log_lines.slice(previous_log_lines.size(), current_log_lines.size())

    var entry_index := 0
    var success_count := 0
    var failure_count := 0
    var skipped_count := 0
    var general_messages: Array = []

    for raw_line in new_lines:
        var parsed := _parse_log_line(raw_line)
        match parsed.get("kind", "message"):
            "entry":
                entry_index += 1
                var entry_payload: Dictionary = parsed["payload"].duplicate()
                entry_payload["index"] = entry_index
                _emit_json(entry_payload)
                match entry_payload.get("status", "info"):
                    "ok":
                        success_count += 1
                    "skipped":
                        skipped_count += 1
                    "error":
                        failure_count += 1
                continue
            _:
                general_messages.append(parsed.get("message", ""))
                _emit_json({
                    "type": "eventbus_replay_log",
                    "timestamp": parsed.get("timestamp", ""),
                    "message": parsed.get("message", ""),
                    "level": parsed.get("level", "info"),
                })

    if args["export_log_path"] is String and not String(args["export_log_path"]).is_empty():
        var export_path := _normalize_path(String(args["export_log_path"]))
        var export_error := harness_root.call("export_log", export_path)
        if export_error != OK:
            var export_message := "Failed to export harness log to %s (error %s)." % [
                export_path,
                error_string(export_error),
            ]
            push_error(export_message)
            _emit_json({
                "type": "eventbus_replay_error",
                "message": export_message,
            })
        else:
            _emit_json({
                "type": "eventbus_replay_log_export",
                "path": export_path,
            })

    var combined_log_text := log_label.get_parsed_text()
    if args["echo_log"]:
        _emit_json({
            "type": "eventbus_replay_echo",
            "text": combined_log_text,
        })

    harness_root.queue_free()
    await process_frame

    var total_entries := success_count + failure_count + skipped_count
    var had_failure := failure_count > 0 or skipped_count > 0 or total_entries == 0
    var summary := {
        "type": "eventbus_replay_summary",
        "total": total_entries,
        "succeeded": success_count,
        "failed": failure_count,
        "skipped": skipped_count,
        "messages": general_messages,
        "exit_code": EXIT_SUCCESS if not had_failure else EXIT_FAILURE,
    }
    _emit_json(summary)

    quit(summary["exit_code"])

func _parse_arguments(args: Array) -> Dictionary:
    var result := {
        "replay_path": "",
        "export_log_path": "",
        "echo_log": false,
        "errors": [],
        "help": false,
    }

    var expect_value_for := ""
    for raw_arg in args:
        var arg := String(raw_arg)
        if not expect_value_for.is_empty():
            result[expect_value_for] = arg
            expect_value_for = ""
            continue

        match arg:
            "-h", "--help":
                result["help"] = true
            "--echo-log":
                result["echo_log"] = true
            "--export-log":
                expect_value_for = "export_log_path"
            _:
                if arg.begins_with("--export-log="):
                    result["export_log_path"] = arg.substr("--export-log=".length())
                elif arg.begins_with("-"):
                    result["errors"].append("Unknown flag: %s" % arg)
                elif result["replay_path"].is_empty():
                    result["replay_path"] = arg
                else:
                    result["errors"].append("Unexpected positional argument: %s" % arg)

    if not expect_value_for.is_empty():
        result["errors"].append("Flag --export-log requires a value.")

    return result

func _normalize_path(path: String) -> String:
    if _is_absolute_path(path):
        return path
    if path.begins_with("res://") or path.begins_with("user://"):
        return path
    var project_root := ProjectSettings.globalize_path("res://")
    return project_root.path_join(path)

func _is_absolute_path(path: String) -> bool:
    if path.is_empty():
        return false
    if path.begins_with("/"):
        return true
    if path.length() > 2 and path[1] == ":" and (path[2] == "/" or path[2] == "\\"):
        return true
    return false

func _load_replay_entries(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"error": "Replay transcript not found at %s" % path}

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"error": "Unable to open replay transcript at %s" % path}

    var contents := file.get_as_text()
    file.close()

    var json := JSON.new()
    var parse_error := json.parse(contents)
    if parse_error != OK:
        return {
            "error": "Failed to parse replay JSON at line %d: %s" % [
                json.get_error_line(),
                json.get_error_message(),
            ]
        }

    var data := json.data
    if typeof(data) != TYPE_ARRAY:
        return {"error": "Replay JSON root must be an array of dictionaries."}

    var validation := _validate_entries(data)
    if validation.has("error"):
        return validation

    return {"entries": validation["entries"]}

func _validate_entries(entries: Array) -> Dictionary:
    var sanitized: Array = []
    for i in range(entries.size()):
        var entry_variant: Variant = entries[i]
        if typeof(entry_variant) != TYPE_DICTIONARY:
            return {"error": "Replay entry %d must be a dictionary." % (i + 1)}
        var entry := (entry_variant as Dictionary).duplicate(true)

        if not entry.has("signal_name"):
            return {"error": "Replay entry %d is missing \"signal_name\"." % (i + 1)}
        var raw_signal_name: Variant = entry["signal_name"]
        match typeof(raw_signal_name):
            TYPE_STRING, TYPE_STRING_NAME:
                entry["signal_name"] = String(raw_signal_name)
            _:
                return {
                    "error": "Replay entry %d has non-string signal_name." % (i + 1)
                }

        if not entry.has("payload"):
            return {"error": "Replay entry %d is missing \"payload\"." % (i + 1)}
        var payload_variant: Variant = entry["payload"]
        if typeof(payload_variant) != TYPE_DICTIONARY:
            return {
                "error": "Replay entry %d payload must be a dictionary." % (i + 1)
            }

        sanitized.append(entry)

    return {"entries": sanitized}

func _resolve_log_label(harness: Node) -> RichTextLabel:
    if harness == null:
        return null
    var label := harness.get_node_or_null("%Log")
    if label == null:
        label = harness.get_node_or_null("Log")
    return label as RichTextLabel

func _split_lines(text: String) -> Array:
    if text.is_empty():
        return []
    var lines: Array = text.split("\n")
    if lines.size() > 0 and String(lines[-1]) == "":
        lines.pop_back()
    return lines

func _parse_log_line(line: String) -> Dictionary:
    var stripped := line.strip_edges()
    var timestamp := ""
    var message := stripped
    if stripped.begins_with("["):
        var closing := stripped.find("]")
        if closing > 0:
            timestamp = stripped.substr(1, closing - 1)
            if closing + 2 <= stripped.length():
                message = stripped.substr(closing + 2, stripped.length())
    if message.begins_with("Replayed "):
        return {
            "kind": "entry",
            "payload": _parse_success_entry(message, timestamp),
        }
    if message.begins_with("Failed to replay "):
        return {
            "kind": "entry",
            "payload": _parse_failure_entry(message, timestamp),
        }
    if message.begins_with("Replay entry ") and message.find("skipping") != -1:
        return {
            "kind": "entry",
            "payload": _parse_skipped_entry(message, timestamp),
        }
    var level := "info"
    if message.findn("failed") != -1 or message.findn("unable") != -1:
        level = "error"
    return {
        "kind": "message",
        "timestamp": timestamp,
        "message": message,
        "level": level,
    }

func _parse_success_entry(message: String, timestamp: String) -> Dictionary:
    var payload_split := message.find(" with payload ")
    if payload_split == -1:
        payload_split = message.length()
    var signal_name := message.substr("Replayed ".length, payload_split - "Replayed ".length)
    return {
        "type": "eventbus_replay_entry",
        "timestamp": timestamp,
        "signal_name": signal_name,
        "status": "ok",
        "message": message,
    }

func _parse_failure_entry(message: String, timestamp: String) -> Dictionary:
    var payload_split := message.find(" with payload ")
    if payload_split == -1:
        payload_split = message.length()
    var signal_name := message.substr("Failed to replay ".length, payload_split - "Failed to replay ".length)
    return {
        "type": "eventbus_replay_entry",
        "timestamp": timestamp,
        "signal_name": signal_name,
        "status": "error",
        "message": message,
    }

func _parse_skipped_entry(message: String, timestamp: String) -> Dictionary:
    var parts := message.split(" ")
    var index_text := parts[2] if parts.size() >= 3 else "0"
    var entry_index := index_text.to_int()
    return {
        "type": "eventbus_replay_entry",
        "timestamp": timestamp,
        "signal_name": "",
        "status": "skipped",
        "message": message,
        "entry_index": entry_index,
    }

func _print_usage() -> void:
    print("Usage: godot --headless --script res://tests/eventbus_replay_runner.gd <replay.json> [--export-log <path>] [--echo-log]")

func _emit_json(payload: Dictionary) -> void:
    print(JSON.stringify(payload))
