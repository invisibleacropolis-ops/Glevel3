extends System
class_name DebugSystem

## Simple system that prints entity statistics to the console each physics frame.
## Designed for Godot 4.4.1.

func _physics_process(delta: float) -> void:
    for entity in get_tree().get_nodes_in_group("entities"):
        var data: EntityData = entity.get("entity_data")
        if data and data.components.has("stats"):
            var stats: StatsComponent = data.components["stats"]
            print("%s HP: %d" % [entity.name, stats.health])
