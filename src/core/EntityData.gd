extends Resource
class_name EntityData

const ULTEnums := preload("res://src/globals/ULTEnums.gd")
## Tracks manifest keys that have already reported invalid component payloads so we
## do not spam logs when the same corrupted entry is queried repeatedly.
var _invalid_component_warnings: Dictionary[String, bool] = {}

## The digital DNA of every object in the game world. This Resource acts as a
## manifest, linking an entity's identity to its modular data Components.
## Adherence to this data contract is critical for all systems.

## A unique identifier for this specific entity instance, persistent within a single World Run.
## Essential for saving, loading, and tracking specific entities for quests and narrative state.
@export var entity_id: String = ""

## The player-facing, in-game name of the entity (e.g., "Grak the Fierce").
@export var display_name: String = ""

## A broad category classification for high-level system filtering.
## See ULTEnums.gd for possible values (e.g., EntityType.MONSTER).
@export var entity_type: ULTEnums.EntityType = ULTEnums.EntityType.NPC

## The unique ID that links to the base archetype resource used for this entity's generation.
## Crucial for informing AI behavior and other procedural systems.
@export var archetype_id: String = ""

## The core of the compositional design. This dictionary holds references to
## all attached Component Resources, keyed by a canonical StringName identifier
## (e.g., ComponentKeys.STATS).
## Keys MUST correspond to the constants defined in ULTEnums.gd (e.g., ComponentKeys.STATS).
var _components: Dictionary[StringName, Component] = {}

## Exposed manifest of component resources keyed by canonical identifiers.
##
## The exported dictionary is now strongly typed so the Inspector knows each
## value expects a Component resource, enabling drag-and-drop authoring from the
## FileSystem dock. The internal `_components` cache still normalises keys to
## `StringName` for stable lookups while tolerating legacy manifest data. The
## getter exposes the live manifest so existing editor tooling and tests that
## expect direct dictionary access continue to function.
@export var components: Dictionary[StringName, Component] = {}:
    set(value):
        _invalid_component_warnings.clear()
        _components = _sanitize_component_manifest(value)
    get:
        return _components

## Registers or replaces a component using a canonical ComponentKeys identifier.
## Converts arbitrary string inputs to StringName before storage to ensure stable lookups.
func add_component(key: Variant, component: Resource) -> void:
    assert(component != null, "EntityData.add_component requires a Component instance.")
    assert(
        _is_component_resource(component),
        "EntityData.add_component only accepts resources derived from Component.",
    )
    var normalized_key: StringName = _normalize_component_key(key)
    assert(
        ULTEnums.is_valid_component_key(normalized_key),
        "Component key '%s' is not registered in ULTEnums.ComponentKeys." % normalized_key,
    )
    _components.erase(normalized_key)
    _components[normalized_key] = component
    var legacy_key := String(normalized_key)
    _invalid_component_warnings.erase(legacy_key)

## Retrieves a component reference by its canonical key.
## Returns null if the key is not registered on this entity.
func get_component(key: Variant) -> Resource:
    var normalized_key: StringName = _normalize_component_key(key)
    if not ULTEnums.is_valid_component_key(normalized_key):
        return null
    var lookup := _locate_component_entry(normalized_key)
    var component = lookup.get("component")
    if component == null:
        return null
    if _is_component_resource(component):
        return component
    _report_invalid_component_type(normalized_key, component)
    return null

## Reports whether a component has been assigned for the given canonical key.
func has_component(key: Variant) -> bool:
    var normalized_key: StringName = _normalize_component_key(key)
    if not ULTEnums.is_valid_component_key(normalized_key):
        return false
    var lookup := _locate_component_entry(normalized_key)
    var component = lookup.get("component")
    if component == null:
        return false
    if _is_component_resource(component):
        return true
    _report_invalid_component_type(normalized_key, component)
    return false

## Removes a component from the manifest and returns the detached resource.
## Returns null when no component was registered for the provided key.
func remove_component(key: Variant) -> Resource:
    var normalized_key: StringName = _normalize_component_key(key)
    if not ULTEnums.is_valid_component_key(normalized_key):
        return null
    var lookup := _locate_component_entry(normalized_key)
    if lookup.get("component") == null:
        return null
    _components.erase(lookup.get("key"))
    if _is_component_resource(lookup.get("component")):
        return lookup.get("component")
    _report_invalid_component_type(normalized_key, lookup.get("component"))
    return null

## Produces a shallow copy of the component manifest for safe iteration.
## External systems must treat the returned dictionary as read-only metadata.
func list_components() -> Dictionary[StringName, Component]:
    var manifest: Dictionary[StringName, Component] = {}
    for key in _components.keys():
        var normalized: StringName = _normalize_component_key(key)
        if not ULTEnums.is_valid_component_key(normalized):
            continue
        var lookup := _locate_component_entry(normalized)
        var component = lookup.get("component")
        if _is_component_resource(component):
            manifest[normalized] = component
        elif component != null:
            _report_invalid_component_type(normalized, component)
    return manifest

func _normalize_component_key(raw_key: Variant) -> StringName:
    if raw_key is StringName:
        return raw_key
    return StringName(str(raw_key))

func _locate_component_entry(normalized_key: StringName) -> Dictionary:
    var entry: Dictionary = {
        "component": null,
        "key": null,
    }
    if _components.has(normalized_key):
        entry["component"] = _components.get(normalized_key)
        entry["key"] = normalized_key
    return entry

func _sanitize_component_manifest(raw_value: Variant) -> Dictionary[StringName, Component]:
    var sanitized: Dictionary[StringName, Component] = {}
    if raw_value == null:
        return sanitized
    if not (raw_value is Dictionary):
        push_warning("EntityData: components export expected a Dictionary but received %s." % type_string(typeof(raw_value)))
        return sanitized
    for key in raw_value.keys():
        var normalized_key := _normalize_component_key(key)
        if normalized_key == StringName():
            continue
        var value: Variant = raw_value.get(key)
        if value == null:
            continue
        if _is_component_resource(value):
            sanitized[normalized_key] = value
        else:
            _report_invalid_component_type(normalized_key, value)
    return sanitized

func _report_invalid_component_type(normalized_key: StringName, value: Variant) -> void:
    var key_string := String(normalized_key)
    if _invalid_component_warnings.get(key_string, false):
        return
    _invalid_component_warnings[key_string] = true
    var value_description := "null"
    if value != null:
        value_description = type_string(typeof(value))
    push_error(
        "EntityData manifest entry '%s' stores %s instead of a Component resource." % [
            key_string,
            value_description,
        ]
    )

## Returns true when the supplied value is a Component resource instance.
func _is_component_resource(candidate: Variant) -> bool:
    return candidate is Component
