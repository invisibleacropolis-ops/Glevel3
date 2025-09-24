# Project Chimera Engineering Manual

## 1. Orientation
Project Chimera (G-LEV-3.0DEV) prototypes a Godot 4 strategy-RPG built on a modular, data-first runtime where Custom Resources capture authored content, stateless Systems operate over entity groups, and an EventBus singleton keeps modules decoupled.【F:README.md†L3-L39】 Procedural subsystems—encounter assembly, quest planning, meta-narrative, and diagnostics—compose these primitives to deliver emergent runs.【F:README.md†L3-L39】 This manual translates the repository’s architecture into an actionable reference for engineers onboarding mid-sprint.

## 2. Architectural Compliance Snapshot
The Architectural Style Guide mandates composition over inheritance, a strict data/logic split, and EventBus-mediated coordination.【F:devdocs/Architectural Style Guide.txt†L5-L154】 The current codebase largely adheres:

- **EntityData & Components** – Every gameplay node stores an `EntityData` manifest that normalises component keys, validates payload types, and hands out unique runtime identifiers, exactly matching the guide’s “digital DNA” specification.【F:src/core/EntityData.gd†L1-L200】【F:devdocs/Architectural Style Guide.txt†L45-L98】 `StatsComponent`, `TraitComponent`, `StatusComponent`, and `Trait` remain data-only Resources with exported fields for designer workflows.【F:src/components/StatsComponent.gd†L1-L200】【F:src/components/TraitComponent.gd†L1-L51】【F:src/components/StatusComponent.gd†L1-L45】【F:src/components/Trait.gd†L1-L21】
- **Systems** – `System.gd`, `DebugSystem`, and `ValidationLoop` treat entities as members of the `entities` group, resolve data through `EntityData`, and emit telemetry through the EventBus rather than direct node references, aligning with the mandated stateless, bus-driven processing.【F:src/systems/System.gd†L1-L62】【F:src/systems/DebugSystem.gd†L69-L151】【F:src/systems/ValidationLoop.gd†L1-L16】
- **Global Singletons** – `EventBus`, `AssetRegistry`, `ModuleRegistry`, and `DebugLogRedirector` implement the documented autoload contracts, exposing static helpers and validation that reinforce decoupling.【F:src/globals/EventBus.gd†L1-L326】【F:src/globals/AssetRegistry.gd†L1-L119】【F:src/globals/ModuleRegistry.gd†L1-L103】【F:src/globals/DebugLogRedirector.gd†L1-L200】

**Notable divergence:** `StatusSystem` still expects `StatusComponent` and `StatsComponent` as child nodes, contradicting the resource-centric entity contract and leaving TODOs around proper entity discovery. This needs realignment with `EntityData` manifests and EventBus workflows to satisfy Section 3’s data access rules.【F:src/systems/StatusSystem.gd†L7-L82】【F:devdocs/Architectural Style Guide.txt†L99-L154】 The integration plan in §8 details the remediation steps.

## 3. Runtime Data Model

### 3.1 Entity Manifests
- **`EntityData.gd` (`res://src/core/EntityData.gd`)** – Maintains exported metadata (display name, archetype id, entity type) plus a typed dictionary of component resources keyed by `ULTEnums.ComponentKeys` (`StringName`). Setters sanitise dictionaries, refusing non-`Component` payloads and warning once per invalid key. Lookups normalise inputs, enforce key validity, and return `null` for missing data. Runtime IDs are auto-reserved via `ensure_runtime_entity_id()`, with static helpers for unmanaged nodes and reset support for world restarts.【F:src/core/EntityData.gd†L1-L200】
- **Usage guidance** – Systems must call `has_component()`/`get_component()` using keys from `ULTEnums.ComponentKeys` to avoid string drift. Authors updating manifests should prefer `add_component()`/`remove_component()` so the sanitiser preserves warning bookkeeping. Reset the runtime ID registry when reinitialising simulations.

