extends "res://src/systems/System.gd"
class_name ValidationLoop

const ULTEnums = preload("res://src/globals/ULTEnums.gd")
const EntityData = preload("res://src/core/EntityData.gd")
const StatsComponent = preload("res://src/components/StatsComponent.gd")

func _physics_process(_delta: float) -> void:
    var entities = get_tree().get_nodes_in_group("entities")
    for entity in entities:
        var entity_data: EntityData = entity.get("entity_data")
        if entity_data == null:
            continue

        if entity_data.has_component(ULTEnums.ComponentKeys.STATS):
            var stats_component: StatsComponent = entity_data.get_component(ULTEnums.ComponentKeys.STATS)
            if stats_component != null:
                print("Entity: %s, Health: %d" % [entity.name, stats_component.health])
