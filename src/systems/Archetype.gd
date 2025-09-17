extends Resource
class_name Archetype

## Resource describing an entity archetype used by procedural generation.
## Archetypes define base stats and the trait pool compatible with the entity.
## Instances are saved as ``Archetype.tres`` files and consumed during the
## "Archetype Selection" phase to seed generators with safe trait combinations.
## Designed for Godot 4.4.1.

@export var archetype_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var base_stats: Dictionary = {}
## Arrays accept ``Trait`` resources; they are typed as ``Resource`` so the
## parser tolerates load-order issues when custom classes are still being
## registered by the editor.
@export var required_traits: Array[Resource] = []
@export var trait_pool: Array[Resource] = []

## Returns all traits that the archetype explicitly allows. Required traits are
## always positioned ahead of optional entries while duplicates (matched by
## ``trait_id``) are removed to keep the payload stable for downstream systems.
func get_all_traits() -> Array:
    var combined: Array = []
    var seen_ids: Dictionary = {}
    _append_unique_traits(combined, required_traits, seen_ids)
    _append_unique_traits(combined, trait_pool, seen_ids)
    return combined

## Determines if a specific trait resource is compatible with the archetype.
## Invalid inputs (``null`` or missing identifiers) are rejected before
## searching the combined list to avoid nil dereferences in consuming systems.
func is_trait_allowed(trait_resource: Resource) -> bool:
    if not _is_trait_resource_valid(trait_resource):
        return false
    var trait_id := _get_trait_id(trait_resource)
    if trait_id == "":
        return false

    var allowed_traits: Array = get_all_traits()
    var index := 0
    while index < allowed_traits.size():
        var allowed_id := _get_trait_id(allowed_traits[index])
        if allowed_id != "" and allowed_id == trait_id:
            return true
        index += 1
    return false

## Validates that a trait component satisfies the archetype rules. The
## component must expose all required trait identifiers and may not advertise
## traits outside of the archetype's combined pool. Any null or malformed
## entries are rejected to maintain the integrity of entity data resources.
func validate_component(component) -> bool:
    if component == null:
        return false

    if not component.has_method("has_trait_id"):
        return false

    var raw_component_traits = component.get("traits")
    if typeof(raw_component_traits) != TYPE_ARRAY:
        return false
    var component_traits: Array = raw_component_traits

    var allowed_traits: Array = get_all_traits()
    var allowed_trait_ids: Dictionary = _collect_trait_id_lookup(allowed_traits)

    var index := 0
    while index < required_traits.size():
        var required_trait_id := _get_trait_id(required_traits[index])
        if required_trait_id == "":
            return false
        if not component.has_trait_id(required_trait_id):
            return false
        index += 1

    index = 0
    while index < component_traits.size():
        var trait_resource = component_traits[index]
        var trait_id := _get_trait_id(trait_resource)
        if trait_id == "":
            return false
        if not allowed_trait_ids.has(trait_id):
            return false
        index += 1

    return true

## Helper that copies valid, non-duplicate traits from ``source`` into
## ``target`` while preserving order. ``seen_ids`` tracks identifiers already
## appended to the target array so optional traits do not overwrite required
## selections.
func _append_unique_traits(target: Array, source: Array, seen_ids: Dictionary) -> void:
    var index := 0
    while index < source.size():
        var trait_resource = source[index]
        if _is_trait_resource_valid(trait_resource):
            var trait_id := _get_trait_id(trait_resource)
            if trait_id != "" and not seen_ids.has(trait_id):
                target.append(trait_resource)
                seen_ids[trait_id] = true
        index += 1

## Builds a dictionary keyed by ``trait_id`` for fast membership checks against
## the archetype's combined trait list.
func _collect_trait_id_lookup(traits: Array) -> Dictionary:
    var lookup: Dictionary = {}
    var index := 0
    while index < traits.size():
        var trait_id := _get_trait_id(traits[index])
        if trait_id != "":
            lookup[trait_id] = true
        index += 1
    return lookup

## Extracts a non-empty identifier from a trait resource or returns an
## empty string when the input is invalid. The helper relies on the
## ``trait_id`` export defined by ``Trait.gd`` but falls back safely if the
## property is missing or stored as a ``StringName``.
func _get_trait_id(trait_resource: Object) -> String:
    if trait_resource == null or not (trait_resource is Object):
        return ""

    var raw_id = trait_resource.get("trait_id")
    if raw_id == null:
        return ""

    var id_type := typeof(raw_id)
    if id_type == TYPE_STRING or id_type == TYPE_STRING_NAME:
        var id_string := String(raw_id)
        if id_string.is_empty():
            return ""
        return id_string

    return ""

## Returns ``true`` when the provided resource is a valid trait definition.
func _is_trait_resource_valid(trait_resource) -> bool:
    if trait_resource == null:
        return false
    if not (trait_resource is Resource):
        return false
    if not trait_resource.has_method("get"):
        return false
    return _get_trait_id(trait_resource) != ""
