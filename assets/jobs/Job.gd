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
@export var stat_bonuses: Array[JobStatBonus] = []

@export_group("Training Bonuses")
## Additive modifiers to training proficiencies identified by StringName.
@export var training_bonuses: Array[JobTrainingBonus] = []

@export_group("Skill Loadout")
## Skill resources granted when the job is assigned.
@export var starting_skills: Array[Skill] = []

## Mapping of skill ids to option arrays unlocked by the job (e.g., tree choices).
@export var skill_options: Dictionary[StringName, Array] = {}

@export_group("Traits")
## Trait resources always granted by the job.
@export var starting_traits: Array[Trait] = []

@export_group("Formula Overrides")
## Arbitrary override tokens consumed by systems (e.g., damage formulas).
@export var formula_overrides: Dictionary[StringName, Variant] = {}

func get_stat_bonuses() -> Array[JobStatBonus]:
    return stat_bonuses.duplicate()

func get_training_bonuses() -> Array[JobTrainingBonus]:
    return training_bonuses.duplicate()

func get_starting_skills() -> Array[Skill]:
    return starting_skills.duplicate()

func get_starting_traits() -> Array[Trait]:
    return starting_traits.duplicate()

## Returns a stable snapshot suitable for serialization or tests.
func to_dictionary() -> Dictionary:
    var options_snapshot: Dictionary[StringName, Array] = {}
    for skill_id in skill_options.keys():
        var options: Array = skill_options[skill_id]
        options_snapshot[skill_id] = options.duplicate()

    var stat_snapshot: Array[Dictionary] = []
    for bonus in stat_bonuses:
        if bonus == null:
            continue
        stat_snapshot.append(bonus.to_dictionary())

    var training_snapshot: Array[Dictionary] = []
    for bonus in training_bonuses:
        if bonus == null:
            continue
        training_snapshot.append(bonus.to_dictionary())

    var skill_snapshot: Array[Dictionary] = []
    for skill in starting_skills:
        if skill == null:
            continue
        skill_snapshot.append(_skill_to_dictionary(skill))

    var trait_snapshot: Array[Dictionary] = []
    for trait_resource in starting_traits:
        if trait_resource == null:
            continue
        trait_snapshot.append(_trait_to_dictionary(trait_resource))

    return {
        "job_id": job_id,
        "job_title": job_title,
        "job_pool_tags": job_pool_tags.duplicate(),
        "stat_bonuses": stat_snapshot,
        "training_bonuses": training_snapshot,
        "starting_skills": skill_snapshot,
        "skill_options": options_snapshot,
        "starting_traits": trait_snapshot,
        "formula_overrides": formula_overrides.duplicate(true),
    }

func _skill_to_dictionary(skill: Skill) -> Dictionary:
    return {
        "resource_path": skill.resource_path,
        "skill_name": skill.skill_name,
        "category": skill.category,
        "rarity": skill.rarity,
    }

func _trait_to_dictionary(trait_resource: Trait) -> Dictionary:
    return {
        "resource_path": trait_resource.resource_path,
        "trait_id": trait_resource.trait_id,
        "display_name": trait_resource.display_name,
    }
