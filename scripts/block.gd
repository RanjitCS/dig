class_name DigBlock
extends Node2D

const SIZE: Vector2 = Vector2(48, 48)

signal click_requested(block: DigBlock)
signal broken(block: DigBlock)

var block_type: BlockType
var hits_remaining: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var _chosen_texture: Texture2D = null  # picked once at setup so it doesn't flicker

@onready var sprite: Sprite2D = $Sprite
@onready var collider: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var hit_area: Area2D = $HitArea
@onready var crack_label: Label = $CrackLabel
@onready var fallback_rect: ColorRect = $FallbackRect
@onready var crack_overlay: CrackOverlay = $CrackOverlay

# Optional hand-drawn crack overlays, loaded once and shared by every block.
# index 1 = light, index 2 = heavy. Missing files -> procedural cracks are drawn.
const CRACK_DIR: String = "res://resources/blocks/"
static var _crack_textures: Array[Texture2D] = []
static var _crack_textures_loaded: bool = false

static func _load_crack_textures() -> Array[Texture2D]:
	if _crack_textures_loaded:
		return _crack_textures
	_crack_textures_loaded = true
	# [0]=unused, [1]=light, [2]=heavy. Build typed so the static var stays Array[Texture2D].
	_crack_textures.clear()
	_crack_textures.append(null)
	_crack_textures.append(null)
	_crack_textures.append(null)
	for stage in [1, 2]:
		var path := "%scrack_%d.png" % [CRACK_DIR, stage]
		if ResourceLoader.exists(path):
			_crack_textures[stage] = load(path)
	return _crack_textures

func setup(type: BlockType, pos: Vector2i) -> void:
	block_type = type
	grid_pos = pos
	hits_remaining = type.hits_to_break
	_chosen_texture = type.pick_texture()  # locks one variant for this block
	if is_node_ready():
		_apply_visuals()

func _ready() -> void:
	hit_area.input_event.connect(_on_hit_area_input)
	if block_type != null:
		_apply_visuals()

func _apply_visuals() -> void:
	if _chosen_texture != null:
		sprite.texture = _chosen_texture
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Scale the texture to fill the cell. Use the EXACT ratio with no overlap
		# fudge: a clean integer scale (16->48 = 3.0x) keeps every source pixel the
		# same size on screen so the tile stays crisp. The old 1.04 "seam bleed"
		# made the scale fractional (3.12x), which smears pixels under Nearest.
		var tex_size: Vector2 = _chosen_texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			sprite.scale = Vector2(SIZE.x / tex_size.x, SIZE.y / tex_size.y)
		sprite.visible = true
		fallback_rect.visible = false
	else:
		sprite.visible = false
		fallback_rect.visible = true
		fallback_rect.color = block_type.color if block_type else Color(0.4, 0.3, 0.2)
		fallback_rect.size = SIZE
		fallback_rect.position = -SIZE * 0.5
	# Configure the crack overlay: hand-drawn textures if present, else procedural,
	# with a per-cell seed so each block's cracks are stable and slightly unique.
	var seed_value: int = grid_pos.x * 73856093 ^ grid_pos.y * 19349663
	crack_overlay.configure(_load_crack_textures(), seed_value)
	_update_crack()

func hit_n(damage: int) -> void:
	# Apply 'damage' HP to this block. Broken when HP reaches 0.
	if block_type == null or damage <= 0:
		return
	if block_type.indestructible:
		_flash()
		return
	hits_remaining -= damage
	if hits_remaining <= 0:
		broken.emit(self)
	else:
		_update_crack()
		_flash()

# Legacy alias: callers using old API.
func hit_once() -> void:
	hit_n(1)

func _update_crack() -> void:
	# Damage now reads as worsening cracks (CrackOverlay), not a number.
	crack_label.text = ""
	if crack_overlay == null:
		return
	if block_type == null or block_type.indestructible:
		crack_overlay.set_stage(0)
		return
	var stage := _damage_stage()
	crack_overlay.set_stage(stage)

# 0 = pristine, 1 = light cracks (past ~1/3 damage), 2 = heavy (past ~2/3 damage).
func _damage_stage() -> int:
	var maxhp: int = block_type.hits_to_break
	if maxhp <= 0:
		return 0
	var frac: float = float(hits_remaining) / float(maxhp)  # 1.0 = full, 0.0 = dead
	if frac > 0.66:
		return 0
	if frac > 0.33:
		return 1
	return 2

func _flash() -> void:
	var target: CanvasItem = sprite if sprite.visible else fallback_rect
	target.modulate = Color(1.4, 1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(target, "modulate", Color(1, 1, 1), 0.12)

func _on_hit_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			click_requested.emit(self)