### 3.2 Component Resources
- **`Component.gd`** – Minimal base class (extends `Resource`) enforcing the data-only contract.【F:devdocs/Architectural Style Guide.txt†L99-L143】
- **`StatsComponent.gd`** – Comprehensive stat surface: job metadata, vital pools, resistances, progression, skill catalogues, and equipment snapshots. Exports grouped Inspector fields and provides `to_dictionary()` for defensive snapshots suitable for telemetry or save payloads.【F:src/components/StatsComponent.gd†L1-L200】【F:src/components/StatsComponent.gd†L157-L200】
- **`TraitComponent.gd`** – Stores `Trait` resources, exposes add/remove helpers keyed by `trait_id`, and returns a defensive list of registered IDs. Traits act as modular behaviour flags or passive modifiers.【F:src/components/TraitComponent.gd†L1-L41】【F:src/components/Trait.gd†L1-L21】
- **`StatusComponent.gd` & `StatusFX.gd`** – Track duplicated `StatusFX` resources in short-term and long-term arrays. Helpers manage insertion, duplicate prevention, and removal by identifier. `StatusFX` resources describe identity, modifier dictionaries, trigger hooks, and turn-based durations.【F:src/components/StatusComponent.gd†L1-L45】【F:src/core/StatusFX.gd†L1-L24】

### 3.3 Authoring Resources
- **`Archetype.gd`** – Defines procedural archetypes: ID, name, description, base stats dictionary, and trait pools. Provides validation utilities that enforce trait compatibility by identifier and merge required traits ahead of optional ones without duplicates.【F:src/systems/Archetype.gd†L1-L104】
- **Entity Node (`Entity.gd`)** – Lightweight `Node3D` wrapper exporting `entity_data`, auto-joining the `entities` group, and synchronising runtime IDs (using `EntityData` helpers or static fallback when data is absent). Systems should treat `Entity` nodes as the canonical carrier for `EntityData` references.【F:src/entities/Entity.gd†L1-L53】

## 4. Global Singletons & Registries

### 4.1 EventBus (`res://src/globals/EventBus.gd`)
- Registers as the `EventBus` autoload. Maintains static `_singleton` accessors (`get_singleton()`, `is_singleton_ready()`) and overrides `emit_signal()` to validate payload dictionaries against `SIGNAL_CONTRACTS`. Contracts cover combat, inventory, quest, debug telemetry, and status effect events, each documenting required/optional keys and type allowances (including String/StringName interchangeability).【F:src/globals/EventBus.gd†L1-L326】
- **Usage checklist:**
  1. Derive systems from `System.gd` and call `emit_event()`/`subscribe_event()` to centralise traffic.
  2. Always emit dictionaries; non-dictionary payloads trigger errors and return `ERR_INVALID_PARAMETER`.
  3. When adding new signals, update `SIGNAL_CONTRACTS` and provide documentation for downstream tooling.

### 4.2 DebugLogRedirector (`res://src/globals/DebugLogRedirector.gd`)
- Hooks Godot’s `Logger` singleton (with retry safeguards) to forward print/warning/error messages to the active `DebugSystem`, while preserving original logging behaviour via stored callbacks. Scenes register/unregister their `DebugSystem` to begin capturing transcripts. Gracefully degrades when the Logger API is unavailable (e.g., headless tests).【F:src/globals/DebugLogRedirector.gd†L1-L200】

### 4.3 AssetRegistry (`res://src/globals/AssetRegistry.gd`)
- Recursively scans configured directories (defaults include archetypes and traits) for `.tres` resources during `_ready()`. Caches loaded assets in-memory, tracks failed loads with absolute paths, and exposes safe copies of both dictionaries. `_scan_and_load_assets()` is public for targeted reloads in tests or tools.【F:src/globals/AssetRegistry.gd†L1-L119】

