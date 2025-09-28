extends Resource
class_name JobStatBonus

## Data entry describing a single StatsComponent property bonus granted by a job.
## Designers pick the exported ``stat_property`` from a curated list of common
## StatsComponent fields and provide a numeric ``amount`` that will be added on
## top of the baseline value when the job is assigned.

const STAT_PROPERTY_HINT_STRING := \
        "Health:health,Max Health:max_health,Energy:energy,Max Energy:max_energy," + \
        "AP:action_points,Max AP:max_action_points,Body:body_pool_fixed,Body Pool Relative:body_pool_relative," + \
        "Mind:mind_pool_fixed,Mind Pool Relative:mind_pool_relative,STR:strength,AGL:agility,SPD:speed," + \
        "INT:intelligence,WIS:wisdom,CHR:charisma"

const STAT_PROPERTY_LOOKUP := {
    "health": StringName("health"),
    "max_health": StringName("max_health"),
    "energy": StringName("energy"),
    "max_energy": StringName("max_energy"),
    "ap": StringName("action_points"),
    "action_points": StringName("action_points"),
    "max ap": StringName("max_action_points"),
    "max_action_points": StringName("max_action_points"),
    "body": StringName("body_pool_fixed"),
    "body_pool_fixed": StringName("body_pool_fixed"),
    "body_pool_relative": StringName("body_pool_relative"),
    "mind": StringName("mind_pool_fixed"),
    "mind_pool_fixed": StringName("mind_pool_fixed"),
    "mind_pool_relative": StringName("mind_pool_relative"),
    "str": StringName("strength"),
    "strength": StringName("strength"),
    "agl": StringName("agility"),
    "agility": StringName("agility"),
    "spd": StringName("speed"),
    "speed": StringName("speed"),
    "int": StringName("intelligence"),
    "intelligence": StringName("intelligence"),
    "wis": StringName("wisdom"),
    "wisdom": StringName("wisdom"),
    "chr": StringName("charisma"),
    "charisma": StringName("charisma"),
}

var _stat_property: StringName = StringName("")
var _amount: int = 0

@export_custom(PropertyHint.ENUM_SUGGESTION, STAT_PROPERTY_HINT_STRING) var stat_property: StringName:
    get:
        return _stat_property
    set(value):
        var resolved := _resolve_stat_property(value)
        if _stat_property == resolved:
            return
        _stat_property = resolved
        emit_changed()

@export var amount: int:
    get:
        return _amount
    set(value):
        if _amount == value:
            return
        _amount = value
        emit_changed()

func to_dictionary() -> Dictionary:
    return {
        "stat_property": stat_property,
        "amount": amount,
    }

func _resolve_stat_property(value: Variant) -> StringName:
    if value is StringName:
        if value == StringName(""):
            return value
        return _lookup_stat_property(String(value))
    if value is String:
        if value.strip_edges() == "":
            return StringName("")
        return _lookup_stat_property(value)
    return _stat_property

func _lookup_stat_property(value: String) -> StringName:
    var normalized := value.strip_edges().to_lower()
    if normalized == "":
        return StringName("")
    if STAT_PROPERTY_LOOKUP.has(normalized):
        return STAT_PROPERTY_LOOKUP[normalized]
    return StringName(value.strip_edges())
