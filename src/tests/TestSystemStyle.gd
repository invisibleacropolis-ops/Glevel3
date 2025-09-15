# src/tests/TestSystemStyle.gd
extends Node

## Verifies that gameplay systems avoid using node lookups or onready exports.
## This helps keep systems decoupled from the scene tree for easier testing.

const TARGET_DIR := "res://src/systems"

var _export_regex := RegEx.new()
var _var_system_regex := RegEx.new()
var _regex_ready := false

func run_test() -> Dictionary:
    var result := {
        "passed": true,
        "successes": 0,
        "total": 1
    }
    print("-- System Style Compliance --")

    if not _regex_ready:
        var err := _export_regex.compile("@export[^\n]*\\bSystem\\b")
        if err != OK:
            push_error("FAIL: Unable to compile export regex (error code %d)." % err)
            result["passed"] = false
            return result
        err = _var_system_regex.compile("^var\\s+\\w+[^\n]*\\bSystem\\b")
        if err != OK:
            push_error("FAIL: Unable to compile var regex (error code %d)." % err)
            result["passed"] = false
            return result
        _regex_ready = true

    var violations: Array[String] = []
    var files_scanned := _scan_directory(TARGET_DIR, violations)

    if files_scanned == 0:
        push_error("FAIL: No GDScript files discovered under %s." % TARGET_DIR)
        result["passed"] = false
        result["total"] = 0
        return result

    if violations.is_empty():
        print("PASS: %d file(s) scanned with no forbidden patterns." % files_scanned)
        result["successes"] = 1
    else:
        result["passed"] = false
        for violation in violations:
            push_error("FAIL: %s" % violation)

    print("Summary: %d/%d checks passed." % [result["successes"], result["total"]])
    return result

func _scan_directory(path: String, violations: Array[String]) -> int:
    var dir := DirAccess.open(path)
    if dir == null:
        violations.append("Unable to open directory: %s" % path)
        return 0

    var files_checked := 0
    dir.list_dir_begin()
    while true:
        var name := dir.get_next()
        if name == "":
            break
        if name.begins_with("."):
            continue

        var full_path := path.path_join(name)
        if dir.current_is_dir():
            files_checked += _scan_directory(full_path, violations)
        elif name.get_extension() == "gd":
            files_checked += 1
            _check_file(full_path, violations)
    dir.list_dir_end()
    return files_checked

func _check_file(file_path: String, violations: Array[String]) -> void:
    var file := FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        violations.append("%s: Unable to read file." % file_path)
        return

    var line_number := 0
    var pending_export_line := -1
    while file.get_position() < file.get_length():
        var line := file.get_line()
        line_number += 1
        var sanitized := _sanitize_line(line)
        if sanitized.is_empty():
            if pending_export_line != -1:
                pending_export_line = -1
            continue

        var trimmed := sanitized.strip_edges()

        if pending_export_line != -1:
            if _var_system_regex.search(trimmed) != null:
                violations.append("%s:%d exports a System reference." % [file_path, pending_export_line])
                pending_export_line = -1
            elif trimmed.begins_with("@"):
                pass
            else:
                pending_export_line = -1

        if sanitized.find("get_node(") != -1:
            violations.append("%s:%d uses get_node()." % [file_path, line_number])
        if sanitized.find("@onready") != -1:
            violations.append("%s:%d uses @onready." % [file_path, line_number])
        if _contains_percent_shorthand(sanitized):
            violations.append("%s:%d uses %% node shorthand." % [file_path, line_number])
        if _export_regex.search(sanitized) != null:
            violations.append("%s:%d exports a System reference." % [file_path, line_number])
        elif sanitized.find("@export") != -1:
            pending_export_line = line_number

func _sanitize_line(line: String) -> String:
    var sanitized := ""
    var in_string := false
    var string_delimiter := ""
    var i := 0
    while i < line.length():
        var character := line.substr(i, 1)
        if in_string:
            if character == "\\" and i + 1 < line.length():
                i += 2
                continue
            elif character == string_delimiter:
                in_string = false
                string_delimiter = ""
            i += 1
            continue
        else:
            if character == "\"" or character == "'":
                in_string = true
                string_delimiter = character
                i += 1
                continue
            elif character == "#":
                break
            else:
                sanitized += character
                i += 1
    return sanitized.strip_edges()

func _contains_percent_shorthand(line: String) -> bool:
    var index := line.find("%")
    while index != -1:
        var prev := index > 0 ? line.substr(index - 1, 1) : ""
        var next := index + 1 < line.length() ? line.substr(index + 1, 1) : ""
        var prev_allows := index == 0 or prev in ["", " ", "\t", "(", "[", "{", "=", ":", ","]
        if prev_allows and _is_identifier_start(next):
            return true
        index = line.find("%", index + 1)
    return false

func _is_identifier_start(char: String) -> bool:
    if char.is_empty():
        return false
    var code := char.unicode_at(0)
    return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or char == "_"
