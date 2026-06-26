class_name Block
extends Control

const SIZE: Vector2 = Vector2(48, 48)

signal broken(block: Block)

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

func _ready() -> void:
	rect.color = block_type.color
	rect.size = SIZE
	_update_crack()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_hit()

func _hit() -> void:
	var click_dirt_bonus := GameState._sum_effect(Upgrade.Effect.CLICK_DIRT)
	var dmg: int = 1 + int(click_dirt_bonus)
	hits_remaining -= dmg
	if hits_remaining <= 0:
		_apply_yields_and_break()
	else:
		_update_crack()
		_flash()

func _apply_yields_and_break() -> void:
	var crit_chance := GameState._sum_effect(Upgrade.Effect.CRIT_CHANCE)
	var crit := 1.0
	if crit_chance > 0.0 and randf() < crit_chance:
		crit = 5.0
	var money_mult := 1.0 + GameState._sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)
	GameState._add_dirt(block_type.dirt_yield * crit)
	if block_type.money_yield > 0.0:
		GameState._add_money(block_type.money_yield * crit * money_mult)
	broken.emit(self)
	queue_free()

func _update_crack() -> void:
	if block_type.hits_to_break <= 1:
		crack_label.text = ""
		return
	crack_label.text = "%d" % hits_remaining

func _flash() -> void:
	var original := rect.color
	rect.modulate = Color(1.4, 1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(rect, "modulate", Color(1, 1, 1), 0.12)
