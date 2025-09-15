# src/tests/TestRunner.gd (Step 12: dependencies + blocked tests)
# Headless test runner with manifest ordering, dependency resolution,
# blocked test reporting, and flaky test retries.
extends SceneTree

var use_color: bool = true
var out_dir: String = "res://tests/"
var _tracked_paths: Array = []

func _init() -> void:
    print("Running headless test suite...")

    use_color = not _has_flag("--no-color")
    var out_dir_values: Array = _get_flag_values("--out-dir")
    if out_dir_values.size() > 0:
        out_dir = out_dir_values[0]
        if not out_dir.ends_with("/"):
            out_dir += "/"

    var suite_start: int = Time.get_ticks_msec()
    var all_passed: bool = true
    var global_successes: int = 0
    var global_total: int = 0
    var global_skipped: int = 0
    var global_flaky: int = 0
    var global_blocked: int = 0
    # Tracks outcome of each test by filename for dependency resolution
    var test_outcomes: Dictionary = {}
    var results: Dictionary = {"tests": []}

    var test_scripts: Array = _load_manifest("res://tests/tests_manifest.json")
    for e in test_scripts:
        var p: String = e["path"] if e is Dictionary else e
        _tracked_paths.append(p)
    # Reorder tests so that dependencies run before dependents
    test_scripts = _resolve_dependencies(test_scripts)
    if test_scripts.is_empty():
        push_error("No tests found in manifest. Ensure res://tests_manifest.json exists and is valid.")
        quit(1)

    var disable_json: bool = _has_flag("--no-json")
    var disable_xml: bool = _has_flag("--no-xml")
    var simple_mode: bool = _has_flag("--simple")
    var batch_size: int = int(_get_flag_values("--batch-size")[0]) if _get_flag_values("--batch-size").size() > 0 else 0
    var slow_n: int = int(_get_flag_values("--slow")[0]) if _get_flag_values("--slow").size() > 0 else 5
    var max_retries: int = int(_get_flag_values("--retries")[0]) if _get_flag_values("--retries").size() > 0 else 0

    var tag_filters: Array = _get_flag_values("--tags")
    var skip_filters: Array = _get_flag_values("--skip")
    var pri_filters: Array = _get_flag_values("--priority")
    var owner_filters: Array = _get_flag_values("--owner")

    var batch_count: int = int(ceil(float(test_scripts.size()) / float(batch_size))) if batch_size > 0 else 1

    var by_priority: Dictionary = {}
    var by_owner: Dictionary = {}
    var by_tags: Dictionary = {}
    var flaky_tests: Array = []

    for b in range(batch_count):
        if batch_size > 0:
            _log("[b]=== Batch %d/%d ===[/b]" % [b + 1, batch_count])
        var batch_failed: bool = false
        var start_index: int = b * batch_size
        var end_index: int = min((b + 1) * batch_size, test_scripts.size()) if batch_size > 0 else test_scripts.size()
        var scripts_in_batch: Array = test_scripts.slice(start_index, end_index)

        for entry in scripts_in_batch:
            var script_path: String = entry["path"] if entry is Dictionary else entry
            var name: String = script_path.get_file()
            var tags: Array = entry["tags"] if entry is Dictionary and entry.has("tags") else []
            var priority: String = entry["priority"] if entry is Dictionary and entry.has("priority") else "unspecified"
            var owner: String = entry["owner"] if entry is Dictionary and entry.has("owner") else "unspecified"

            if tag_filters.size() > 0 and not _tags_match(tags, tag_filters):
                _log("[color=yellow]SKIP[/color] %s — tag filter mismatch" % name)
                global_skipped += 1
                test_outcomes[name] = "skipped"
                continue
            if skip_filters.size() > 0 and _tags_match(tags, skip_filters):
                _log("[color=yellow]SKIP[/color] %s — skipped by tag" % name)
                global_skipped += 1
                test_outcomes[name] = "skipped"
                continue
            if pri_filters.size() > 0 and not pri_filters.has(priority):
                _log("[color=yellow]SKIP[/color] %s — priority filter mismatch" % name)
                global_skipped += 1
                test_outcomes[name] = "skipped"
                continue
            if owner_filters.size() > 0 and not owner_filters.has(owner):
                _log("[color=yellow]SKIP[/color] %s — owner filter mismatch" % name)
                global_skipped += 1
                test_outcomes[name] = "skipped"
                continue

            var test_result: Dictionary = {
                "name": name,
                "path": script_path,
                "tags": tags,
                "priority": priority,
                "owner": owner,
                "passed": false,
                "successes": 0,
                "total": 0,
                "duration": 0,
                "errors": [],
                "flaky": false,
                "retry_count": 0,
                "blocked": false,
                "blocked_reason": ""
            }

            var depends: Array = entry["depends_on"] if entry is Dictionary and entry.has("depends_on") else []
            var blocked: bool = false
            var blocked_reason: String = ""
            # Determine if any dependency failed or was skipped
            for dep in depends:
                if test_outcomes.has(dep):
                    var dep_outcome: String = test_outcomes[dep]
                    if dep_outcome != "passed":
                        blocked = true
                        blocked_reason = "dependency %s %s" % [dep, dep_outcome]
                        break
                else:
                    blocked = true
                    blocked_reason = "dependency %s not run" % dep
                    break
            if blocked:
                _log("[color=yellow]SKIP[/color] %s — blocked (%s)" % [name, blocked_reason])
                global_blocked += 1
                test_result["blocked"] = true
                test_result["blocked_reason"] = "Dependency %s" % blocked_reason.substr(11)
                test_outcomes[name] = "blocked"
                _update_group(by_priority, priority, test_result)
                _update_group(by_owner, owner, test_result)
                for t in tags:
                    _update_group(by_tags, t, test_result)
                results["tests"].append(test_result)
                continue

            var attempt: int = 0
            var final_passed: bool = false
            var last_duration: int = 0

            while attempt <= max_retries and not final_passed:
                var test_class: Script = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
                if test_class == null:
                    _log("[color=red]FAIL[/color] %s — could not load script" % name)
                    all_passed = false
                    batch_failed = true
                    test_result["errors"].append("Could not load script")
                    break

                var test_instance = test_class.new()
                root.add_child(test_instance)
                await process_frame
                if not test_instance.has_method("run_test"):
                    _log("[color=yellow]SKIP[/color] %s — no run_test() method" % name)
                    test_result["passed"] = true
                    global_skipped += 1
                    test_outcomes[name] = "skipped"
                    break

                var start: int = Time.get_ticks_msec()
                var result: Dictionary = await test_instance.run_test()
                test_instance.queue_free()
                await process_frame

                last_duration = Time.get_ticks_msec() - start

                if result:
                    var passed: bool = result.get("passed", false)
                    var successes: int = result.get("successes", 0)
                    var total: int = result.get("total", 0)

                    test_result["successes"] = successes
                    test_result["total"] = total
                    test_result["duration"] = last_duration

                    global_successes += successes
                    global_total += total

                    var pct := float(successes) / float(total) * 100.0 if total > 0 else 100.0
                    var pct_str: String = "%.1f" % pct

                    if passed:
                        if attempt == 0:
                            _log("[color=green]PASS[/color] %s — %d/%d (%s%%) — %d ms" % [name, successes, total, pct_str, last_duration])
                        else:
                            _log("[color=green]PASS[/color] %s (retry) — %d/%d (%s%%) — %d ms" % [name, successes, total, pct_str, last_duration])
                            test_result["flaky"] = true
                            test_result["retry_count"] = attempt
                            global_flaky += 1
                            flaky_tests.append(name)
                            _log("⚠️ Flaky test detected: %s (passed after %d retry)" % [name, attempt])
                        final_passed = true
                        test_result["passed"] = true
                    else:
                        _log("[color=red]FAIL[/color] %s — %d/%d (%s%%) — %d ms" % [name, successes, total, pct_str, last_duration])
                        var errs: Array = result.get("errors", [])
                        for err in errs:
                            var msg = err.get("msg", str(err)) if typeof(err) == TYPE_DICTIONARY else str(err)
                            _log("    ❌ %s" % msg)
                            test_result["errors"].append(err)
                        if attempt < max_retries:
                            attempt += 1
                            _log("Retrying (%d/%d)..." % [attempt, max_retries])
                            continue
                        else:
                            all_passed = false
                            batch_failed = true
                    # end if passed
                else:
                    if attempt < max_retries:
                        attempt += 1
                        _log("Retrying (%d/%d)..." % [attempt, max_retries])
                        continue
                    else:
                        all_passed = false
                        batch_failed = true
                break

            if not test_outcomes.has(name):
                test_outcomes[name] = "passed" if test_result["passed"] else "failed"

            _log("   tags: %s" % ", ".join(tags))
            _log("   priority: %s" % priority)
            _log("   owner: %s" % owner)

            _update_group(by_priority, priority, test_result)
            _update_group(by_owner, owner, test_result)
            for t in tags:
                _update_group(by_tags, t, test_result)

            results["tests"].append(test_result)

        if batch_size > 0:
            if batch_failed:
                _log("❌ Some tests failed in batch %d" % (b+1))
            else:
                _log("✅ All tests passed in batch %d" % (b+1))

    var suite_duration_ms: int = Time.get_ticks_msec() - suite_start
    var global_pct := float(global_successes) / float(global_total) * 100.0 if global_total > 0 else 100.0
    var global_pct_str := "%.1f" % global_pct

    results["global"] = {
        "passed": all_passed,
        "successes": global_successes,
        "total": global_total,
        "skipped": global_skipped,
        "blocked_count": global_blocked,
        "flaky_count": global_flaky,
        "duration": suite_duration_ms
    }

    _log("")
    _log("[b]=== GLOBAL TEST SUMMARY ===[/b]")
    _log("Total: %d/%d (%s%%) — %d ms, Skipped: %d, Flaky: %d, Blocked: %d" % [global_successes, global_total, global_pct_str, suite_duration_ms, global_skipped, global_flaky, global_blocked])

    _print_group_summary("Priority", by_priority)
    _print_group_summary("Owner", by_owner)
    _print_group_summary("Tag", by_tags)

    if global_flaky > 0:
        _log("")
        _log("[b]=== Flaky Tests ===[/b]")
        for f in flaky_tests:
            _log("%s" % f)

    if not disable_json:
        var file := FileAccess.open(out_dir + "results.json", FileAccess.WRITE)
        if file:
            file.store_string(JSON.stringify(results, "  "))
            file.close()
            print("Results saved to %sresults.json" % out_dir)

    if not disable_xml:
        var xml: String = _build_junit_xml(results)
        var file2 := FileAccess.open(out_dir + "results.xml", FileAccess.WRITE)
        if file2:
            file2.store_string(xml)
            file2.close()
            print("Results saved to %sresults.xml" % out_dir)

    var summary_line: String = "::summary::%d/%d tests passed, %d failed, %d skipped, %d flaky, %d blocked in %d ms" % [global_successes, global_total, global_total - global_successes, global_skipped, global_flaky, global_blocked, suite_duration_ms]
    print(summary_line)

    _dump_resource_cache()

    if all_passed:
        _log("[color=green]✅ All test suites passed.[/color]")
        quit(0)
    else:
        _log("[color=red]❌ Some test suites failed.[/color]")
        quit(1)

