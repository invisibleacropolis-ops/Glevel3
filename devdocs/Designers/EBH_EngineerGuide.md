# EventBus Harness Engineer Guide

This guide explains how the [`EventBus` autoload](../src/globals/EventBus.gd) is validated through the dedicated harness scene and automated tests.
It is intended for engineers who need to emit diagnostic payloads, replay captured logs, or extend the system with new contracts.

## Key scripts

* [`src/globals/EventBus.gd`](../src/globals/EventBus.gd) – singleton that defines the contracts and runtime validation rules for every published signal. `emit_signal()` wraps the built-in implementation with contract validation, so malformed payloads never propagate to downstream systems.【F:src/globals/EventBus.gd†L82-L178】
* [`src/tests/EventBusHarness.gd`](../src/tests/EventBusHarness.gd) – control surface that builds form inputs for each contract, emits payloads, and manages log export/replay. `_build_signal_controls()` generates UI from the live contracts and `_wire_signal_controls()` binds emit/utility buttons at runtime so the scene stays synchronized with code.【F:src/tests/EventBusHarness.gd†L35-L210】【F:src/tests/EventBusHarness.gd†L471-L540】
* [`src/tests/EventBusHarnessListener.gd`](../src/tests/EventBusHarnessListener.gd) – omniscient subscriber that mirrors every EventBus signal into the harness log. `_connect_to_bus()` binds a reference-counted callable per signal and relays payloads back to the harness’ `append_log()` helper.【F:src/tests/EventBusHarnessListener.gd†L13-L86】

## Runtime flow at a glance

1. **EventBus resolution.** `_resolve_event_bus()` locates the active autoload on the scene tree or instantiates a private copy (added deferred when required) so engineers can run the harness in isolation without modifying project autoloads.【F:src/tests/EventBusHarness.gd†L541-L573】
2. **Dynamic UI generation.** Once the scene is ready, `_build_signal_controls()` clears previous children, sorts contract names, and produces a section for each signal including per-field tooltips and validation metadata. `_apply_field_error_styles()` and `_coerce_field_value()` work together to keep inline validation and type coercion consistent across sessions.【F:src/tests/EventBusHarness.gd†L35-L210】【F:src/tests/EventBusHarness.gd†L235-L371】
3. **Emission and logging.** `_emit_signal()` gathers the payload dictionary from the current editors. When validation passes it forwards the payload to `EventBus.emit_signal()`. The listener’s `_on_signal_received()` then calls back into `append_log()` so every broadcast is timestamped in the RichTextLabel.【F:src/tests/EventBusHarness.gd†L219-L388】【F:src/tests/EventBusHarnessListener.gd†L60-L86】
4. **Replay pipeline.** Selecting **Replay Log** funnels the chosen file through `_on_replay_file_selected()` and `replay_signals_from_json()`. The helper accepts raw JSON text or an in-memory array, performs structural validation per entry, and replays each payload while logging the Godot error code for auditing.【F:src/tests/EventBusHarness.gd†L389-L644】

## EventBus contracts

All EventBus payloads must be `Dictionary` values. Runtime validation inside `EventBus.emit_signal()` enforces the keys and Variant types described below. Keys marked _optional_ may be omitted entirely. When multiple types are listed the payload may supply any of them.

### `debug_stats_reported`

| Key | Type(s) | Notes |
| --- | --- | --- |
| `entity_id` | `String`, `StringName` | Required. Identifier for the entity whose stats were sampled. |
| `stats` | `Dictionary` | Required. Raw snapshot of the entity's `StatsComponent`. |
| `timestamp` | `float` | Optional monotonic timestamp. |

### `entity_killed`

| Key | Type(s) | Notes |
| --- | --- | --- |
| `entity_id` | `String`, `StringName` | Required. Identifier of the defeated entity. |
| `killer_id` | `String`, `StringName` | Optional. Identifier of the entity or hazard responsible for the kill. |
| `archetype_id` | `String`, `StringName` | Optional. Original archetype for analytics and loot tuning. |
| `entity_type` | `StringName` | Optional. High-level taxonomy (e.g., `&"enemy"`). |
| `components` | `Dictionary` | Optional. Snapshot of component values attached to the entity. |

### `item_acquired`

| Key | Type(s) | Notes |
| --- | --- | --- |
| `item_id` | `String`, `StringName` | Required. Identifier of the item resource or definition. |
| `quantity` | `int` | Required. Number of units added to the inventory. |
| `owner_id` | `String`, `StringName` | Optional. Recipient entity identifier. |
| `source` | `StringName` | Optional. Acquisition source (e.g., `&"loot_drop"`, `&"vendor_purchase"`). |
| `metadata` | `Dictionary` | Optional. Arbitrary supplemental context passed to UI or analytics. |

### `quest_state_changed`

| Key | Type(s) | Notes |
| --- | --- | --- |
| `quest_id` | `String`, `StringName` | Required. Identifier of the quest resource or runtime instance. |
| `state` | `StringName` | Required. New state value such as `&"in_progress"` or `&"completed"`. |
| `progress` | `float` | Optional. Normalized progress between `0.0` and `1.0`. |
| `objectives` | `Array` | Optional. Collection of per-objective dictionaries for UI presentation. |
| `metadata` | `Dictionary` | Optional. Free-form context delivered to notification, quest, or analytics systems. |

