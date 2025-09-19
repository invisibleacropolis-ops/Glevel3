extends "res://src/core/Skill.gd"
class_name BaseRangedSkill

## A specialized Skill resource for the Ranged category.
## Inherits all properties from Skill.gd.

func _init():
    # Automatically set the category and a default range for new Ranged skills.
    category = ULTEnums.SkillCategory.RANGED
    range = 10