func _update_group(map: Dictionary, key: String, test_result: Dictionary) -> void:
    if not map.has(key):
        map[key] = {"successes": 0, "total": 0, "failed": 0}
    map[key]["total"] += test_result["total"]
    map[key]["successes"] += test_result["successes"]
    if not test_result["passed"]:
        map[key]["failed"] += 1

func _print_group_summary(label: String, map: Dictionary) -> void:
    _log("")
    _log("[b]=== Summary by %s ===[/b]" % label)
    for k in map.keys():
        var v: Dictionary = map[k]
        var passed: int = v["successes"]
        var total: int = v["total"]
        var failed: int = v["failed"]
        _log("%s: %d/%d passed, %d failed" % [k, passed, total, failed])

func _has_flag(flag: String) -> bool:
    for a in OS.get_cmdline_args():
        if a == flag:
            return true
    return false

func _get_flag_values(flag: String) -> Array:
    var values: Array = []
    var args: Array = OS.get_cmdline_args()
    for i in range(args.size()):
        if args[i] == flag and i + 1 < args.size():
            values.append_array(args[i+1].split(","))
    return values

func _tags_match(tags: Array, filters: Array) -> bool:
    for f in filters:
        if tags.has(f):
            return true
    return false

func _load_manifest(path: String) -> Array:
    var scripts: Array = []
    if not FileAccess.file_exists(path):
        return []
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        return []
    var data: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not (data is Dictionary):
        return []
    if data.has("tests"):
        for entry in data["tests"]:
            if entry is String:
                scripts.append(entry)
            elif entry is Dictionary and entry.has("path"):
                scripts.append(entry)
                if entry["path"].ends_with(".json") and entry["path"].find("manifest") != -1:
                    scripts.append_array(_load_manifest(entry["path"]))
    return scripts

