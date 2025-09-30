extends "res://src/core/Component.gd"
class_name StatsComponent

## Canonical data block describing a character's core stats and progression surface.
## Every property is exported so designers can author archetypes directly in the Inspector.
## Runtime systems mutate these values in response to gameplay.

const JOB_COMPONENT_SCRIPT_PATH := "res://src/components/JobComponent.gd"
const Trait := preload("res://src/components/Trait.gd")
const Skill := preload("res://src/components/Skill.gd")
const JobStatBonus := preload("res://assets/jobs/JobStatBonus.gd")
const JobTrainingBonus := preload("res://assets/jobs/JobTrainingBonus.gd")
var _job_component_script: GDScript = null
var _job_component_internal: Resource = null
var _job_component_monitor: Resource = null
var _active_job_resource: Resource = null
var _applied_job_snapshot: Dictionary = {}
var _active_job_subresources: Array[Resource] = []

## Optional JobComponent resource that layers profession data on top of baseline stats.
## Attach a JobComponent to reuse this StatsComponent across multiple archetypes.
@export_group("Job Assignment")
@export var job_component: Resource:
    get:
        return _job_component_internal
    set(value):
        if _job_component_internal == value:
            return
        _remove_job_bonuses()
        if _job_component_monitor != null and _job_component_monitor.has_signal("changed") and _job_component_monitor.changed.is_connected(Callable(self, "_on_job_component_changed")):
            _job_component_monitor.changed.disconnect(Callable(self, "_on_job_component_changed"))
        _job_component_internal = value
        _job_component_monitor = _job_component_internal
        if _job_component_monitor != null and _job_component_monitor.has_signal("changed") and not _job_component_monitor.changed.is_connected(Callable(self, "_on_job_component_changed")):
            _job_component_monitor.changed.connect(Callable(self, "_on_job_component_changed"))
        _apply_job_bonuses()

## ---- Vital Resources ----
## Current health pool. When this reaches 0 the entity is considered defeated.
@export_group("Vital Resources")
@export var health: int = 0

## Maximum health capacity granted by the character's archetype, gear, and traits.
@export var max_health: int = 0

## Current energy resource used for skill execution or mind-driven abilities.
@export var energy: int = 0

## Maximum energy capacity for the character's job formula.
@export var max_energy: int = 0

## Armor value mitigating incoming damage before other resistances are applied.
@export var armor_rating: int = 0

## Action points available during the current tactical round.
@export var action_points: int = 0

## Maximum action points restored during turn resets or camp rests.
@export var max_action_points: int = 0

## ---- Status Tracking ----
## Short-lived status effects such as Poisoned or Inspired that should clear between missions.
@export_group("Status Tracking")
@export var short_term_statuses: Array[StringName] = []

## Persistent status effects such as Diseased or Aged that survive multiple encounters.
@export var long_term_statuses: Array[StringName] = []

## Mapping of effect identifiers to fractional mitigation (e.g., fire => 0.25 for 25% resistance).
@export var resistances: Dictionary[StringName, float] = {}

## Mapping of effect identifiers to vulnerability multipliers (e.g., cold => 1.5 for 50% more damage).
@export var vulnerabilities: Dictionary[StringName, float] = {}

## ---- Progression ----
## Experience points accumulated toward the next level reward.
@export_group("Progression")
@export var experience_points: int = 0

## Character level used to gate skill unlocks and campaign events.
@export var level: int = 1

## Narrative title associated with the current level (e.g., "Veteran", "Archmage").
@export var level_title: String = ""

## Traits derived from stats, achievements, or narrative milestones (e.g., STR:4 => "strong").
@export var traits: Array[StringName] = []

## ---- Attribute Pools ----
## Fixed points allocated to the Body pool that cannot be reassigned.
@export_group("Attribute Pools")
@export var body_pool_fixed: int = 0

## Flexible points currently stored in the Body pool for camp reallocation.
@export var body_pool_relative: int = 0

## Fixed points allocated to the Mind pool that cannot be reassigned.
@export var mind_pool_fixed: int = 0

## Flexible points currently stored in the Mind pool for camp reallocation.
@export var mind_pool_relative: int = 0

## Strength attribute driving melee accuracy, carry weight, and athletic checks.
@export var strength: int = 0

