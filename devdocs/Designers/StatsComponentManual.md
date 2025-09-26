# Stats Component Manual

## Overview

`StatsComponent` defines the player-facing and systemic statistics used to describe combatants, recruits, and NPCs. Every field is exported so the resource can be authored in the Godot Inspector, and runtime helpers encapsulate common adjustments such as damage, healing, and resource deltas.【F:src/components/StatsComponent.gd†L1-L204】 This manual captures the canonical meaning of each field along with the balancing ranges currently used across prototypes so systems, tooling, and content authoring all operate from the same assumptions. Where numeric windows are listed they reflect common targets—designers may diverge for boss encounters or narrative set pieces, but new content should start from these baselines.

### Reading the tables

Each section groups related properties. "Common range" records the values most builds fall into today; treat them as guidance rather than hard limits. Array and dictionary entries note expected counts plus the canonical key or value formats (e.g., `StringName`).

## Job composition

| Property | Type | Description | Common range & notes |
| --- | --- | --- | --- |
| `job_component` | `JobComponent` | Optional reference to a modular job overlay that injects profession metadata, stat bonuses, skills, and traits on top of the baseline stats.【F:src/components/StatsComponent.gd†L8-L12】【F:src/components/JobComponent.gd†L1-L55】 | Leave unset for generic civilians. Starter archetypes normally bind a `JobComponent` with a single primary job; late-game entities may expose alternates for generators to roll between. When a `JobComponent` is assigned the stats component now applies additive stat and training bonuses immediately and merges any job-supplied trait resources, keeping the effective values synchronized as designers tweak the job resource.【F:src/components/StatsComponent.gd†L8-L189】 |

Job resources expose designer-friendly arrays so profession data can be composed without touching dictionaries. Use the `stat_bonuses` and `training_bonuses` lists to add any number of `JobStatBonus` or `JobTrainingBonus` entries, each pairing a StatsComponent property with an additive modifier. `starting_skills` accepts direct references to `Skill` resources, and `starting_traits` links `Trait` resources that should be injected when the job is active.【F:src/jobs/Job.gd†L1-L88】【F:src/jobs/MageJob.gd†L1-L63】

## Vital resources and tactical economy

| Property | Type | Description | Common range & notes |
| --- | --- | --- | --- |
| `health` | `int` | Current hit points; reaching 0 marks the entity defeated.【F:src/components/StatsComponent.gd†L23-L26】 | 30–120 for fresh recruits, 150–300 for elite bosses. Damage application clamps at 0 via `apply_damage()`. |
| `max_health` | `int` | Maximum health based on archetype, gear, and traits.【F:src/components/StatsComponent.gd†L28-L30】 | Match or exceed `health`. Typical caps land 20–40% above the job's starting HP curve. |
| `energy` | `int` | Current resource used for skill execution and abilities.【F:src/components/StatsComponent.gd†L32-L34】 | 0–80 for casters and support roles; stamina-light jobs hover at 0 unless they use energy-based skills. |
| `max_energy` | `int` | Maximum energy budget granted by the job formula.【F:src/components/StatsComponent.gd†L36-L38】 | Early jobs cap between 30–80. Leave 0 for archetypes that do not consume energy; helpers treat 0 as unlimited when restoring.【F:src/components/StatsComponent.gd†L208-L214】 |
| `armor_rating` | `int` | Flat mitigation applied before resistances and vulnerabilities.【F:src/components/StatsComponent.gd†L40-L42】 | 0–12 for lightly armored scouts, 15–35 for heavy infantry. Boss variants may spike to 45+. |
| `action_points` | `int` | Available actions for the current tactical round.【F:src/components/StatsComponent.gd†L44-L46】 | 2–6 in standard encounters; systems clamp at 0 when spending AP.【F:src/components/StatsComponent.gd†L216-L222】 |
| `max_action_points` | `int` | Maximum AP restored between turns or rests.【F:src/components/StatsComponent.gd†L48-L50】 | Set between 3–7 for most jobs; leave at 0 when AP is intentionally uncapped for scripted moments.【F:src/components/StatsComponent.gd†L224-L230】 |

## Status tracking, resistances, and vulnerabilities

