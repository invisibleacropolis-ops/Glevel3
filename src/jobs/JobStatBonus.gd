extends Resource
class_name JobStatBonus

## Data entry describing a single StatsComponent property bonus granted by a job.
## Designers pick the exported ``stat_property`` from the StatsComponent property
## list and provide a numeric ``amount`` that will be added on top of the
## baseline value when the job is assigned.

var _stat_property: StringName = StringName("")
var _amount: int = 0

@export var stat_property: StringName:
    get:
        return _stat_property
    set(value):
        if _stat_property == value:
            return
        _stat_property = value
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