## Agility attribute controlling ranged accuracy, stealth, and evasive maneuvers.
@export var agility: int = 0

## Speed attribute influencing initiative and grid travel distance per action point.
@export var speed: int = 0

## Intelligence attribute governing skill option availability and knowledge checks.
@export var intelligence: int = 0

## Wisdom attribute affecting XP modifiers, meta choices, and will-based saves.
@export var wisdom: int = 0

## Charisma attribute for social interactions, recruitment, and morale swings.
@export var charisma: int = 0

## ---- Training Proficiencies ----
## Athletic training score used for climbing, swimming, and similar body checks.
@export_group("Training Proficiencies")
@export var athletics: int = 0

## Combat training score measuring general martial expertise across weapon types.
@export var combat_training: int = 0

## Thievery training score for stealth movement, traps, and criminal actions.
@export var thievery: int = 0

## Diplomacy training score resolving negotiations, speech checks, and alliances.
@export var diplomacy: int = 0

## Lore training score representing historical knowledge and route planning.
@export var lore: int = 0

## Technical training score for crafting, maintenance, and gadget-based challenges.
@export var technical: int = 0

## Advanced training slots unlocked later in progression (e.g., "Pilot", "Medic").
## Keys are training identifiers, values represent their current rank.
@export var advanced_training: Dictionary[StringName, int] = {}

## ---- Skill Surface ----
## Mapping of skill identifiers to their current level tier (basic/common/rare/etc.).
@export_group("Skill Surface")
@export_subgroup("Skill Catalog Organization")
## Hierarchical catalog describing every skill available to the character.
## Keys follow the structure:
##   skill_catalog[skill_type][rarity][upgrade_level][trait] -> Array[StringName] of action IDs.
## * skill_type: broad categories such as "melee", "ranged", "defense", or "utility".
## * rarity: strings like "basic", "common", "unique", or "legendary".
## * upgrade_level: identifiers such as "base", "path_a_rank_1", etc., representing the upgrade tier.
## * trait: trait identifiers describing the mechanical modifier for the upgrade action.
## Each Array should contain StringName identifiers referencing concrete skill actions.
@export var skill_catalog: Dictionary[StringName, Dictionary] = {}
@export_subgroup("Skill Loadouts")
@export var skill_levels: Dictionary[StringName, int] = {}

## Mapping of skill identifiers to unlocked option identifiers within each skill tree.
## Godot 4.4.1 does not support nested generic type hints (Dictionary[StringName, Array[StringName]]),
## so we export a Dictionary[StringName, Array] and document that each Array should contain StringName values.
@export var skill_options: Dictionary[StringName, Array] = {}

## ---- Equipment Snapshot ----
## Mapping of equipment slot identifiers (e.g., "weapon", "armor") to equipped item IDs.
@export_group("Equipment Snapshot")
@export var equipped_items: Dictionary[StringName, StringName] = {}

## Bag or locker items carried by the character outside of equipped slots.
@export var inventory_items: Array[StringName] = []


