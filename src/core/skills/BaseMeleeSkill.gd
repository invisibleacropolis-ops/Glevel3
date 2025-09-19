extends "res://src/core/Skill.gd"
class_name BaseMeleeSkill

## A specialized Skill resource for the Melee category.
## Inherits all properties from Skill.gd.

func _init():
    # Automatically set the category for any new resource of this type.
    category = ULTEnums.SkillCategory.MELEE
