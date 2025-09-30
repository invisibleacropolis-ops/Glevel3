extends "res://src/core/Component.gd"
class_name JobComponent

## Component bridging StatsComponent data to modular Job resources.
## Designers assign a primary Job resource plus optional alternates
## so generators can swap professions without duplicating baseline stats.

const JOB_SCRIPT_PATH := "res://assets/jobs/Job.gd"
var _job_script: GDScript = null

@export_group("Job Assignment")
@export var primary_job: Resource

## Optional pool of alternate jobs that can replace the primary_job
## during generation or scripted events. Entries should be Job resources.
@export var alternate_jobs: Array[Resource] = []

func has_primary_job() -> bool:
    return _as_job(primary_job) != null

func get_primary_job_id() -> StringName:
    var job = _as_job(primary_job)
    if job == null:
        return StringName("")
    return job.job_id

func get_primary_job() -> Resource:
    return _as_job(primary_job)

func list_jobs() -> Array[Resource]:
    var jobs: Array[Resource] = []
    var primary := _as_job(primary_job)
    if primary != null:
        jobs.append(primary)
    for entry in alternate_jobs:
        var job := _as_job(entry)
        if job == null:
            continue
        if jobs.has(job):
            continue
        jobs.append(job)
    return jobs

func list_job_ids() -> PackedStringArray:
    var ids: PackedStringArray = []
    var primary = _as_job(primary_job)
    if primary != null and primary.job_id != StringName(""):
        ids.append(String(primary.job_id))
    for entry in alternate_jobs:
        var job = _as_job(entry)
        if job == null:
            continue
        var id_string := String(job.job_id)
        if not ids.has(id_string):
            ids.append(id_string)
    return ids

func to_dictionary() -> Dictionary:
    var primary_snapshot = _job_snapshot(primary_job)
    var alternate_snapshots: Array = []
    for entry in alternate_jobs:
        var snapshot = _job_snapshot(entry)
        if snapshot != null:
            alternate_snapshots.append(snapshot)
    return {
        "primary_job": primary_snapshot,
        "alternate_jobs": alternate_snapshots,
    }

func _job_snapshot(candidate: Resource) -> Variant:
    var job = _as_job(candidate)
    if job == null:
        return null
    if not job.has_method("to_dictionary"):
        return null
    return job.to_dictionary()

func _as_job(candidate: Resource) -> Resource:
    if candidate == null:
        return null
    if _job_script == null:
        _job_script = load(JOB_SCRIPT_PATH)
    if _job_script == null:
        return null
    if candidate.get_script() != _job_script:
        return null
    return candidate