func to_dictionary() -> Dictionary:
    """Returns a defensive snapshot of every exported stat value."""
    var skill_options_copy: Dictionary[StringName, Array] = {}
    for key in skill_options.keys():
        var options: Array = skill_options[key]
        skill_options_copy[key] = options.duplicate()

    var skill_catalog_copy: Dictionary[StringName, Dictionary] = {}
    for type_key in skill_catalog.keys():
        var rarity_map: Dictionary = skill_catalog[type_key]
        var rarity_copy: Dictionary[StringName, Dictionary] = {}
        for rarity_key in rarity_map.keys():
            var level_map: Dictionary = rarity_map[rarity_key]
            var level_copy: Dictionary[StringName, Dictionary] = {}
            for level_key in level_map.keys():
                var trait_map: Dictionary = level_map[level_key]
                level_copy[level_key] = trait_map.duplicate(true)
            rarity_copy[rarity_key] = level_copy
        skill_catalog_copy[type_key] = rarity_copy

    return {
        "job_component": _job_component_snapshot(),
        "health": health,
        "max_health": max_health,
        "energy": energy,
        "max_energy": max_energy,
        "armor_rating": armor_rating,
        "action_points": action_points,
        "max_action_points": max_action_points,
        "short_term_statuses": short_term_statuses.duplicate(),
        "long_term_statuses": long_term_statuses.duplicate(),
        "resistances": resistances.duplicate(true),
        "vulnerabilities": vulnerabilities.duplicate(true),
        "experience_points": experience_points,
        "level": level,
        "level_title": level_title,
        "traits": traits.duplicate(),
        "body_pool_fixed": body_pool_fixed,
        "body_pool_relative": body_pool_relative,
        "mind_pool_fixed": mind_pool_fixed,
        "mind_pool_relative": mind_pool_relative,
        "strength": strength,
        "agility": agility,
        "speed": speed,
        "intelligence": intelligence,
        "wisdom": wisdom,
        "charisma": charisma,
        "athletics": athletics,
        "combat_training": combat_training,
        "thievery": thievery,
        "diplomacy": diplomacy,
        "lore": lore,
        "technical": technical,
        "advanced_training": advanced_training.duplicate(true),
        "skill_catalog": skill_catalog_copy,
        "skill_levels": skill_levels.duplicate(true),
        "skill_options": skill_options_copy,
        "equipped_items": equipped_items.duplicate(true),
        "inventory_items": inventory_items.duplicate(),
    }


func _job_component_snapshot() -> Variant:
    var component = _get_job_component()
    if component == null:
        return null
    if not component.has_method("to_dictionary"):
        return null
    return component.to_dictionary()


func _get_job_component() -> Resource:
    if _job_component_internal == null:
        return null
    if _job_component_script == null:
        _job_component_script = load(JOB_COMPONENT_SCRIPT_PATH)
    if _job_component_script == null:
        return null
    if _job_component_internal.get_script() != _job_component_script:
        push_warning("StatsComponent.job_component expects a JobComponent resource.")
        return null
    return _job_component_internal


func _apply_job_bonuses() -> void:
    _applied_job_snapshot.clear()

    var component: Resource = _get_job_component()
    if component == null:
        return
    if not component.has_method("get_primary_job"):
        return

    var job: Resource = component.get_primary_job()
    if job == null:
        return

    var stat_deltas: Dictionary[StringName, int] = {}
    if job.has_method("get_stat_bonuses"):
        for bonus in job.get_stat_bonuses():
            if bonus == null:
                continue
            if not (bonus is JobStatBonus):
                continue
            var property_name: StringName = bonus.stat_property
            if property_name == StringName(""):
                continue
            var current_value: Variant = _get_numeric_property(property_name)
            if current_value == null:
                push_warning("Job %s references unknown stat '%s'." % [str(job.job_id), str(property_name)])
                continue
            var amount := int(bonus.amount)
            if amount == 0:
                continue
            set(String(property_name), current_value + amount)
            stat_deltas[property_name] = int(stat_deltas.get(property_name, 0)) + amount
            _register_job_subresource(bonus)

    var training_deltas: Dictionary[StringName, int] = {}
    if job.has_method("get_training_bonuses"):
        for bonus in job.get_training_bonuses():
            if bonus == null:
                continue
            if not (bonus is JobTrainingBonus):
                continue
            var training_name: StringName = bonus.training_property
            if training_name == StringName(""):
                continue
            var current_training: Variant = _get_numeric_property(training_name)
            if current_training == null:
                push_warning("Job %s references unknown training '%s'." % [str(job.job_id), str(training_name)])
                continue
            var training_amount := int(bonus.amount)
            if training_amount == 0:
                continue
            set(String(training_name), current_training + training_amount)
            training_deltas[training_name] = int(training_deltas.get(training_name, 0)) + training_amount
            _register_job_subresource(bonus)

    var applied_traits: Array[StringName] = []
    if job.has_method("get_starting_traits"):
        for trait_resource in job.get_starting_traits():
            if trait_resource == null:
                continue
            var trait_id := _resolve_trait_id(trait_resource)
            if trait_id == StringName(""):
                push_warning("Job %s references a trait without an id." % [str(job.job_id)])
                continue
            if trait_id in traits:
                continue
            add_trait(trait_id)
            applied_traits.append(trait_id)
            _register_job_subresource(trait_resource)

    _applied_job_snapshot = {
        "stat_bonuses": stat_deltas,
        "training_bonuses": training_deltas,
        "starting_traits": applied_traits,
        "starting_skills": _build_skill_snapshot(job),
        "job_id": job.job_id,
    }

    _active_job_resource = job
    if job.has_signal("changed") and not job.changed.is_connected(Callable(self, "_on_job_resource_changed")):
        job.changed.connect(Callable(self, "_on_job_resource_changed"))


