extends Resource
class_name Skill

const ULTEnums := preload("res://src/globals/ULTEnums.gd")

@export_group("Core Identity")
@export var skill_name: String = ""
@export var description: String = ""
@export var category: ULTEnums.SkillCategory = ULTEnums.SkillCategory.MELEE
@export var rarity: ULTEnums.SkillRarity = ULTEnums.SkillRarity.BASIC

@export_group("Base Stats")
@export var ap_cost: int = 0
@export var damage: int = 0
@export var target_type: ULTEnums.TargetType = ULTEnums.TargetType.ENEMY
@export var initiative_modifier: int = 0
@export var area_of_effect: int = 0
@export var range_tiles: int = 0

@export_group("Status Effect")
## If this skill applies a status effect, define it here. Leave blank for no effect.
@export var status_effect_to_apply: StringName = &""
@export var status_effect_duration: int = 3
@export var status_effect_is_long_term: bool = false
@export var status_effect_chance: float = 1.0

@export_group("Traits & Requirements")
@export var base_traits: Array[StringName] = []
@export var weapon_requirement: ULTEnums.WeaponType = ULTEnums.WeaponType.NONE

@export_group("Advanced Actions & Upgrades")
## For more complex skills, these can override the base stats.
@export var base_actions: Array[Dictionary] = []
@export var upgrades: Dictionary = {}
