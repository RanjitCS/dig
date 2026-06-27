extends CanvasLayer

const TYPE_SPEED_CPS: float = 40.0  # characters per second

@onready var title_label: Label = %TitleLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var continue_button: Button = %ContinueButton
@onready var fast_button: Button = %FastButton
@onready var skip_button: Button = %SkipButton

var _full_body: String = ""
var _revealed_chars: float = 0.0
var _is_typing: bool = false

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue)
	fast_button.pressed.connect(_on_fast)
	skip_button.pressed.connect(_on_skip)
	GameState.cutscene_triggered.connect(_on_cutscene_triggered)

func _on_cutscene_triggered(scene: Cutscene) -> void:
	title_label.text = scene.title
	_full_body = scene.body
	body_label.text = ""
	body_label.visible_characters = 0
	_revealed_chars = 0.0
	_is_typing = true
	continue_button.disabled = true
	visible = true
	body_label.text = _full_body
	body_label.visible_characters = 0

func _process(delta: float) -> void:
	if not _is_typing:
		return
	_revealed_chars += TYPE_SPEED_CPS * delta
	var target: int = int(_revealed_chars)
	if target >= _full_body.length():
		body_label.visible_characters = -1  # show all
		_is_typing = false
		continue_button.disabled = false
	else:
		body_label.visible_characters = target

func _on_fast() -> void:
	# Instantly reveal all the text. Continue becomes available.
	_is_typing = false
	body_label.visible_characters = -1
	continue_button.disabled = false

func _on_continue() -> void:
	visible = false

func _on_skip() -> void:
	# Close without finishing the read. Cutscene is already marked triggered.
	visible = false
