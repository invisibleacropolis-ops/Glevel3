# src/tests/TestRunner.gd (Step 11: flaky test detection + retries)
extends SceneTree

var use_color := true
var out_dir := "res://tests/"

func _init() -> void:
    print("Running headless test suite...")

    use_color = not _has_flag("--no-color")
    var out_dir_values := _get_flag_values("--out-dir")
    if out_dir_values.size() > 0:
        out_dir = out_dir_values[0]
        if not out_dir.ends_with("/"):
            out_dir += "/"

    var suite_start := Time.get_ticks_msec()
    var all_passed := true
    var global_successes := 0
    var global_total := 0
    var global_skipped := 0
    var global_flaky := 0
    var results := {"tests": []}

    var test_scripts := _load_manifest("res://tests_manifest.json")
    if test_scripts.is_empty():
        push_error("No tests found in manifest. Ensure res://tests_manifest.json exists and is valid.")
        quit(1)

    var disable_json := _has_flag("--no-json")
    var disable_xml := _has_flag("--no-xml")
    var simple_mode := _has_flag("--simple")
    var batch_size := _get_flag_values("--batch-size").size() > 0 ? int(_get_flag_values("--batch-size")[0]) : 0
    var slow_n := _get_flag_values("--slow").size() > 0 ? int(_get_flag_values("--slow")[0]) : 5
    var max_retries := _get_flag_values("--retries").size() > 0 ? int(_get_flag_values("--retries")[0]) : 0

    var tag_filters := _get_flag_values("--tags")
    var skip_filters := _get_flag_values("--skip")
    var pri_filters := _get_flag_values("--priority")
    var owner_filters := _get_flag_values("--owner")

    var batch_count := batch_size > 0 ? int(ceil(float(test_scripts.size()) / float(batch_size))) : 1

    var by_priority := {}
    var by_owner := {}
    var by_tags := {}
    var flaky_tests := []

    for b in range(batch_count):
        if batch_size > 0:
            _log("[b]=== Batch %d/%d ===[/b]" % [b+1, batch_count])
        var batch_failed := false
        var start_index := b * batch_size
        var end_index := batch_size > 0 ? min((b+1) * batch_size, test_scripts.size()) : test_scripts.size()
        var scripts_in_batch := test_scripts.slice(start_index, end_index)

        for entry in scripts_in_batch:
            var script_path := typeof(entry) == TYPE_DICTIONARY ? entry.path : entry
            var name := script_path.get_file()
            var tags := typeof(entry) == TYPE_DICTIONARY and entry.has("tags") ? entry.tags : []
            var priority := typeof(entry) == TYPE_DICTIONARY and entry.has("priority") ? entry.priority : "unspecified"
            var owner := typeof(entry) == TYPE_DICTIONARY and entry.has("owner") ? entry.owner : "unspecified"

            if tag_filters.size() > 0 and not _tags_match(tags, tag_filters):
                _log("[color=yellow]SKIP[/color] %s — tag filter mismatch" % name)
                global_skipped += 1
                continue
            if skip_filters.size() > 0 and _tags_match(tags, skip_filters):
                _log("[color=yellow]SKIP[/color] %s — skipped by tag" % name)
                global_skipped += 1
                continue
            if pri_filters.size() > 0 and not pri_filters.has(priority):
                _log("[color=yellow]SKIP[/color] %s — priority filter mismatch" % name)
                global_skipped += 1
                continue
            if owner_filters.size() > 0 and not owner_filters.has(owner):
                _log("[color=yellow]SKIP[/color] %s — owner filter mismatch" % name)
                global_skipped += 1
                continue

            var test_result := {
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
                "retry_count": 0
            }

            var attempt := 0
            var final_passed := false
            var last_duration := 0

            while attempt <= max_retries and not final_passed:
                var test_class = load(script_path)
                if test_class == null:
                    _log("[color=red]FAIL[/color] %s — could not load script" % name)
                    all_passed = false
                    batch_failed = true
                    test_result.errors.append("Could not load script")
                    break

                var test_instance = test_class.new()
                if not test_instance.has_method("run_test"):
                    _log("[color=yellow]SKIP[/color] %s — no run_test() method" % name)
                    test_result["passed"] = true
                    global_skipped += 1
                    break

                var start := Time.get_ticks_msec()
                var result : Dictionary
                var caught_error := false

                try:
                    result = await test_instance.run_test()
                catch e:
                    push_error("Exception in %s: %s" % [name, str(e)])
                    test_result.errors.append({"msg": "Exception", "got": str(e)})
                    caught_error = true
                    all_passed = false
                    batch_failed = true

                last_duration = Time.get_ticks_msec() - start

                if not caught_error and result:
                    var passed := result.get("passed", false)
                    var successes := result.get("successes", 0)
                    var total := result.get("total", 0)

                    test_result.successes = successes
                    test_result.total = total
                    test_result.duration = last_duration

                    global_successes += successes
                    global_total += total

                    var pct := total > 0 ? float(successes) / float(total) * 100.0 : 100.0
                    var pct_str := "%.1f" % pct

                    if passed:
                        if attempt == 0:
                            _log("[color=green]PASS[/color] %s — %d/%d (%s%%) — %d ms" % [name, successes, total, pct_str, last_duration])
                        else:
                            _log("[color=green]PASS[/color] %s (retry) — %d/%d (%s%%) — %d ms" % [name, successes, total, pct_str, last_duration])
                            test_result.flaky = true
                            test_result.retry_count = attempt
                            global_flaky += 1
                            flaky_tests.append(name)
                            _log("⚠️ Flaky test detected: %s (passed after %d retry)" % [name, attempt])
                        final_passed = true
                        test_result.passed = true
                    else:
                        _log("[color=red]FAIL[/color] %s — %d/%d (%s%%) — %d ms" % [name, successes, total, pct_str, last_duration])
                        var errs = result.get("errors", [])
                        for err in errs:
                            var msg = typeof(err) == TYPE_DICTIONARY ? err.get("msg", str(err)) : str(err)
                            _log("    ❌ %s" % msg)
                            test_result.errors.append(err)
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

            _log("   tags: %s" % ", ".join(tags))
            _log("   priority: %s" % priority)
            _log("   owner: %s" % owner)

            _update_group(by_priority, priority, test_result)
            _update_group(by_owner, owner, test_result)
            for t in tags:
                _update_group(by_tags, t, test_result)

            results.tests.append(test_result)

        if batch_size > 0:
            if batch_failed:
                _log("❌ Some tests failed in batch %d" % (b+1))
            else:
                _log("✅ All tests passed in batch %d" % (b+1))

    var suite_duration_ms := Time.get_ticks_msec() - suite_start
    var global_pct := global_total > 0 ? float(global_successes) / float(global_total) * 100.0 : 100.0
    var global_pct_str := "%.1f" % global_pct

    results["global"] = {
        "passed": all_passed,
        "successes": global_successes,
        "total": global_total,
        "skipped": global_skipped,
        "flaky_count": global_flaky,
        "duration": suite_duration_ms
    }

    _log("")
    _log("[b]=== GLOBAL TEST SUMMARY ===[/b]")
    _log("Total: %d/%d (%s%%) — %d ms, Skipped: %d, Flaky: %d" % [global_successes, global_total, global_pct_str, suite_duration_ms, global_skipped, global_flaky])

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
        var xml := _build_junit_xml(results)
        var file2 := FileAccess.open(out_dir + "results.xml", FileAccess.WRITE)
        if file2:
            file2.store_string(xml)
            file2.close()
            print("Results saved to %sresults.xml" % out_dir)

    var summary_line := "::summary::%d/%d tests passed, %d failed, %d skipped, %d flaky in %d ms" % [global_successes, global_total, global_total - global_successes, global_skipped, global_flaky, suite_duration_ms]
    print(summary_line)

    if all_passed:
        _log("[color=green]✅ All test suites passed.[/color]")
        quit(0)
    else:
        _log("[color=red]❌ Some test suites failed.[/color]")
        quit(1)

