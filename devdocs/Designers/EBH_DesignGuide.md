# EventBus Harness Design Guide

The EventBus test harness (\[`tests/EventBus_TestHarness.tscn`\]) lets designers, writers, and engineers prototype narrative and progression flows without touching runtime content. This guide explains how to model common scenarios, analyze the resulting logs, and package findings so review partners can act on them quickly.

## Getting started

1. Open the scene in the Godot editor (`tests/EventBus_TestHarness.tscn`) and press ▶ to run it.
2. Review the automatically generated signal sections. The harness asks [`EventBusHarness.gd`](../src/tests/EventBusHarness.gd) for the contracts published in [`EventBusSignals.md`](./EventBusSignals.md) / `EventBus.SIGNAL_CONTRACTS` and builds UI controls on the fly, so new keys appear without manual scene edits.【F:src/tests/EventBusHarness.gd†L35-L119】
3. Populate the input fields. Required keys are highlighted until they receive values; optional keys can be left blank. Leaving a required field empty triggers the red tooltip/border styling configured by `_mark_field_invalid()` which keeps your payloads honest before they hit the bus.【F:src/tests/EventBusHarness.gd†L235-L343】
4. Click the **Emit** button for the signal you want to test. The sibling listener logs the result in the right-hand transcript pane by relaying every payload through [`EventBusHarnessListener.gd`](../src/tests/EventBusHarnessListener.gd).【F:src/tests/EventBusHarnessListener.gd†L13-L71】

> Tip: The harness accepts JSON fragments in any field. Entering `{ "quest_id": "tutorial" }` or `["objective_a", "objective_b"]` saves you from hand-escaping dictionaries and arrays.

### Harness internals (quick reference)

- **Dynamic sections.** `_build_signal_controls()` clears the previous layout, sorts the published signal names, and calls `_create_signal_section()` for each contract so the scene always reflects the latest singleton state.【F:src/tests/EventBusHarness.gd†L35-L119】
- **Smart editors.** `_populate_field_rows()` adds `LineEdit` widgets with contextual placeholders and tooltips describing the accepted Variant types. `_coerce_field_value()` then accepts JSON, booleans, integers, floats, or string-likes at emit time to minimise copy/paste friction.【F:src/tests/EventBusHarness.gd†L121-L210】【F:src/tests/EventBusHarness.gd†L345-L371】
- **Automatic logging.** `EventBusHarnessListener.gd` connects to every user-defined signal when the scene is ready and pushes timestamped payloads into the log with `append_log()`, so designers can focus on contract content rather than wiring.【F:src/tests/EventBusHarnessListener.gd†L13-L86】【F:src/tests/EventBusHarness.gd†L373-L388】
- **Utility buttons.** The Clear, Save, and Replay actions on the log are wired by `_wire_signal_controls()`. Save opens `FileDialog` with a timestamped filename, while Replay parses a JSON array (or raw string) and re-emits each entry through the live EventBus instance for deterministic reproductions.【F:src/tests/EventBusHarness.gd†L471-L644】

## Scenario playbooks

### Quest completion pacing

Use the `quest_state_changed` contract to simulate milestone transitions and verify downstream reactions (UI, analytics, unlock logic).

1. Locate **quest_state_changed** in the signal list.
2. Provide a `quest_id` (for example, `tutorial_intro`) and a `state` such as `completed`, `failed`, or `in_progress`.
3. Optionally set `progress` (0.0–1.0) and attach an `objectives` array to mimic detailed updates.
4. Emit the signal. The log captures the timestamped payload, allowing narrative designers to check whether objective metadata matches localization hooks and pacing expectations.
5. Iterate quickly by tweaking `state` or `progress`, emitting again, and comparing adjacent log entries to confirm the intended sequence (e.g., `in_progress` → `ready_to_turn_in` → `completed`).

### Item acquisition reward loops

Model loot drops, vendor purchases, and quest rewards with the `item_acquired` contract.

1. Select **item_acquired** in the harness UI.
2. Fill in `item_id` (such as `healing_potion_small`) and `quantity`.
3. Optionally supply `owner_id` and `source` (e.g., `quest_reward`, `vendor_purchase`). Add a `metadata` dictionary if you want to surface rarity, drop table, or economy tracking details.
4. Emit the signal to evaluate whether the downstream systems (inventory UI, notifications, analytics hooks) respond as expected. Watch for log entries that confirm the payload structure and any follow-up signals from listeners.
5. Chain multiple emissions—like a quest completion followed by its `item_acquired` reward—to rehearse the full loop. The log order demonstrates the cadence the player would experience.

## Interpreting log output

The transcript renders each entry as `[timestamp] signal_name -> {payload}`. Use it to reason about pacing and balance:

- **Narrative sequencing:** Confirm that quest states progress monotonically. Gaps or reversals signal missing intermediate beats or mis-ordered content logic.
- **Reward cadence:** Measure the distance (in log lines and timestamps) between `quest_state_changed` and `item_acquired` to gauge perceived delay between accomplishment and reward.
- **Payload audits:** Expand complex dictionaries (objective metadata, loot descriptors) to ensure localization tags, stat deltas, and economy flags align with documentation. If a required key is absent, the harness will block emission, surfacing gaps before integration.
- **Regression detection:** Replay a saved log via **Replay Log** to compare historical sessions against current contracts. Divergent listener output highlights content or systems changes that may impact balance.

When tuning, export the transcript with **Save Log**. The `.log` file preserves timestamps, while exporting a replayable `.json` from external tooling captures the exact signal/payload sequence for regression checks. The harness will create any missing directories and report failures directly in the console, so you always know whether the capture succeeded.【F:src/tests/EventBusHarness.gd†L483-L509】

## Sharing results during content reviews

- **Attach artifacts:** Include the saved `.log` (and optional replay JSON) in review tickets or documentation. Name files after the scenario (`tutorial_quest_completion.log`) so stakeholders can quickly identify coverage.
- **Summarize deltas:** In your review notes, point to the relevant log lines (timestamps + signal names) and describe why they support the proposed change. Highlight any expectations for downstream systems.
- **Provide reproduction steps:** Link back to this guide and specify the field values you used. When possible, bundle a pre-filled replay JSON so reviewers can load and emit the same sequence locally via **Replay Log**.
- **Track decisions:** If content leads sign off on the harness results, archive the log alongside narrative or balance docs. This creates a lightweight audit trail showing how EventBus payloads validated the feature.

Investing a few minutes in structured harness sessions keeps event contracts honest, accelerates narrative iteration, and equips reviewers with concrete evidence instead of screenshots or anecdotal notes.
