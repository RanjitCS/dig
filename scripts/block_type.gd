class_name BlockType
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var color: Color = Color(0.4, 0.3, 0.2)
@export var texture: Texture2D  # single texture; fallback to color rect if null
# Optional variant textures. When non-empty, a block picks one at random per
# spawn to break grid repetition. Falls back to `texture`, then the color rect.
@export var textures: Array[Texture2D] = []
@export var hits_to_break: int = 1
@export var dirt_yield: float = 1.0
@export var money_yield: float = 0.0
@export var min_depth: int = 1
@export var max_depth: int = 99999
@export var weight: float = 1.0
@export var indestructible: bool = false

# --- Hazard behaviour ------------------------------------------------------
# A loose block: when the cell directly beneath it becomes empty, it shudders
# briefly then falls until it lands on something solid, re-blocking the shaft.
# Cascades if loose blocks stack. Never damages the player (time-cost only).
@export var unstable: bool = false
# Rich reward pocket. Spawned in small clusters, biased next to unstable rock so
# the payoff sits behind the cave-in risk. Purely a tagging flag for generation.
@export var is_ore_pocket: bool = false

# Returns a texture to display: a random variant if any, else the single
# texture, else null (caller draws the colored rect fallback).
func pick_texture() -> Texture2D:
	if textures.size() > 0:
		return textures[randi() % textures.size()]
	return texture