func _update_group(map: Dictionary, key: String, test_result: Dictionary) -> void:
    if not map.has(key):
        map[key] = {"successes": 0, "total": 0, "failed": 0}
    map[key].total += test_result.total
    map[key].successes += test_result.successes
    if not test_result.passed:
        map[key].failed += 1

func _print_group_summary(label: String, map: Dictionary) -> void:
    _log("")
    _log("[b]=== Summary by %s ===[/b]" % label)
    for k in map.keys():
        var v = map[k]
        var passed := v.successes
        var total := v.total
        var failed := v.failed
        _log("%s: %d/%d passed, %d failed" % [k, passed, total, failed])

func _has_flag(flag: String) -> bool:
    for a in OS.get_cmdline_args():
        if a == flag:
            return true
    return false

func _get_flag_values(flag: String) -> Array:
    var values := []
    var args := OS.get_cmdline_args()
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
    var scripts := []
    if not FileAccess.file_exists(path):
        return []
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        return []
    var data := JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(data) != TYPE_DICTIONARY:
        return []
    if data.has("tests"):
        for entry in data.tests:
            if typeof(entry) == TYPE_STRING:
                scripts.append(entry)
            elif typeof(entry) == TYPE_DICTIONARY and entry.has("path"):
                scripts.append(entry)
                if entry.path.ends_with(".json") and entry.path.find("manifest") != -1:
                    scripts.append_array(_load_manifest(entry.path))
    return scripts

func _build_junit_xml(results: Dictionary) -> String:
    var xml := "<testsuites>\n"
    var global := results.global
    var suite_name := "GodotTestSuite"
    var total := global.total
    var failures := total - global.successes
    var time := str(float(global.duration) / 1000.0)

    xml += "  <testsuite name=\"%s\" tests=\"%d\" failures=\"%d\" skipped=\"%d\" time=\"%s\">\n" % [suite_name, total, failures, global.skipped, time]

    for t in results.tests:
        var case_name := t.name
        var case_time := str(float(t.duration) / float(1000.0))
        xml += "    <testcase classname=\"%s\" name=\"%s\" time=\"%s\">\n" % [case_name, case_name, case_time]
        xml += "      <properties>\n"
        xml += "        <property name=\"tags\" value=\"%s\"/>\n" % ",".join(t.tags)
        xml += "        <property name=\"priority\" value=\"%s\"/>\n" % t.priority
        xml += "        <property name=\"owner\" value=\"%s\"/>\n" % t.owner
        xml += "        <property name=\"flaky\" value=\"%s\"/>\n" % (t.flaky ? "true" : "false")
        xml += "        <property name=\"retry_count\" value=\"%d\"/>\n" % t.retry_count
        xml += "      </properties>\n"
        if not t.passed:
            for err in t.errors:
                var msg = typeof(err) == TYPE_DICTIONARY ? err.get("msg", str(err)) : str(err)
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