# Orders tests so that dependencies declared via `depends_on`
# run before their dependents while preserving manifest order
# for tests without dependencies.
func _resolve_dependencies(tests: Array) -> Array:
    var name_to_entry: Dictionary = {}
    for entry in tests:
        var path: String = entry["path"] if entry is Dictionary else entry
        name_to_entry[path.get_file()] = entry

    var ordered: Array = []
    var visiting: Dictionary = {}
    var visited: Dictionary = {}

    for entry in tests:
        var path: String = entry["path"] if entry is Dictionary else entry
        _visit_dependency(path.get_file(), name_to_entry, visiting, visited, ordered)

    return ordered

func _visit_dependency(name: String, name_to_entry: Dictionary, visiting: Dictionary, visited: Dictionary, ordered: Array) -> void:
    if visited.has(name):
        return
    if visiting.has(name):
        push_error("Circular dependency detected for %s" % name)
        return

    visiting[name] = true
    var entry = name_to_entry.get(name, null)
    if entry != null:
        var deps: Array = entry["depends_on"] if entry is Dictionary and entry.has("depends_on") else []
        for dep in deps:
            if name_to_entry.has(dep):
                _visit_dependency(dep, name_to_entry, visiting, visited, ordered)
    visiting.erase(name)
    visited[name] = true
    if entry != null:
        ordered.append(entry)

