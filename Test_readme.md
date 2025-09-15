# Godot Headless Test Runner

This document provides a thorough reference for the `tests/Test_runner.gd` script. The runner executes GDScript-based tests in a headless Godot environment, supports dependency ordering, flaky test retries, result aggregation, output serialization, and basic leak diagnostics.

## Overview

The script extends `SceneTree` and runs automatically on initialization. When invoked, it prints a banner and begins processing the test manifest. Tests are loaded from `res://tests_manifest.json` and executed in a deterministic order that respects inter-test dependencies.

Key features include:

- Manifest-driven test discovery and dependency resolution.
- Tag, priority, and owner filtering to select subsets of tests.
- Optional batching of tests and retries for flaky cases.
- Output in colorized or plain text logs.
- Summary statistics and grouped metrics.
- Generation of `results.json` and JUnit-compatible `results.xml` reports.
- Explicit tracking of skipped and blocked tests.

## Running the Runner

Invoke the runner with a headless Godot 4.4.1 binary:

```bash
/path/to/godot4 --headless --path . -s tests/Test_runner.gd
```

## Command-line Flags

The runner inspects CLI arguments using `OS.get_cmdline_args()` and supports the following switches:

| Flag | Purpose | Default |
|------|---------|---------|
| `--no-color` | Disable rich color output. | color enabled |
| `--out-dir <path>` | Directory for output files (`results.json`/`results.xml`). A trailing slash is added if missing. | `res://tests/` |
| `--no-json` | Suppress writing `results.json`. | enabled |
| `--no-xml` | Suppress writing `results.xml`. | enabled |
| `--simple` | Placeholder flag for simplified output; not currently used. | disabled |
| `--batch-size <N>` | Run tests in batches of `N`. | all tests in one batch |
| `--slow <N>` | Threshold (ms) for flagging slow tests. Currently unused. | `5` |
| `--retries <N>` | Number of times to retry failing tests to detect flakiness. | `0` |
| `--tags tag1,tag2` | Only run tests containing any of the listed tags. | no filter |
| `--skip tag1,tag2` | Skip tests containing any of the listed tags. | none |
| `--priority p1,p2` | Only run tests with matching `priority`. | no filter |
| `--owner name1,name2` | Only run tests owned by listed people. | no filter |

## Test Manifest and Dependency Handling

Tests are declared in `tests_manifest.json`. Each entry may be a string path or an object with metadata such as `tags`, `priority`, `owner`, and `depends_on` for dependency tracking. The runner loads the manifest and reorders tests so that all dependencies execute before dependents. A test whose dependency fails or is skipped is marked as **blocked** and not run.

## Execution Flow

1. Parse CLI flags and establish configuration variables.
2. Load and order the manifest.
3. Optionally divide the test list into batches.
4. For each test:
   - Skip if tag/priority/owner filters do not match.
   - Skip and mark as blocked if any dependency did not pass.
   - Instantiate the test script and call its `run_test()` method.
   - Capture successes, totals, duration, and any errors.
   - Retry failing tests up to `--retries` times; a later pass marks the test as flaky.
5. Record results and update grouped metrics by tag, priority, and owner.
6. After all tests (or each batch) print status lines and aggregate statistics.
7. Emit JSON and XML reports unless disabled by flags.
8. Exit with code `0` if all tests passed, `1` otherwise.

## Output Artifacts

Unless suppressed, the runner writes two files to the output directory:

- `results.json` – Raw structured data with per-test details and a global summary.
- `results.xml` – JUnit-format report suitable for CI tools.

Both files include metadata such as tags, priority, owner, flakiness, retry counts, and durations. The console also prints a GitHub Actions-compatible summary line in the form `::summary::X/Y tests passed...`.

## Test Script Contract

Each test script referenced in the manifest must implement a `run_test()` method returning a dictionary with:

- `passed`: boolean
- `successes`: number of passed assertions
- `total`: total assertions
- `errors`: optional array of error dictionaries `{"msg": "..."}` or strings

The runner logs pass/fail results with timing, accumulates global statistics, and adds metadata (tags, priority, owner) for later aggregation.

## Grouped Summaries

After execution, the runner prints grouped summaries:

- **Priority** – successes, totals, and failed test count per priority level.
- **Owner** – aggregation by test owner.
- **Tag** – aggregation by tag.

Flaky tests are listed separately when detected.

### Resource Diagnostics

To aid debugging when Godot reports resources still in use at exit, the runner now emits a "Resource Diagnostics" section. It prints the total number of `Resource` objects still alive and lists any cached test scripts or assets that remain referenced. This helps pinpoint leaks during test development.

## Notes

- The script currently defines `--simple` and `--slow` switches without implementing associated behaviour.
- Dependency tracking expects manifest entries to reference dependencies by filename.
- Ensure the specified output directory exists or is writable; otherwise file operations may fail silently.

