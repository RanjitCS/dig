class_name Interactable
extends Area2D

@export var prompt_text: String = "[E]"
@export var enabled: bool = true

signal interacted

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false
	prompt_label.text = prompt_text

func set_prompt(text: String) -> void:
	prompt_text = text
	if is_node_ready():
		prompt_label.text = text

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_in_range = true
		_refresh_prompt()

func _on_body_exited(body: Node) -> void:
	if body is Player:
		_player_in_range = false
		_refresh_prompt()

func _refresh_prompt() -> void:
	prompt_label.visible = _player_in_range and enabled

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or not enabled:
		return
	if event.is_action_pressed("interact"):
		interacted.emit()
		get_viewport().set_input_as_handled()