func _remove_job_bonuses() -> void:
    if _active_job_resource != null and _active_job_resource.has_signal("changed") and _active_job_resource.changed.is_connected(Callable(self, "_on_job_resource_changed")):
        _active_job_resource.changed.disconnect(Callable(self, "_on_job_resource_changed"))
    _active_job_resource = null
    _clear_job_subresource_connections()

    if _applied_job_snapshot.is_empty():
        _applied_job_snapshot.clear()
        return

    var stat_deltas: Dictionary = _applied_job_snapshot.get("stat_bonuses", {})
    for property_name in stat_deltas.keys():
        var current_value_variant: Variant = _get_numeric_property(StringName(property_name))
        if current_value_variant == null:
            continue
        set(String(property_name), current_value_variant - int(stat_deltas[property_name]))

    var training_deltas: Dictionary = _applied_job_snapshot.get("training_bonuses", {})
    for training_name in training_deltas.keys():
        var current_training_variant: Variant = _get_numeric_property(StringName(training_name))
        if current_training_variant == null:
            continue
        set(String(training_name), current_training_variant - int(training_deltas[training_name]))

    var applied_traits: Array = _applied_job_snapshot.get("starting_traits", [])
    for trait_id in applied_traits:
        var normalized := StringName(trait_id)
        if normalized in traits:
            remove_trait(normalized)

    _applied_job_snapshot.clear()


func _refresh_job_bonuses() -> void:
    var current_component: Resource = _job_component_internal
    _remove_job_bonuses()
    if current_component != null:
        _apply_job_bonuses()


func _on_job_resource_changed() -> void:
    _refresh_job_bonuses()


func _on_job_component_changed() -> void:
    _refresh_job_bonuses()


func _get_numeric_property(property_name: StringName) -> Variant:
    if not _has_exported_property(property_name):
        return null
    var value: Variant = get(String(property_name))
    var value_type := typeof(value)
    if value_type != TYPE_INT and value_type != TYPE_FLOAT:
        return null
    return int(value)


func _has_exported_property(property_name: StringName) -> bool:
    if property_name == StringName(""):
        return false
    var normalized := String(property_name)
    for property_info in get_property_list():
        if property_info.get("name", "") == normalized:
            return true
    return false


func _build_skill_snapshot(job: Resource) -> Array[Dictionary]:
    if not job.has_method("get_starting_skills"):
        return []
    var snapshot: Array[Dictionary] = []
    for skill in job.get_starting_skills():
        if skill == null:
            continue
        if not (skill is Skill):
            continue
        snapshot.append({
            "resource_path": skill.resource_path,
            "skill_name": skill.skill_name,
        })
        _register_job_subresource(skill)
    return snapshot


func _resolve_trait_id(trait_resource: Resource) -> StringName:
    if trait_resource == null:
        return StringName("")
    if trait_resource is Trait:
        var typed_trait: Trait = trait_resource
        var direct_id := typed_trait.trait_id.strip_edges()
        if direct_id != "":
            return StringName(direct_id)
        if typed_trait.resource_path != "":
            return StringName(typed_trait.resource_path.get_file().get_basename())
        var display := typed_trait.display_name.strip_edges()
        if display != "":
            return StringName(display)
    elif trait_resource.resource_path != "":
        return StringName(trait_resource.resource_path.get_file().get_basename())
    return StringName("")


func _register_job_subresource(resource: Resource) -> void:
    if resource == null:
        return
    if not resource.has_signal("changed"):
        return
    var callable := Callable(self, "_on_job_resource_changed")
    if resource.changed.is_connected(callable):
        return
    resource.changed.connect(callable)
    _active_job_subresources.append(resource)


func _clear_job_subresource_connections() -> void:
    var callable := Callable(self, "_on_job_resource_changed")
    for resource in _active_job_subresources:
        if resource == null:
            continue
        if resource.has_signal("changed") and resource.changed.is_connected(callable):
            resource.changed.disconnect(callable)
    _active_job_subresources.clear()