If a payload fails validation, `emit_signal()` returns a non-`OK` error and logs a descriptive message so defects are caught before reaching listeners.

## Harness workflow

The harness scene [`tests/EventBus_TestHarness.tscn`](../tests/EventBus_TestHarness.tscn) instantiates `EventBusHarness.gd` and its listener. When the scene enters the tree:

1. The harness resolves the active EventBus singleton or spawns a private instance if the autoload is absent, ensuring isolated tests remain deterministic.
2. UI controls are generated dynamically for every contract in `EventBus.SIGNAL_CONTRACTS`. Required fields are flagged with red borders and tooltips until valid data is supplied.
3. Pressing an "Emit" button serializes the current form into a `Dictionary`, validates it locally, and calls `EventBus.emit_signal()`.
4. The listener mirrors every broadcast into the scrollable log with a timestamp and JSON payload so teams can inspect interactions.
5. Log buttons allow the operator to clear entries, export them to disk, or replay a JSON transcript through the bus.

Because controls are generated from the source contracts, new signals become available in the harness automatically after updating `EventBus.gd`.

## Running the harness scene

### From the Godot editor

1. Open the project in the Godot editor.
2. In the FileSystem dock, double-click `tests/EventBus_TestHarness.tscn`.
3. Press <kbd>F6</kbd> (Run Current Scene) to launch the harness.
4. Populate the required fields for a signal, press the corresponding "Emit" button, and review the results in the log pane.

### Via the command line

Use the Godot CLI to run the harness in isolation (handy for remote desktop sessions or continuous integration smoke tests):

```bash
godot4 --path . --scene res://tests/EventBus_TestHarness.tscn
```

Godot will open the scene with the same controls provided by the editor workflow.

When a graphical session is unavailable, the Python automation helpers under `tools/` can orchestrate a headless run. Export `CODEX_GODOT_BIN` with the path to your Godot executable and execute a short script that reuses the shared process manager:

```bash
python - <<'PY'
from tools.codex_godot_process_manager import CodexGodotProcessManager

with CodexGodotProcessManager(extra_args=["--scene", "res://tests/EventBus_TestHarness.tscn"]) as session:
    print(session.describe_session())
PY
```

`CodexGodotProcessManager` wraps `subprocess.Popen` with Codex defaults (headless mode, JSON-friendly pipes, heartbeat support) so the same entry point powers CI smoke tests and local reproductions.【F:tools/codex_godot_process_manager.py†L40-L208】

## Log export and replay

### Exported log files

Selecting **Save Log** writes the rendered transcript to disk using `_log_label.get_parsed_text()`. The log is plain text that mirrors what you see in the UI, for example:

```
[12:34:56] debug_stats_reported -> {"entity_id":"npc_rogue","stats":{"health":42}}
[12:35:11] entity_killed -> {"entity_id":"goblin_a","killer_id":"player"}
```

### Replay schema

The **Replay Log** button expects JSON data that matches the structure consumed by [`EventBusHarness.replay_signals_from_json()`](../src/tests/EventBusHarness.gd). The top-level value must be an array of dictionaries with the following shape:

```json
[
  {
    "signal_name": "item_acquired",
    "payload": {
      "item_id": "healing_potion",
      "quantity": 1,
      "owner_id": "player"
    }
  },
  {
    "signal_name": "quest_state_changed",
    "payload": {
      "quest_id": "tutorial_1",
      "state": "completed",
      "progress": 1.0
    }
  }
]
```

Each entry is emitted sequentially. Payloads are validated against the same contracts used for manual emission. The harness records success or failure per entry in the replay log, including any Godot error codes returned by the EventBus.

## Running automated tests

Execute the unit test manifest through Godot's headless runner to confirm EventBus behaviour before submitting changes:

```bash
godot4 --headless --path . --run-tests --test junit --output tests/results.xml
godot4 --headless --path . --run-tests --test json --output tests/results.json
```

Both commands consume [`tests/tests_manifest.json`](../tests/tests_manifest.json) and populate machine-readable reports alongside human-readable console output. If you prefer the Python orchestrator, run `python tools/codex_run_manifest_tests.py --godot-binary "$CODEX_GODOT_BIN" --project-root .` to mirror the CI harness and capture structured summaries for dashboards.【F:tools/codex_run_manifest_tests.py†L1-L150】【F:tools/codex_run_manifest_tests.py†L222-L289】

## Extending the EventBus ecosystem

When introducing a new signal or modifying an existing contract:

1. Update `SIGNAL_CONTRACTS` and the associated `signal` declaration in [`EventBus.gd`](../src/globals/EventBus.gd), including descriptions and key/type listings.
2. Document the change in this guide (and [`EventBusSignals.md`](./EventBusSignals.md)) so downstream teams understand the schema.
3. Re-run the automated tests to verify the new payload validates correctly.
4. Launch the harness scene to manually exercise the new signal. The UI should include the new section automatically; confirm required/optional fields behave as expected.
5. If bespoke listeners rely on the signal, add unit tests or integration coverage to the appropriate modules.

Following this workflow keeps the EventBus self-documenting and ensures the harness remains a reliable tool for engineers and QA.
