class_name Helper
extends Resource

# A hired/family helper that digs passively into the deposit pile.
# Production runs during DIGGING and accrues (capped) while away.
# Narrative: each helper is a person who came to help him — automation = the
# family coming back into his life. See project_dig_gameplay_expansion.md.

@export var id: StringName = &""
@export var display_name: String = ""
@export var flavor: String = ""

# Production per second, per level owned.
@export var dirt_per_sec: float = 0.0
# Ore production: this helper digs this ore type at ore_per_sec (0 = no ore).
@export var ore_id: StringName = &""
@export var ore_per_sec: float = 0.0

# Cost curve (money). cost_at(level) = base_cost * cost_mult^level.
@export var base_cost: float = 100.0
@export var cost_mult: float = 1.25
@export var max_level: int = 0  # 0 = infinite

# Visibility gate — only offered once the player has earned this much total.
@export var unlock_money: float = 0.0

func cost_at(level: int) -> float:
	return base_cost * pow(cost_mult, level)

func is_maxed(level: int) -> bool:
	if max_level <= 0:
		return false
	return level >= max_level
