extends "res://src/jobs/Job.gd"
class_name MageJob

## Sample job demonstrating how to preconfigure a magic-focused loadout.

func _init() -> void:
    job_id = StringName("mage")
    job_title = "Battle Mage"
    job_pool_tags = [StringName("magic"), StringName("starter")]
    stat_bonuses = {
        StringName("max_energy"): 30,
        StringName("intelligence"): 4,
        StringName("wisdom"): 2,
    }
    training_bonuses = {
        StringName("lore"): 3,
        StringName("technical"): 1,
    }
    starting_skills = [StringName("arcane_bolt"), StringName("mana_barrier")]
    skill_options = {
        StringName("arcane_bolt"): [StringName("focus_burst"), StringName("piercing_wave")],
    }
    starting_traits = [StringName("arcane_attuned"), StringName("scholar")]
    formula_overrides = {
        StringName("energy_regen_formula"): StringName("mage_channel"),
    }
