# Stabilisation Plan for Project Chimera Entities

The architecture already enforces a data-first workflow, but we are still early in development. The following engineering
suggestions keep day-to-day work aligned with the design philosophy while smoothing the next milestones.

## Short-Term Guardrails (Current Sprint)
- **Automate manifest validation in CI.** Add a lightweight script that loads every `EntityData` resource and runs
  `_sanitize_component_manifest()` plus `ensure_runtime_entity_id()` to surface invalid keys or corrupted payloads before
  they reach designers. Hook it into the existing Git hooks once they are available.
- **Document canonical component keys in code.** Generate or hand-maintain a markdown table mapping each
  `ULTEnums.ComponentKeys` entry to its owning component script. Place it next to the enums so refactors keep data and
  documentation in sync.
- **Extend the Sprint1 validation scene.** Add an automated check (even a simple Godot unit test) that instantiates
  `Entity.gd` without data, confirming the warning path and `generate_runtime_entity_id()` fallback continue to behave.

## Medium-Term Improvements (Next 2–3 Sprints)
- **Runtime ID lifecycle contract.** Define which system is responsible for calling `EntityData.reset_runtime_entity_ids()`
  on world teardown, and add an integration test to prevent regressions when the world reset flow changes.
- **Component authoring presets.** Provide reusable `.tres` templates for common component sets (combatant, interactable,
  ambient life). This reduces copy-paste errors and keeps designers focused on parameter tweaking instead of wiring data.
- **System query helpers.** Introduce a small utility on the systems base class to fetch entities by component composition.
  That keeps future logic nodes from reimplementing iteration patterns and reinforces the group + manifest contract.

## Long-Term Architectural Investments
- **Inspector tooling.** Consider a custom editor inspector for `EntityData` that filters component dictionaries to only
  display valid `Component` subclasses. This maintains the data-oriented approach while improving usability.
- **Hot-reload friendly manifests.** Explore caching strategies that detect when a resource is duplicated at runtime and
  ensure the unique ID registry stays in sync without manual resets.
- **Data provenance tracking.** As procedural generation ramps up, invest in metadata that records which algorithm or
  template produced each manifest. This will be essential for debugging emergent behaviours without violating the
  composition-over-inheritance philosophy.
