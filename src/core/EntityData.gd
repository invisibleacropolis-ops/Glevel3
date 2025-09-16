extends Resource
class_name EntityData

const Enums := preload("res://src/globals/Enums.gd")

## The digital DNA of every object in the game world. This Resource acts as a
## manifest, linking an entity's identity to its modular data Components.
## Adherence to this data contract is critical for all systems.

## A unique identifier for this specific entity instance, persistent within a single World Run.
## Essential for saving, loading, and tracking specific entities for quests and narrative state.
@export var entity_id: String = ""

## The player-facing, in-game name of the entity (e.g., "Grak the Fierce").
@export var display_name: String = ""

## A broad category classification for high-level system filtering.
## See Enums.gd for possible values (e.g., EntityType.MONSTER).
@export var entity_type: Enums.EntityType = Enums.EntityType.NPC

## The unique ID that links to the base archetype resource used for this entity's generation.
## Crucial for informing AI behavior and other procedural systems.
@export var archetype_id: String = ""

## The core of the compositional design. This dictionary holds references to
## all attached Component Resources, keyed by a string identifier (e.g., "stats").
## Keys MUST correspond to the constants defined in Enums.gd (e.g., ComponentKeys.STATS).
@export var components: Dictionary = {}

## Registers or replaces a component using a canonical ComponentKeys identifier.
## Converts arbitrary string inputs to StringName before storage to ensure stable lookups.
func add_component(key: String, component: Component) -> void:
    assert(component != null, "EntityData.add_component requires a Component instance.")
    var normalized_key := _normalize_component_key(key)
    assert(
        Enums.is_valid_component_key(normalized_key),
        "Component key '%s' is not registered in Enums.ComponentKeys." % normalized_key,
    )
    var legacy_key := String(normalized_key)
    if components.has(legacy_key):
        components.erase(legacy_key)
    components[normalized_key] = component

## Retrieves a component reference by its canonical key.
## Returns null if the key is not registered on this entity.
func get_component(key: String) -> Component:
    var normalized_key := _normalize_component_key(key)
    var component := components.get(normalized_key, null)
    if component == null:
        component = components.get(String(normalized_key), null)
    return component as Component

## Reports whether a component has been assigned for the given canonical key.
func has_component(key: String) -> bool:
    var normalized_key := _normalize_component_key(key)
    return components.has(normalized_key) or components.has(String(normalized_key))

## Removes a component from the manifest and returns the detached resource.
## Returns null when no component was registered for the provided key.
func remove_component(key: String) -> Component:
    var normalized_key := _normalize_component_key(key)
    if components.has(normalized_key):
        var removed: Component = components.get(normalized_key)
        components.erase(normalized_key)
        return removed
    var legacy_key := String(normalized_key)
    if components.has(legacy_key):
        var removed_legacy: Component = components.get(legacy_key)
        components.erase(legacy_key)
        return removed_legacy
    return null

## Produces a shallow copy of the component manifest for safe iteration.
## External systems must treat the returned dictionary as read-only metadata.
func list_components() -> Dictionary:
    var manifest: Dictionary = {}
    for key in components.keys():
        var normalized := _normalize_component_key(key)
        manifest[normalized] = components[key]
    return manifest

func _normalize_component_key(raw_key: Variant) -> StringName:
    if raw_key is StringName:
        return raw_key
    return StringName(str(raw_key))
