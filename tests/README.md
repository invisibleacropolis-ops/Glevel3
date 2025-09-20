# Tests & Tooling Guide

This guide explains how every test harness in `res://tests` fits together so any
team member—from a new designer to a senior engineer—can spin up the toolchain,
spawn gameplay entities, and validate the Hybrid ECS architecture in isolation.

## 1. Environment Preparation

1. **Install the required Godot build.** This project targets the headless-
   capable Godot 4.4.1 editor. Confirm it is on your `$PATH` with:
   ```bash
godot4 --version
   ```
2. **Clone the repository and open a terminal in the project root.** All
   commands below assume the working directory is the same folder that contains
   `project.godot`.
3. **Verify required autoloads.** The tooling expects the following singletons
   to be active (already defined in `project.godot`):
   - `AssetRegistry` – resource catalogue used by the spawner panels.
   - `EventBus` – global signal hub surfaced in the Event Bus log.
   - `DeveloperConsole` – dropdown console toggled with the <kbd>~</kbd> key.

## 2. Launching the System Testbed

The System Testbed is the central control room for isolated gameplay testing.
Start it in one of two ways:

- **From the editor:** double-click `tests/scenes/System_Testbed.tscn`.
- **Headless CLI:**
  ```bash
godot4 --headless --path . --scene res://tests/scenes/System_Testbed.tscn --quit-after 5
  ```
  The `--quit-after` flag exits automatically after a few seconds so automated
  checks do not stall.

### 2.1 Layout Primer

Each panel in the updated UI is labelled and colour coded:

| Panel | Purpose |
| --- | --- |
| **Entity Spawner** | Pick an `EntityData` archetype from the Asset Registry. Press **Spawn Entity** to duplicate the resource (deep copy) and instance it under the `TestEnvironment` node. |
| **Scene Inspector** | Displays every spawned entity. Selecting an entry publishes the active target to all other panels. Use **Delete Selected** to free nodes safely. |
| **Component Viewer** | Generates editors for every exported component property on the selected entity. Values update live as systems mutate data. |
| **System Triggers** | Buttons to exercise combat logic. The status label reports whether a target is locked. Triggers enable automatically once an entity is selected. |
| **Event Bus Log** | Streams every signal emitted through the Event Bus. Use **Clear Log** between experiments to focus on fresh traffic. |

### 2.2 Required Workflow: Spawn a Goblin and Apply Damage

Follow these steps to satisfy the sprint validation requirement:

1. **Load the archetype catalogue.** Wait for the Entity Spawner panel to list
   entries. If it shows a warning, confirm `AssetRegistry` initialised correctly
   in the output console.
2. **Spawn the goblin.** Select `GoblinArcher_EntityData.tres` (or the relevant
   goblin archetype) and click **Spawn Entity**. The Scene Inspector will report
   the new node immediately.
3. **Target the goblin.** Click the entity in the Scene Inspector tree. The
   System Trigger status label will switch to `Active target: <Name>` and the
   trigger buttons will unlock.
4. **Apply damage.** Press **Apply 10 Fire Damage to Target**. Watch the
   Component Viewer to confirm the health field decreases and check the Event
   Bus Log for `entity_damaged` or related signals emitted by the combat stub.
5. **Optional kill flow.** Press **Kill Target** to fire the mock lethal path
   and then click **Emit 'entity_killed' Signal** to broadcast a manual replay.
6. **Reset log.** Use **Clear Log** before the next experiment to keep captures
   focused.

If any panel fails to update, open the Developer Console (<kbd>~</kbd>) and run
`help()` to review built-in commands. `spawn("GoblinArcher_EntityData.tres")`
duplicates the same archetype as the UI, which is useful for scripting macros.

## 3. Component Testbed

Use `tests/scenes/Component_Testbed.tscn` to audit and edit resource data
without wiring a full scene.

- **Launch:**
  ```bash
godot4 --path . --scene res://tests/scenes/Component_Testbed.tscn
  ```
- **Workflow:**
  1. Click **Load EntityData** and choose a `.tres` file.
  2. Review the manifest and component sections. Controls mirror the exported
     property type (booleans -> checkboxes, numbers -> spin boxes, enums ->
     dropdowns).
  3. Press **Save EntityData** to persist changes. The console logs the result
     and the System Testbed will pick up modifications immediately because it
     always duplicates the resource before spawning.

## 4. Debug Overlay Test Environment

`tests/scenes/DebugOverlay_TestEnvironment.tscn` provides a lightweight 3D
sandbox for overlay widgets.

- The on-screen panel summarises the key shortcuts:
  - <kbd>~</kbd>: Toggle the Developer Console.
  - <kbd>F3</kbd>: Example overlay toggle (bind your own actions as needed).
- Oscillating demo entities continuously mutate their stats, which is perfect
  for verifying live overlay bindings and the Component Viewer’s read-only mode.

## 5. Developer Console Essentials

The autoloaded console lives at `res://src/debug/developer_console/DeveloperConsole.tscn`.
Important details:

- Toggle with the <kbd>~</kbd> key (action `debug_toggle_console`).
- Commands use Godot’s `Expression` API. Built-in helpers include:
  - `help()` – list registered commands.
  - `spawn("ArchetypeId")` – spawn an archetype near the player or current
    scene root. Resources are always duplicated to avoid mutating the catalogue.
- Use the arrow keys to cycle through command history and Tab for autocomplete.

## 6. Command-Line & Automation Tips

- **Headless sanity checks:**
  ```bash
godot4 --headless --path . --scene res://tests/scenes/System_Testbed.tscn --quit-after 5 --verbose
  ```
- **Parse validation:** the repository ships with `tools/gdscript_parse_helper.py`.
  Run it after editing scripts to spot syntax issues without opening the editor:
  ```bash
python tools/gdscript_parse_helper.py tests/scripts
  ```
- **Batch event-bus replays:** `tools/codex_replay_eventbus.py` can drive the
  Event Bus log for regression scenarios once custom payloads are recorded.

## 7. Troubleshooting Checklist

| Symptom | Resolution |
| --- | --- |
| Entity list is empty after spawning | Ensure the `TestEnvironment` node is present and not paused. Confirm the Entity Spawner panel status text for additional hints. |
| Component Viewer displays placeholders only | Select an entity in the Scene Inspector. If the entity lacks `EntityData`, the viewer intentionally shows a guidance message. |
| Event Bus log stays blank | Verify the `EventBus` singleton is registered. Use **Emit 'entity_killed' Signal** to confirm connections. |
| Console command fails with “AssetRegistry autoload unavailable” | Check that `AssetRegistry` is enabled in the project autoload list and the target resource exists in `res://assets/entity_archetypes`. |

With these steps a fresh teammate can open the project, read this document, and
successfully spawn a goblin in the System Testbed, apply damage, and observe the
resulting system activity across the inspector, component viewer, triggers, and
Event Bus log.
