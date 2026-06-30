extends Node2D

const BlockScene := preload("res://scenes/block.tscn")
const GRID_COLS: int = 32
# Layout: house on the LEFT, deposit station in the middle, the dig MOUTH on the
# right of the house. The player exits the back door and digs straight DOWN through
# a narrow neck; below the surface the diggable region flares open into a wide
# cavern (a "bottle" shape) whose left wall reaches back UNDER the house footprint.
const HOUSE_COL_START: int = 2
const HOUSE_COL_END: int = 8
# --- Bottle profile (see _dig_span_for_row) -------------------------------
# Neck: a narrow vertical shaft the player digs down through.
const NECK_COL_LO: int = 13       # inclusive
const NECK_COL_HI: int = 16       # inclusive (4 wide)
const NECK_ROWS: int = 4          # rows 1..4 stay neck-width
# Cavern body: the wide chamber below. Left wall (col 4) sits under the house
# (cols 2..8); right wall col 16. 13 cols wide.
const BODY_COL_LO: int = 4        # inclusive
const BODY_COL_HI: int = 16       # inclusive (13 wide)
const SHOULDER_ROWS: int = 6      # rows NECK_ROWS+1 .. +SHOULDER_ROWS flare open
const ROWS_AHEAD: int = 30
const BLOCK_DIR: String = "res://resources/blocks/"
const BLOCK_SIZE: Vector2 = Vector2(48, 48)
const SURFACE_HEIGHT_PX: float = 96.0

@onready var surface_visual: Node2D = $Surface
@onready var grid_root: Node2D = $Grid
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D

var block_types: Array[BlockType] = []
var bedrock_type: BlockType
var rng := RandomNumberGenerator.new()
var generated_rows: int = 0
var blocks_by_pos: Dictionary = {}  # Vector2i -> DigBlock
var broken_cells: Dictionary = {}   # Vector2i -> true

signal deepest_changed(row: int)
# Emitted each frame while digging: how deep the player is and whether the
# remaining day time is enough to climb back to the surface to deposit.
# danger 0 = safe, 1 = cutting it close, 2 = you probably won't make it.
signal return_status(player_depth: int, danger: int)

# Rough seconds it takes the player to climb back up one row of depth.
const RETURN_SEC_PER_ROW: float = 0.9

func _ready() -> void:
	rng.randomize()
	_load_block_types()
	_generate_rows(ROWS_AHEAD)
	_spawn_player_at_surface()
	GameState.day_started.connect(_on_day_started)
	GameState.world_reset_requested.connect(_on_world_reset)
	GameState.phase_changed.connect(_on_phase_changed)
	# Defer initial activation by one frame so cameras can resolve cleanly.
	call_deferred("_initial_phase_check")

func _process(_delta: float) -> void:
	# Only meaningful while actively digging.
	if GameState.phase != GameState.Phase.DIGGING or GameState.day_paused:
		return
	if player == null:
		return
	# Player depth in rows below the surface (0 = at/above surface).
	var depth: int = max(0, int(floor(player.global_position.y / BLOCK_SIZE.y)) + 1)
	var danger: int = 0
	if depth > 0:
		var needed: float = float(depth) * RETURN_SEC_PER_ROW
		var left: float = GameState.time_left
		if left < needed:
			danger = 2          # probably won't make it back
		elif left < needed * 1.5:
			danger = 1          # cutting it close
	return_status.emit(depth, danger)

func _initial_phase_check() -> void:
	_on_phase_changed(GameState.phase)

func activate() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_spawn_player_at_surface()
	if camera != null:
		camera.make_current()

func deactivate() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func _on_phase_changed(p: int) -> void:
	if p == GameState.Phase.DIGGING:
		activate()
	else:
		deactivate()

func _on_world_reset() -> void:
	_regenerate_world()

func _regenerate_world() -> void:
	for child in grid_root.get_children():
		child.queue_free()
	blocks_by_pos.clear()
	broken_cells.clear()
	generated_rows = 0
	_generate_rows(ROWS_AHEAD)
	_spawn_player_at_surface()

func _spawn_player_at_surface() -> void:
	# Spawn standing on the surface directly over the neck, so digging straight
	# down drops the player into the bottle. (House is to the left; the neck is
	# the mouth of the shaft just past the back yard.)
	var neck_center_x := (float(NECK_COL_LO + NECK_COL_HI) + 1.0) * 0.5 * BLOCK_SIZE.x
	player.reset_to(Vector2(neck_center_x, -24))

func _on_day_started(day: int) -> void:
	# Day 1 = initial _ready() handles spawn; subsequent days regenerate the grid.
	if day > 1:
		_regenerate_world()
	else:
		_spawn_player_at_surface()

func _load_block_types() -> void:
	block_types.clear()
	bedrock_type = null
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
				if res.indestructible:
					bedrock_type = res
				else:
					block_types.append(res)
		file = dir.get_next()
	dir.list_dir_end()

