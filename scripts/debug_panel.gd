extends PanelContainer

@onready var money_button: Button = $Box/MoneyButton
@onready var skip_button: Button = $Box/SkipButton
@onready var unlock_button: Button = $Box/UnlockButton
@onready var fill_button: Button = $Box/FillButton

func _ready() -> void:
	money_button.pressed.connect(_on_money)
	skip_button.pressed.connect(_on_skip)
	unlock_button.pressed.connect(_on_unlock)
	fill_button.pressed.connect(_on_fill)

func _on_money() -> void:
	# Route through _add_money so milestones, totals, and signals all update correctly.
	GameState._add_money(1000.0)

func _on_skip() -> void:
	# Force the day to end immediately, going through the normal pipe.
	if GameState.phase == GameState.Phase.DIGGING:
		GameState.time_left = 0.0
	else:
		# Already in house or end-of-day; force end-of-day flow.
		GameState.skip_to_end_of_day()

func _on_unlock() -> void:
	# Big total_money_earned so every upgrade unlocks. Trigger milestone checks too.
	GameState.total_money_earned = max(GameState.total_money_earned, 1e9)
	GameState._check_milestones()
	GameState.money_changed.emit(GameState.money)

func _on_fill() -> void:
	# Top off the backpack to cap with dirt for testing the deposit flow.
	var cap: float = GameState.backpack_capacity()
	var room: float = cap - GameState.carried_total()
	if room > 0.0:
		GameState._add_dirt(room)
