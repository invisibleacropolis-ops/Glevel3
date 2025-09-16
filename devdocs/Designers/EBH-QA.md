# EventBus Harness QA Walkthrough



The Event Bus Test Harness scene (`tests/EventBus_TestHarness.tscn`) lets QA teams and engineers exercise every documented EventBus contract without writing custom scripts. The harness instantiates an EventBus, renders input editors for each signal, and wires a listener that echoes payloads into the on-screen log for quick validation.【F:tests/EventBus_TestHarness.tscn†L3-L92】【F:src/tests/EventBusHarness.gd†L13-L67】【F:src/tests/EventBusHarnessListener.gd†L6-L71】 Use this walkthrough whenever you need to confirm signal schemas, reproduce integration issues, or capture telemetry for downstream debugging.



## Launch checklist



1. **Open the harness scene.** In the Godot editor, load `tests/EventBus_TestHarness.tscn` and press ▶, or invoke the CLI with `godot4 --path <project> --scene res://tests/EventBus_TestHarness.tscn` from the repository root. The scene boots directly into the harness UI.【F:README.md†L71-L76】

2. **Allow the harness to provision the EventBus.** When the scene enters the tree it either locates the existing autoload or instantiates a private `EventBus` node so QA can test signals without touching the main game tree.【F:src/tests/EventBusHarness.gd†L13-L33】【F:src/tests/EventBusHarness.gd†L545-L573】

3. **Let the listener attach.** A sibling `EventBusHarnessListener` node subscribes to every known signal and relays payloads into the log panel automatically once the tree is ready.【F:tests/EventBus_TestHarness.tscn†L77-L92】【F:src/tests/EventBusHarnessListener.gd†L14-L108】



## Entering payloads



1. **Locate the signal section.** The harness enumerates `EventBusSingleton.SIGNAL_CONTRACTS` and generates a form for each signal, including descriptions, required keys, and optional keys. New contracts appear automatically whenever the singleton is updated.【F:src/tests/EventBusHarness.gd†L35-L152】

2. **Fill required fields first.** Leave optional fields blank when exploring edge cases; the harness marks missing required values with red borders and tooltips until valid text is supplied.【F:src/tests/EventBusHarness.gd†L235-L287】【F:src/tests/EventBusHarness.gd†L324-L343】

3. **Use JSON to speed up entry.** Payload editors accept JSON, integers, floats, booleans, and `StringName` tokens. The harness coerces valid JSON into dictionaries/arrays automatically so you can paste complex payloads directly from docs or saved logs.【F:src/tests/EventBusHarness.gd†L345-L371】



## Emitting signals and reading the log



1. **Press the “Emit <signal>” button** beneath a payload form to broadcast the dictionary through the EventBus. The harness will abort the emit if validation detects missing required data.【F:src/tests/EventBusHarness.gd†L219-L257】

2. **Watch the listener echo results.** Every emission triggers the listener, which appends the timestamped payload to the log with scrolling enabled so the newest entry is visible immediately.【F:src/tests/EventBusHarness.gd†L373-L388】【F:src/tests/EventBusHarnessListener.gd†L34-L71】



![Annotated log controls highlighting Clear, Save, and Replay actions.](../assets/eventbus_harness_log_controls.png)



The log toolbar sits directly under the “Signal Log” heading:



- **Clear Log** wipes the transcript and resets scrolling—handy before starting a new repro pass.【F:tests/EventBus_TestHarness.tscn†L53-L75】【F:src/tests/EventBusHarness.gd†L522-L524】【F:src/tests/EventBusHarness.gd†L383-L388】

- **Save Log** opens a file dialog pre-filled with a timestamped filename in the user data directory (`user://`). Confirm the path to export a `.log` (or `.txt`) capture containing the parsed log text.【F:tests/EventBus_TestHarness.tscn†L63-L86】【F:src/tests/EventBusHarness.gd†L575-L600】【F:src/tests/EventBusHarness.gd†L483-L509】

- **Replay Log** prompts for a previously saved replay (`.json` or `.log`). Once selected, the harness replays each entry through the EventBus and reports success or failure inline.【F:tests/EventBus_TestHarness.tscn†L67-L92】【F:src/tests/EventBusHarness.gd†L602-L644】【F:src/tests/EventBusHarness.gd†L389-L482】



## Saving and replaying sessions



1. **Export during or after a run.** Click **Save Log**, choose a destination, and confirm. The harness will create any missing folders, persist the log text, and print the export path to the output console for auditing.【F:src/tests/EventBusHarness.gd†L483-L509】

2. **Capture replay JSON for regression tests.** Construct an array of entries using the schema `[{"signal_name": "quest_state_changed", "payload": { ... }}]` and save it alongside your `.log`. The harness accepts raw JSON strings or arrays and validates each entry before emitting it.【F:README.md†L71-L76】【F:src/tests/EventBusHarness.gd†L389-L481】

3. **Load the replay.** Click **Replay Log**, pick the JSON or log file, and watch the log panel for success/failure lines. Non-dictionary entries or malformed payloads are skipped with explicit error text so you can fix the capture before re-running.【F:src/tests/EventBusHarness.gd†L602-L644】【F:src/tests/EventBusHarness.gd†L389-L482】



## Forwarding exports to engineers



1. **Locate the files.** By default the dialogs point to `OS.get_user_data_dir()`—on desktop this resolves to `~/.local/share/godot/app_userdata/Glevel3/` unless you redirect the path. Retrieve both the `.log` export and any replay `.json` from that directory.【F:src/tests/EventBusHarness.gd†L575-L600】

2. **Package context.** Rename the files with the issue ID and reproduction summary (for example, `bug-1423_entity-killed.log`). Include a short README snippet describing the Godot commit, signal(s) exercised, and any anomalies observed during the run.

3. **Share through the team’s channel.** Attach the files to the Jira ticket or Slack thread used for the bug. Mention whether the replay completed without errors per the harness log so engineers know if they can run it verbatim.【F:src/tests/EventBusHarness.gd†L389-L482】

4. **Optional: check into version control.** For enduring scenarios, add the replay JSON under `tests/manual_replays/` (create the folder if necessary) and note it in the QA report. This keeps canonical reproductions alongside the automated suite.



## Troubleshooting tips



- **Missing EventBus warning.** If the log prints `EventBus is unavailable`, confirm you launched the harness via the test scene rather than embedding it in another context; the helper will spawn a private EventBus when run standalone.【F:src/tests/EventBusHarness.gd†L545-L573】

- **Red borders on inputs.** Required fields highlight in red until populated. Hover the tooltip to see which key is missing and the expected type hint.【F:src/tests/EventBusHarness.gd†L235-L287】

- **Replay parsing errors.** The harness prints the failing line number and error message when JSON cannot be parsed, making it straightforward to repair the file before rerunning.【F:src/tests/EventBusHarness.gd†L400-L431】



With these steps you can repeatedly validate EventBus changes, deliver actionable logs to engineers, and keep regression scenarios reproducible across sprints.

