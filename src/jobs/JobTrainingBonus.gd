extends Resource
class_name JobTrainingBonus

## Data entry describing a training proficiency bonus supplied by a job.
## ``training_property`` should map to an exported training stat on
## ``StatsComponent`` such as ``athletics`` or ``lore``. ``amount`` is the
## additive modifier applied when the job is active.

var _training_property: StringName = StringName("")
var _amount: int = 0

@export var training_property: StringName:
    get:
        return _training_property
    set(value):
        if _training_property == value:
            return
        _training_property = value
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
