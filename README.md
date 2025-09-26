# G-LEV-3.0DEV

## Project vision
G-LEV-3.0DEV (Project Chimera) is an ambitious Godot 4 strategy-RPG prototype that pursues modular, data-first design so systemic content can be composed on the fly instead of hard-coding bespoke encounters.【F:project.godot†L1-L15】【F:devdocs/Project Chimera.txt†L2-L45】 The design bible mandates a hybrid approach where Custom Resources capture data, gameplay Systems operate over entity groups, and a global EventBus singleton keeps modules decoupled while still allowing them to react to world events.【F:devdocs/Project Chimera.txt†L18-L46】 Procedural generation pipelines—map construction, quest planning, and meta-narrative state—are planned as layered services that transform seeds and registries of reusable content into coherent runs.【F:devdocs/Project Chimera.txt†L143-L177】 


# Project Chimera Architecture Reference

This repository prototypes the compositional runtime architecture described in the Project Chimera design bible. The new diagrams
collected here summarize how core runtime objects interact so outside engineers can quickly orient themselves before touching
the Godot scenes or scripts.

## Entity Composition

Gameplay entities are ordinary Godot nodes added to the `entities` group. Each node exposes an `entity_data` property that points
to an `EntityData` resource responsible for storing identifying metadata plus a dictionary of component resources. All component
resources inherit from the `Component` base type, which enforces the data-only contract described in the style guide. Concrete
resources such as `StatsComponent` and `TraitComponent` extend this base class, bridging entity data to systems and higher-order
authoring tools. `TraitComponent` maintains references to modular `Trait` resources, while `Archetype` resources validate that a
generated entity exposes an allowed trait mix before entering play. See the diagram below for a visual summary of these
relationships.

![Entity composition diagram](devdocs/diagrams/entity_composition_component.svg)

### Core data contract status

- `EntityData` continues to anchor every entity manifest and now normalizes component keys to `StringName` values while still tolerating legacy string data for compatibility. The helper methods (`add_component()`, `get_component()`, `has_component()`, `remove_component()`, and `list_components()`) enforce registration through `ULTEnums.is_valid_component_key()` so malformed manifests fail fast.【F:src/core/EntityData.gd†L1-L74】
- Always reference components through `ULTEnums.ComponentKeys` constants instead of raw strings when reading or writing the manifest. The enums module exposes canonical `StringName` keys plus metadata describing the expected resource for each slot so systems, tools, and archetype authoring stay in sync.【F:src/globals/ULTEnums.gd†L31-L92】【F:src/globals/ULTEnums.gd†L129-L174】
- `StatsComponent` is the current reference payload for combatants and recruits. It exposes exported fields for baseline vitals, attribute pools, training proficiencies, and equipment snapshots while delegating profession metadata to the modular `JobComponent`.【F:src/components/StatsComponent.gd†L1-L204】【F:src/components/JobComponent.gd†L1-L40】 A dedicated [Stats Component Manual](devdocs/Designers/StatsComponentManual.md) captures designer-friendly descriptions and balancing ranges for every property.

## Event Flow Through the Global Event Bus

All gameplay systems extend the `System` base class, which centralizes helper methods for publishing and subscribing to the
autoloaded `EventBus` singleton. `DebugSystem` demonstrates the pattern by iterating over entity nodes, collecting their stats
component payload, and emitting a `debug_stats_reported` signal whenever new telemetry is captured for diagnostics. The `EventBus`
enforces payload contracts for shared signals such as `entity_killed`, allowing subscriber systems—quests, loot, analytics, and
debuggers—to respond without tight coupling. The sequence below captures both the stats reporting loop and the broadcast path
combat-oriented systems use when an entity is removed from play, matching the process documented in Section 1.3 of the Project
Chimera design doc.

![Event flow sequence diagram](devdocs/diagrams/event_flow_sequence.svg)

## Diagram Sources

Editable Mermaid definitions are stored alongside the rendered assets in `devdocs/diagrams/` so future contributors can refresh
the images after architecture updates.