| Property | Type | Description | Common range & notes |
| --- | --- | --- | --- |
| `short_term_statuses` | `Array[StringName]` | Time-limited effects expected to clear between missions.【F:src/components/StatsComponent.gd†L52-L55】 | Maintain 0–2 simultaneous statuses to keep UI legible; arrays rarely exceed 4 entries. |
| `long_term_statuses` | `Array[StringName]` | Persistent effects that survive multiple encounters.【F:src/components/StatsComponent.gd†L57-L60】 | Usually 0–3 concurrent records. They update via `add_status()` with `is_long_term = true`.【F:src/components/StatsComponent.gd†L232-L248】 |
| `resistances` | `Dictionary[StringName, float]` | Maps effect identifiers to fractional mitigation (e.g., fire ⇒ 0.25 for 25% resistance).【F:src/components/StatsComponent.gd†L62-L64】 | Values stay between 0.0–0.75 in standard play; 1.0 indicates immunity and should be reserved for exceptional gear sets. |
| `vulnerabilities` | `Dictionary[StringName, float]` | Maps effect identifiers to multipliers (e.g., cold ⇒ 1.5 for 50% more damage).【F:src/components/StatsComponent.gd†L66-L68】 | Baseline is 1.0 (no change). Common penalties range 1.15–1.5; anything above 1.75 signals a severe narrative drawback. |

## Progression and traits

| Property | Type | Description | Common range & notes |
| --- | --- | --- | --- |
| `experience_points` | `int` | Accumulated XP toward the next reward.【F:src/components/StatsComponent.gd†L70-L72】 | Reset to 0 when leveling. Use 0–1,000 for low tiers and scale exponentially (e.g., 5,000+) for late campaigns. |
| `level` | `int` | Character level gating skills and events.【F:src/components/StatsComponent.gd†L74-L76】 | Starts at 1. Prototype campaigns cap near 20; systems clamp to ≥1 when applying deltas.【F:src/components/StatsComponent.gd†L270-L274】 |
| `level_title` | `String` | Narrative label associated with the level (e.g., "Veteran").【F:src/components/StatsComponent.gd†L78-L80】 | Optional flavor text; keep within 20 characters to avoid UI wrapping. |
| `traits` | `Array[StringName]` | Derived perks unlocked by stats, achievements, or story beats.【F:src/components/StatsComponent.gd†L82-L84】 | Lists grow from 0–4 in early game to 6–8 for veteran heroes. Traits adjust via `add_trait()` / `remove_trait()`.【F:src/components/StatsComponent.gd†L258-L268】 |

## Attribute pools

| Property | Type | Description | Common range & notes |
| --- | --- | --- | --- |
| `body_pool_fixed` | `int` | Non-reassignable Body points that seed physical stats.【F:src/components/StatsComponent.gd†L86-L88】 | Base characters launch with 5 fixed points and 1 relative point in Body.【F:BaseCharacterStats.md†L38-L49】 Narrative rewards may raise fixed values to 8–10. |
| `body_pool_relative` | `int` | Reallocatable Body points held for camp redistribution.【F:src/components/StatsComponent.gd†L90-L92】 | 0–3 throughout most of the game; only edge-case builds exceed 4 relative points.【F:BaseCharacterStats.md†L35-L49】 |
| `mind_pool_fixed` | `int` | Non-reassignable Mind points backing mental stats.【F:src/components/StatsComponent.gd†L94-L96】 | Mirrors Body: 5 fixed points by default with late-game caps near 8–10.【F:BaseCharacterStats.md†L51-L60】 |
| `mind_pool_relative` | `int` | Reallocatable Mind points for rest-period tuning.【F:src/components/StatsComponent.gd†L98-L100】 | Maintain 0–3 relative points for balance parity with Body pools.【F:BaseCharacterStats.md†L35-L61】 |

## Core attributes

| Property | Type | Description | Common range & notes |
| --- | --- | --- | --- |
| `strength` | `int` | Governs melee accuracy, carry weight, and athletic checks.【F:src/components/StatsComponent.gd†L102-L104】 | Entry-level recruits start at 2–4; specialists and bosses stretch to 8–12. Derived from Body pool allocations.【F:BaseCharacterStats.md†L41-L43】 |
| `agility` | `int` | Controls ranged accuracy, stealth, and evasion.【F:src/components/StatsComponent.gd†L106-L108】 | 2–5 baseline, 8–11 for rogues and scouts. |
| `speed` | `int` | Influences initiative and grid travel per AP.【F:src/components/StatsComponent.gd†L110-L112】 | 1–4 for heavy units, 6–9 for skirmishers. Speed pairs strongly with AP formulas.【F:BaseCharacterStats.md†L23-L33】 |
| `intelligence` | `int` | Governs skill slots and knowledge checks.【F:src/components/StatsComponent.gd†L114-L116】 | 3–6 for generalists, 8–12 for scholars and tacticians.【F:BaseCharacterStats.md†L53-L55】 |
| `wisdom` | `int` | Affects XP modifiers, meta choices, and will saves.【F:src/components/StatsComponent.gd†L118-L120】 | 2–6 baseline. High-end sages reach 10+. |
| `charisma` | `int` | Drives social interactions, recruitment, and morale.【F:src/components/StatsComponent.gd†L122-L124】 | 2–5 for typical recruits, 7–11 for diplomats and leaders.【F:BaseCharacterStats.md†L57-L59】 |

