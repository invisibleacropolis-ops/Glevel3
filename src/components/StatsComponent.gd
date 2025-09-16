extends Component
class_name StatsComponent

## Canonical data block describing a character's core stats and progression surface.
## Every property is exported so designers can author archetypes directly in the Inspector.
## Runtime systems mutate these values in response to gameplay.

## Runtime identifier that links the character to a Job or Profession definition resource.
## Designers assign a stable key so generators can request "ninja" or "scientist" loadouts.
@export var job_id: StringName = StringName("")

## Optional localized title to show in UI for the current Job selection.
@export var job_title: String = ""

## Ordered tags that describe which job pools may offer this character to the player.
## Designers expand this set as meta-progression unlocks more recruitment tables.
@export var job_pool_tags: Array[StringName] = []

## ---- Vital Resources ----
## Current health pool. When this reaches 0 the entity is considered defeated.
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
@export var short_term_statuses: Array[StringName] = []

## Persistent status effects such as Diseased or Aged that survive multiple encounters.
@export var long_term_statuses: Array[StringName] = []

## Mapping of effect identifiers to fractional mitigation (e.g., fire => 0.25 for 25% resistance).
@export var resistances: Dictionary[StringName, float] = {}

## Mapping of effect identifiers to vulnerability multipliers (e.g., cold => 1.5 for 50% more damage).
@export var vulnerabilities: Dictionary[StringName, float] = {}

## ---- Progression ----
## Experience points accumulated toward the next level reward.
@export var experience_points: int = 0

## Character level used to gate skill unlocks and campaign events.
@export var level: int = 1

## Narrative title associated with the current level (e.g., "Veteran", "Archmage").
@export var level_title: String = ""

## Traits derived from stats, achievements, or narrative milestones (e.g., STR:4 => "strong").
@export var traits: Array[StringName] = []

## ---- Attribute Pools ----
## Fixed points allocated to the Body pool that cannot be reassigned.
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
@export var skill_levels: Dictionary[StringName, int] = {}

## Mapping of skill identifiers to unlocked option identifiers within each skill tree.
@export var skill_options: Dictionary[StringName, Array[StringName]] = {}

## ---- Equipment Snapshot ----
## Mapping of equipment slot identifiers (e.g., "weapon", "armor") to equipped item IDs.
@export var equipped_items: Dictionary[StringName, StringName] = {}

## Bag or locker items carried by the character outside of equipped slots.
@export var inventory_items: Array[StringName] = []


func to_dictionary() -> Dictionary:
    """Returns a defensive snapshot of every exported stat value."""
    return {
        "job_id": job_id,
        "job_title": job_title,
        "job_pool_tags": job_pool_tags.duplicate(),
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
        "skill_levels": skill_levels.duplicate(true),
        "skill_options": skill_options.duplicate(true),
        "equipped_items": equipped_items.duplicate(true),
        "inventory_items": inventory_items.duplicate(),
    }


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
        health = int(clamp(health + amount, 0, max_health))
    else:
        health += amount


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
        energy = int(clamp(energy + amount, 0, max_energy))
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
        action_points = int(clamp(action_points + amount, 0, max_action_points))
    else:
        action_points += amount


func add_status(effect: StringName, is_long_term: bool = false) -> void:
    """Adds a status effect to the appropriate list if it is not already present."""
    var target: Array[StringName] = long_term_statuses if is_long_term else short_term_statuses
    if effect in target:
        return
    target.append(effect)
    if is_long_term:
        long_term_statuses = target
    else:
        short_term_statuses = target


func remove_status(effect: StringName) -> void:
    """Removes a status effect from both short and long term lists."""
    if effect in short_term_statuses:
        short_term_statuses.erase(effect)
    if effect in long_term_statuses:
        long_term_statuses.erase(effect)


func add_trait(trait: StringName) -> void:
    """Registers a derived trait such as \"Goblin Slayer\" when conditions are met."""
    if trait in traits:
        return
    traits.append(trait)


func remove_trait(trait: StringName) -> void:
    """Clears a trait when its prerequisite stats are no longer satisfied."""
    if trait in traits:
        traits.erase(trait)


func apply_stat_mod(modifiers: Dictionary) -> void:
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
        for trait in modifiers["traits_to_add"]:
            add_trait(StringName(trait))

    if modifiers.has("traits_to_remove"):
        for trait in modifiers["traits_to_remove"]:
            remove_trait(StringName(trait))


func reset_for_new_run() -> void:
    """Resets per-run resources while preserving long-term progression."""
    if max_health > 0:
        health = max_health
    if max_energy > 0:
        energy = max_energy
    if max_action_points > 0:
        action_points = max_action_points
    short_term_statuses.clear()
