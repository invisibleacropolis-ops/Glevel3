extends Resource
class_name Job

## Data-only resource describing a modular profession or role overlay.
## Jobs augment baseline stats with additional bonuses, loadouts, and
## metadata so the same StatsComponent resource can support multiple
## archetypes.

@export_group("Identity")
@export var job_id: StringName = StringName("")
@export var job_title: String = ""
@export var job_pool_tags: Array[StringName] = []

@export_group("Stat Bonuses")
## Additive modifiers applied when the job is attached to a StatsComponent.
## Keys should match exported property names on StatsComponent (e.g., "strength").
@export var stat_bonuses: Dictionary[StringName, int] = {}

@export_group("Training Bonuses")
## Additive modifiers to training proficiencies identified by StringName.
@export var training_bonuses: Dictionary[StringName, int] = {}

@export_group("Skill Loadout")
## Skill identifiers granted when the job is assigned.
@export var starting_skills: Array[StringName] = []

## Mapping of skill ids to option arrays unlocked by the job (e.g., tree choices).
@export var skill_options: Dictionary[StringName, Array[StringName]] = {}

@export_group("Traits")
## Trait identifiers always granted by the job.
@export var starting_traits: Array[StringName] = []

@export_group("Formula Overrides")
## Arbitrary override tokens consumed by systems (e.g., damage formulas).
@export var formula_overrides: Dictionary[StringName, Variant] = {}

## Returns a stable snapshot suitable for serialization or tests.
func to_dictionary() -> Dictionary:
    var options_snapshot: Dictionary[StringName, Array[StringName]] = {}
    for skill_id in skill_options.keys():
        var options: Array[StringName] = skill_options[skill_id]
        options_snapshot[skill_id] = options.duplicate()

    return {
        "job_id": job_id,
        "job_title": job_title,
        "job_pool_tags": job_pool_tags.duplicate(),
        "stat_bonuses": stat_bonuses.duplicate(true),
        "training_bonuses": training_bonuses.duplicate(true),
        "starting_skills": starting_skills.duplicate(),
        "skill_options": options_snapshot,
        "starting_traits": starting_traits.duplicate(),
        "formula_overrides": formula_overrides.duplicate(true),
    }
