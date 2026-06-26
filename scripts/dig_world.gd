extends Node2D

const BlockScene := preload("res://scenes/block.tscn")
const GRID_COLS: int = 12
const ROWS_AHEAD: int = 30
const BLOCK_DIR: String = "res://resources/blocks/"
const BLOCK_SIZE: Vector2 = Vector2(48, 48)
const SURFACE_HEIGHT_PX: float = 96.0

@onready var surface_visual: Node2D = $Surface
@onready var grid_root: Node2D = $Grid
@onready var player: Player = $Player

var block_types: Array[BlockType] = []
var rng := RandomNumberGenerator.new()
var generated_rows: int = 0
var blocks_by_pos: Dictionary = {}  # Vector2i -> DigBlock
var broken_cells: Dictionary = {}   # Vector2i -> true

signal deepest_changed(row: int)

func _ready() -> void:
	rng.randomize()
	_load_block_types()
	_generate_rows(ROWS_AHEAD)
	_pre_break_starting_gap()
	_spawn_player_at_surface()
	GameState.day_started.connect(_on_day_started)

func _spawn_player_at_surface() -> void:
	# Stand on the surface, centered horizontally over the grid.
	var grid_center_x := (GRID_COLS * BLOCK_SIZE.x) * 0.5
	# Surface floor top is y = -2 (a 4px thick body centered at -2). Player half-height ~22.
	player.reset_to(Vector2(grid_center_x, -24))

func _on_day_started(_day: int) -> void:
	_spawn_player_at_surface()

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
	for col in GRID_COLS:
		var type := _pick_block_type_for_depth(row)
		if type == null:
			continue
		var block: DigBlock = BlockScene.instantiate()
		block.setup(type, Vector2i(col, row))
		# Block origin is its CENTER. Position so block tops align with row baseline.
		block.position = Vector2(
			col * BLOCK_SIZE.x + BLOCK_SIZE.x * 0.5,
			(row - 1) * BLOCK_SIZE.y + BLOCK_SIZE.y * 0.5
		)
		grid_root.add_child(block)
		block.click_requested.connect(_on_block_click_requested)
		block.broken.connect(_on_block_broken)
		blocks_by_pos[Vector2i(col, row)] = block

func _pre_break_starting_gap() -> void:
	var center_col: int = GRID_COLS / 2
	var pos := Vector2i(center_col, 1)
	var block: DigBlock = blocks_by_pos.get(pos, null)
	if block != null:
		_remove_block(block, false)

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
	if pos.y <= 0:
		return true
	if pos.x < 0 or pos.x >= GRID_COLS:
		return false
	return broken_cells.has(pos)

func is_reachable(pos: Vector2i, reach: int) -> bool:
	if not blocks_by_pos.has(pos):
		return false
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
	return is_broken(Vector2i(pos.x, pos.y - 1))

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
	if reach == Upgrade.Reach.AOE_3X3:
		_hit_aoe(block.grid_pos)
	else:
		block.hit_once()

# Player-driven dig: targeted at a specific grid cell adjacent to the player.
# Bypasses the click-reach rules since physical proximity is the new reach.
func try_dig_at(grid_pos: Vector2i) -> bool:
	if GameState.day_paused:
		print("[world] try_dig_at(", grid_pos, "): day paused")
		return false
	if GameState.backpack_full():
		print("[world] try_dig_at(", grid_pos, "): backpack full")
		return false
	var block: DigBlock = blocks_by_pos.get(grid_pos, null)
	if block == null:
		var neighbors: Array = []
		for o in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var p: Vector2i = grid_pos + o
			neighbors.append("%s=%s" % [str(p), "yes" if blocks_by_pos.has(p) else "no"])
		print("[world] try_dig_at(", grid_pos, "): no block. neighbors: ", neighbors)
		return false
	block.hit_once()
	return true

func world_pos_to_grid(world_pos: Vector2) -> Vector2i:
	# Block origins are at (col * SIZE + SIZE/2, (row-1) * SIZE + SIZE/2).
	# Row 1 occupies y = 0 to SIZE.y; row 2 occupies SIZE.y to 2*SIZE.y; etc.
	var col := int(floor(world_pos.x / BLOCK_SIZE.x))
	var row := int(floor(world_pos.y / BLOCK_SIZE.y)) + 1
	return Vector2i(col, row)

func _hit_aoe(center: Vector2i) -> void:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var p := center + Vector2i(dx, dy)
			var b: DigBlock = blocks_by_pos.get(p, null)
			if b != null:
				b.hit_once()

func _nudge_block(block: DigBlock) -> void:
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
