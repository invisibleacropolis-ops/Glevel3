extends SceneTree

const StatsComponent := preload("res://src/components/StatsComponent.gd")
const Job := preload("res://assets/jobs/Job.gd")
const JobStatBonus := preload("res://assets/jobs/JobStatBonus.gd")
const JobTrainingBonus := preload("res://assets/jobs/JobTrainingBonus.gd")
const Trait := preload("res://src/components/Trait.gd")
const JobComponent := preload("res://src/components/JobComponent.gd")

func _init() -> void:
    _run_tests()
    quit()

func _run_tests() -> void:
    var stats := StatsComponent.new()
    stats.strength = 2
    stats.athletics = 1

    var job := Job.new()
    job.job_id = StringName("tester")

    var stat_bonus := JobStatBonus.new()
    stat_bonus.stat_property = StringName("strength")
    stat_bonus.amount = 3
    job.stat_bonuses = [stat_bonus]

    var training_bonus := JobTrainingBonus.new()
    training_bonus.training_property = StringName("athletics")
    training_bonus.amount = 4
    job.training_bonuses = [training_bonus]

    var trait_resource := Trait.new()
    trait_resource.trait_id = "test_trait"
    job.starting_traits = [trait_resource]

    var component := JobComponent.new()
    component.primary_job = job

    stats.job_component = component

    assert(stats.strength == 5, "Strength should include job bonus")
    assert(stats.athletics == 5, "Athletics should include job training bonus")
    assert(StringName("test_trait") in stats.traits, "Trait from job should be applied")
    assert(stat_bonus.changed.is_connected(Callable(stats, "_on_job_resource_changed")), "Stats component should listen for job stat changes")

    stat_bonus.amount = 5
    assert(stats.strength == 7, "Strength should refresh after stat bonus update")

    stats.job_component = null
    assert(stats.strength == 2, "Strength should revert when job removed")
    assert(stats.athletics == 1, "Training should revert when job removed")
    assert(not (StringName("test_trait") in stats.traits), "Job trait should be removed when job cleared")

    print("Job system tests passed.")
