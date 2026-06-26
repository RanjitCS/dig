class_name Upgrade
extends Resource

enum Effect {
	CLICK_DIRT,
	CLICK_MONEY_MULT,
	CRIT_CHANCE,
	AUTO_DIRT_PER_SEC,
	AUTO_MONEY_PER_SEC,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var flavor: String = ""
@export var effect: Effect = Effect.CLICK_DIRT
@export var effect_per_level: float = 1.0
@export var base_cost: float = 10.0
@export var cost_mult: float = 1.15
@export var cost_currency: StringName = &"money"  # "money" or "dirt"
@export var unlock_money: float = 0.0  # min money ever earned before this is visible

func cost_at(level: int) -> float:
	return base_cost * pow(cost_mult, level)