func _build_junit_xml(results: Dictionary) -> String:
    var xml: String = "<testsuites>\n"
    var global: Dictionary = results["global"]
    var suite_name: String = "GodotTestSuite"
    var total: int = global["total"]
    var failures: int = total - global["successes"]
    var time := str(float(global["duration"]) / 1000.0)

    xml += "  <testsuite name=\"%s\" tests=\"%d\" failures=\"%d\" skipped=\"%d\" time=\"%s\">\n" % [suite_name, total, failures, global["skipped"] + global.get("blocked_count", 0), time]

    for t in results["tests"]:
        var case_name: String = t["name"]
        var case_time: String = str(float(t["duration"]) / float(1000.0))
        xml += "    <testcase classname=\"%s\" name=\"%s\" time=\"%s\">\n" % [case_name, case_name, case_time]
        xml += "      <properties>\n"
        xml += "        <property name=\"tags\" value=\"%s\"/>\n" % ",".join(t["tags"])
        xml += "        <property name=\"priority\" value=\"%s\"/>\n" % t["priority"]
        xml += "        <property name=\"owner\" value=\"%s\"/>\n" % t["owner"]
        xml += "        <property name=\"flaky\" value=\"%s\"/>\n" % ("true" if t["flaky"] else "false")
        xml += "        <property name=\"retry_count\" value=\"%d\"/>\n" % t["retry_count"]
        xml += "      </properties>\n"
        if t.get("blocked", false):
            var dep_tokens: Array = t["blocked_reason"].split(" ")
            var dep_name: String = dep_tokens[1] if dep_tokens.size() >= 2 else t["blocked_reason"]
            xml += "      <skipped message=\"Blocked by dependency %s\"/>\n" % dep_name
        elif not t["passed"]:
            for err in t["errors"]:
                var msg = err.get("msg", str(err)) if typeof(err) == TYPE_DICTIONARY else str(err)
                xml += "      <failure message=\"%s\">%s</failure>\n" % [msg, msg]
        xml += "    </testcase>\n"

    xml += "  </testsuite>\n"
    xml += "</testsuites>\n"
    return xml

func _log(msg: String) -> void:
    if use_color:
        print_rich(msg)
    else:
        var clean := msg.replace("[color=green]","").replace("[color=red]","").replace("[color=yellow]","").replace("[b]","").replace("[/b]","").replace("[/color]","")
        print(clean)

func _dump_resource_cache() -> void:
    var count: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
    if count > 0:
        _log("")
        _log("[b]=== Resource Diagnostics ===[/b]")
        _log("Resources still in memory: %d" % count)
        for path in _tracked_paths:
            if ResourceLoader.has_cached(path):
                _log("Cached: %s" % path)
        var dir := DirAccess.open("res://tests/test_assets/")
        if dir:
            dir.list_dir_begin()
            var file_name := dir.get_next()
            while file_name != "":
                if file_name.ends_with(".tres"):
                    var apath := "res://tests/test_assets/" + file_name
                    if ResourceLoader.has_cached(apath):
                        _log("Cached: %s" % apath)
                file_name = dir.get_next()
            dir.list_dir_end()



