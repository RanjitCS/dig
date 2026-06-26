extends Control

const BlockScene := preload("res://scenes/block.tscn")
const GRID_COLS: int = 12
const ROWS_AHEAD: int = 30
const BLOCK_DIR: String = "res://resources/blocks/"

@onready var surface: ColorRect = %Surface
@onready var grid: Control = %Grid

var block_types: Array[BlockType] = []
var rng := RandomNumberGenerator.new()
var generated_rows: int = 0
var blocks_by_pos: Dictionary = {}  # Vector2i -> DigBlock
var broken_cells: Dictionary = {}   # Vector2i -> true (also includes "above-surface" sentinels)

signal deepest_changed(row: int)

func _ready() -> void:
	rng.randomize()
	_load_block_types()
	_generate_rows(ROWS_AHEAD)
	_pre_break_starting_gap()

func _load_block_types() -> void:
	block_types.clear()
	var dir := DirAccess.open(BLOCK_DIR)
	if dir == null:
		push_error("Could not open " + BLOCK_DIR)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(BLOCK_DIR + file)
			if res is BlockType:
				block_types.append(res)
		file = dir.get_next()
	dir.list_dir_end()

func _generate_rows(count: int) -> void:
	for i in count:
		_generate_row(generated_rows + 1)
		generated_rows += 1

func _generate_row(row: int) -> void:
	# Row 0 is the surface line (all "broken"/air conceptually — see is_broken).
	for col in GRID_COLS:
		var type := _pick_block_type_for_depth(row)
		if type == null:
			continue
		var block: DigBlock = BlockScene.instantiate()
		block.setup(type, Vector2i(col, row))
		block.position = Vector2(col * DigBlock.SIZE.x, (row - 1) * DigBlock.SIZE.y)
		grid.add_child(block)
		block.click_requested.connect(_on_block_click_requested)
		block.broken.connect(_on_block_broken)
		blocks_by_pos[Vector2i(col, row)] = block

func _pre_break_starting_gap() -> void:
	var center_col: int = GRID_COLS / 2
	var pos := Vector2i(center_col, 1)
	var block: DigBlock = blocks_by_pos.get(pos, null)
	if block != null:
		_remove_block(block, false)
	# Note: surface (row 0) is implicitly broken for adjacency purposes — see is_broken.

func _pick_block_type_for_depth(depth: int) -> BlockType:
	var candidates: Array = []
	var total_weight := 0.0
	for t in block_types:
		if depth >= t.min_depth and depth <= t.max_depth:
			candidates.append(t)
			total_weight += t.weight
	if candidates.is_empty() or total_weight <= 0.0:
		return null
	var roll := rng.randf() * total_weight
	var accum := 0.0
	for t in candidates:
		accum += t.weight
		if roll <= accum:
			return t
	return candidates[candidates.size() - 1]

# --- Adjacency / reach -----------------------------------------------------

func is_broken(pos: Vector2i) -> bool:
	# Anything at row 0 or above is implicit air.
	if pos.y <= 0:
		return true
	# Anything outside the grid columns is treated as wall (impassable).
	if pos.x < 0 or pos.x >= GRID_COLS:
		return false
	return broken_cells.has(pos)

func is_reachable(pos: Vector2i, reach: int) -> bool:
	if not blocks_by_pos.has(pos):
		return false  # already broken or never existed
	match reach:
		Upgrade.Reach.CARDINAL_4:
			return _has_broken_neighbor(pos, false)
		Upgrade.Reach.OMNI_8:
			return _has_broken_neighbor(pos, true)
		Upgrade.Reach.COLUMN_DOWN:
			return _has_broken_above(pos)
		Upgrade.Reach.AOE_3X3:
			return _has_broken_neighbor(pos, false)
	return false

func _has_broken_neighbor(pos: Vector2i, include_diagonals: bool) -> bool:
	var offsets := [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)
	]
	if include_diagonals:
		offsets.append_array([
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
		])
	for o in offsets:
		if is_broken(pos + o):
			return true
	return false

func _has_broken_above(pos: Vector2i) -> bool:
	# Any broken cell in the same column above this one — straight column dig.
	if is_broken(Vector2i(pos.x, pos.y - 1)):
		return true
	return false

# --- Click handling --------------------------------------------------------

func _on_block_click_requested(block: DigBlock) -> void:
	if GameState.day_paused:
		return
	if GameState.backpack_full():
		_nudge_block(block)
		return
	var reach: int = GameState.equipped_reach()
	if not is_reachable(block.grid_pos, reach):
		_nudge_block(block)
		return
	# Valid target. Apply tool damage.
	if reach == Upgrade.Reach.AOE_3X3:
		_hit_aoe(block.grid_pos)
	else:
		block.hit_once()

func _hit_aoe(center: Vector2i) -> void:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var p := center + Vector2i(dx, dy)
			var b: DigBlock = blocks_by_pos.get(p, null)
			if b != null:
				b.hit_once()

func _nudge_block(block: DigBlock) -> void:
	# Tiny shake to signal "can't reach this."
	var orig := block.position
	var tw := create_tween()
	tw.tween_property(block, "position", orig + Vector2(-3, 0), 0.04)
	tw.tween_property(block, "position", orig + Vector2(3, 0), 0.06)
	tw.tween_property(block, "position", orig, 0.04)

# --- Block lifecycle -------------------------------------------------------

func _remove_block(block: DigBlock, award_yields: bool) -> void:
	broken_cells[block.grid_pos] = true
	blocks_by_pos.erase(block.grid_pos)
	if award_yields:
		_award_yields_for(block.block_type)
	_maybe_extend_world(block.grid_pos.y)
	block.queue_free()

func _on_block_broken(block: DigBlock) -> void:
	_remove_block(block, true)

func _award_yields_for(type: BlockType) -> void:
	var crit_chance := GameState._sum_effect(Upgrade.Effect.CRIT_CHANCE)
	var crit := 1.0
	if crit_chance > 0.0 and randf() < crit_chance:
		crit = 5.0
	var money_mult := 1.0 + GameState._sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)
	GameState._add_dirt(type.dirt_yield * crit)
	if type.money_yield > 0.0:
		GameState._add_money(type.money_yield * crit * money_mult)

func _maybe_extend_world(broken_row: int) -> void:
	var target := broken_row + ROWS_AHEAD
	if target > generated_rows:
		_generate_rows(target - generated_rows)
	deepest_changed.emit(broken_row)
