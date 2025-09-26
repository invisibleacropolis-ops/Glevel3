extends "res://src/jobs/Job.gd"
class_name MageJob

## Sample job demonstrating how to preconfigure a magic-focused loadout.

const ARCANE_BOLT_SKILL_PATH := "res://assets/skills/ArcaneBoltSkill.tres"
const MANA_BARRIER_SKILL_PATH := "res://assets/skills/ManaBarrierSkill.tres"
const FIRE_ATTUNED_TRAIT_PATH := "res://assets/traits/FireAttunedTrait.tres"
const QUICK_TRAIT_PATH := "res://assets/traits/QuickTrait.tres"

func _init() -> void:
    job_id = StringName("mage")
    job_title = "Battle Mage"
    job_pool_tags = [StringName("magic"), StringName("starter")]
    var energy_bonus := JobStatBonus.new()
    energy_bonus.stat_property = StringName("max_energy")
    energy_bonus.amount = 30

    var intelligence_bonus := JobStatBonus.new()
    intelligence_bonus.stat_property = StringName("intelligence")
    intelligence_bonus.amount = 4

    var wisdom_bonus := JobStatBonus.new()
    wisdom_bonus.stat_property = StringName("wisdom")
    wisdom_bonus.amount = 2

    stat_bonuses = [energy_bonus, intelligence_bonus, wisdom_bonus]

    var lore_bonus := JobTrainingBonus.new()
    lore_bonus.training_property = StringName("lore")
    lore_bonus.amount = 3

    var technical_bonus := JobTrainingBonus.new()
    technical_bonus.training_property = StringName("technical")
    technical_bonus.amount = 1

    training_bonuses = [lore_bonus, technical_bonus]

    starting_skills = _load_skills([
        ARCANE_BOLT_SKILL_PATH,
        MANA_BARRIER_SKILL_PATH,
    ])
    skill_options = {
        StringName("arcane_bolt"): [StringName("focus_burst"), StringName("piercing_wave")],
    }
    starting_traits = _load_traits([
        FIRE_ATTUNED_TRAIT_PATH,
        QUICK_TRAIT_PATH,
    ])
    formula_overrides = {
        StringName("energy_regen_formula"): StringName("mage_channel"),
    }


func _load_skills(paths: Array[String]) -> Array[Skill]:
    var result: Array[Skill] = []
    for path in paths:
        var resource := load(path)
        if resource == null:
            continue
        if resource is Skill:
            result.append(resource)
    return result


func _load_traits(paths: Array[String]) -> Array[Trait]:
    var result: Array[Trait] = []
    for path in paths:
        var resource := load(path)
        if resource == null:
            continue
        if resource is Trait:
            result.append(resource)
    return result
