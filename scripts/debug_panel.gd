extends PanelContainer

@onready var money_button: Button = $Box/MoneyButton
@onready var skip_button: Button = $Box/SkipButton
@onready var unlock_button: Button = $Box/UnlockButton
@onready var fill_button: Button = $Box/FillButton
@onready var dig_button: Button = $Box/DigButton
@onready var event_picker: OptionButton = $Box/EventPicker
@onready var force_event_button: Button = $Box/ForceEventButton

func _ready() -> void:
	money_button.pressed.connect(_on_money)
	skip_button.pressed.connect(_on_skip)
	unlock_button.pressed.connect(_on_unlock)
	fill_button.pressed.connect(_on_fill)
	dig_button.pressed.connect(_on_go_dig)
	force_event_button.pressed.connect(_on_force_event)
	_populate_events()

func _populate_events() -> void:
	# Item 0 = force an ordinary (no-event) day; then one entry per DayEvent, with
	# the event id stored as item metadata so we can force it exactly.
	event_picker.clear()
	event_picker.add_item("(no event)")
	event_picker.set_item_metadata(0, &"")
	for e in GameState.day_events:
		var label: String = e.title if e.title != "" else String(e.id)
		event_picker.add_item(label)
		event_picker.set_item_metadata(event_picker.item_count - 1, e.id)

func _on_go_dig() -> void:
	# Skip the walk through the house and jump straight to digging.
	GameState.set_phase(GameState.Phase.DIGGING)

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
	# Big total_money_earned so every upgrade unlocks. Unlock the City so helpers
	# are available. Grant spendable cash. Trigger milestone checks too.
	GameState.total_money_earned = max(GameState.total_money_earned, 1e9)
	GameState.money += 100000.0
	GameState.city_unlocked = true
	GameState._check_milestones()
	GameState.money_changed.emit(GameState.money)

func _on_fill() -> void:
	# Top off the backpack to cap with dirt for testing the deposit flow.
	var cap: float = GameState.backpack_capacity()
	var room: float = cap - GameState.carried_total()
	if room > 0.0:
		GameState._add_dirt(room)

func _on_force_event() -> void:
	# Force the selected special day (or "no event") and roll straight into a new
	# day so the morning announce + all day modifiers apply through the real pipe.
	var idx: int = event_picker.selected
	if idx < 0:
		idx = 0
	var event_id: StringName = event_picker.get_item_metadata(idx)
	GameState.force_next_event(event_id)
	# start_next_day() advances the day and applies the forced event through the
	# real pipeline (gift, day-length, announce, modifiers). If we're mid-dig,
	# end the day first so we're not starting a day from inside one.
	if GameState.phase == GameState.Phase.DIGGING:
		GameState.skip_to_end_of_day()
	GameState.start_next_day()
