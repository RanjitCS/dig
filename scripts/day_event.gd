class_name DayEvent
extends Resource

# A "special day" modifier. Rolled rarely at the start of a day, announced to the
# player in the morning, and applied for that whole day only. Cleared next day.

enum Category {
	GOOD,    # pure upside — a lucky day
	RISKY,   # more danger for more reward
	COZY,    # atmosphere / story; little or no mechanical change
	TOUGH,   # harder with no bonus — friction; use sparingly
}

@export var id: StringName = &""
@export var title: String = ""
@export var description: String = ""        # morning-announce body (placeholder copy)
@export var category: Category = Category.GOOD
@export var weight: float = 1.0             # relative chance GIVEN a special day fires

# --- Typed modifiers (read by GameState / dig_world). Neutral defaults = no-op. ---
# Multiplies the day's sell value (lucky market, etc.).
@export var money_mult: float = 1.0
# Scales the spawn weight of money-bearing ore blocks this day (rich vein).
@export var ore_weight_mult: float = 1.0
# Overrides the cave-in crumble chance for the day. <0 means "no override".
@export var crumble_chance: float = -1.0
# Scales the day length (storm = shorter, still air = longer).
@export var day_length_mult: float = 1.0
# A non-dig day (cozy/flavor). The dig is skipped; the day is about the morning beat.
@export var no_dig: bool = false

func category_color() -> Color:
	match category:
		Category.GOOD:
			return Color(0.55, 0.82, 0.45)   # green
		Category.RISKY:
			return Color(0.88, 0.55, 0.28)   # amber
		Category.COZY:
			return Color(0.62, 0.74, 0.90)   # soft blue
		Category.TOUGH:
			return Color(0.80, 0.40, 0.38)   # dull red
	return Color(0.85, 0.82, 0.72)
