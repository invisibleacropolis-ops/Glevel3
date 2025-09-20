extends "res://src/entities/Entity.gd"
class_name OscillatingEntity
"""Debug-focused entity that oscillates in space and mutates demo stats for inspection."""

const ULTEnums := preload("res://src/globals/ULTEnums.gd")
const STATS_COMPONENT := preload("res://src/components/StatsComponent.gd")

@export var oscillation_axis: Vector3 = Vector3(1, 0, 0)
@export var oscillation_amplitude := 2.0
@export var oscillation_speed := 1.5
@export var health_wave_amplitude := 12
@export var health_wave_speed := 0.8

var _base_position := Vector3.ZERO
var _time_offset := 0.0
var _baseline_health := 0

func _ready() -> void:
    super._ready()
    _base_position = global_position
    _time_offset = randf_range(0.0, TAU)
    if entity_data != null:
        entity_data = entity_data.duplicate(true)
        var stats := _extract_stats_component()
        if stats != null:
            _baseline_health = stats.health

func _process(_delta: float) -> void:
    _apply_position_oscillation()
    _update_demo_stats()

func _apply_position_oscillation() -> void:
    """Moves the entity along a configurable sine wave for visual feedback."""
    var axis := oscillation_axis
    if axis.length() <= 0.01:
        axis = Vector3(1, 0, 0)
    var direction := axis.normalized()
    var time_seconds := Time.get_ticks_msec() / 1000.0
    var offset := direction * oscillation_amplitude * sin((time_seconds + _time_offset) * oscillation_speed)
    global_position = _base_position + offset

func _update_demo_stats() -> void:
    """Animates the entity's health value so inspectors show live updates."""
    var stats := _extract_stats_component()
    if stats == null:
        return
    var baseline := _baseline_health
    if baseline == 0:
        baseline = stats.health
    var max_health := stats.max_health if stats.max_health > 0 else baseline + health_wave_amplitude
    var time_seconds := Time.get_ticks_msec() / 1000.0
    var wave := sin((time_seconds + _time_offset) * health_wave_speed)
    var delta := int(round(wave * health_wave_amplitude))
    stats.health = clampi(baseline + delta, 0, max_health)

func _extract_stats_component() -> STATS_COMPONENT:
    """Helper that resolves the StatsComponent resource when present."""
    if entity_data == null:
        return null
    var key := ULTEnums.ComponentKeys.STATS
    if not entity_data.has_component(key):
        return null
    var stats := entity_data.get_component(key)
    if stats is STATS_COMPONENT:
        return stats
    return null