### 4.4 ModuleRegistry (`res://src/globals/ModuleRegistry.gd`)
- Stores procedural generator nodes keyed by `StringName`, with automatic cleanup when modules exit the scene tree (via `tree_exiting` hook). Provides register/unregister/get/has helpers and normalises keys to avoid whitespace mismatches.【F:src/globals/ModuleRegistry.gd†L1-L103】

### 4.5 ULTEnums (`res://src/globals/ULTEnums.gd`)
- Autoload enumerations for entity types, skill metadata, and canonical component keys. Includes metadata dictionaries describing each component’s expected resource type and purpose, plus helpers for validation and iteration.【F:src/globals/ULTEnums.gd†L1-L143】 Systems and authoring tools must use these constants for all manifest operations.

## 5. Gameplay Systems

### 5.1 Base System (`System.gd`)
- Provides EventBus helper methods (`emit_event`, `subscribe_event`) and a `_process_entity()` virtual hook for optional per-entity processing patterns. Internally resolves the autoload or scene-tree fallback so tests can inject custom buses. Systems should avoid storing persistent state beyond frame-scoped temporaries to remain stateless as mandated by the style guide.【F:src/systems/System.gd†L1-L62】【F:devdocs/Architectural Style Guide.txt†L147-L154】

### 5.2 DebugSystem (`res://src/systems/DebugSystem.gd`)
- Responsibilities:
  - On `_physics_process`, iterates `entities` group, extracts `EntityData`, and reports `StatsComponent` snapshots to the console and EventBus (`debug_stats_reported`).【F:src/systems/DebugSystem.gd†L82-L108】
  - Manages log capture: prepares per-scene files under `user://logs`, maintains a master error log in `res://`, registers with `DebugLogRedirector`, and buffers entries for diagnostics. Handles directory fallbacks and error reporting gracefully.【F:src/systems/DebugSystem.gd†L110-L199】
  - Exposes optional dependency injection hooks (`event_bus`, `log_redirector`) to simplify isolated testing.
- Integration instructions:
  1. Ensure DebugSystem nodes enter the tree after autoloads; they self-register with the redirector during `_enter_tree()`.
  2. When authoring new diagnostics, extend `_snapshot_stats()` or add new EventBus emissions instead of augmenting the data traversal loop.
  3. Keep log directories configurable through `log_directory_path` to support CI pipelines.

### 5.3 ValidationLoop (`res://src/systems/ValidationLoop.gd`)
- Minimal verification system that mirrors DebugSystem’s entity iteration to print health totals, demonstrating how gameplay systems should resolve `EntityData` and `StatsComponent` without hard-coded node references.【F:src/systems/ValidationLoop.gd†L1-L16】 Use it as a template for future validation scripts.

### 5.4 StatusSystem (`res://src/systems/StatusSystem.gd`)
- Intended to manage status effect durations by subscribing to `turn_passed` and `day_passed`. Currently uses placeholder logic that searches for child nodes named `StatusComponent`/`StatsComponent` and directly mutates node-level state, conflicting with the EntityData/component contract. TODO comments highlight missing entity discovery and component duplication safeguards.【F:src/systems/StatusSystem.gd†L7-L82】
- **Immediate guidance:**
  1. Replace direct node access with `EntityData` lookups: iterate `Entity` nodes, call `entity.entity_data.get_component(ULTEnums.ComponentKeys.STATUS)` to fetch `StatusComponent` resources, and operate on their arrays.
  2. Emit `status_effect_applied`/`status_effect_ended` via `emit_event()` rather than direct bus usage to maintain the abstraction.
  3. Reconcile stat adjustments by applying modifiers to the owning `StatsComponent` resource (`apply_stat_mod` or equivalent) rather than assuming node methods exist. Where helper methods are missing, extend `StatsComponent` with pure-data utilities instead of referencing scene nodes.
  4. Document how new effects enter `StatusComponent` (likely through quest/combat systems) and ensure they duplicate `StatusFX` resources before storage, as flagged by the TODO block.