## Repository layout
- `assets/` – Hand-authored data resources (traits, archetypes, etc.) that Systems and registries consume; for example, the Merchant archetype aggregates trait resources such as Fire-Attuned to describe behaviors and stat templates.【F:assets/archetypes/MerchantArchetype.tres†L1-L15】【F:assets/traits/FireAttunedTrait.tres†L1-L11】 
- `devdocs/` – Canonical design references covering architecture, style standards, and troubleshooting practices for Godot 4 projects.【F:devdocs/Architectural Style Guide.txt†L205-L253】【F:devdocs/GDScriptOPS.txt†L201-L227】 
- `src/core/` – Base data primitives like `EntityData` and `Component` resources that encode entity identity plus component dictionaries for Systems to consume.【F:src/core/EntityData.gd†L6-L22】 
- `src/globals/` – Autoload-friendly singleton scripts (`EventBusSingleton`, `AssetRegistrySingleton`, `ModuleRegistrySingleton`) that the project registers as the `EventBus`, `AssetRegistry`, and `ModuleRegistry` autoloads to broker inter-system communication and shared data access.【F:src/globals/EventBus.gd†L1-L188】【F:src/globals/AssetRegistry.gd†L1-L33】【F:src/globals/ModuleRegistry.gd†L1-L20】
- `src/components/` – Data-only component resources such as `StatsComponent`, `JobComponent`, `TraitComponent`, and `Trait` that encode modular attributes for EntityData manifests.【F:src/components/StatsComponent.gd†L1-L26】【F:src/components/JobComponent.gd†L1-L40】【F:src/components/TraitComponent.gd†L1-L38】【F:src/components/Trait.gd†L1-L19】
- `src/jobs/` – Authorable job resources (`Job`, `MageJob`) that layer profession metadata, stat bonuses, and loadouts onto baseline stats via `JobComponent`.【F:src/jobs/Job.gd†L1-L55】【F:src/jobs/MageJob.gd†L1-L24】
- `src/systems/` – Reusable gameplay systems such as `DebugSystem` that operate on grouped entities through the EventBus pattern.【F:src/systems/DebugSystem.gd†L1-L118】
- `src/tests/` – Focused GDScript unit suites that instantiate registries and systems directly to verify signal contracts, data loading, and style rules via each script’s `run_test()` helper.【F:src/tests/TestEventBus.gd†L4-L184】【F:src/tests/TestAssetRegistry.gd†L4-L42】【F:src/tests/TestModuleRegistry.gd†L4-L72】【F:src/tests/TestDebugSystem.gd†L4-L87】【F:src/tests/TestSystemStyle.gd†L4-L155】 
- `tests/` – Godot scenes, manifests, and mock resources used for manual and automated validation, including the EventBus harness, sprint validation scene, and companion test assets like `TestDummy.tres` + stats. The folder also hosts `test_assets/registry_samples/`, a miniature catalogue (`sword.tres`, `shield.tres`, and the intentionally malformed `broken_asset.tres`) exercised by the AssetRegistry unit tests.【F:tests/EventBus_TestHarness.tscn†L1-L200】【F:tests/Sprint1_Validation.tscn†L1-L14】【F:tests/test_assets/TestDummy.tres†L1-L13】【F:tests/test_assets/TestDummyStats.tres†L1-L7】【F:tests/test_assets/registry_samples/sword.tres†L1-L8】【F:tests/test_assets/registry_samples/shield.tres†L1-L8】【F:tests/test_assets/registry_samples/broken_asset.tres†L1-L3】【F:tests/tests_manifest.json†L1-L13】

## Autoload singletons
Register the following scripts under **Project > Project Settings > Autoload** before running gameplay or tests so every system can resolve its global dependencies and the diagnostics stack can capture logger output:

The scripts export `class_name` identifiers suffixed with `Singleton` to avoid Godot's parser warning "Class <name> hides an autoload singleton". Keep the autoload entries named `DebugLogRedirector`, `EventBus`, `AssetRegistry`, and `ModuleRegistry` even though the underlying classes are registered with `Singleton` suffixes; this preserves ergonomic static typing without tripping the engine safeguard.【F:src/globals/DebugLogRedirector.gd†L1-L103】【F:src/globals/EventBus.gd†L1-L188】【F:src/globals/AssetRegistry.gd†L1-L33】【F:src/globals/ModuleRegistry.gd†L1-L20】

- **ULTEnums** – `res://src/globals/ULTEnums.gd` (autoload name `ULTEnums`). Register this as a **script** singleton (omit the leading `*` in the Project Settings entry) because the file extends `Object` rather than `Node`; attempting to mount it in the scene tree will trigger the Godot startup error `Failed to instantiate an autoload, script ... does not inherit from 'Node'`. The singleton keeps canonical entity type enums and component dictionary keys consistent across resources and systems.【F:src/globals/ULTEnums.gd†L1-L196】
- **DebugLogRedirector** – `res://src/globals/DebugLogRedirector.gd` (autoload name `DebugLogRedirector`). Installs a custom logger callback that forwards every `print()`, `push_warning()`, and `push_error()` invocation to the active `DebugSystem` while still chaining to Godot's default console output.【F:src/globals/DebugLogRedirector.gd†L1-L103】 Scenes register their `DebugSystem` node when it enters the tree so the redirector writes transcripts for the active scene only.
- **EventBus** – `res://src/globals/EventBus.gd` (autoload name `EventBus`). Centralizes all cross-system signals, enforces dictionary payload contracts, and exposes static helpers so tests can inject isolated instances.【F:src/globals/EventBus.gd†L4-L188】 The architectural guides treat this singleton as the “central nervous system” of the project, so every broadcast and subscription should route through it.【F:devdocs/Architectural Style Guide.txt†L205-L228】
- **AssetRegistry** – `res://src/globals/AssetRegistry.gd` (autoload name `AssetRegistry`). Scans data directories on startup (by default `res://assets/archetypes/` and `res://assets/traits/`) and caches `.tres` resources for instant lookup during procedural generation.【F:src/globals/AssetRegistry.gd†L4-L33】【F:devdocs/Project Chimera.txt†L41-L45】 Override or extend the scan paths as the asset catalog grows.
- **ModuleRegistry** – `res://src/globals/ModuleRegistry.gd` (autoload name `ModuleRegistry`). Keeps a dictionary of procedural generator nodes so higher-level directors can request content without hardcoding node paths.【F:src/globals/ModuleRegistry.gd†L4-L20】【F:devdocs/Project Chimera.txt†L41-L45】

