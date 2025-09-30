# Job System Overview

The job system layers modular profession data on top of a character's baseline `StatsComponent`. Each entity that supports jobs references a `JobComponent` resource, which stores a primary job and optional alternates. When a `StatsComponent` receives a job component it immediately resolves the primary job, applies any stat and training bonuses, merges the granted traits and skills, and subscribes to change notifications so edits in the Inspector propagate live during play.

## Data resources

- **`JobComponent`** – Bridges the stats resource to modular job definitions. Designers assign a `primary_job` and optional `alternate_jobs` so generators can roll substitutes without touching baseline stats.【F:src/components/JobComponent.gd†L1-L55】
- **`Job`** – Authorable profession resource that captures identity, stat bonuses, training bonuses, granted skills, granted traits, and formula overrides. Utility methods return defensive copies for serialization or runtime inspection.【F:assets/jobs/Job.gd†L1-L88】
- **`JobStatBonus`** – Helper resource for additive stat adjustments. The Inspector now exposes a curated dropdown of core `StatsComponent` fields (Health, Energy, AP, Body, Mind, STR, AGL, SPD, INT, WIS, CHR, plus their max/pool variants) so designers only edit the numeric amount. Custom string names are still accepted for edge cases.【F:assets/jobs/JobStatBonus.gd†L1-L83】
- **`JobTrainingBonus`** – Helper resource for training adjustments. Designers select the relevant training (Athletics, Combat, Thievery, Diplomacy, Lore, or Technical) and enter the additive amount.【F:assets/jobs/JobTrainingBonus.gd†L1-L73】

## Runtime flow

`StatsComponent` loads the job component script on demand, validates that resources actually extend `Job`/`JobComponent`, and applies bonuses when the job attachment changes. Stat and training modifiers call `_get_numeric_property()` to ensure the named property exists; any unknown keys trigger a warning so data errors surface immediately.【F:src/components/StatsComponent.gd†L259-L316】 The component tracks applied deltas in `_applied_job_snapshot`, allowing `_remove_job_bonuses()` to restore baseline values when the job changes or the component is cleared.【F:src/components/StatsComponent.gd†L318-L374】

Traits and skills added by the job follow the same lifecycle: they are injected during `_apply_job_bonuses()`, recorded in the snapshot, and removed when the job is detached. The stats resource also subscribes to the job's `changed` signal, so edits to the job resource or its subresources re-run `_refresh_job_bonuses()` automatically.【F:src/components/StatsComponent.gd†L300-L373】

## Inspector workflow

1. Create or open a `Job` resource under `res://assets/jobs/` or your content directory.
2. In the **Stat Bonuses** section, add entries as needed. Use the dropdown to pick the target stat; leave the amount at `0` for no adjustment or raise/lower to apply bonuses or penalties. The field accepts manual text if you must reference a bespoke `StatsComponent` property.
3. Populate the **Training Bonuses** array with training modifiers. Each entry targets one of the canonical proficiencies exposed by `StatsComponent`.
4. Assign `starting_traits`, `starting_skills`, and `formula_overrides` as required by your design.
5. Attach the job to an entity by creating a `JobComponent`, assigning the job resource to `primary_job`, and linking the job component to the entity's `StatsComponent`.

At runtime the `StatsComponent` reflects these bonuses immediately. You can verify changes in the remote inspector or via the `DebugSystem`, which reports job-adjusted stats every frame in the sprint validation scene.【F:tests/Sprint1_Validation.tscn†L3-L14】【F:src/systems/DebugSystem.gd†L18-L33】 Edits made while the game is running propagate because the stats resource monitors the job resource and each bonus subresource's `changed` signal.【F:src/components/StatsComponent.gd†L259-L383】
