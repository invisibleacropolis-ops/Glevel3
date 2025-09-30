# EventBus Signal Reference

The `EventBus` autoload centralizes all cross-system communication. Every signal it exposes accepts a single `Dictionary` payload. The contract for that payload is validated at runtime, so downstream systems can rely on the documented keys and types when reacting to events.

Each section below summarizes the contract enforced in [`src/globals/EventBus.gd`](../src/globals/EventBus.gd) and surfaces the description authored alongside the signal definition.

## `debug_stats_reported`

Telemetry broadcast emitted whenever `DebugSystem` captures a snapshot of an entity's `StatsComponent` for diagnostics.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `entity_id` | `String` or `StringName` | Required | Unique identifier for the reported entity. |
| `stats` | `Dictionary` | Required | Snapshot of the entity's statistics (e.g., `health`, `action_points`). |
| `timestamp` | `float` | Optional | Monotonic timestamp indicating when the sample was captured. |

## `entity_killed`

CombatSystem notification that an entity has been removed from play. Downstream systems such as quests, loot, or meta-narrative modules react to this signal to update their state.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `entity_id` | `String` or `StringName` | Required | Identifier of the defeated entity. |
| `killer_id` | `String` or `StringName` | Optional | Identifier of the killer, if known. |
| `archetype_id` | `String` or `StringName` | Optional | Source archetype for postmortem analytics. |
| `entity_type` | `StringName` | Optional | High-level taxonomy from component enums. |
| `components` | `Dictionary` | Optional | Snapshot of relevant Components for downstream systems. |

## `combat_encounter_started`

`CombatTimer` broadcast emitted when an encounter opens and the initiative queue seeds its participants.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `participants` | `Array[StringName]` | Required | Ordered identifiers for combatants entering the encounter. |
| `encounter_id` | `String` or `StringName` | Optional | Author-provided identifier for analytics or scripted lookups. |

## `combat_round_started`

`CombatTimer` broadcast emitted at the start of each new combat round after the initiative queue advances.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `round` | `int` | Required | The 1-indexed combat round that just began. |
| `queue_snapshot` | `Array[Dictionary]` | Optional | Frozen initiative order for UI overlays or AI planning. |

## `combat_turn_started`

`CombatTimer` broadcast emitted when the next combatant becomes active.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `entity_id` | `String` or `StringName` | Required | Identifier for the acting combatant. |
| `round` | `int` | Required | Combat round currently in progress. |
| `initiative` | `int` | Required | Initiative score or rank assigned to the combatant this round. |
| `turn_index` | `int` | Optional | Zero-based index of the turn within the round for deterministic playback. |
| `queue_snapshot` | `Array[Dictionary]` | Optional | Initiative queue as recalculated for this turn. |

## `combat_turn_ready_for_action`

`CombatTimer` broadcast emitted once the active combatant's turn has fully initialized and downstream systems may resolve actions. Payload mirrors `combat_turn_started`.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `entity_id` | `String` or `StringName` | Required | Identifier for the acting combatant. |
| `round` | `int` | Required | Combat round currently executing. |
| `initiative` | `int` | Required | Initiative score for the acting combatant. |
| `turn_index` | `int` | Optional | Zero-based index of the turn within the round. |
| `queue_snapshot` | `Array[Dictionary]` | Optional | Initiative queue as recalculated for this action window. |

## `combat_turn_completed`

`CombatTimer` broadcast emitted after the active combatant finishes acting and cleanup has completed.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `entity_id` | `String` or `StringName` | Required | Identifier for the combatant whose turn concluded. |
| `round` | `int` | Required | Combat round during which the turn ended. |
| `results` | `Dictionary` | Optional | Aggregated outcome data such as damage dealt or status effects applied. |

## `combat_queue_rebuilt`

`CombatTimer` broadcast emitted whenever the initiative queue is rebuilt.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `round` | `int` | Required | Combat round the rebuilt queue applies to. |
| `queue_snapshot` | `Array[Dictionary]` | Required | Ordered initiative entries ready for UI or AI consumers. |

## `combat_encounter_ended`

`CombatTimer` broadcast emitted when an encounter resolves and downstream systems need to react to the final state.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `outcome` | `StringName` | Required | Encounter resolution classification (for example, `&"victory"`, `&"defeat"`). |
| `summary` | `Dictionary` | Required | Aggregated encounter data for rewards, analytics, or scripting. |
| `winning_team` | `StringName` | Optional | Identifier for the victorious team when applicable. |

## `combat_initiative_modified`

`CombatTimer` broadcast emitted whenever a combatant's initiative value changes during an encounter.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `entity_id` | `String` or `StringName` | Required | Identifier for the combatant whose initiative shifted. |
| `delta` | `int` | Required | Signed change applied to the initiative score. |
| `source` | `StringName` | Required | System or effect responsible for the adjustment. |
| `remaining_turns` | `int` | Optional | Number of turns the modification will persist when duration-based. |

## `item_acquired`

Inventory or loot system broadcast whenever an entity adds an item stack to its inventory.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `item_id` | `String` or `StringName` | Required | Identifier of the acquired item resource. |
| `quantity` | `int` | Required | Number of units added to the stack. |
| `owner_id` | `String` or `StringName` | Optional | Identifier of the receiving entity. |
| `source` | `StringName` | Optional | Origin of the acquisition (e.g., `loot_drop`, `vendor_purchase`). |
| `metadata` | `Dictionary` | Optional | Arbitrary supplemental data for UI, analytics, or logging. |

## `quest_state_changed`

QuestSystem update describing a quest's latest lifecycle state transition.

| Key | Type(s) | Requirement | Description |
| --- | --- | --- | --- |
| `quest_id` | `String` or `StringName` | Required | Identifier of the quest resource or runtime instance. |
| `state` | `StringName` | Required | New quest state (for example, `&"in_progress"`, `&"completed"`). |
| `progress` | `float` | Optional | Normalized progress value between `0.0` and `1.0`. |
| `objectives` | `Array` | Optional | Collection of objective payload dictionaries for UI updates. |
| `metadata` | `Dictionary` | Optional | Arbitrary contextual data for analytics or notifications. |

## Usage patterns

### Emitting a signal

```gdscript
func award_loot(entity_id: StringName, item_id: StringName, quantity: int) -> void:
    var payload := {
        "item_id": item_id,
        "quantity": quantity,
        "owner_id": entity_id,
        "source": &"quest_reward",
    }
    EventBus.emit_signal(&"item_acquired", payload)
```

### Subscribing to a signal

```gdscript
func _ready() -> void:
    EventBus.item_acquired.connect(_on_item_acquired)

func _on_item_acquired(data: Dictionary) -> void:
    var owner: StringName = data["owner_id"]
    var count: int = data["quantity"]
    print("%s gained %d items" % [owner, count])
```

The subscription pattern above ensures that only validated payloads reach `_on_item_acquired`, allowing the handler to interact with strongly typed data without redundant checks. Disconnect from the signal in `_exit_tree()` when the listener should stop receiving updates.