# Strata signage: name + the row depth where the layer begins. Painted on the
# bedrock wall just left of the dig strip as the player descends past each one.
# Plain names for now (flavor pass later).
const LAYER_MARKERS := [
	{"depth": 1, "name": "Topsoil"},
	{"depth": 2, "name": "Dirt"},
	{"depth": 5, "name": "Stone Layer"},
	{"depth": 8, "name": "Coal Seam"},
	{"depth": 20, "name": "Iron Vein"},
	{"depth": 40, "name": "Gem Depths"},
]

func _generate_rows(count: int) -> void:
	for i in count:
		_generate_row(generated_rows + 1)
		_maybe_place_layer_marker(generated_rows + 1)
		generated_rows += 1

# Inclusive [lo, hi] range of diggable columns at a given depth row. Outside this
# span is bedrock. The profile is a bottle: a narrow neck near the surface that
# flares open into a wide cavern below.
func _dig_span_for_row(row: int) -> Vector2i:
	if row <= NECK_ROWS:
		return Vector2i(NECK_COL_LO, NECK_COL_HI)
	if row <= NECK_ROWS + SHOULDER_ROWS:
		var t := float(row - NECK_ROWS) / float(SHOULDER_ROWS)  # 0..1 across shoulder
		var lo := int(round(lerp(float(NECK_COL_LO), float(BODY_COL_LO), t)))
		var hi := int(round(lerp(float(NECK_COL_HI), float(BODY_COL_HI), t)))
		return Vector2i(lo, hi)
	return Vector2i(BODY_COL_LO, BODY_COL_HI)

func _generate_row(row: int) -> void:
	var span := _dig_span_for_row(row)
	for col in GRID_COLS:
		var type: BlockType = null
		if col >= span.x and col <= span.y:
			type = _pick_block_type_for_depth(row)
		else:
			type = bedrock_type
		if type == null:
			continue
		var block: DigBlock = BlockScene.instantiate()
		block.setup(type, Vector2i(col, row))
		block.position = Vector2(
			col * BLOCK_SIZE.x + BLOCK_SIZE.x * 0.5,
			(row - 1) * BLOCK_SIZE.y + BLOCK_SIZE.y * 0.5
		)
		grid_root.add_child(block)
		block.click_requested.connect(_on_block_click_requested)
		block.broken.connect(_on_block_broken)
		blocks_by_pos[Vector2i(col, row)] = block

func _maybe_place_layer_marker(row: int) -> void:
	for m in LAYER_MARKERS:
		if int(m["depth"]) != row:
			continue
		var label := Label.new()
		label.text = "%s\n%dm" % [m["name"], row]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72, 0.9))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Sit on the bedrock wall just left of the diggable span at this row's depth.
		var span := _dig_span_for_row(row)
		var wall_right_x := float(span.x) * BLOCK_SIZE.x
		label.position = Vector2(
			wall_right_x - 140.0,
			(row - 1) * BLOCK_SIZE.y + BLOCK_SIZE.y * 0.5 - 14.0
		)
		label.size = Vector2(132, 28)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_root.add_child(label)

# Player digs their own entry now; no pre-broken gap.

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
func try_dig_at(grid_pos: Vector2i, damage: int = 1, aoe: bool = false) -> bool:
	if GameState.day_paused:
		return false
	if GameState.backpack_full():
		return false
	var center_block: DigBlock = blocks_by_pos.get(grid_pos, null)
	if center_block == null:
		return false
	# Center is always indestructible-aware: a single tap on bedrock does nothing.
	if center_block.block_type and center_block.block_type.indestructible:
		# Visual nudge but no damage and no "successful dig" semantics.
		return false
	if aoe:
		_hit_area(grid_pos, damage)
	else:
		_hit_single(center_block, damage)
	return true

func _hit_single(block: DigBlock, damage: int) -> void:
	if block.block_type and block.block_type.indestructible:
		return
	block.hit_n(damage)

func _hit_area(center: Vector2i, damage: int) -> void:
	# Row-only AoE: center + left + right (no vertical spread).
	for dx in [-1, 0, 1]:
		var p: Vector2i = center + Vector2i(dx, 0)
		var b: DigBlock = blocks_by_pos.get(p, null)
		if b == null:
			continue
		if b.block_type and b.block_type.indestructible:
			continue
		b.hit_n(damage)

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
	print("block broken: pos=%s type=%s" % [str(block.grid_pos), str(block.block_type.id)])
	_remove_block(block, true)

func _award_yields_for(type: BlockType) -> void:
	var crit_chance := GameState._sum_effect(Upgrade.Effect.CRIT_CHANCE)
	var crit: float = 1.0
	if crit_chance > 0.0 and randf() < crit_chance:
		crit = 5.0
	var dirt_amt: float = type.dirt_yield * crit
	if dirt_amt > 0.0:
		GameState._add_dirt(dirt_amt)
	# If this block has a money value, it becomes ORE in the backpack
	# (1 ore unit per break, multiplied by crit). Sell happens at end-of-day.
	if type.money_yield > 0.0:
		var ore_count: int = max(1, int(round(crit)))
		GameState.add_ore(type.id, ore_count)

func _maybe_extend_world(broken_row: int) -> void:
	var target := broken_row + ROWS_AHEAD
	if target > generated_rows:
		_generate_rows(target - generated_rows)
	deepest_changed.emit(broken_row)
