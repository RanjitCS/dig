extends Control

const BlockScene := preload("res://scenes/block.tscn")
const GRID_COLS: int = 12
const ROWS_AHEAD: int = 30  # generate this many rows ahead of deepest visible
const BLOCK_DIR: String = "res://resources/blocks/"

@onready var surface: ColorRect = %Surface
@onready var grid: Control = %Grid
@onready var camera_target: Node = self  # we'll move grid manually for scroll

var block_types: Array[BlockType] = []
var rng := RandomNumberGenerator.new()
var generated_rows: int = 0
var blocks_by_pos: Dictionary = {}  # Vector2i -> Block

signal deepest_changed(row: int)

func _ready() -> void:
	rng.randomize()
	_load_block_types()
	_generate_rows(ROWS_AHEAD)

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
		block.position = Vector2(col * DigBlock.SIZE.x, (row - 1) * DigBlock.SIZE.y)
		grid.add_child(block)
		block.broken.connect(_on_block_broken)
		blocks_by_pos[Vector2i(col, row)] = block

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

func _on_block_broken(block: DigBlock) -> void:
	blocks_by_pos.erase(block.grid_pos)
	_maybe_extend_world(block.grid_pos.y)

func _maybe_extend_world(broken_row: int) -> void:
	# Keep at least ROWS_AHEAD rows beyond the deepest broken block.
	var target := broken_row + ROWS_AHEAD
	if target > generated_rows:
		_generate_rows(target - generated_rows)
	deepest_changed.emit(broken_row)

func deepest_broken_row() -> int:
	# Approx: scan blocks_by_pos for the smallest existing row, infer broken depth.
	# Simpler: track explicitly elsewhere if needed.
	return generated_rows - ROWS_AHEAD
