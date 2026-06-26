class_name Milestone
extends Resource

enum Trigger {
	MONEY_TOTAL_EARNED,
	DIRT_TOTAL_DUG,
	UPGRADE_LEVEL,
}

@export var id: StringName = &""
@export var title: String = ""
@export var body: String = ""
@export var trigger: Trigger = Trigger.MONEY_TOTAL_EARNED
@export var threshold: float = 0.0
@export var upgrade_id: StringName = &""  # only used for UPGRADE_LEVEL