func apply_damage(amount: int) -> void:
    """Reduces health by the supplied damage amount, clamped to zero."""
    if amount <= 0:
        return
    health = max(health - amount, 0)


func heal(amount: int) -> void:
    """Restores health up to max_health. Designers should keep max_health >= health."""
    if amount <= 0:
        return
    if max_health > 0:
        health = clampi(health + amount, 0, max_health)
    else:
        health += amount


func get_skill_action_ids(skill_type: StringName, rarity: StringName, upgrade_level: StringName, trait_id: StringName) -> Array[StringName]:
    """Returns the action identifiers tied to the requested skill catalog entry.

    The lookup traverses the hierarchy of type → rarity → upgrade level → trait. A
    defensive copy is returned so callers may mutate the result without affecting the
    stored catalog.
    """
    var empty_actions: Array[StringName] = []
    if not skill_catalog.has(skill_type):
        return empty_actions
    var rarity_map: Dictionary = skill_catalog[skill_type]
    if not rarity_map.has(rarity):
        return empty_actions
    var level_map: Dictionary = rarity_map[rarity]
    if not level_map.has(upgrade_level):
        return empty_actions
    var trait_map: Dictionary = level_map[upgrade_level]
    if not trait_map.has(trait_id):
        return empty_actions
    var actions: Array = trait_map[trait_id]
    var result: Array[StringName] = actions.duplicate()
    return result


func spend_energy(amount: int) -> void:
    """Consumes energy for abilities and prevents the value from dropping below zero."""
    if amount <= 0:
        return
    energy = max(energy - amount, 0)


func restore_energy(amount: int) -> void:
    """Restores energy up to max_energy. Designers can leave max_energy at zero for non-users."""
    if amount <= 0:
        return
    if max_energy > 0:
        energy = clampi(energy + amount, 0, max_energy)
    else:
        energy += amount


func spend_action_points(amount: int) -> void:
    """Subtracts action points for tactical costs, clamped so negative budgets cannot accumulate."""
    if amount <= 0:
        return
    action_points = max(action_points - amount, 0)


func restore_action_points(amount: int) -> void:
    """Restores action points, honoring max_action_points where defined."""
    if amount <= 0:
        return
    if max_action_points > 0:
        action_points = clampi(action_points + amount, 0, max_action_points)
    else:
        action_points += amount


func add_status(effect: StringName, is_long_term: bool = false) -> void:
    """Adds a status effect tag to the appropriate list if it is not already present.

    StatusSystem.apply_status_effect() calls this helper after inserting a
    duplicated ``StatusFX`` into StatusComponent so downstream systems and UI
    widgets can inspect the entity's current conditions without dereferencing
    resources. Designers can also author starting conditions directly in the
    inspector and the arrays remain unique per effect identifier.
    """
    var normalized := StringName(effect)
    var target := long_term_statuses if is_long_term else short_term_statuses
    if normalized in target:
        return
    target.append(normalized)
    if is_long_term:
        long_term_statuses = target
    else:
        short_term_statuses = target


func remove_status(effect: StringName) -> void:
    """Removes a status effect tag from both short and long term lists.

    StatusSystem invokes this when an effect expires so HUD panels and save
    systems stay synchronized with the canonical runtime modifiers.
    """
    var normalized := StringName(effect)
    if normalized in short_term_statuses:
        short_term_statuses.erase(normalized)
    if normalized in long_term_statuses:
        long_term_statuses.erase(normalized)


func add_trait(trait_name: StringName) -> void:
    """Registers a derived trait such as \"Goblin Slayer\" when conditions are met."""
    var normalized := StringName(trait_name)
    if normalized in traits:
        return
    traits.append(normalized)


func remove_trait(trait_name: StringName) -> void:
    """Clears a trait when its prerequisite stats are no longer satisfied."""
    var normalized := StringName(trait_name)
    if normalized in traits:
        traits.erase(normalized)


