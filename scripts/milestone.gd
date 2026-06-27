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

# Achievement-style permanent reward when this milestone fires.
# Effect is the same enum used by Upgrade. Amount is added to the player's effect total.
# Leave reward_effect alone (default CLICK_DIRT) and reward_amount=0 for story-only milestones.
@export var reward_effect: Upgrade.Effect = Upgrade.Effect.CLICK_DIRT
@export var reward_amount: float = 0.0
@export var reward_text: String = ""  # short tag like "+5s day" shown in the toast
