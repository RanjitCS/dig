class_name Upgrade
extends Resource

enum Effect {
	CLICK_DIRT,
	CLICK_MONEY_MULT,
	CRIT_CHANCE,
	AUTO_DIRT_PER_SEC,
	AUTO_MONEY_PER_SEC,
	DAY_LENGTH_SEC,
	BACKPACK_CAPACITY,
}

enum Reach {
	CARDINAL_4,
	OMNI_8,
	COLUMN_DOWN,
	AOE_3X3,
}

enum Category {
	TOOLS,
	FAMILY,
	ARYA,
	LAND,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var flavor: String = ""
@export var category: Category = Category.TOOLS
@export var effect: Effect = Effect.CLICK_DIRT
@export var effect_per_level: float = 1.0
@export var base_cost: float = 10.0
@export var cost_mult: float = 1.15
@export var cost_currency: StringName = &"money"
@export var unlock_money: float = 0.0
@export var reach: Reach = Reach.CARDINAL_4
@export var is_equippable: bool = true
@export var max_level: int = 0  # 0 = infinite

func cost_at(level: int) -> float:
	return base_cost * pow(cost_mult, level)

func is_maxed(level: int) -> bool:
	if max_level <= 0:
		return false
	return level >= max_level