func apply_modifiers(modifiers: Dictionary) -> void:
    """Applies a bundle of runtime stat adjustments (damage, heals, AP shifts, tags, etc.)."""
    if modifiers.is_empty():
        return

    if modifiers.has("damage"):
        apply_damage(int(modifiers["damage"]))
    if modifiers.has("heal"):
        heal(int(modifiers["heal"]))

    if modifiers.has("energy_delta"):
        var energy_delta := int(modifiers["energy_delta"])
        if energy_delta < 0:
            spend_energy(-energy_delta)
        elif energy_delta > 0:
            restore_energy(energy_delta)

    if modifiers.has("action_points_delta"):
        var ap_delta := int(modifiers["action_points_delta"])
        if ap_delta < 0:
            spend_action_points(-ap_delta)
        elif ap_delta > 0:
            restore_action_points(ap_delta)

    if modifiers.has("xp_delta"):
        experience_points = max(experience_points + int(modifiers["xp_delta"]), 0)

    if modifiers.has("level_delta"):
        level = max(level + int(modifiers["level_delta"]), 1)

    if modifiers.has("add_short_status"):
        for status in modifiers["add_short_status"]:
            add_status(StringName(status), false)

    if modifiers.has("add_long_status"):
        for status in modifiers["add_long_status"]:
            add_status(StringName(status), true)

    if modifiers.has("remove_status"):
        for status in modifiers["remove_status"]:
            remove_status(StringName(status))

    if modifiers.has("traits_to_add"):
        for trait_name in modifiers["traits_to_add"]:
            add_trait(StringName(trait_name))

    if modifiers.has("traits_to_remove"):
        for trait_name in modifiers["traits_to_remove"]:
            remove_trait(StringName(trait_name))


func apply_stat_mod(modifiers: Dictionary) -> void:
    """Legacy helper retained for backwards compatibility. Prefer apply_modifiers()."""
    apply_modifiers(modifiers)


func get_inverse_modifiers(modifiers: Dictionary) -> Dictionary:
    """Builds an inverse payload that reverts adjustments applied by ``apply_modifiers``."""
    if modifiers.is_empty():
        return {}

    var inverse: Dictionary = {}
    for key in modifiers.keys():
        var value: Variant = modifiers[key]
        if value == null:
            continue

        match key:
            "damage":
                var heal_amount := int(value)
                if heal_amount > 0:
                    inverse["heal"] = int(inverse.get("heal", 0)) + heal_amount
            "heal":
                var damage_amount := int(value)
                if damage_amount > 0:
                    inverse["damage"] = int(inverse.get("damage", 0)) + damage_amount
            "energy_delta", "action_points_delta", "xp_delta", "level_delta":
                var numeric_delta := int(value)
                if numeric_delta != 0:
                    inverse[key] = int(inverse.get(key, 0)) - numeric_delta
            "add_short_status", "add_long_status":
                if value is Array:
                    var removal: Array[StringName] = []
                    if inverse.has("remove_status"):
                        removal = inverse["remove_status"]
                    for status_name in value:
                        removal.append(StringName(status_name))
                    inverse["remove_status"] = removal
            "traits_to_add":
                if value is Array:
                    var traits_to_remove: Array[StringName] = []
                    if inverse.has("traits_to_remove"):
                        traits_to_remove = inverse["traits_to_remove"]
                    for trait_name in value:
                        traits_to_remove.append(StringName(trait_name))
                    inverse["traits_to_remove"] = traits_to_remove
            "traits_to_remove":
                if value is Array:
                    var traits_to_add: Array[StringName] = []
                    if inverse.has("traits_to_add"):
                        traits_to_add = inverse["traits_to_add"]
                    for trait_name in value:
                        traits_to_add.append(StringName(trait_name))
                    inverse["traits_to_add"] = traits_to_add
            _:
                continue

    return inverse


func revert_modifiers(modifiers: Dictionary) -> void:
    """Reapplies the inverse of ``modifiers`` so passive status effects can cleanly expire."""
    var inverse := get_inverse_modifiers(modifiers)
    if inverse.is_empty():
        return
    apply_modifiers(inverse)


func reset_for_new_run() -> void:
    """Resets per-run resources while preserving long-term progression."""
    if max_health > 0:
        health = max_health
    if max_energy > 0:
        energy = max_energy
    if max_action_points > 0:
        action_points = max_action_points
    short_term_statuses.clear()