## 6. Diagnostics & Tooling
- **EventBus Test Harness (`tests/EventBus_TestHarness.tscn`)** – Interactive scene for entering payload dictionaries, emitting signals, and observing listener output. Supports log clearing, saving, and replaying captured sessions to verify contract stability.【F:README.md†L80-L84】
- **Sprint Validation Scenes (`tests/Sprint1_Validation.tscn`, `tests/Sprint2Val.tscn`)** – Headless or editor-run smoke tests that spawn a dummy entity plus DebugSystem to confirm autoload wiring and EventBus telemetry.【F:README.md†L82-L85】
- **Testbed Scripts (`tests/scripts/system_testbed/`)** – GDScript harnesses for combat/inventory experiments. Use them to exercise systems in isolation before integrating into runtime scenes.

## 7. Autoload Configuration Checklist
Register the following under Project Settings → Autoload (using the specified names) before running systems or tests: `DebugLogRedirector`, `EventBus`, `AssetRegistry`, `ModuleRegistry`, and the script singleton `ULTEnums`. Load them in the sequence DebugLogRedirector → EventBus → AssetRegistry → ModuleRegistry so logger interception activates before systems initialise and enum constants are available during script parsing.【F:README.md†L58-L69】

## 8. Integration Plan Aligned with the Style Guide
To finish aligning the runtime with the architectural directives:

1. **Refactor StatusSystem to be data-first.** Replace node lookups with `EntityData` component access, operate on `StatusComponent`/`StatsComponent` resources, and emit EventBus payloads via the inherited helpers. This realigns the system with Section 3’s data pipeline requirements and removes TODO placeholders.【F:src/systems/StatusSystem.gd†L7-L82】【F:devdocs/Architectural Style Guide.txt†L99-L154】
2. **Augment `StatsComponent` with modifier utilities.** Introduce pure-resource methods to apply/revert modifier dictionaries (used by status effects) so systems can mutate stats without accessing scene nodes, preserving the data/logic split.【F:src/components/StatsComponent.gd†L1-L200】【F:devdocs/Architectural Style Guide.txt†L99-L143】
3. **Define status effect workflows.** Document and implement how effects are applied (likely through combat or narrative systems): duplicate `StatusFX`, append to `StatusComponent`, update `StatsComponent.short_term_statuses`/`long_term_statuses`, and broadcast `status_effect_applied`. Mirror this removal path when durations expire, ensuring modifiers are reverted and `status_effect_ended` includes contextual metadata per EventBus contract.【F:src/components/StatusComponent.gd†L1-L45】【F:src/globals/EventBus.gd†L24-L210】
4. **Add validation coverage.** Extend the existing test harnesses or add new scripts to confirm `StatusSystem` contracts and EventBus payload validation, similar to the README’s `TestSystemStyle` pattern. This keeps future regressions visible.

## 9. Implementation Checklists
When building new systems or components, follow these steps:

1. Create a Resource component that extends `Component.gd`, export all authoring fields, and register it in `ULTEnums.ComponentKeys` metadata with a unique `StringName` key.【F:src/globals/ULTEnums.gd†L31-L143】
2. Update `EntityData` manifests (via code or `.tres`) using `add_component()` with the new key; avoid direct dictionary mutation to preserve sanitisation.【F:src/core/EntityData.gd†L54-L115】
3. Derive a System from `System.gd`, resolve the EventBus through `emit_event()`/`subscribe_event()`, and iterate `entities` group nodes to pull component resources. Never store persistent references to entities or components across frames.【F:src/systems/System.gd†L1-L62】【F:devdocs/Architectural Style Guide.txt†L147-L154】
4. Define or update EventBus contracts for new signals and add tests or harness scenarios to exercise them.【F:src/globals/EventBus.gd†L1-L326】
5. Document the workflow in this manual and the relevant designer docs so cross-disciplinary teams remain aligned.

