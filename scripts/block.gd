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
		sprite.visible = true
		fallback_rect.visible = false
	else:
		sprite.visible = false
		fallback_rect.visible = true
		fallback_rect.color = block_type.color if block_type else Color(0.4, 0.3, 0.2)
		fallback_rect.size = SIZE
		fallback_rect.position = -SIZE * 0.5
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
	if block_type == null or block_type.indestructible or block_type.hits_to_break <= 1:
		crack_label.text = ""
		return
	crack_label.text = "%d" % hits_remaining

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
