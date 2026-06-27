class_name DepositStation
extends Area2D

signal pile_changed(amount: float)
signal prompt_visible_changed(visible: bool)

@onready var marker: ColorRect = $Marker
@onready var prompt_label: Label = $PromptLabel
@onready var pile_visual: ColorRect = $PileVisual

var _player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.deposited_changed.connect(_on_deposited_changed)
	GameState.dirt_changed.connect(_on_dirt_changed)
	prompt_label.visible = false
	_refresh_pile_visual()

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_in_range = true
		_refresh_prompt()

func _on_body_exited(body: Node) -> void:
	if body is Player:
		_player_in_range = false
		_refresh_prompt()

func _on_dirt_changed(_v: float) -> void:
	_refresh_prompt()

func _on_deposited_changed(_v: float) -> void:
	_refresh_pile_visual()

func _refresh_prompt() -> void:
	var show := _player_in_range and GameState.dirt > 0.0
	prompt_label.visible = show
	prompt_visible_changed.emit(show)

func _refresh_pile_visual() -> void:
	# Pile grows in height as dirt accumulates. Cap visual at ~80 px tall.
	var h: float = clamp(GameState.deposited_dirt * 0.5, 4.0, 80.0)
	pile_visual.size = Vector2(64, h)
	pile_visual.position = Vector2(-32, -h)
	pile_visual.visible = GameState.deposited_dirt > 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if not event.is_action_pressed("interact"):
		return
	if GameState.dirt <= 0.0:
		return
	var moved := GameState.deposit_carried()
	pile_changed.emit(GameState.deposited_dirt)
	get_viewport().set_input_as_handled()