## Training proficiencies

| Property | Type | Description | Common range & notes |
| --- | --- | --- | --- |
| `athletics` | `int` | Training score for climbing, swimming, and physical checks.【F:src/components/StatsComponent.gd†L126-L128】 | 0–40 with milestone perks every 10 points. Core formula weights STR, SPD, and job factors.【F:BaseCharacterStats.md†L69-L77】 |
| `combat_training` | `int` | General martial expertise across weapon types.【F:src/components/StatsComponent.gd†L130-L132】 | 0–50; front-line fighters trend 30+. Derived from STR, AGL, and job templates.【F:BaseCharacterStats.md†L69-L78】 |
| `thievery` | `int` | Stealth movement, traps, and criminal actions.【F:src/components/StatsComponent.gd†L134-L136】 | 0–45; rogues routinely land 25+. Formula leans on AGL and SPD.【F:BaseCharacterStats.md†L70-L79】 |
| `diplomacy` | `int` | Negotiations, speech checks, and alliances.【F:src/components/StatsComponent.gd†L138-L140】 | 0–40; statespeople average 20–30 with CHR weighting.【F:BaseCharacterStats.md†L72-L80】 |
| `lore` | `int` | Historical knowledge and route planning.【F:src/components/StatsComponent.gd†L142-L144】 | 0–40; scholars average 25. Uses INT and CHR in generation formulas.【F:BaseCharacterStats.md†L72-L82】 |
| `technical` | `int` | Crafting, maintenance, and gadget challenges.【F:src/components/StatsComponent.gd†L146-L148】 | 0–40; engineers settle near 20–30. Weighted by INT and WIS.【F:BaseCharacterStats.md†L74-L83】 |
| `advanced_training` | `Dictionary[StringName, int]` | Flexible slot for late-game specializations (e.g., "Pilot").【F:src/components/StatsComponent.gd†L150-L153】 | Keep ranks between 0–5 per specialty. Expect 0–2 simultaneous entries until late campaign unlocks.【F:BaseCharacterStats.md†L84-L91】 |

## Skill surfaces

| Property | Type | Description | Common range & notes |
| --- | --- | --- | --- |
| `skill_levels` | `Dictionary[StringName, int]` | Tracks each learned skill's tier (basic/common/rare/etc.).【F:src/components/StatsComponent.gd†L155-L158】 | Store 3–8 skills for early heroes, expanding toward 12 for veterans. Values typically map to 0–4 representing rarity tiers.【F:BaseCharacterStats.md†L95-L123】 |
| `skill_options` | `Dictionary[StringName, Array]` | Lists unlocked options or upgrades per skill tree. Arrays should contain `StringName` entries even though the exported type is untyped to satisfy Godot's parser.【F:src/components/StatsComponent.gd†L125-L128】 | Each skill carries 1–3 unlocked options mid-game; complex trees may hit 5. Arrays should stay ordered for deterministic UI.【F:BaseCharacterStats.md†L95-L123】 |

## Equipment and inventory snapshots

| Property | Type | Description | Common range & notes |
| --- | --- | --- | --- |
| `equipped_items` | `Dictionary[StringName, StringName]` | Maps equipment slots to equipped item IDs.【F:src/components/StatsComponent.gd†L165-L168】 | Core humanoids expose slots like `weapon`, `armor`, `trinket`. Maintain 0–6 entries; leave absent slots unspecified.【F:BaseCharacterStats.md†L125-L135】 |
| `inventory_items` | `Array[StringName]` | Bag or locker items carried outside equipped slots.【F:src/components/StatsComponent.gd†L170-L172】 | Carry 0–10 references for tactical missions. Logistics-heavy scenarios may stretch to 20 but consider migrating overflow to a dedicated inventory system.【F:BaseCharacterStats.md†L125-L138】 |

## Runtime helpers

The component exposes convenience methods for common stat mutations: `apply_damage()`, `heal()`, `spend_energy()`, `restore_energy()`, `spend_action_points()`, `restore_action_points()`, status and trait mutators, bundled `apply_modifiers()` / `revert_modifiers()` helpers (with `apply_stat_mod()` retained for compatibility), and `reset_for_new_run()` to refresh per-run resources.【F:src/components/StatsComponent.gd†L174-L452】 Use these utilities instead of rewriting bespoke logic so downstream systems inherit the same clamping rules described above.
