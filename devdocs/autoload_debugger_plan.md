# Autoload Debugger Implementation Plan

## Purpose and Guiding Principles
- Provide a unified, always-on diagnostics layer for all autoload singletons (`EventBus`, `AssetRegistry`, `ModuleRegistry`, and `ULTEnums`).
- Record high-signal error and warning events with enough structured metadata that engineers can triage issues without reproducing them locally.
- Preserve the low-friction workflow established in the design docs: singletons remain lightweight and decoupled, while the debugger observes their behaviour without introducing circular dependencies.
- Ship editor-friendly tooling (a dockable panel and exported reports) so designers can view validation output when authoring resources.

## Autoload Inventory and Instrumentation Points

### EventBus (`res://src/globals/EventBus.gd`)
- Already validates payloads inside `emit_signal()` and produces `push_error` messages when contracts are violated.
- Provides structured signal metadata through `SIGNAL_CONTRACTS` and `describe_signal()`.
- **Hook Plan:** Wrap `emit_signal()` to forward validation results (success or error code) and payload snapshots to the debugger. Capture:
  - Signal name, payload dictionary, contract lookup, validation result.
  - Caller stack snippet (via `get_stack()` when running in debug builds).
  - Timestamp to reconstruct chronological order during multi-system tests.

### AssetRegistry (`res://src/globals/AssetRegistry.gd`)
- Performs recursive directory scans and records failures in `failed_assets` while emitting `push_warning` / `push_error` logs.
- **Hook Plan:** Emit structured events whenever:
  - A directory cannot be opened (`_scan_and_load_assets`).
  - A resource fails to load (`_ingest_resource`).
  - A duplicate key replaces an existing asset.
- Recorded metadata: path, error code, Godot error string, optional stack trace, registry snapshot counts (assets vs. failures).

### ModuleRegistry (`res://src/globals/ModuleRegistry.gd`)
- Manages lifecycle of procedural modules with guard rails (`push_warning` on invalid registrations, cleanup hooks, etc.).
- **Hook Plan:** Report key transitions to the debugger:
  - Registration, replacement, and unregistration events.
  - Automatic clean-up triggered by `_on_module_tree_exiting`.
  - Any rejected registration attempts (empty name, invalid node).
- Metadata to include: module name (`StringName`), node path, validity flags, and whether the event was manual or automatic.

### ULTEnums (`res://src/globals/ULTEnums.gd`)
- Defines entity taxonomy and `ComponentKeys` metadata plus validation helpers (`assert_valid_*`, `inspect_component_dictionary`, etc.).
- **Hook Plan:**
  - Instrument `assert_valid_entity_type` and `assert_valid_component_key` so both log to the debugger in addition to `push_error` when a check fails.
  - When `inspect_component_dictionary()` or `validate_component_dictionary()` run, forward the generated report/messages to the debugger for archival.
- Captured metadata: offending value, normalized key, validation report, context dictionary provided by caller when available.

## Autoload Debugger Design Overview

### Singleton Responsibilities
1. **Event Bus for Diagnostics:** Provide typed methods such as `log_error(source: StringName, payload: Dictionary)` and `log_warning(...)` so monitored singletons forward structured data without depending on concrete debugger implementation.
2. **Persistent Ring Buffer:** Maintain bounded history (configurable size) storing dictionaries with fields:
   - `timestamp` (float, `Time.get_singleton().get_ticks_msec()/1000.0`).
   - `source_autoload` (`StringName`).
   - `event` (`StringName`, e.g., `signal_validation_failed`, `asset_load_failed`).
   - `severity` (enum with values INFO/WARNING/ERROR).
   - `details` (Dictionary mirroring singleton-specific metadata defined above).
3. **Export Interfaces:**
   - Method returning a deep copy of the log for tests (`export_log(): Array[Dictionary]`).
   - Optional streaming signal `debug_event_logged(details: Dictionary)` so UI panels can update live.
4. **Aggregation Helpers:** Provide query helpers (e.g., `find_latest_errors(source_autoload: StringName)`), JSON export for CI attachments, and summary stats for quick health overviews.

### Integration Strategy
- The debugger lives in `res://src/globals/AutoloadDebugger.gd` and is autoloaded before other singletons so hooks are available during their `_ready()` callbacks.
- Each monitored singleton imports the debugger via `const AutoloadDebugger = preload("res://src/globals/AutoloadDebugger.gd")` or by calling `AutoloadDebugger.get_singleton()` if we mirror the pattern used by `EventBus`.
- Introduce minimal wrapper helpers (e.g., `_report_error(event: StringName, details: Dictionary)`) inside each singleton to avoid repetitive boilerplate and to ensure logging survives refactors.
- Maintain optional toggles (exported booleans) so developers can disable verbose logging in performance-critical builds.

## Data Model Specification
| Field             | Type          | Description                                                                 |
|-------------------|---------------|-----------------------------------------------------------------------------|
| `timestamp`       | `float`       | UTC timestamp in seconds when the event was recorded.                       |
| `source_autoload` | `StringName`  | Which singleton reported the event.                                         |
| `event`           | `StringName`  | Event identifier (`signal_emitted`, `component_key_invalid`, etc.).         |
| `severity`        | `int` enum    | 0 = INFO, 1 = WARNING, 2 = ERROR.                                           |
| `details`         | `Dictionary`  | Source-specific payload (payload copies, module names, validation issues).  |
| `stack` *(opt)*   | `Array`       | Optional call stack frames when captured (debug builds only).              |

## Phase Breakdown
1. **Foundation (Sprint 1):**
   - Implement `AutoloadDebugger` with ring buffer, export functions, and optional signal.
   - Add autoload entry and confirm singleton order (Debugger first).
   - Unit test core logging API using minimal Godot headless scripts or GUT harness.
2. **Instrumentation (Sprint 2):**
   - Update each singleton to import the debugger and emit structured events at the touch points described above.
   - Extend existing tests (e.g., EventBus test harness) to assert the debugger captured validation failures correctly.
3. **Editor Tooling (Sprint 3):**
   - Build a `Control`-based dock that subscribes to `debug_event_logged` and visualises records (filter by source, severity, time range).
   - Provide export button writing JSON to `res://tests/results/` for inclusion in CI artifacts.
4. **Advanced Analytics (Stretch):**
   - Correlate repeated errors (e.g., same asset failing to load multiple times) and surface aggregated counts.
  - Integrate with `ULTEnums.inspect_component_dictionary()` to annotate entries with missing component keys vs. null references.

## Testing and Maintenance Plan
- Extend automated regression scenes (`EventBus_TestHarness.tscn`, `Sprint1_Validation.tscn`) with scripts that intentionally trigger errors and then assert the debugger recorded them.
- Provide a CLI script (GDScript `@tool`) to dump the debugger log for QA triage.
- Document onboarding steps in `devdocs` so new engineers know how to enable verbose logging and interpret debugger output.
- Schedule quarterly audits of the debugger schema to accommodate new autoloads or metadata requirements.