Load singletons in dependency order (DebugLogRedirector → EventBus → AssetRegistry → ModuleRegistry) so log interception starts before other systems initialise and all static type hints resolve when Godot parses the scripts; the GDScript operations guide calls out autoload order as a common cause of parse errors.【F:devdocs/GDScriptOPS.txt†L201-L227】 

## Developer documentation
All design references live under [`devdocs/`](devdocs):

- [`Project Chimera`](devdocs/Project%20Chimera.txt) – High-level goals, ECS/Resource hybrid rationale, and procedural content pipelines that inform every system’s responsibilities.【F:devdocs/Project Chimera.txt†L2-L196】 
- [`Architectural Style Guide`](devdocs/Architectural%20Style%20Guide.txt) – Mandatory coding standards (no direct system references, signal usage expectations, directory layout) plus rationale for the EventBus-first topology.【F:devdocs/Architectural Style Guide.txt†L205-L253】 
- [`GDScript OPS Guide`](devdocs/GDScriptOPS.txt) – Troubleshooting playbook for parser issues, autoload ordering, and circular dependency mitigation strategies in Godot 4.x.【F:devdocs/GDScriptOPS.txt†L201-L233】 

These texts should accompany code reviews so new engineers can align with the project’s architecture and debugging norms. 

## Running test scenes and suites
1. **Event bus manual validation** – Open `tests/EventBus_TestHarness.tscn` and press ▶ in the Godot editor (or run `godot4 --path <project> --scene res://tests/EventBus_TestHarness.tscn`). The harness lets you enter payload dictionaries for each signal and emit them via UI buttons while a sibling listener logs the results—ideal for verifying new EventBus contracts interactively.【F:tests/EventBus_TestHarness.tscn†L6-L75】【F:devdocs/Architectural Style Guide.txt†L223-L238】【F:src/tests/EventBusHarness.gd†L219-L257】 The log pane now exposes **Clear Log**, **Save Log**, and **Replay Log** controls next to the transcript so you can reset noisy sessions, export a timestamped capture, or load a JSON replay that the harness will emit back through the EventBus in sequence.【F:tests/EventBus_TestHarness.tscn†L67-L92】【F:src/tests/EventBusHarness.gd†L389-L481】【F:src/tests/EventBusHarness.gd†L602-L644】 Provide a file containing an array of dictionaries with `signal_name` and `payload` keys—e.g. `[ { "signal_name": "quest_state_changed", "payload": { "quest_id": "tutorial", "state": "completed" } } ]`—and the harness logs the outcome of each replay alongside the listener output so you can compare saved sessions against current contracts.【F:src/tests/EventBusHarness.gd†L389-L481】【F:src/tests/EventBusHarness.gd†L602-L644】
2. **Sprint integration smoke test** – Run `tests/Sprint1_Validation.tscn` headlessly (`godot4 --headless --path <project> --scene res://tests/Sprint1_Validation.tscn`) or from the editor. The scene spawns a `TestDummyEntity` with stats data and a `DebugSystem`, allowing you to confirm that systems discover entities through the `entities` group and emit `debug_stats_reported` snapshots through the EventBus.【F:tests/Sprint1_Validation.tscn†L3-L14】【F:tests/test_assets/TestDummy.tres†L1-L13】【F:tests/test_assets/TestDummyStats.tres†L1-L7】【F:src/tests/TestDummyEntity.gd†L7-L13】【F:src/systems/DebugSystem.gd†L18-L33】 Watch the output console for the HP printout and ensure your autoloaded EventBus receives the broadcast. 
3. **Script-level unit tests** – Each `src/tests/Test*.gd` script exposes a `run_test()` helper that instantiates the singleton under test, executes assertions, and prints a summary; the manifest in `tests/tests_manifest.json` enumerates the expected modules for automation harnesses.【F:src/tests/TestEventBus.gd†L74-L184】【F:src/tests/TestAssetRegistry.gd†L16-L42】【F:src/tests/TestModuleRegistry.gd†L16-L72】【F:src/tests/TestDebugSystem.gd†L37-L87】【F:src/tests/TestSystemStyle.gd†L13-L155】【F:tests/tests_manifest.json†L1-L13】 You can wire these into your preferred runner by loading each script as a node, calling `run_test()`, and aggregating the returned dictionaries; ensure required autoloads are registered beforehand to satisfy their dependencies. 

All test assets and harnesses target Godot 4.4.1, matching the engine features specified by the project and the design docs.【F:project.godot†L11-L15】【F:src/tests/TestEventBus.gd†L4-L6】【F:src/tests/TestDebugSystem.gd†L4-L6】 


