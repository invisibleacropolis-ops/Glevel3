extends Resource
class_name JobTrainingBonus

## Data entry describing a training proficiency bonus supplied by a job.
## ``training_property`` maps to an exported training stat on ``StatsComponent``
## such as ``athletics`` or ``lore``. ``amount`` is the additive modifier applied
## when the job is active.

const TRAINING_PROPERTY_HINT_STRING := \
        "Athletics:athletics,Combat:combat_training,Thievery:thievery,Diplomacy:diplomacy," + \
        "Lore:lore,Technical:technical"

const TRAINING_PROPERTY_LOOKUP := {
    "athletics": StringName("athletics"),
    "combat": StringName("combat_training"),
    "combat_training": StringName("combat_training"),
    "thievery": StringName("thievery"),
    "diplomacy": StringName("diplomacy"),
    "lore": StringName("lore"),
    "technical": StringName("technical"),
}

var _training_property: StringName = StringName("")
var _amount: int = 0

@export_custom(PropertyHint.ENUM_SUGGESTION, TRAINING_PROPERTY_HINT_STRING) var training_property: StringName:
    get:
        return _training_property
    set(value):
        var resolved := _resolve_training_property(value)
        if _training_property == resolved:
            return
        _training_property = resolved
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
        "training_property": training_property,
        "amount": amount,
    }

func _resolve_training_property(value: Variant) -> StringName:
    if value is StringName:
        if value == StringName(""):
            return value
        return _lookup_training_property(String(value))
    if value is String:
        if value.strip_edges() == "":
            return StringName("")
        return _lookup_training_property(value)
    return _training_property

func _lookup_training_property(value: String) -> StringName:
    var normalized := value.strip_edges().to_lower()
    if normalized == "":
        return StringName("")
    if TRAINING_PROPERTY_LOOKUP.has(normalized):
        return TRAINING_PROPERTY_LOOKUP[normalized]
    return StringName(value.strip_edges())
