extends SceneTree

const MANIFEST_PATH := "res://tests/tests_manifest.json"
const RESULT_JSON_PATH := "res://tests/results.json"
const RESULT_XML_PATH := "res://tests/results.xml"

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var manifest: Array = _load_manifest()
    if manifest.is_empty():
        push_error("No tests found in manifest %s" % MANIFEST_PATH)
        _write_failure_reports("Manifest missing or invalid.")
        quit(1)
        return

    var aggregated: Dictionary = {
        "tests": [],
        "total": 0,
        "passed": 0,
        "failed": 0,
    }

    for test_path_variant in manifest:
        var test_path := String(test_path_variant)
        var result: Dictionary = await _execute_test(test_path)
        aggregated["tests"].append(result)
        aggregated["total"] += int(result.get("total", 0))
        if result.get("passed", false):
            aggregated["passed"] += 1
        else:
            aggregated["failed"] += 1

    _print_summary(aggregated)
    _write_json_report(aggregated)
    _write_junit_report(aggregated)

    var exit_code := 0 if aggregated["failed"] == 0 else 1
    quit(exit_code)

func _load_manifest() -> Array:
    if not FileAccess.file_exists(MANIFEST_PATH):
        push_error("Test manifest not found at %s" % MANIFEST_PATH)
        return []

    var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    if file == null:
        push_error("Unable to open manifest %s" % MANIFEST_PATH)
        return []

    var contents := file.get_as_text()
    file.close()

    var parser := JSON.new()
    var error := parser.parse(contents)
    if error != OK:
        push_error(
            "Failed to parse manifest %s (line %d, error %s)" % [
                MANIFEST_PATH,
                parser.get_error_line(),
                parser.get_error_message(),
            ]
        )
        return []

    var data_variant: Variant = parser.get_data()
    if typeof(data_variant) != TYPE_DICTIONARY or not (data_variant as Dictionary).has("tests"):
        push_error("Manifest %s did not contain a tests array." % MANIFEST_PATH)
        return []

    var data := data_variant as Dictionary
    var tests_variant: Variant = data["tests"]
    if not (tests_variant is Array):
        push_error("Manifest tests entry is not an array in %s." % MANIFEST_PATH)
        return []

    return tests_variant

func _execute_test(test_path: String) -> Dictionary:
    var result: Dictionary = {
        "path": test_path,
        "passed": false,
        "successes": 0,
        "total": 0,
        "failures": 0,
        "errors": [],
    }

    var script := load(test_path)
    if script == null:
        result["errors"].append("Unable to load test script.")
        return result

    var node_object: Object = script.new()
    if not (node_object is Node):
        result["errors"].append("Test script does not extend Node.")
        return result

    var node := node_object as Node
    get_root().add_child(node)

    var response: Variant = await node.run_test()

    if typeof(response) == TYPE_DICTIONARY:
        result["passed"] = response.get("passed", false)
        result["successes"] = int(response.get("successes", 0))
        result["total"] = int(response.get("total", 0))
        result["failures"] = max(result["total"] - result["successes"], 0)
    else:
        result["errors"].append("Test did not return a result dictionary.")

    node.queue_free()
    await process_frame

    return result

func _print_summary(aggregated: Dictionary) -> void:
    print("\n==== Test Summary ====")
    var tests: Array = []
    var tests_variant: Variant = aggregated.get("tests", [])
    if tests_variant is Array:
        tests = tests_variant
    for entry_variant in tests:
        var entry := entry_variant as Dictionary
        var status: String = "PASS" if entry.get("passed", false) else "FAIL"
        print("[%s] %s (%d/%d)" % [status, entry.get("path", ""), entry.get("successes", 0), entry.get("total", 0)])
        var errors_variant: Variant = entry.get("errors", [])
        if errors_variant is Array:
            for error_message_variant in errors_variant:
                var error_message := String(error_message_variant)
                push_error("%s: %s" % [entry.get("path", ""), error_message])
    print("======================")
    print(
        "Scripts passed: %d | Scripts failed: %d" % [
            aggregated.get("passed", 0),
            aggregated.get("failed", 0),
        ]
    )

func _write_json_report(aggregated: Dictionary) -> void:
    var report: Dictionary = {
        "summary": {
            "scripts_passed": aggregated.get("passed", 0),
            "scripts_failed": aggregated.get("failed", 0),
            "assertions": aggregated.get("total", 0),
        },
        "tests": aggregated.get("tests", []),
    }

    var file := FileAccess.open(RESULT_JSON_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Unable to write JSON report to %s" % RESULT_JSON_PATH)
        return
    file.store_string(JSON.stringify(report, "  "))
    file.close()

func _write_junit_report(aggregated: Dictionary) -> void:
    var tests_array: Array = []
    var tests_variant: Variant = aggregated.get("tests", [])
    if tests_variant is Array:
        tests_array = tests_variant
    var total_scripts: int = tests_array.size()
    var failed_scripts: int = int(aggregated.get("failed", 0))
    var xml := "<testsuites>\n"
    xml += "  <testsuite name=\"GodotTestSuite\" tests=\"%d\" failures=\"%d\" skipped=\"0\">\n" % [
        total_scripts,
        failed_scripts,
    ]
    for entry_variant in tests_array:
        var entry := entry_variant as Dictionary
        var name := String(entry.get("path", ""))
        xml += "    <testcase classname=\"%s\" name=\"%s\">\n" % [name.get_file().get_basename(), name]
        if not entry.get("passed", false):
            var errors_variant: Variant = entry.get("errors", [])
            var errors: Array = []
            if errors_variant is Array:
                errors = errors_variant
            var string_errors: Array = []
            for error_message_variant in errors:
                string_errors.append(String(error_message_variant))
            var failure_message: String = "; ".join(string_errors)
            if failure_message == "":
                failure_message = "One or more assertions failed."
            xml += "      <failure message=\"%s\"/>\n" % failure_message.xml_escape()
        xml += "    </testcase>\n"
    xml += "  </testsuite>\n"
    xml += "</testsuites>\n"

    var file := FileAccess.open(RESULT_XML_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Unable to write XML report to %s" % RESULT_XML_PATH)
        return
    file.store_string(xml)
    file.close()

func _write_failure_reports(message: String) -> void:
    var error_report: Dictionary = {
        "summary": {
            "scripts_passed": 0,
            "scripts_failed": 0,
            "assertions": 0,
            "error": message,
        },
        "tests": [],
    }

    var json_file := FileAccess.open(RESULT_JSON_PATH, FileAccess.WRITE)
    if json_file != null:
        json_file.store_string(JSON.stringify(error_report, "  "))
        json_file.close()

    var xml := "<testsuites>\n  <testsuite name=\"GodotTestSuite\" tests=\"0\" failures=\"0\" skipped=\"0\">\n"
    xml += "    <system-err>%s</system-err>\n" % message.xml_escape()
    xml += "  </testsuite>\n</testsuites>\n"
    var xml_file := FileAccess.open(RESULT_XML_PATH, FileAccess.WRITE)
    if xml_file != null:
        xml_file.store_string(xml)
        xml_file.close()
