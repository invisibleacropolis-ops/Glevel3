extends Node3D
class_name Entity

## Runtime node representing a spawned gameplay entity within the testbed.
## Wraps an EntityData manifest so systems can operate on canonical data while
## keeping the scene graph lightweight.
@export var entity_data: EntityData

## Canonical identifier for systems requiring stable lookups. Delegates to the
## EntityData runtime registry so every spawned instance receives a unique,
## persistent id within the current world run.
var entity_id: StringName:
        get:
                if entity_data != null and not entity_data.entity_id.is_empty():
                        return StringName(entity_data.entity_id)
                if has_meta("entity_id"):
                        var via_meta: Variant = get_meta("entity_id")
                        if via_meta is StringName:
                                return via_meta
                        if via_meta is String:
                                return StringName(via_meta)
                return StringName(name)

func _ready() -> void:
        """Registers the node with the canonical entities group for system discovery."""
        add_to_group("entities")
        if entity_data == null:
                push_warning("Entity node instantiated without EntityData. Assign a manifest before running systems.")
        _synchronise_entity_metadata()

func assign_entity_data(data: EntityData) -> void:
        """Applies ``data`` and refreshes cached metadata used by debug systems."""
        entity_data = data
        _synchronise_entity_metadata()

func get_entity_id() -> StringName:
        """Provides a stable identifier for systems that expect a node-level accessor."""
        return entity_id

func _synchronise_entity_metadata() -> void:
        var resolved_id: StringName
        if entity_data == null:
                if has_meta("entity_id"):
                        var via_meta: Variant = get_meta("entity_id")
                        if via_meta is StringName:
                                resolved_id = via_meta
                        elif via_meta is String:
                                resolved_id = StringName(via_meta)
                if resolved_id == StringName():
                        resolved_id = EntityData.generate_runtime_entity_id(StringName(name))
        else:
                resolved_id = entity_data.ensure_runtime_entity_id(StringName(name))
        set_meta("entity_id", resolved_id)
