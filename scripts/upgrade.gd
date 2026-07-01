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
	JUMP_VELOCITY_BONUS,  # extra upward jump speed (px/s) per level; e.g. rocket boots
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

# Tool mechanics (only meaningful when is_equippable=true).
# These are the BASE (tier 0) values. If tier arrays below are populated,
# they override per-level.
@export var tool_damage: int = 1
@export var tool_cooldown_sec: float = 0.15
@export var tool_aoe: bool = false
@export var tool_column_only: bool = false

# Tier chain (optional). When non-empty, each index = a named tier with its own stats.
# tier_names[i] is the display name when the player is at level i.
# tier_flavors[i] is the flavor text. Stats arrays are read at level i.
# If a stats array is shorter than tier_names, it falls back to the base value.
@export var tier_names: PackedStringArray = []
@export var tier_flavors: PackedStringArray = []
@export var tier_damage: PackedInt32Array = []
@export var tier_cooldown: PackedFloat32Array = []

func cost_at(level: int) -> float:
	return base_cost * pow(cost_mult, level)

func is_maxed(level: int) -> bool:
	if max_level <= 0:
		return false
	return level >= max_level

func has_tiers() -> bool:
	return tier_names.size() > 0

func tier_name_at(level: int) -> String:
	if level >= 0 and level < tier_names.size():
		return tier_names[level]
	return display_name

func tier_flavor_at(level: int) -> String:
	if level >= 0 and level < tier_flavors.size():
		return tier_flavors[level]
	return flavor

func damage_at(level: int) -> int:
	if level >= 0 and level < tier_damage.size():
		return tier_damage[level]
	return tool_damage

func cooldown_at(level: int) -> float:
	if level >= 0 and level < tier_cooldown.size():
		return tier_cooldown[level]
	return tool_cooldown_sec
