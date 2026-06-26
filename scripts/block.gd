class_name DigBlock
extends Control

const SIZE: Vector2 = Vector2(48, 48)

signal click_requested(block: DigBlock)
signal broken(block: DigBlock)

var block_type: BlockType
var hits_remaining: int = 0
var grid_pos: Vector2i = Vector2i.ZERO

@onready var rect: ColorRect = $Rect
@onready var crack_label: Label = $CrackLabel

func setup(type: BlockType, pos: Vector2i) -> void:
	block_type = type
	grid_pos = pos
	hits_remaining = type.hits_to_break
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_node_ready():
		_apply_visuals()

func _ready() -> void:
	if block_type != null:
		_apply_visuals()

func _apply_visuals() -> void:
	rect.color = block_type.color
	rect.size = SIZE
	_update_crack()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			click_requested.emit(self)

func hit_once() -> void:
	if block_type == null:
		return
	var click_dirt_bonus := GameState._sum_effect(Upgrade.Effect.CLICK_DIRT)
	var dmg: int = 1 + int(click_dirt_bonus)
	hits_remaining -= dmg
	if hits_remaining <= 0:
		broken.emit(self)
	else:
		_update_crack()
		_flash()

func _update_crack() -> void:
	if block_type == null or block_type.hits_to_break <= 1:
		crack_label.text = ""
		return
	crack_label.text = "%d" % hits_remaining

func _flash() -> void:
	rect.modulate = Color(1.4, 1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(rect, "modulate", Color(1, 1, 1), 0.12)
